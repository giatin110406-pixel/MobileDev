import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';

const _palette = [
  0xFFF3E9D2, 0xFF1D2B53, 0xFF2F4B8F, 0xFF4D7FC4, //
  0xFF8DB7D8, 0xFFF2C94C, 0xFFE8A317, 0xFFC97B1E,
  0xFF7A9E4A, 0xFF3F6B3A, 0xFF26402B, 0xFFB4573A,
  0xFF7B3B2A, 0xFFD9C7A0, 0xFF5E5240, 0xFF171717,
];

/// A different little picture for every entry (stripes, rings, checks).
GalleryEntry sample(int seq) {
  const n = 32;
  final pixels = Uint8List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final dx = x - 15.5, dy = y - 15.5;
      final ring = (dx * dx + dy * dy) ~/ (30 + seq % 5 * 10);
      pixels[y * n + x] = switch (seq % 3) {
        0 => (ring + seq) % 16,
        1 => ((x ~/ 4) + (y ~/ 4) * 2 + seq) % 16,
        _ => ((x + y + seq) ~/ 3) % 16,
      };
    }
  }
  return GalleryEntry(
    id: 'entry-$seq',
    contestId: 'c1',
    seq: seq,
    groupName: 'Group $seq',
    width: n,
    height: n,
    palette: _palette,
    pixels: pixels,
    submittedAt: DateTime(2026, 10, 10),
  );
}

void main() {
  Future<void> shoot(
    WidgetTester tester, {
    required double cameraZ,
    required bool lite,
    String? writeTo,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entries = [for (var i = 1; i <= 100; i++) sample(i)];
    final slots = layoutFrames([for (final e in entries) e.id]);
    final cache = EntryImageCache();
    // Decode every picture that can be on screen, as the app does while painting.
    await tester.runAsync(() async {
      for (final slot in visibleSlots(slots, cameraZ)) {
        await cache.load(entries[slot.index]);
      }
    });
    final camera = ValueNotifier<double>(cameraZ);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: SizedBox.expand(
            child: CustomPaint(
              painter: CorridorPainter(
                camera: camera,
                entries: entries,
                slots: slots,
                cache: cache,
                lite: lite,
              ),
            ),
          ),
        ),
      ),
    );
    // Rendering must not throw, whatever the position; the picture itself was
    // checked by eye (see docs/gallery_corridor.png).
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    if (writeTo != null) {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final image = await tester.runAsync(() => boundary.toImage());
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File(writeTo).writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
    cache.dispose();
  }

  testWidgets('the corridor at the entrance', (tester) async {
    await shoot(
      tester,
      cameraZ: 0,
      lite: false,
      writeTo: const String.fromEnvironment('CORRIDOR_PNG').isEmpty
          ? null
          : const String.fromEnvironment('CORRIDOR_PNG'),
    );
  });

  testWidgets('the corridor halfway down', (tester) async {
    await shoot(tester, cameraZ: 22.4, lite: false);
  });

  testWidgets('the light version for slow phones', (tester) async {
    await shoot(tester, cameraZ: 22.4, lite: true);
  });

  testWidgets('the very end of the corridor', (tester) async {
    await shoot(tester, cameraZ: 90, lite: false);
  });
}
