import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/banner_art.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/progress/server_player_repository.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'contest_test.dart';
import 'server_player_test.dart' show doc;

/// A server for the player's Sunbit and shop that sells the winning paintings for a
/// limited time.
class FakeShopServer {
  FakeShopServer({int balance = 500, List<String> owned = const []})
    : state = doc(balance: balance, owned: owned);

  Map<String, dynamic> state;
  final calls = <String>[];
  Object? failBuy;

  Future<dynamic> call(String name, Map<String, dynamic>? params) async {
    calls.add('$name:${params?['p_item'] ?? ''}');
    if (name == 'buy_item') {
      final failure = failBuy;
      if (failure != null) throw failure;
      final price = const {
        'contest_e1': 300,
        'contest_e2': 220,
        'contest_e3': 150,
      }[params!['p_item']]!;
      state = doc(
        balance: (state['balance'] as int) - price,
        owned: [
          ...(state['owned'] as List<dynamic>).cast<String>(),
          params['p_item'] as String,
        ],
        banner: state['banner_id'] as String?,
      );
    } else if (name == 'equip_item') {
      state = doc(
        balance: state['balance'] as int,
        owned: (state['owned'] as List<dynamic>).cast<String>(),
        banner: params!['p_item'] as String,
      );
    }
    return state;
  }
}

Future<PlayerStore> storeFor(FakeShopServer server) async {
  final store = PlayerStore(
    repository: ServerPlayerRepository(
      userId: 'me',
      clock: () => DateTime.utc(2026, 10, 1, 5),
      rpc: server.call,
    ),
  );
  await store.load();
  return store;
}

