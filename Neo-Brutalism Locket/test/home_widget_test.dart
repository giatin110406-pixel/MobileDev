import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/widget/widget_bridge.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';
import 'package:neo_brutalism_locket/features/widget/widget_updater.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test.dart' show FakeAuth, FakeProfiles;
import 'fakes_backend.dart';
import 'friends_test.dart' show FakeFriends, FakePostsRepository;
import 'push_test.dart' show FakePrefs, FakePush;
import 'safety_test.dart' show FakeSafety;

const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
const post1 = '33333333-3333-4333-8333-333333333333';
const post2 = '44444444-4444-4444-8444-444444444444';

class FakeBridge implements WidgetBridge {
  final shown = <(WidgetPost, String)>[];

  /// The source each entry of [shown] was for.
  final shownFor = <String>[];
  var cleared = 0;
  Iterable<String> clearedSources = const [];

  /// What the placed widgets follow, besides everybody.
  Set<String> active = {};
  List<WidgetChoice> choices = [];

  @override
  Future<void> show(
    WidgetPost post,
    String imagePath, {
    String source = allSource,
  }) async {
    shown.add((post, imagePath));
    shownFor.add(source);
  }

  @override
  Future<void> clear({Iterable<String> sources = const []}) async {
    cleared++;
    clearedSources = sources.toList();
  }

  @override
  Future<Set<String>> activeSources() async => active;

  @override
  Future<void> publishChoices(List<WidgetChoice> choices) async =>
      this.choices = choices;
}

class FakeUrls implements MediaUrls {
  FakeUrls({this.offline = false});

  /// No link for anything: screens show their placeholder, nothing is loaded.
  final bool offline;
  final asked = <String>[];

  @override
  Future<String?> resolve(String bucket, String path) async {
    asked.add('$bucket/$path');
    return offline ? null : 'https://files.test/$bucket/$path';
  }
}

RemotePost post(
  String id,
  String author, {
  int minute = 0,
  String caption = '',
  String kind = 'photo',
  String? thumb = 'thumb.jpg',
}) => RemotePost(
  id: id,
  authorId: author,
  kind: kind,
  mediaPath: '$author/$id.jpg',
  thumbPath: thumb == null ? null : '$author/$id/$thumb',
  caption: caption,
  createdAt: DateTime.utc(2026, 10, 7, 12, minute),
);

