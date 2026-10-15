import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/app/neo_bottom_nav.dart';
import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/camera_experience.dart';
import 'package:neo_brutalism_locket/features/camera/style_pill.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> host(
    WidgetTester tester,
    Widget child,
    ValueChanged<int> change,
  ) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TabSwipeDetector(
          tabCount: 5,
          currentIndex: 2,
          onSwipe: change,
          child: Center(child: child),
        ),
      ),
    ),
  );

  testWidgets('exact distance and short fast flick thresholds', (tester) async {
    final changes = <int>[];
    await host(
      tester,
      Container(width: 300, height: 300, color: Colors.white),
      changes.add,
    );
    final target = find.byType(Container);
    await tester.timedDrag(
      target,
      const Offset(-47, 0),
      const Duration(seconds: 1),
    );
    expect(changes, isEmpty);
    await tester.timedDrag(
      target,
      const Offset(-48, 0),
      const Duration(seconds: 1),
    );
    expect(changes, [3]);
    changes.clear();
    await tester.fling(target, const Offset(-24, 0), 800);
    expect(changes, [3]);
    changes.clear();
    await tester.fling(target, const Offset(-16, 0), 800);
    expect(changes, [3]);
    changes.clear();
    await tester.fling(target, const Offset(-15, 0), 800);
    expect(changes, isEmpty);
  });

  testWidgets('multiple fingers never switch, next single swipe works', (
    tester,
  ) async {
    final changes = <int>[];
    await host(
      tester,
      Container(width: 300, height: 300, color: Colors.white),
      changes.add,
    );
    final center = tester.getCenter(find.byType(Container));
    final first = await tester.startGesture(center, pointer: 1);
    await first.moveBy(const Offset(-25, 0));
    final second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await first.moveBy(const Offset(-90, 0));
    await second.up();
    await first.up();
    expect(changes, isEmpty);
    await tester.drag(find.byType(Container), const Offset(-80, 0));
    expect(changes, [3]);
  });

  testWidgets('style picker keeps swipes even at its edge', (tester) async {
    final changes = <int>[];
    final styles = <StyleType>[];
    await host(
      tester,
      StylePill(value: StyleType.none, onChanged: styles.add),
      changes.add,
    );
    await tester.drag(find.byType(StylePill), const Offset(-80, 0));
    expect(styles, [StyleType.pixel8bit]);
    await tester.drag(find.byType(StylePill), const Offset(80, 0));
    expect(changes, isEmpty);
  });

  testWidgets(
    'before/after consumes edge drags with and without a styled image',
    (tester) async {
      for (final styled in [null, 'styled.jpg']) {
        final changes = <int>[];
        await host(
          tester,
          SizedBox.square(
            dimension: 250,
            child: BeforeAfterView(
              originalPath: 'original.jpg',
              styledPath: styled,
              styleLabel: '8-BIT',
              showStyled: false,
              onChanged: (_) {},
            ),
          ),
          changes.add,
        );
        await tester.drag(find.byType(BeforeAfterView), const Offset(90, 0));
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
      }
    },
  );

  testWidgets('preview scale and slider gestures stay inside their controls', (
    tester,
  ) async {
    final changes = <int>[];
    int scales = 0;
    bool pinched = false;
    await host(
      tester,
      TabSwipeExclusion(
        child: GestureDetector(
          onScaleUpdate: (details) {
            scales++;
            if (details.pointerCount >= 2) pinched = true;
          },
          child: Container(width: 250, height: 250, color: Colors.white),
        ),
      ),
      changes.add,
    );
    await tester.drag(find.byType(Container), const Offset(-90, 0));
    expect(scales, greaterThan(0));
    final center = tester.getCenter(find.byType(Container));
    final left = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 4,
    );
    final right = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 5,
    );
    await left.moveBy(const Offset(-30, 0));
    await right.moveBy(const Offset(30, 0));
    await left.up();
    await right.up();
    expect(pinched, isTrue);
    expect(changes, isEmpty);
    double value = 0.5;
    await host(
      tester,
      Slider(value: value, onChanged: (v) => value = v),
      changes.add,
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    for (var i = 0; i < 100; i++) {
      await drag.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    expect(value, greaterThan(0.5));
    expect(changes, isEmpty);
  });

  testWidgets('vertical scroll and selecting text do not navigate', (
    tester,
  ) async {
    final changes = <int>[];
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await host(
      tester,
      ListView(
        controller: scroll,
        children: List.generate(
          30,
          (i) => SizedBox(height: 60, child: Text('row $i')),
        ),
      ),
      changes.add,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    expect(scroll.offset, greaterThan(0));
    expect(changes, isEmpty);
    await host(
      tester,
      const SelectableText('Select and drag this long piece of text'),
      changes.add,
    );
    await tester.drag(find.byType(SelectableText), const Offset(-90, 0));
    expect(changes, isEmpty);
  });

  testWidgets('separate routes and dialogs do not receive main-menu swipes', (
    tester,
  ) async {
    final changes = <int>[];
    await host(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Container(
                      key: const ValueKey('route'),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              child: const Text('Open route'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  content: SizedBox(
                    key: ValueKey('dialog'),
                    width: 200,
                    height: 100,
                  ),
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ],
        ),
      ),
      changes.add,
    );
    await tester.tap(find.text('Open route'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('route')),
      const Offset(-90, 0),
    );
    expect(changes, isEmpty);
    Navigator.of(tester.element(find.byKey(const ValueKey('route')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('dialog')),
      const Offset(-90, 0),
    );
    expect(changes, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'shell menu swipes, taps and repeated swipes preserve camera state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(player.load);
      await tester.pumpWidget(
        MaterialApp(
          theme: NeoTheme.data,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AppShell(playerStore: player),
        ),
      );
      await tester.pumpAndSettle();
      final camera = tester.state<CameraTabState>(find.byType(CameraTab));
      NeoBottomNav nav() =>
          tester.widget<NeoBottomNav>(find.byType(NeoBottomNav));
      expect(nav().selectedIndex, 0);
      for (var i = 1; i < 5; i++) {
        await tester.drag(find.byType(NeoBottomNav), const Offset(-70, 0));
        await tester.pumpAndSettle();
        expect(nav().selectedIndex, i);
      }
      await tester.drag(find.byType(NeoBottomNav), const Offset(-70, 0));
      expect(nav().selectedIndex, 4);
      for (var i = 3; i >= 0; i--) {
        await tester.drag(find.byType(NeoBottomNav), const Offset(70, 0));
        await tester.pumpAndSettle();
        expect(nav().selectedIndex, i);
      }
      await tester.tap(
        find.descendant(
          of: find.byType(NeoBottomNav),
          matching: find.byIcon(Icons.chat_bubble_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(nav().selectedIndex, 2);
      await tester.tap(find.byTooltip('SHOOT'));
      await tester.pumpAndSettle();
      expect(
        tester.state<CameraTabState>(find.byType(CameraTab)),
        same(camera),
      );
      await tester.pumpWidget(const SizedBox());
      player.dispose();
    },
  );

  testWidgets(
    'all tab colours, pills and large text fit 320px in both languages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final colors = [
        NeoColors.teal,
        NeoColors.purple,
        NeoColors.blue,
        NeoColors.orange,
        NeoColors.pink,
      ];
      for (final labels in [
        ['CHỤP', 'BẠN BÈ', 'HỘP THƯ', 'LỊCH SỬ', 'TÔI'],
        ['SHOOT', 'FRIENDS', 'INBOX', 'HISTORY', 'ME'],
      ]) {
        for (var selected = 0; selected < 5; selected++) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                child: Scaffold(
                  bottomNavigationBar: NeoBottomNav(
                    selectedIndex: selected,
                    onSelected: (_) {},
                    tabs: List.generate(
                      5,
                      (i) => NeoBottomNavTab(
                        label: labels[i],
                        outlineIcon: Icons.person_outline,
                        filledIcon: Icons.person,
                        activeColor: colors[i],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final icon = tester.widget<Icon>(find.byIcon(Icons.person));
          // The selected icon is black on its solid pill.
          expect(icon.color, NeoColors.ink);
          expect(icon.size, 24);
          final pills = tester
              .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
              .toList();
          expect(
            (pills[selected].decoration as BoxDecoration).color,
            colors[selected],
          );
          for (final pill in pills) {
            expect(pill.constraints!.maxWidth, 48);
            expect(pill.constraints!.maxHeight, 32);
          }
        }
      }
    },
  );
}
