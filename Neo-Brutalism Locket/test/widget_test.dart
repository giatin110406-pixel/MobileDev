// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

void main() {
  testWidgets('NeoSwitch toggles using the library control', (tester) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NeoSwitch(
              value: enabled,
              label: 'NEO PRINT',
              onChanged: (value) => setState(() => enabled = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('NEO PRINT'));
    await tester.pumpAndSettle();

    expect(enabled, isTrue);
  });

  testWidgets('NeoButton dispatches its action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NeoButton(
            label: 'OPEN CAMERA',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN CAMERA'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });
}