Widget app(Widget child, {FakeContest? contest}) => MaterialApp(
  theme: NeoTheme.data,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: contest == null
      ? child
      : ContestArtScope(cache: ContestArtCache(contest), child: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the limited-time banners in the shop', () {
    final start = DateTime.utc(2026, 10, 1, 5);

    Future<(FakeContest, FakeShopServer, PlayerStore)> open(
      WidgetTester tester, {
      List<GalleryShopItem>? items,
      int balance = 500,
      List<String> owned = const [],
      DateTime Function()? clock,
      bool showBanners = true,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final contest = FakeContest()
        ..shop.addAll(items ?? [shopItemOf(1), shopItemOf(2), shopItemOf(3)]);
      for (final id in ['contest_e1', 'contest_e2', 'contest_e3']) {
        contest.art[id] = bannerArtOf();
      }
      final server = FakeShopServer(balance: balance, owned: owned);
      final store = (await tester.runAsync(() => storeFor(server)))!;
      await tester.pumpWidget(
        app(
          ShopScreen(
            store: store,
            contest: contest,
            clock: clock ?? () => start,
          ),
          contest: contest,
        ),
      );
      await tester.pump();
      await tester.pump();
      if (showBanners) {
        await tester.tap(find.text('BANNER'));
        await tester.pumpAndSettle();
      }
      return (contest, server, store);
    }

    testWidgets('there is no paintings shelf any more', (tester) async {
      await open(tester);
      expect(find.text('PAINTINGS'), findsNothing);
      expect(find.text('AVATAR FRAME'), findsOneWidget);
      expect(find.text('BANNER'), findsOneWidget);
    });

    testWidgets('has no offers without a contest', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = (await tester.runAsync(() => storeFor(FakeShopServer())))!;
      await tester.pumpWidget(app(ShopScreen(store: store)));
      await tester.pump();
      await tester.tap(find.text('BANNER'));
      await tester.pumpAndSettle();
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
    });

    testWidgets('the winners are a limited time offer with a countdown', (
      tester,
    ) async {
      final (contest, _, _) = await open(tester);
      expect(contest.shopLoads, 1);
      expect(find.text('LIMITED TIME OFFER'), findsOneWidget);
      expect(find.text('Group 1'), findsOneWidget);
      expect(find.text('Group 3'), findsOneWidget);
      expect(find.text('Ends in 2d 05:03:09'), findsNWidgets(3));
      expect(find.text('300'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.textContaining('1ST PLACE'), findsOneWidget);
      expect(find.textContaining('Sunflowers'), findsWidgets);
    });

    testWidgets('offers only show on the banner tab', (tester) async {
      await open(tester, showBanners: false);
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
      await tester.tap(find.text('BANNER'));
      await tester.pumpAndSettle();
      expect(find.text('LIMITED TIME OFFER'), findsOneWidget);
      await tester.tap(find.text('AVATAR FRAME'));
      await tester.pumpAndSettle();
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
    });

    testWidgets('a painting banner has the shape of a profile banner', (
      tester,
    ) async {
      await open(tester);
      final banner = find.byWidgetPredicate(
        (w) => w is ProfileBanner && w.bannerId == 'contest_e1',
      );
      final size = tester.getSize(banner);
      expect(size.width / size.height, closeTo(profileBannerAspect, 0.01));
    });

    testWidgets('with nothing on offer the shop is just the shop', (
      tester,
    ) async {
      await open(tester, items: []);
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
    });

    testWidgets('an offer that is already over is not shown', (tester) async {
      await open(
        tester,
        items: [
          shopItemOf(1, endsAt: start.subtract(const Duration(hours: 1))),
        ],
      );
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
      expect(find.text('Group 1'), findsNothing);
    });

    testWidgets('offers that cannot load are left out, the shop still works', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final contest = FakeContest()
        ..failNext = const ContestFailure(ContestFailureKind.network);
      final store = (await tester.runAsync(() => storeFor(FakeShopServer())))!;
      await tester.pumpWidget(
        app(
          ShopScreen(store: store, contest: contest, clock: () => start),
          contest: contest,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('BANNER'));
      await tester.pumpAndSettle();
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the countdown ticks, and the offer vanishes when it ends', (
      tester,
    ) async {
      var now = start;
      final end = start.add(const Duration(seconds: 3));
      await open(
        tester,
        items: [shopItemOf(1, endsAt: end)],
        clock: () => now,
      );
      expect(find.text('Ends in 00:00:03'), findsOneWidget);
      now = start.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Ends in 00:00:02'), findsOneWidget);
      now = end.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('LIMITED TIME OFFER'), findsNothing);
      expect(find.text('Group 1'), findsNothing);
    });

    testWidgets('buying: the server is asked and the item becomes mine', (
      tester,
    ) async {
      final (_, server, store) = await open(tester);
      await tester.tap(find.text('Group 1'));
      await tester.pumpAndSettle();
      expect(find.text('BUY · 300 SUNBIT'), findsOneWidget);
      // The sheet says it is a limited offer and when it ends.
      expect(find.text('LIMITED TIME OFFER'), findsWidgets);
      expect(find.text('Ends in 2d 05:03:09'), findsWidgets);
      expect(find.textContaining('20% of every sale'), findsOneWidget);
      await tester.tap(find.text('BUY · 300 SUNBIT'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('buy_item:contest_e1'));
      expect(store.state!.owns('contest_e1'), isTrue);
      expect(store.balance, 200);
      expect(find.text('EQUIP'), findsOneWidget);

      await tester.tap(find.text('EQUIP'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('equip_item:contest_e1'));
      expect(store.state!.equippedBanner, 'contest_e1');
      expect(find.text('REMOVE'), findsOneWidget);
    });

    testWidgets('not enough Sunbit: says how much is missing, cannot buy', (
      tester,
    ) async {
      final (_, server, _) = await open(tester, balance: 100);
      await tester.tap(find.text('Group 2'));
      await tester.pumpAndSettle();
      expect(find.text('120 SUNBIT SHORT'), findsOneWidget);
      await tester.tap(find.text('120 SUNBIT SHORT'));
      await tester.pump();
      expect(server.calls.where((c) => c.startsWith('buy_item')), isEmpty);
    });

    testWidgets('an offer that ended while the sheet was open is refused', (
      tester,
    ) async {
      final (_, server, store) = await open(tester);
      server.failBuy = PostgrestException(message: 'offer_ended');
      await tester.tap(find.text('Group 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BUY · 300 SUNBIT'));
      await tester.pumpAndSettle();
      expect(store.state!.owns('contest_e1'), isFalse);
      expect(store.balance, 500);
      expect(find.text('This offer has ended.'), findsOneWidget);
    });

    testWidgets('the buy button turns off when the time runs out', (
      tester,
    ) async {
      var now = start;
      final end = start.add(const Duration(seconds: 5));
      final (_, server, _) = await open(
        tester,
        items: [shopItemOf(1, endsAt: end)],
        clock: () => now,
      );
      await tester.tap(find.text('Group 1'));
      await tester.pumpAndSettle();
      expect(find.text('BUY · 300 SUNBIT'), findsOneWidget);
      now = end;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('OFFER ENDED'), findsWidgets);
      expect(find.text('BUY · 300 SUNBIT'), findsNothing);
      await tester.tap(find.text('OFFER ENDED').last);
      await tester.pump();
      expect(server.calls.where((c) => c.startsWith('buy_item')), isEmpty);
    });

    testWidgets('a painting a winner already owns shows as owned', (
      tester,
    ) async {
      await open(
        tester,
        items: [shopItemOf(1, owned: true)],
        owned: const ['contest_e1'],
      );
      expect(find.text('OWNED'), findsOneWidget);
    });
  });

  group('painting banners', () {
    Finder artPainter() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BannerArtPainter,
    );

    testWidgets('are drawn from the painting', (tester) async {
      final contest = FakeContest()..art['contest_e1'] = bannerArtOf();
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: ProfileBanner(bannerId: 'contest_e1', height: 100),
          ),
          contest: contest,
        ),
      );
      expect(artPainter(), findsNothing); // still loading: the plain banner
      await tester.pump();
      await tester.pump();
      expect(artPainter(), findsOneWidget);
      expect(contest.artLoads, 1);
    });

    testWidgets('the same banner on two profiles is fetched once', (
      tester,
    ) async {
      final contest = FakeContest()..art['contest_e1'] = bannerArtOf();
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: Column(
              children: [
                ProfileBanner(bannerId: 'contest_e1', height: 60),
                ProfileBanner(bannerId: 'contest_e1', height: 60),
              ],
            ),
          ),
          contest: contest,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(artPainter(), findsNWidgets(2));
      expect(contest.artLoads, 1);
    });

    testWidgets('fall back to the plain banner when the picture is gone', (
      tester,
    ) async {
      final contest = FakeContest(); // no art at all
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: ProfileBanner(bannerId: 'contest_missing', height: 100),
          ),
          contest: contest,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(artPainter(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and without a scope (an older screen) too', (tester) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: ProfileBanner(bannerId: 'contest_e1', height: 100),
          ),
        ),
      );
      await tester.pump();
      expect(artPainter(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fixed shop banner is not looked up on the server', (
      tester,
    ) async {
      final contest = FakeContest();
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: ProfileBanner(bannerId: 'banner_space', height: 100),
          ),
          contest: contest,
        ),
      );
      await tester.pump();
      expect(contest.artLoads, 0);
    });

    test('copies join up: every other copy is mirrored', () async {
      // A 2x2 painting [[black, red], [red, black]] on a banner 4 cells tall... the
      // tile is as tall as the banner, so a banner of 2 tiles is 2 x its height wide.
      final art = bannerArtOf();
      final painter = BannerArtPainter(art);
      const size = ui.Size(40, 20); // two tiles of 20 x 20, cells of 10
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), size);
      final image = await recorder.endRecording().toImage(40, 20);
      final data = (await image.toByteData())!;
      int argbAt(int x, int y) {
        final i = (y * 40 + x) * 4;
        return 0xFF000000 |
            (data.getUint8(i) << 16) |
            (data.getUint8(i + 1) << 8) |
            data.getUint8(i + 2);
      }

      // The first tile as drawn: top-left black, top-right red.
      expect(argbAt(5, 5), 0xFF000000);
      expect(argbAt(15, 5), 0xFFFF0000);
      // The second tile is mirrored: its top-left is red, top-right black, so the
      // red cells meet at the seam instead of a hard cut.
      expect(argbAt(25, 5), 0xFFFF0000);
      expect(argbAt(35, 5), 0xFF000000);
      image.dispose();
    });
  });
}