Map<String, String> pushData({
  String id = post1,
  String name = 'Ava',
  String url = 'https://files.test/img.jpg',
  String created = '1000',
}) => {
  'type': 'widget_update',
  'post_id': id,
  'name': name,
  'caption': 'Lunch',
  'image_url': url,
  'created_at': created,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what a push says', () {
    test('a good message becomes a widget post', () {
      final post = parseWidgetData(pushData())!;
      expect(post.postId, post1);
      expect(post.name, 'Ava');
      expect(post.caption, 'Lunch');
      expect(post.createdAtMs, 1000);
      expect(post.imageUrl, 'https://files.test/img.jpg');
    });

    test('anything else is ignored', () {
      expect(parseWidgetData(null), isNull);
      expect(parseWidgetData({'type': 'message'}), isNull);
      expect(parseWidgetData({...pushData(), 'post_id': ''}), isNull);
      expect(parseWidgetData({...pushData(), 'image_url': ''}), isNull);
      expect(
        parseWidgetData({...pushData(), 'image_url': 'http://insecure/x.jpg'}),
        isNull,
        reason: 'only https links',
      );
      expect(
        parseWidgetData({...pushData(), 'image_url': 'file:///etc/passwd'}),
        isNull,
      );
    });

    test('a missing date becomes 0', () {
      expect(
        parseWidgetData({...pushData(), 'created_at': 'x'})!.createdAtMs,
        0,
      );
    });
  });

  group('which photo the widget shows', () {
    final friends = {A};

    test('the newest from a friend, not mine and not a stranger\'s', () {
      final posts = [
        post('mine', B, minute: 5),
        post('stranger', 'zzz', minute: 4),
        post('theirs', A, minute: 3),
        post('older', A, minute: 1),
      ];
      expect(
        latestFriendPost(posts, myId: B, friendIds: friends)?.id,
        'theirs',
      );
    });

    test('a video without a still is skipped; with a still it is fine', () {
      final posts = [
        post('clip', A, minute: 3, kind: 'video', thumb: null),
        post('clip2', A, minute: 2, kind: 'video'),
        post('photo', A, minute: 1),
      ];
      expect(latestFriendPost(posts, myId: B, friendIds: friends)?.id, 'clip2');
      expect(
        latestFriendPost(posts.sublist(0, 1), myId: B, friendIds: friends),
        isNull,
      );
    });

    test('nothing to show when there are no friend posts', () {
      expect(latestFriendPost([], myId: B, friendIds: friends), isNull);
      expect(
        latestFriendPost([post('mine', B)], myId: B, friendIds: friends),
        isNull,
      );
    });
  });

  group('links from the widget', () {
    test('a post link gives the id', () {
      expect(postIdFromLink(Uri.parse(postLinkFor(post1))), post1);
      expect(postLinkFor(post1), 'neolocket://post/$post1');
      expect(
        postIdFromLink(Uri.parse('neolocket://post/${post1.toUpperCase()}')),
        post1,
      );
    });

    test('other links are not post links', () {
      for (final bad in [
        'neolocket://add/ava',
        'neolocket://post/',
        'neolocket://post/not-a-uuid',
        'neolocket://post/$post1/extra',
        'https://post/$post1',
      ]) {
        expect(postIdFromLink(Uri.parse(bad)), isNull, reason: bad);
      }
    });
  });

  group('updating the widget', () {
    late Directory dir;
    late FakeBridge bridge;
    late List<Uri> downloads;
    var status = 200;

    WidgetUpdater updater() => WidgetUpdater(
      bridge: bridge,
      directory: () async => dir,
      client: MockClient((request) async {
        downloads.add(request.url);
        return http.Response.bytes([1, 2, 3, 4], status);
      }),
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('widget_test');
      bridge = FakeBridge();
      downloads = [];
      status = 200;
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('a push downloads the picture, saves it and shows it', () async {
      expect(await updater().applyData(pushData()), isTrue);
      expect(downloads.single.toString(), 'https://files.test/img.jpg');
      final (shown, path) = bridge.shown.single;
      expect(shown.name, 'Ava');
      expect(File(path).readAsBytesSync(), [1, 2, 3, 4]);
    });

    test('junk or a failed download changes nothing', () async {
      expect(await updater().applyData({'type': 'message'}), isFalse);
      status = 500;
      expect(await updater().applyData(pushData()), isFalse);
      expect(bridge.shown, isEmpty);
    });

    test('the same post is not downloaded twice', () async {
      final u = updater();
      expect(await u.applyData(pushData()), isTrue);
      expect(await u.applyData(pushData()), isFalse);
      expect(downloads, hasLength(1));
    });

    test('a newer post replaces it and the old file is removed', () async {
      final u = updater();
      await u.applyData(pushData(created: '1000'));
      final first = bridge.shown.single.$2;
      await u.applyData(pushData(id: post2, created: '2000', name: 'Bo'));
      expect(bridge.shown, hasLength(2));
      expect(bridge.shown.last.$1.name, 'Bo');
      expect(File(first).existsSync(), isFalse);
      expect(File(bridge.shown.last.$2).existsSync(), isTrue);
    });

    test(
      'a message that arrives late cannot bring back an older photo',
      () async {
        final u = updater();
        await u.applyData(pushData(id: post2, created: '2000'));
        expect(
          await u.applyData(pushData(id: post1, created: '1000')),
          isFalse,
        );
        expect(bridge.shown, hasLength(1));
      },
    );

    test('loading the feed shows the newest friend photo, once', () async {
      final urls = FakeUrls();
      final u = updater();
      final posts = [
        post(post1, A, minute: 5, caption: 'Hi'),
        post(post2, A, minute: 1),
      ];
      await u.refreshFromFeed(
        posts: posts,
        myId: B,
        friendNames: {A: 'Ava Chen'},
        urls: urls,
      );
      expect(urls.asked, ['media/$A/$post1/thumb.jpg']);
      expect(bridge.shown.single.$1.name, 'Ava Chen');
      expect(bridge.shown.single.$1.caption, 'Hi');
      expect(
        bridge.shown.single.$1.createdAtMs,
        DateTime.utc(2026, 10, 7, 12, 5).millisecondsSinceEpoch,
      );
      await u.refreshFromFeed(
        posts: posts,
        myId: B,
        friendNames: {A: 'Ava Chen'},
        urls: urls,
      );
      expect(bridge.shown, hasLength(1), reason: 'nothing new to show');
      expect(downloads, hasLength(1));
    });

    test('signing out empties the widget and deletes the picture', () async {
      final u = updater();
      await u.applyData(pushData());
      final path = bridge.shown.single.$2;
      await u.clear();
      expect(bridge.cleared, 1);
      expect(File(path).existsSync(), isFalse);
      // The same post can be shown again for the next account.
      expect(await u.applyData(pushData()), isTrue);
    });
  });

  group('a widget that follows one friend or one group', () {
    const C = '55555555-5555-4555-8555-555555555555';
    final friends = {A, C};

    test('one friend: only their photos, and only if they are a friend', () {
      final posts = [post('c1', C, minute: 5), post('a1', A, minute: 3)];
      expect(
        latestPostForSource(
          posts,
          friendSource(A),
          myId: B,
          friendIds: friends,
        )?.id,
        'a1',
      );
      expect(
        latestPostForSource(
          posts,
          friendSource('stranger'),
          myId: B,
          friendIds: friends,
        ),
        isNull,
      );
    });

    test(
      'one group: photos of its members only, not mine or other friends',
      () {
        final posts = [
          post('mine', B, minute: 9),
          post('c1', C, minute: 5),
          post('a1', A, minute: 3),
        ];
        final groups = {
          'fam': {A, B},
        };
        expect(
          latestPostForSource(
            posts,
            groupSource('fam'),
            myId: B,
            friendIds: friends,
            groups: groups,
          )?.id,
          'a1',
        );
        expect(
          latestPostForSource(
            posts,
            groupSource('nope'),
            myId: B,
            friendIds: friends,
            groups: groups,
          ),
          isNull,
        );
        expect(
          latestPostForSource(posts, 'x_1', myId: B, friendIds: friends),
          isNull,
          reason: 'an unknown kind of source shows nothing',
        );
      },
    );

    late Directory dir;
    late FakeBridge bridge;
    late List<Uri> downloads;

    WidgetUpdater updater() => WidgetUpdater(
      bridge: bridge,
      directory: () async => dir,
      client: MockClient((request) async {
        downloads.add(request.url);
        return http.Response.bytes([7, 7], 200);
      }),
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('widget_sources');
      bridge = FakeBridge();
      downloads = [];
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    final fam = WidgetGroup(id: 'fam', name: 'Family', memberIds: {A, B});

    test('the picker is told which friends and groups there are', () async {
      await updater().refreshFromFeed(
        posts: const [],
        myId: B,
        friendNames: {A: 'Ava', C: 'Cy'},
        urls: FakeUrls(),
        groups: [fam],
      );
      expect(
        {for (final c in bridge.choices) c.key: c.label},
        {
          friendSource(A): 'Ava',
          friendSource(C): 'Cy',
          groupSource('fam'): 'Family',
        },
      );
    });

    test('pictures are fetched only for sources a widget follows', () async {
      final urls = FakeUrls();
      final posts = [post('c1', C, minute: 5), post('a1', A, minute: 3)];
      await updater().refreshFromFeed(
        posts: posts,
        myId: B,
        friendNames: {A: 'Ava', C: 'Cy'},
        urls: urls,
        groups: [fam],
      );
      expect(bridge.shownFor, [allSource], reason: 'no one follows a friend');
      expect(bridge.shown.single.$1.postId, 'c1');

      bridge.active = {friendSource(A), groupSource('fam')};
      await updater().refreshFromFeed(
        posts: posts,
        myId: B,
        friendNames: {A: 'Ava', C: 'Cy'},
        urls: urls,
        groups: [fam],
      );
      expect(bridge.shownFor.toSet(), {
        allSource,
        friendSource(A),
        groupSource('fam'),
      });
      for (var i = 1; i < bridge.shown.length; i++) {
        expect(bridge.shown[i].$1.postId, 'a1');
        expect(bridge.shown[i].$1.authorId, A);
      }
      expect(
        bridge.shown.map((e) => e.$2).toSet(),
        hasLength(bridge.shown.length),
        reason: 'each source has its own file',
      );
    });

    test('a push reaches the widgets that follow its author', () async {
      final u = updater();
      bridge.active = {friendSource(A), friendSource(C), groupSource('fam')};
      // The group is known from the last time the feed loaded.
      await u.refreshFromFeed(
        posts: const [],
        myId: B,
        friendNames: {A: 'Ava', C: 'Cy'},
        urls: FakeUrls(),
        groups: [fam],
      );
      await u.applyData({...pushData(), 'author_id': A});
      expect(bridge.shownFor.toSet(), {
        allSource,
        friendSource(A),
        groupSource('fam'),
      });
      expect(
        downloads,
        hasLength(1),
        reason: 'the picture is downloaded once and copied',
      );
    });

    test('a push without an author only reaches the main widget', () async {
      bridge.active = {friendSource(A)};
      await updater().applyData(pushData());
      expect(bridge.shownFor, [allSource]);
    });

    test('signing out clears every source and its pictures', () async {
      final u = updater();
      bridge.active = {friendSource(A)};
      await u.refreshFromFeed(
        posts: [post('a1', A)],
        myId: B,
        friendNames: {A: 'Ava'},
        urls: FakeUrls(),
      );
      final files = bridge.shown.map((e) => e.$2).toList();
      expect(files, hasLength(2));
      await u.clear();
      expect(bridge.clearedSources, [friendSource(A)]);
      for (final path in files) {
        expect(File(path).existsSync(), isFalse);
      }
    });
  });

  group('in the app', () {
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

    late Directory dir;
    late FakeBridge bridge;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('widget_shell');
      bridge = FakeBridge();
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    /// Lets the real I/O behind the shell (prefs, files) finish.
    Future<void> settle(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 40 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    Future<AccountSession> pump(
      WidgetTester tester, {
      required List<RemotePost> feed,
      Stream<Uri>? links,
      bool offline = false,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(player.load);
      final auth = FakeAuth();
      final profiles = FakeProfiles(
        profile: const Profile(id: B, username: 'me', displayName: 'Me'),
      );
      final session = AccountSession(
        user: const AuthUser(id: B),
        profile: profiles.profile,
        auth: auth,
        profiles: profiles,
      );
      await tester.pumpWidget(
        app(
          AppShell(
            playerStore: player,
            session: session,
            friendsRepository: FakeFriends(
              friends: [
                Friend(
                  person: const Person(
                    id: A,
                    username: 'ava',
                    displayName: 'Ava Chen',
                  ),
                  since: DateTime(2026),
                ),
              ],
            ),
            postsRepository: FakePostsRepository(feed),
            chatRepository: FakeChat(myId: B),
            interactionsRepository: FakeInteractions(),
            safetyRepository: FakeSafety(),
            settings: AppSettings(),
            push: FakePush(),
            notificationPrefs: FakePrefs(),
            mediaUrls: FakeUrls(offline: offline),
            widgetUpdater: WidgetUpdater(
              bridge: bridge,
              directory: () async => dir,
              client: MockClient((_) async => http.Response.bytes([9, 9], 200)),
            ),
            inviteLinks: links ?? const Stream<Uri>.empty(),
          ),
        ),
      );
      await settle(tester, () => offline || bridge.shown.isNotEmpty);
      return session;
    }

    testWidgets('opening the app puts the newest friend photo on the widget', (
      tester,
    ) async {
      await pump(tester, feed: [post(post1, A, minute: 5, caption: 'Hi')]);
      expect(bridge.shown, hasLength(1));
      expect(bridge.shown.single.$1.postId, post1);
      expect(bridge.shown.single.$1.name, 'Ava Chen');
    });

    testWidgets('no friend photos, nothing on the widget', (tester) async {
      await pump(tester, feed: [post(post1, B)]);
      expect(bridge.shown, isEmpty);
    });

    testWidgets('signing out takes the photo off the home screen', (
      tester,
    ) async {
      final session = await pump(tester, feed: [post(post1, A)]);
      expect(bridge.cleared, 0);
      await tester.runAsync(session.signOut);
      expect(bridge.cleared, 1);
    });

    testWidgets('tapping the widget opens that post', (tester) async {
      final links = Stream<Uri>.value(Uri.parse(postLinkFor(post1)));
      await pump(
        tester,
        feed: [post(post1, A, caption: 'From the widget')],
        links: links,
        offline: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('From the widget'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });
}
