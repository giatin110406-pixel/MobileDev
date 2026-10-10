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

/// A winning painting for the Hall of Fame pictures.
GalleryEntry winnerSample(int n) {
  final base = sample(n);
  return GalleryEntry(
    id: base.id,
    contestId: 'c',
    seq: 1,
    groupName: 'Nhóm Hướng Dương $n',
    width: base.width,
    height: base.height,
    palette: base.palette,
    pixels: base.pixels,
    submittedAt: base.submittedAt,
    rank: (n - 1) % 3 + 1,
    score: 4.2 - n * 0.1,
    voteCount: 12,
    weekKey: '2026-W${41 - n}',
    titleVi: 'Đêm đầy sao',
    titleEn: 'The Starry Night',
  );
}

void main() {
  Future<void> shoot(
    WidgetTester tester, {
    required double cameraZ,
    required bool lite,
    String? writeTo,
    int count = 100,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entries = [for (var i = 1; i <= count; i++) sample(i)];
    final slots = layoutGallery(entries.length);
    final cache = EntryImageCache();
    // Decode every picture that can be on screen, as the app does while painting.
    await tester.runAsync(() async {
      for (final slot in visibleSlots(slots, cameraZ)) {
        if (!slot.isBlank) await cache.load(entries[slot.index]);
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
                endZ: corridorLength(slots) + 1,
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
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
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

  // Pictures of the Gallery, written when the paths are given (see docs/).
  for (final (name, define, count, z) in const [
    ('with no entry', String.fromEnvironment('GALLERY_EMPTY_PNG'), 0, 0.0),
    ('with a few entries', String.fromEnvironment('GALLERY_FEW_PNG'), 7, 0.0),
    (
      'with many entries, further in',
      String.fromEnvironment('GALLERY_MANY_PNG'),
      100,
      30.0,
    ),
  ]) {
    testWidgets('the Gallery $name', (tester) async {
      await shoot(
        tester,
        cameraZ: z,
        lite: false,
        count: count,
        writeTo: define.isEmpty ? null : define,
      );
    });
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

  testWidgets('the door where the visitor stops', (tester) async {
    final end = corridorLength(layoutGallery(100)) + 1;
    await shoot(
      tester,
      cameraZ: end - 5,
      lite: false,
      writeTo: const String.fromEnvironment('GALLERY_END_PNG').isEmpty
          ? null
          : const String.fromEnvironment('GALLERY_END_PNG'),
    );
  });

  testWidgets('the very end of the corridor', (tester) async {
    await shoot(tester, cameraZ: 90, lite: false);
  });
}
