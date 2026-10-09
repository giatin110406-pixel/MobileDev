import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/history/history_logic.dart';
import 'package:neo_brutalism_locket/features/history/history_screen.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/posts/posts_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

RemotePost post(String id, String author, DateTime at, {String? quest}) =>
    RemotePost(
      id: id,
      authorId: author,
      mediaPath: '$author/$id.jpg',
      thumbPath: '$author/${id}_thumb.jpg',
      questId: quest,
      createdAt: at,
    );

/// A server that pages by time like the real one.
class PagingPosts implements PostsRepository {
  PagingPosts(this.all);

  final List<RemotePost> all; // newest first
  var calls = 0;
  bool fail = false;

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) async {
    calls++;
    if (fail) throw const PostsFailure(retryable: true);
    return all
        .where((p) => before == null || p.createdAt.isBefore(before))
        .take(limit)
        .toList();
  }

  @override
  Future<void> send(PendingPost post) async {}

  @override
  Stream<void> get incoming => const Stream<void>.empty();

  @override
  void dispose() {}
}

Widget app(Widget home) => MaterialApp(
  theme: NeoTheme.data,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

void main() {
  final jan3 = DateTime(2026, 1, 3);
  final jan1 = DateTime(2026, 1, 1);
  final dec30 = DateTime(2025, 12, 30);
  final dec2 = DateTime(2025, 12, 2);
  final posts = [
    post('a', 'me', jan3),
    post('b', 'ava', jan1),
    post('c', 'bo', dec30),
    post('d', 'ava', dec2),
  ];

  group('filtering and grouping', () {
    test('all, mine, and one friend', () {
      List<String> ids(HistoryFilter f) => [
        for (final p in filterHistory(posts, myId: 'me', filter: f)) p.id,
      ];
      expect(ids(HistoryFilter.all), ['a', 'b', 'c', 'd']);
      expect(ids(HistoryFilter.mine), ['a']);
      expect(ids(HistoryFilter.from('ava')), ['b', 'd']);
      expect(ids(HistoryFilter.from('nobody')), isEmpty);
    });

    test('months come newest first, each keeping its order', () {
      final months = groupByMonth(posts);
      expect(months.map((m) => m.month), [
        DateTime(2026, 1),
        DateTime(2025, 12),
      ]);
      expect(months[0].posts.map((p) => p.id), ['a', 'b']);
      expect(months[1].posts.map((p) => p.id), ['c', 'd']);
      expect(groupByMonth(const []), isEmpty);
    });

    test('filters compare by friend id', () {
      expect(HistoryFilter.from('x') == HistoryFilter.from('x'), isTrue);
      expect(HistoryFilter.from('x') == HistoryFilter.from('y'), isFalse);
    });
  });

  group('paging', () {
    List<RemotePost> many(int n) => [
      for (var i = 0; i < n; i++)
        post('p$i', 'ava', DateTime(2026, 1, 1).subtract(Duration(hours: i))),
    ];

    test('loadMore adds the next page, without repeats', () async {
      final fake = PagingPosts(many(120));
      final store = PostsStore(fake);
      await store.refresh();
      expect(store.posts, hasLength(50));
      expect(store.hasMore, isTrue);
      await store.loadMore();
      expect(store.posts, hasLength(100));
      expect(store.posts.map((p) => p.id).toSet(), hasLength(100));
      await store.loadMore();
      expect(store.posts, hasLength(120));
      expect(store.hasMore, isFalse, reason: 'last page was short');
      final calls = fake.calls;
      await store.loadMore();
      expect(fake.calls, calls, reason: 'nothing more to ask for');
      store.dispose();
    });

    test('a short first page means there is nothing more', () async {
      final store = PostsStore(PagingPosts(many(5)));
      await store.refresh();
      expect(store.hasMore, isFalse);
      store.dispose();
    });

    test('a failed page keeps the posts and can be retried', () async {
      final fake = PagingPosts(many(120));
      final store = PostsStore(fake);
      await store.refresh();
      fake.fail = true;
      await store.loadMore();
      expect(store.failed, isTrue);
      expect(store.posts, hasLength(50));
      expect(store.hasMore, isTrue);
      fake.fail = false;
      await store.loadMore();
      expect(store.posts, hasLength(100));
      expect(store.failed, isFalse);
      store.dispose();
    });

    test('refresh starts over from the newest page', () async {
      final store = PostsStore(PagingPosts(many(120)));
      await store.refresh();
      await store.loadMore();
      await store.refresh();
      expect(store.posts, hasLength(50));
      expect(store.hasMore, isTrue);
      store.dispose();
    });
  });

  group('history screen', () {
    final ava = const Person(
      id: 'ava',
      username: 'ava',
      displayName: 'Ava Chen',
    ).toPocketFriend();
    final bo = const Person(
      id: 'bo',
      username: 'bo',
      displayName: 'Bo Tran',
    ).toPocketFriend();

    Future<List<(List<String>, int)>> pump(
      WidgetTester tester, {
      List<RemotePost>? list,
      bool failed = false,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <(List<String>, int)>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: HistoryScreen(
              posts: list ?? posts,
              friends: [ava, bo],
              myId: 'me',
              failed: failed,
              onOpen: (shown, index) =>
                  opened.add(([for (final p in shown) p.id], index)),
            ),
          ),
        ),
      );
      await tester.pump();
      return opened;
    }

    testWidgets('shows a section per month and a tile per post', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('JANUARY 2026'), findsOneWidget);
      expect(find.text('DECEMBER 2025'), findsOneWidget);
      expect(find.byType(RemoteImage), findsNWidgets(4));
    });

    testWidgets('a tile opens its post among the filtered ones', (
      tester,
    ) async {
      final opened = await pump(tester);
      await tester.tap(find.byType(RemoteImage).at(2));
      expect(opened.single.$1, ['a', 'b', 'c', 'd']);
      expect(opened.single.$2, 2);
    });

    testWidgets('picking a friend narrows the grid and the viewer list', (
      tester,
    ) async {
      final opened = await pump(tester);
      await tester.tap(find.text('Ava'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsNWidgets(2));
      expect(find.text('DECEMBER 2025'), findsOneWidget);
      await tester.tap(find.byType(RemoteImage).last);
      expect(opened.single.$1, ['b', 'd']);
      expect(opened.single.$2, 1);
    });

    testWidgets('"mine" shows only what I sent', (tester) async {
      await pump(tester);
      await tester.tap(find.text('MINE'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsOneWidget);
      await tester.tap(find.text('ALL'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsNWidgets(4));
    });

    testWidgets('a person with no posts shows the empty message', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Bo'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsOneWidget); // Bo has one post
      await pump(tester, list: const []);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
    });

    testWidgets('a failed load says so instead of looking empty', (
      tester,
    ) async {
      await pump(tester, list: const [], failed: true);
      expect(
        find.textContaining('Could not load your history'),
        findsOneWidget,
      );
    });

    testWidgets('quest posts are marked with a note', (tester) async {
      await pump(tester, list: [post('q', 'me', jan3, quest: 'vg_grapes')]);
      expect(find.text('♪'), findsOneWidget);
    });
  });
}
