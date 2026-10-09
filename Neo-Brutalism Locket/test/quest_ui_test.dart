import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/music/quest_music.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMusic implements MusicPlayer {
  final log = <String>[];
  String? playing;

  @override
  Future<void> play(String asset) async {
    if (playing == asset) return;
    playing = asset;
    log.add('play $asset');
  }

  @override
  Future<void> stop() async {
    if (playing != null) log.add('stop');
    playing = null;
  }

  @override
  Future<void> dispose() async => stop();
}

void main() {
  final friend = PocketFriend(
    id: 'f1',
    name: 'Ava Chen',
    handle: '@ava',
    avatarColor: 0xFFFF6B6B,
    isSample: true,
    addedAt: DateTime(2026),
  );
  final questPost = FriendPost(
    id: 'q1',
    friendId: 'f1',
    caption: 'Ăn nấm, to gấp đôi!',
    emoji: '🍄',
    color: 0xFF5C94FC,
    createdAt: DateTime(2026, 1, 3),
    questId: 'px_mushroom',
  );
  final plainPost = FriendPost(
    id: 'p1',
    friendId: 'f1',
    caption: 'Morning light',
    emoji: '☀️',
    color: 0xFFFFE66D,
    createdAt: DateTime(2026, 1, 2),
  );

  group('feed music', () {
    Future<FakeMusic> pumpFeed(
      WidgetTester tester,
      List<FeedEntry> entries, {
      bool muted = false,
      ValueChanged<bool>? onMute,
    }) async {
      final music = FakeMusic();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedScreen(
              entries: entries,
              friends: [friend],
              onClose: () {},
              onReplyText: (p, text) async {},
              onReact: (p, emoji) async {},
              onOpenPrint: (_) {},
              musicMuted: muted,
              onMuteChanged: onMute ?? (_) {},
              musicPlayer: music,
            ),
          ),
        ),
      );
      await tester.pump();
      return music;
    }

    testWidgets('a quest post plays its style music while on screen', (
      tester,
    ) async {
      final music = await pumpFeed(tester, [
        FeedEntry.post(questPost),
        FeedEntry.post(plainPost),
      ]);
      expect(music.playing, QuestMusic.trackFor(StyleType.pixel8bit, 'q1'));
      expect(QuestMusic.chiptuneTracks, contains(music.playing));
      expect(find.text('♪ 8-BIT'), findsOneWidget);

      // Swipe to the everyday post: the music stops.
      await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      expect(music.playing, isNull);

      // And back: it plays again.
      await tester.fling(find.byType(PageView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(music.playing, isNotNull);
    });

    testWidgets('everyday posts have no music', (tester) async {
      final music = await pumpFeed(tester, [FeedEntry.post(plainPost)]);
      expect(music.log, isEmpty);
      expect(find.byTooltip('Tắt nhạc'), findsNothing);
    });

    testWidgets('muted: nothing plays; the button asks to unmute', (
      tester,
    ) async {
      bool? asked;
      final music = await pumpFeed(
        tester,
        [FeedEntry.post(questPost)],
        muted: true,
        onMute: (value) => asked = value,
      );
      expect(music.playing, isNull);
      await tester.tap(find.byTooltip('Bật nhạc'));
      expect(asked, isFalse);
    });

    testWidgets('leaving the feed stops the music', (tester) async {
      final music = await pumpFeed(tester, [FeedEntry.post(questPost)]);
      expect(music.playing, isNotNull);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(music.playing, isNull);
    });

    test('van gogh posts get orchestral tracks, 8-bit chiptune', () {
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(
          QuestMusic.vanGoghTracks,
          contains(QuestMusic.trackFor(StyleType.vanGogh, id)),
        );
        expect(
          QuestMusic.chiptuneTracks,
          contains(QuestMusic.trackFor(StyleType.pixel8bit, id)),
        );
      }
    });

    test('a print posted as a quest shows once, as the quest post', () {
      final print = NeoPhoto(
        id: 'photo-1',
        originalPath: 'x.jpg',
        createdAt: DateTime(2026, 1, 1),
        status: ProcessingStatus.done,
      );
      final mine = QuestPost(
        id: 'mine',
        questId: 'vg_grapes',
        photoId: 'photo-1',
        imagePath: 'x.png',
        caption: '',
        style: StyleType.vanGogh,
        createdAt: DateTime(2026, 1, 1, 1),
        day: 1,
      );
      final feed = buildFeed([], [print], questPosts: [mine]);
      expect(feed.single.quest, mine);
      expect(feed.single.musicStyle, StyleType.vanGogh);
    });
  });

  group('shop sheet', () {
    late PlayerStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await store.load();
    });

    Future<void> pumpSheet(WidgetTester tester, ShopItem item) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showShopItemSheet(context, store, item),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('not enough Sunbit: the button is locked and shows the gap', (
      tester,
    ) async {
      await pumpSheet(tester, shopItemById('frame_pixel')!);
      expect(find.text('CÒN THIẾU 50 SUNBIT'), findsOneWidget);
    });

    testWidgets('buying turns the button into TRANG BỊ, then THÁO RA', (
      tester,
    ) async {
      final item = shopItemById('frame_pixel')!;
      await tester.runAsync(() async {
        await store.completeQuest(
          quest: questCatalog.first,
          questDay: store.today,
          photoId: 'p',
          imagePath: '/x.png',
          caption: '',
        );
        final next = PlayerStore(
          repository: PlayerRepository(
            clock: () => DateTime.utc(2026, 10, 2, 5),
          ),
        );
        await next.completeQuest(
          quest: questCatalog.first,
          questDay: next.today,
          photoId: 'p2',
          imagePath: '/x.png',
          caption: '',
        );
        await store.load(); // 50 Sunbit
      });
      expect(store.balance, 50);
      await pumpSheet(tester, item);
      expect(find.text('MUA · 50 SUNBIT'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('MUA · 50 SUNBIT'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(store.balance, 0);
      expect(find.text('TRANG BỊ'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('TRANG BỊ'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(store.state!.equippedFrame, item.id);
      expect(find.text('THÁO RA'), findsOneWidget);
    });
  });

  group('quest strip', () {
    testWidgets('shows the subject and tries left; then out of tries', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(store.load);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: store,
              builder: (context, _) => QuestStrip(store: store, onTap: () {}),
            ),
          ),
        ),
      );
      expect(find.text('Chụp ${store.todayQuest!.subject}'), findsOneWidget);
      expect(tester.widget<AttemptDots>(find.byType(AttemptDots)).left, 3);

      await tester.runAsync(() async {
        for (var i = 0; i < QuestRules.attemptsPerDay; i++) {
          await store.recordFailedAttempt();
        }
      });
      await tester.pump();
      expect(questStatusOf(store), QuestStatus.outOfTries);
      expect(find.text('HẾT LƯỢT'), findsOneWidget);
    });
  });

  testWidgets('the Sunbit badge bounces and shows +N when it goes up', (
    tester,
  ) async {
    Widget badge(int balance) => MaterialApp(
      home: Scaffold(
        body: Center(child: SunbitBadge(balance: balance)),
      ),
    );
    await tester.pumpWidget(badge(0));
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(badge(75));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('+75'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('+75'), findsNothing);
    expect(find.text('75'), findsOneWidget);
  });
}
