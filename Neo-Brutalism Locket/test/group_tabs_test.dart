import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/groups/group_tabs.dart';

Widget host(GroupTabBar bar) => MaterialApp(home: Scaffold(body: bar));

const tabs = [
  GroupTabData(
    label: 'CHAT',
    icon: Icons.chat_bubble_outline,
    color: NeoColors.accent,
    badge: 3,
  ),
  GroupTabData(
    label: 'CANVAS',
    icon: Icons.grid_on,
    color: NeoColors.coral,
    info: '5 INK',
  ),
  GroupTabData(
    label: 'ALBUM',
    icon: Icons.photo_album_outlined,
    color: NeoColors.teal,
  ),
];

void main() {
  testWidgets('each tab shows its label, its news and its badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(GroupTabBar(tabs: tabs, selected: 0, onSelect: (_) {})),
    );
    expect(find.text('CHAT'), findsOneWidget);
    expect(find.text('CANVAS'), findsOneWidget);
    expect(find.text('ALBUM'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'unread count');
    expect(find.text('5 INK'), findsOneWidget);
  });

  testWidgets('no badge for zero, and 100 or more reads 99+', (tester) async {
    await tester.pumpWidget(
      host(
        GroupTabBar(
          tabs: [
            tabs[2],
            const GroupTabData(
              label: 'CHAT',
              icon: Icons.chat,
              color: NeoColors.accent,
              badge: 250,
            ),
          ],
          selected: 0,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('0'), findsNothing);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('the selected tab takes its own colour', (tester) async {
    Color? fillOf(String label) {
      // Two animated boxes wrap a tab; the one with a fill is the inner one.
      final boxes = tester.widgetList<AnimatedContainer>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return boxes
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .single
          .color;
    }

    await tester.pumpWidget(
      host(GroupTabBar(tabs: tabs, selected: 1, onSelect: (_) {})),
    );
    expect(fillOf('CANVAS'), NeoColors.coral);
    expect(fillOf('CHAT'), NeoColors.surface);
    expect(fillOf('ALBUM'), NeoColors.surface);
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    int? picked;
    await tester.pumpWidget(
      host(GroupTabBar(tabs: tabs, selected: 0, onSelect: (i) => picked = i)),
    );
    await tester.tap(find.text('ALBUM'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(picked, 2);
  });
}
