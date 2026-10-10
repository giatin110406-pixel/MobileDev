import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/features/profile/profile_screen.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/quest/quest_card.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The new screens must fit a small phone (360 x 640) without overflow.
void main() {
  late PlayerStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PlayerStore(
      repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
    );
  });

  Future<void> small(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(store.load);
    await tester.pumpWidget(
      MaterialApp(
        theme: NeoTheme.data,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );
    await tester.pump();
  }

  testWidgets('profile', (tester) async {
    await small(tester, Scaffold(body: ProfileScreen(store: store)));
    expect(tester.takeException(), isNull);
    expect(find.text('SHOP'), findsOneWidget);
    expect(find.byType(SunbitBadge), findsOneWidget);
  });

  testWidgets('shop, both tabs, and an item sheet', (tester) async {
    await small(tester, ShopScreen(store: store));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('BANNER'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pixel space banner'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('100 SUNBIT SHORT'), findsOneWidget);
  });

  testWidgets('quest sheet', (tester) async {
    await small(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showQuestSheet(context, store),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('START SHOOTING'), findsOneWidget);
    expect(
      find.text(store.todayQuest!.storyTitleFor(vietnamese: false)),
      findsOneWidget,
    );
  });

  testWidgets('camera tab with the status strip, quest strip and 5 tabs', (
    tester,
  ) async {
    await small(tester, AppShell(playerStore: store));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(QuestStrip), findsOneWidget);
    // The viewfinder is just the picture: no LIVE / HOME LAPTOP / n PRINTS chips.
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('HOME LAPTOP'), findsNothing);
    expect(find.text('ON DEVICE'), findsNothing);
    expect(find.textContaining(' PRINTS'), findsNothing);
    expect(find.byType(StreakChip), findsOneWidget);
    expect(find.text('ME'), findsOneWidget);
    // Quest mode: camera only, so the gallery button is gone.
    expect(find.byTooltip('Upload a photo from this device'), findsOneWidget);
    await tester.tap(find.byType(QuestStrip));
    await tester.pumpAndSettle();
    // The story is long: on a small phone the button is below the fold.
    await tester.ensureVisible(find.text('START SHOOTING'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START SHOOTING'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Upload a photo from this device'), findsNothing);
    expect(find.text('QUEST MODE · LIVE CAMERA ONLY'), findsOneWidget);

    // The profile tab.
    await tester.tap(find.text('ME'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ProfileScreen), findsOneWidget);
    // Regression: the page must take the whole area, not collapse to 0 wide.
    final page = tester.getSize(find.byType(ProfileScreen));
    expect(page.width, 360);
    expect(page.height, greaterThan(300));
    expect(find.text('SHOP'), findsOneWidget);

    for (final tab in ['FRIENDS', 'INBOX', 'PRINTS']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final area = tester.getSize(
        find
            .descendant(
              of: find.byType(Scaffold).first,
              matching: find.byType(AnimatedSwitcher),
            )
            .last,
      );
      expect(area.width, 360, reason: tab);
      expect(area.height, greaterThan(300), reason: tab);
    }
  });
}
