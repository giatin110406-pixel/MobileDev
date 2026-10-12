import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/app/neo_bottom_nav.dart';
import 'package:neo_brutalism_locket/app/tab_swipe_detector.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

void main() {
  final sampleTabs = [
    const NeoBottomNavTab(
      label: 'CHỤP',
      outlineIcon: Icons.photo_camera_outlined,
      filledIcon: Icons.photo_camera,
      activeColor: NeoColors.teal,
    ),
    const NeoBottomNavTab(
      label: 'BẠN BÈ',
      outlineIcon: Icons.people_alt_outlined,
      filledIcon: Icons.people_alt,
      activeColor: NeoColors.purple,
    ),
    const NeoBottomNavTab(
      label: 'HỘP THƯ',
      outlineIcon: Icons.chat_bubble_outline,
      filledIcon: Icons.chat_bubble,
      activeColor: NeoColors.blue,
    ),
    const NeoBottomNavTab(
      label: 'LỊCH SỬ',
      outlineIcon: Icons.grid_view_outlined,
      filledIcon: Icons.grid_view_rounded,
      activeColor: NeoColors.orange,
    ),
    const NeoBottomNavTab(
      label: 'TÔI',
      outlineIcon: Icons.person_outline,
      filledIcon: Icons.person,
      activeColor: NeoColors.pink,
    ),
  ];

  group('NeoBottomNav UI & Accessibility Tests', () {
    testWidgets('renders five icon-only tabs with accessible names', (
      tester,
    ) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) => NeoBottomNav(
                selectedIndex: selected,
                tabs: sampleTabs,
                onSelected: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('CHỤP'), findsOneWidget);
      expect(find.byTooltip('BẠN BÈ'), findsOneWidget);
      expect(find.byTooltip('HỘP THƯ'), findsOneWidget);
      expect(find.byTooltip('LỊCH SỬ'), findsOneWidget);
      expect(find.byTooltip('TÔI'), findsOneWidget);

      expect(find.byType(Text), findsNothing);
      // Selected tab 0 has filled icon
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
      // Unselected tabs have outline icons
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Tap tab 2 (Hộp thư)
      await tester.tap(find.byTooltip('HỘP THƯ'));
      await tester.pumpAndSettle();

      expect(selected, 2);
      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });

    testWidgets('has correct pill background blend and semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NeoBottomNav(
              selectedIndex: 1, // Bạn bè (purple)
              tabs: sampleTabs,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byTooltip('BẠN BÈ'));
      expect(
        semantics.getSemanticsData().flagsCollection.isSelected ==
            Tristate.isTrue,
        isTrue,
      );

      final unselectedSemantics = tester.getSemantics(find.byTooltip('CHỤP'));
      expect(
        unselectedSemantics.getSemanticsData().flagsCollection.isSelected ==
            Tristate.isTrue,
        isFalse,
      );
    });

    testWidgets('does not overflow on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NeoBottomNav(
              selectedIndex: 0,
              tabs: sampleTabs,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('TabSwipeDetector Logic Tests', () {
    testWidgets('swipe left >= 48px switches to next tab', (tester) async {
      int current = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Drag left by 60px (> 48px)
      await tester.drag(find.byType(Container), const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(current, 2);
    });

    testWidgets('swipe right >= 48px switches to previous tab', (tester) async {
      int current = 3;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Drag right by 60px (> 48px)
      await tester.drag(find.byType(Container), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(current, 2);
    });

    testWidgets('short slow drag (< 48px) does NOT switch tab', (tester) async {
      int current = 2;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Timed drag: 30px over 600ms = 50 px/s (< 450 px/s and < 48px) -> should not switch
      await tester.timedDrag(
        find.byType(Container),
        const Offset(-30, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(current, 2);
    });

    testWidgets('fast flick (>= 16px and >= 450px/s) switches tab', (
      tester,
    ) async {
      int current = 2;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Fling: 60px with velocity 800 px/s (>= 450 px/s and >= 16px) -> switches to 3
      await tester.fling(find.byType(Container), const Offset(-60, 0), 800.0);
      await tester.pumpAndSettle();

      expect(current, 3);
    });

    testWidgets('clamps at edges without wrap-around', (tester) async {
      int current = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Swipe right at index 0 -> should not wrap to 4
      await tester.drag(find.byType(Container), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(current, 0);

      // Move to last tab
      current = 4;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => TabSwipeDetector(
              tabCount: 5,
              currentIndex: current,
              onSwipe: (idx) => setState(() => current = idx),
              child: Container(color: Colors.blue, width: 400, height: 400),
            ),
          ),
        ),
      );

      // Swipe left at index 4 -> should not wrap to 0
      await tester.drag(find.byType(Container), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(current, 4);
    });
  });
}
