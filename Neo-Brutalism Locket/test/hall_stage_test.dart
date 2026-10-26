import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/features/contest/hall_stage.dart';

/// Where the pictures of the stage and of the door are written, when given:
///   flutter test test/hall_stage_test.dart --dart-define=HALL_PNG_DIR=the-folder
const _out = String.fromEnvironment('HALL_PNG_DIR');

void main() {
  group('the opening of the stage', () {
    test(
      'the curtains are shut at the start and wide open before the columns',
      () {
        expect(StageTiming.curtains(0), 0);
        expect(StageTiming.curtains(0.3), closeTo(1, 1e-9));
        expect(StageTiming.curtains(0.15), inExclusiveRange(0, 1));
        // Nothing is built while the curtains are still moving.
        expect(StageTiming.column(0.3, 3), 0);
      },
    );

    test('third place goes up first, then second, then first', () {
      expect(StageTiming.column(0.4, 3), greaterThan(0));
      expect(StageTiming.column(0.4, 2), 0);
      expect(StageTiming.column(0.5, 2), greaterThan(0));
      expect(StageTiming.column(0.5, 1), 0);
      expect(StageTiming.column(0.6, 1), greaterThan(0));
      // All three stand at the end.
      for (final rank in const [1, 2, 3]) {
        expect(StageTiming.column(1, rank), 1);
        expect(StageTiming.plate(1, rank), closeTo(1, 1e-9));
      }
    });

    test('the painting and the plate come when the column is built', () {
      expect(StageTiming.plate(0.5, 3), lessThan(1));
      expect(StageTiming.plate(0.5, 3), greaterThanOrEqualTo(0));
      expect(StageTiming.plate(0.3, 3), 0);
    });

    test('first place stands highest, in the middle', () {
      const layout = StageLayout(Size(400, 800));
      expect(layout.columnHeight(1), greaterThan(layout.columnHeight(2)));
      expect(layout.columnHeight(2), greaterThan(layout.columnHeight(3)));
      expect(layout.centerX(1), 200);
      expect(layout.centerX(2), lessThan(layout.centerX(1)));
      expect(layout.centerX(3), greaterThan(layout.centerX(1)));
      // The columns do not touch each other.
      expect(
        layout.centerX(2) + layout.capitalWidth / 2,
        lessThan(layout.centerX(1) - layout.capitalWidth / 2),
      );
    });
  });

  group('the stage on screen', () {
    Future<void> shoot(WidgetTester tester, double t, String name) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final intro = AlwaysStoppedAnimation<double>(t);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: StagePainter(intro: intro)),
                  CustomPaint(painter: CurtainPainter(intro: intro)),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (_out.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      await tester.pumpWidget(const SizedBox());
    }

    for (final (name, t) in const [
      ('stage_0_shut', 0.0),
      ('stage_1_curtains_half', 0.17),
      ('stage_2_curtains_open', 0.31),
      ('stage_3_third_up', 0.48),
      ('stage_4_second_up', 0.64),
      ('stage_5_first_half', 0.76),
      ('stage_6_done', 1.0),
    ]) {
      testWidgets('draws at $t without trouble', (tester) async {
        await shoot(tester, t, name);
      });
    }
  });

  group('the door at the end of the corridor', () {
    Future<void> shoot(
      WidgetTester tester, {
      required double cameraZ,
      required double open,
      required String name,
      String? caption = 'HALL OF FAME',
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final slots = layoutGallery(0);
      final cache = EntryImageCache();
      final camera = ValueNotifier<double>(cameraZ);
      final door = ValueNotifier<double>(open);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: CorridorPainter(
                  camera: camera,
                  entries: const [],
                  slots: slots,
                  cache: cache,
                  endZ: corridorLength(slots) + 1,
                  doorOpen: door,
                  doorCaption: caption,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (_out.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
      door.dispose();
      cache.dispose();
    }

    final end = corridorLength(layoutGallery(0)) + 1;

    for (final (name, back, open) in const [
      ('door_far', 12.0, 0.35),
      ('door_near', 4.0, 0.35),
      ('door_opening', 1.6, 0.7),
      ('door_open', 0.9, 1.0),
    ]) {
      testWidgets('$name draws without trouble', (tester) async {
        await shoot(tester, cameraZ: end - back, open: open, name: name);
      });
    }

    testWidgets('a shut door with no sign draws too', (tester) async {
      await shoot(
        tester,
        cameraZ: end - 5,
        open: 0,
        name: 'door_shut',
        caption: null,
      );
    });

    test('the door is a finger wide to hit, even far away', () {
      final view = Projection(const Size(400, 800), 0);
      final hit = CorridorPainter.doorHit(view, end)!;
      expect(hit.width, greaterThanOrEqualTo(48));
      expect(hit.height, greaterThanOrEqualTo(48));
      expect(hit.center.dx, closeTo(200, 1));
    });

    test('close up, the door is as big as it looks', () {
      final far = CorridorPainter.doorHit(
        Projection(const Size(400, 800), 0),
        end,
      )!;
      final near = CorridorPainter.doorHit(
        Projection(const Size(400, 800), end - 3),
        end,
      )!;
      expect(near.width, greaterThan(far.width));
    });
  });
}
