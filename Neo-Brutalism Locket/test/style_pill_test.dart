import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/camera/style_pill.dart';
import 'package:neo_brutalism_locket/features/image_engine/original_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

Future<List<StyleType>> pumpPill(
  WidgetTester tester, {
  StyleType value = StyleType.none,
  bool enabled = true,
}) async {
  final changes = <StyleType>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StylePill(
            value: value,
            enabled: enabled,
            onChanged: changes.add,
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  test('pill order is no style, 8-bit, Van Gogh', () {
    expect(StyleType.values, [
      StyleType.none,
      StyleType.pixel8bit,
      StyleType.vanGogh,
    ]);
  });

  testWidgets('swiping left moves to the next mode', (tester) async {
    final changes = await pumpPill(tester);
    await tester.drag(find.byType(StylePill), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(changes, [StyleType.pixel8bit]);
  });

  testWidgets('swiping right goes back one mode', (tester) async {
    final changes = await pumpPill(tester, value: StyleType.vanGogh);
    await tester.drag(find.byType(StylePill), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(changes, [StyleType.pixel8bit]);
  });

  testWidgets('a quick flick counts as a swipe', (tester) async {
    final changes = await pumpPill(tester);
    await tester.fling(find.byType(StylePill), const Offset(-36, 0), 1000);
    await tester.pumpAndSettle();
    expect(changes, [StyleType.pixel8bit]);
  });

  testWidgets('a tiny drag or a tap does not change the mode', (tester) async {
    final changes = await pumpPill(tester);
    await tester.drag(find.byType(StylePill), const Offset(-8, 0));
    await tester.tap(find.byType(StylePill));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('no change past the first or last mode', (tester) async {
    var changes = await pumpPill(tester);
    await tester.drag(find.byType(StylePill), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    changes = await pumpPill(tester, value: StyleType.vanGogh);
    await tester.drag(find.byType(StylePill), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('a disabled pill ignores swipes', (tester) async {
    final changes = await pumpPill(tester, enabled: false);
    await tester.drag(find.byType(StylePill), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('shows only the current mode, one pill', (tester) async {
    await pumpPill(tester, value: StyleType.pixel8bit);
    await tester.pumpAndSettle();
    expect(find.text('8-BIT'), findsOneWidget);
    expect(find.text('VAN GOGH'), findsNothing);
    expect(find.text('NO STYLE'), findsNothing);
  });

  test('every mode has its own colour', () {
    final colours = StyleType.values.map(stylePillColor).toSet();
    expect(colours.length, StyleType.values.length);
  });

  test('no-style engine returns the original file untouched', () async {
    final directory = await Directory.systemTemp.createTemp('locket_none');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/photo.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
    final before = file.readAsBytesSync();

    final output = await const StyleEngineFactory()
        .create(StyleType.none)
        .process(file, StyleType.none);

    expect(output.file.path, file.path);
    expect(output.source, StyleSource.original);
    expect(file.readAsBytesSync(), before);
    expect(const OriginalStyleEngine(), isA<OriginalStyleEngine>());
  });

  test('gallery photos are centre-cropped to a square and size-capped', () {
    final wide = img.Image(width: 4000, height: 3000);
    final out = img.decodeJpg(
      cropToSquareJpegCapped(img.encodeJpg(wide, quality: 50)),
    )!;
    expect(out.width, uploadMaxSide);
    expect(out.height, uploadMaxSide);

    final small = img.Image(width: 400, height: 300);
    final smallOut = img.decodeJpg(
      cropToSquareJpegCapped(img.encodeJpg(small)),
    )!;
    expect((smallOut.width, smallOut.height), (300, 300));
  });
}
