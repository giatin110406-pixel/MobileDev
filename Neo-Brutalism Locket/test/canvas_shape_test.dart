import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_painter.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_view.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'canvas_store_test.dart' show FakeCanvas;

/// A canvas in the shape of a banner: 8 cells wide and 2 tall (the fake's 16 cells).
class WideCanvas extends FakeCanvas {
  @override
  CanvasData get snapshot => CanvasData(
    id: 'c1',
    groupId: 'g1',
    width: 8,
    height: 2,
    palette: const [0xFF000000, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF],
    pixels: Uint8List(16),
    version: 0,
    inkBalance: 10,
  );
}

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('the shape of a canvas', () {
    test('a banner, a canvas and a frame in the Gallery are all one shape', () {
      expect(canvasAspect, profileBannerAspect);
      expect(canvasAspect, Corridor.frameAspect);
    });

    test('every height the owner can choose gives a banner-shaped canvas', () {
      expect(canvasHeights, [12, 16, 20]);
      expect([for (final h in canvasHeights) canvasWidthFor(h)], [30, 40, 50]);
      for (final h in canvasHeights) {
        expect(canvasWidthFor(h) / h, canvasAspect);
      }
    });
  });

  group('a wide canvas on screen', () {
    final painterFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CanvasPainter,
    );

    Future<CanvasStore> open(WidgetTester tester, Size screen) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = CanvasStore(
        WideCanvas(),
        groupId: 'g1',
        batchDelay: const Duration(hours: 1),
        retryDelay: Duration.zero,
      );
      await tester.runAsync(store.load);
      await tester.pumpWidget(
        app(CanvasView(store: store, nameOf: (_) => null)),
      );
      return store;
    }

    testWidgets('keeps its shape, wider than tall, on a phone', (tester) async {
      final store = await open(tester, const Size(400, 800));
      final size = tester.getSize(painterFinder);
      expect(size.width / size.height, closeTo(4, 0.01));
      expect(size.width, greaterThan(size.height));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('fits the width of the screen', (tester) async {
      final store = await open(tester, const Size(400, 800));
      expect(tester.getSize(painterFinder).width, lessThanOrEqualTo(400));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('a tap lands on the cell under the finger', (tester) async {
      final store = await open(tester, const Size(400, 800));
      final topLeft = tester.getTopLeft(painterFinder);
      final cell = tester.getSize(painterFinder).width / 8;
      // The last cell of the second (bottom) row.
      await tester.tapAt(topLeft + Offset(cell * 7.5, cell * 1.5));
      await tester.pump();
      expect(store.colorIndexAt(7, 1), 1);
      expect(store.isPending(7, 1), isTrue);
      expect(store.colorIndexAt(7, 0), 0);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });
}
