import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/photo_tools_menu.dart';

Widget host(List<PhotoTool> tools) => MaterialApp(
  theme: NeoTheme.data,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: PhotoToolsButton(
          tools: tools,
          title: 'PHOTO TOOLS',
          tooltip: 'Photo tools',
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('with no tools there is no button', (tester) async {
    await tester.pumpWidget(host(const []));
    expect(find.byType(Container), findsNothing);
    expect(find.byIcon(Icons.auto_fix_high), findsNothing);
  });

  testWidgets('the button opens a menu with the heading and every tool, and '
      'picking one runs it', (tester) async {
    final ran = <String>[];
    await tester.pumpWidget(
      host([
        PhotoTool(
          icon: Icons.history_toggle_off,
          label: 'MISCAPTURED?',
          run: () => ran.add('frame'),
        ),
        PhotoTool(
          icon: Icons.crop,
          label: 'CROP',
          run: () => ran.add('crop'),
        ),
      ]),
    );
    expect(find.text('PHOTO TOOLS'), findsNothing);

    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    expect(find.text('PHOTO TOOLS'), findsOneWidget);
    expect(find.text('MISCAPTURED?'), findsOneWidget);
    expect(find.text('CROP'), findsOneWidget);
    expect(ran, isEmpty);

    await tester.tap(find.text('CROP'));
    await tester.pumpAndSettle();
    expect(ran, ['crop']);
    expect(find.text('PHOTO TOOLS'), findsNothing, reason: 'the menu closed');
  });

  testWidgets('tapping outside closes the menu and runs nothing', (
    tester,
  ) async {
    var ran = false;
    await tester.pumpWidget(
      host([
        PhotoTool(
          icon: Icons.history_toggle_off,
          label: 'MISCAPTURED?',
          run: () => ran = true,
        ),
      ]),
    );
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.text('PHOTO TOOLS'), findsNothing);
    expect(ran, isFalse);
  });
}
