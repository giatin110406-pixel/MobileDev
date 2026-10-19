import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

Widget _box(bool pressed) => Container(
  key: const ValueKey('box'),
  width: 50,
  height: 50,
  decoration: BoxDecoration(boxShadow: NeoPress.shadow(pressed)),
);

void main() {
  testWidgets('a held press moves the thing and drops its shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: NeoPress(onTap: () {}, builder: (context, p) => _box(p)),
        ),
      ),
    );
    List<BoxShadow>? shadow() =>
        ((tester
                    .widget<Container>(find.byKey(const ValueKey('box')))
                    .decoration)
                as BoxDecoration)
            .boxShadow
            ?.cast<BoxShadow>();
    final rest = tester.getTopLeft(find.byKey(const ValueKey('box')));
    expect(shadow(), isNotEmpty);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('box'))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(shadow(), isEmpty);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('box'))) - rest,
      const Offset(4, 4),
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(shadow(), isNotEmpty);
    expect(tester.getTopLeft(find.byKey(const ValueKey('box'))), rest);
  });

  testWidgets('sunken stays pressed in without a touch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: NeoPress(sunken: true, builder: (context, p) => _box(p)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final box = tester.widget<Container>(find.byKey(const ValueKey('box')));
    expect((box.decoration! as BoxDecoration).boxShadow, isEmpty);
  });
}
