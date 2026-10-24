import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/strip/strip_render.dart';
import 'package:neo_brutalism_locket/features/strip/strip_studio_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A plain photo of one colour, as a file would arrive.
Uint8List photoBytes(int r, int g, int b, {int w = 400, int h = 300}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

Future<List<ui.Image>> photos(int n) async => [
  for (var i = 0; i < n; i++)
    await decodeStripPhoto(photoBytes(40 * i, 120, 200 - 40 * i)),
];

/// The colour at (x, y) of [image].
Future<Color> pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawing a strip', () {
    test(
      'a strip is 2×6 inches at 300 dpi; the sheet is two of them',
      () async {
        final pics = await photos(4);
        final strip = await renderStrip(
          const StripSpec(paper: StripPaper.strip2x6, title: 'Trip'),
          pics,
        );
        expect((strip.width, strip.height), (600, 1800));
        final sheet = await renderStrip(const StripSpec(title: 'Trip'), pics);
        expect((sheet.width, sheet.height), (1200, 1800));
      },
    );

    test('the two strips on a sheet are the same, to be cut apart', () async {
      final sheet = await renderStrip(
        const StripSpec(style: StripStyle.neo, title: 'Trip'),
        await photos(3),
      );
      final data = (await sheet.toByteData())!;
      for (final (x, y) in [(5, 5), (300, 200), (120, 900), (300, 1650)]) {
        final left = data.getUint32((y * 1200 + x) * 4);
        final right = data.getUint32((y * 1200 + x + 600) * 4);
        expect(right, left, reason: 'at ($x, $y)');
      }
    });

    test(
      'a strip shows the first three photos, whatever it is given',
      () async {
        final pics = [
          await decodeStripPhoto(photoBytes(255, 0, 0)),
          await decodeStripPhoto(photoBytes(0, 255, 0)),
          await decodeStripPhoto(photoBytes(0, 0, 255)),
          await decodeStripPhoto(photoBytes(255, 255, 0)),
          await decodeStripPhoto(photoBytes(0, 255, 255)),
        ];
        final strip = await renderStrip(
          const StripSpec(
            style: StripStyle.classicLight,
            paper: StripPaper.strip2x6,
          ),
          pics,
        );
        expect((strip.width, strip.height), (600, 1800));
        final data = (await strip.toByteData())!;
        // The yellow of the fourth photo is nowhere on it.
        var yellow = 0;
        for (var i = 0; i < data.lengthInBytes; i += 4) {
          if (data.getUint8(i) == 255 &&
              data.getUint8(i + 1) == 255 &&
              data.getUint8(i + 2) == 0) {
            yellow++;
          }
        }
        expect(yellow, 0);
      },
    );

    test('the 2×3 grid is one 4×6 sheet of six squares', () async {
      final colours = [
        (255, 0, 0),
        (0, 255, 0),
        (0, 0, 255),
        (255, 255, 0),
        (0, 255, 255),
        (255, 0, 255),
      ];
      final pics = [
        for (final (r, g, b) in colours)
          await decodeStripPhoto(photoBytes(r, g, b, w: 300, h: 300)),
      ];
      final sheet = await renderStrip(
        const StripSpec(
          style: StripStyle.classicLight,
          paper: StripPaper.grid4x6,
        ),
        pics,
      );
      expect((sheet.width, sheet.height), (1200, 1800));
      final data = (await sheet.toByteData())!;
      bool isColour(int x, int y, (int, int, int) c) {
        final i = (y * sheet.width + x) * 4;
        return data.getUint8(i) == c.$1 &&
            data.getUint8(i + 1) == c.$2 &&
            data.getUint8(i + 2) == c.$3;
      }

      // Find each photo's box by walking out from a point inside it.
      Rect boxOf(int x, int y, (int, int, int) c) {
        var l = x, r = x, t = y, b = y;
        while (isColour(l - 1, y, c)) {
          l--;
        }
        while (isColour(r + 1, y, c)) {
          r++;
        }
        while (isColour(x, t - 1, c)) {
          t--;
        }
        while (isColour(x, b + 1, c)) {
          b++;
        }
        return Rect.fromLTRB(l.toDouble(), t.toDouble(), r + 1.0, b + 1.0);
      }

      // Row by row, left to right: 2 columns, 3 rows, all the same square.
      Rect? first;
      final lefts = <double>{};
      final tops = <double>{};
      for (var i = 0; i < 6; i++) {
        final x = i.isEven ? 300 : 900;
        final y = [330, 330, 900, 900, 1380, 1380][i];
        expect(isColour(x, y, colours[i]), isTrue, reason: 'photo ${i + 1}');
        final box = boxOf(x, y, colours[i]);
        expect(box.width, closeTo(box.height, 1), reason: 'photo ${i + 1}');
        first ??= box;
        expect(box.width, closeTo(first.width, 1));
        lefts.add(box.left);
        tops.add(box.top);
      }
      expect(lefts, hasLength(2));
      expect(tops, hasLength(3));
    });

    test('a grid with fewer photos fills the rest with cards', () async {
      for (final style in StripStyle.values) {
        final sheet = await renderStrip(
          StripSpec(style: style, paper: StripPaper.grid4x6, title: 'Trip'),
          await photos(2),
        );
        expect((sheet.width, sheet.height), (1200, 1800), reason: '$style');
      }
    });

    test('every frame draws with 2, 3 and 4 photos', () async {
      for (final style in StripStyle.values) {
        for (final n in [2, 3, 4]) {
          final image = await renderStrip(
            StripSpec(
              style: style,
              paper: StripPaper.strip2x6,
              title: 'A title far too long to fit on one strip of paper',
              subtitle: '20/10 – 23/10',
            ),
            await photos(n),
          );
          expect(image.height, 1800, reason: '$style with $n');
        }
      }
    });

    test(
      'the photos land in their slots, top to bottom; a card fills the rest',
      () async {
        final pics = [
          await decodeStripPhoto(photoBytes(255, 0, 0)),
          await decodeStripPhoto(photoBytes(0, 0, 255)),
        ];
        final strip = await renderStrip(
          const StripSpec(
            style: StripStyle.classicLight,
            paper: StripPaper.strip2x6,
          ),
          pics,
        );
        expect(await pixel(strip, 300, 300), const Color(0xFFFF0000));
        expect(await pixel(strip, 300, 700), const Color(0xFF0000FF));
        // With two photos the third frame is a card with the app's name.
        expect(await pixel(strip, 300, 1250), isNot(const Color(0xFF0000FF)));
        // The margin is the paper.
        expect(await pixel(strip, 10, 10), const Color(0xFFFFFBEF));
      },
    );

    test('photos are square, like the ones the app takes', () async {
      for (final n in [2, 3]) {
        final red = await decodeStripPhoto(
          photoBytes(255, 0, 0, w: 300, h: 300),
        );
        final strip = await renderStrip(
          const StripSpec(
            style: StripStyle.classicLight,
            paper: StripPaper.strip2x6,
          ),
          [for (var i = 0; i < n; i++) red],
        );
        final data = (await strip.toByteData())!;
        bool isRed(int x, int y) {
          final i = (y * strip.width + x) * 4;
          return data.getUint8(i) == 255 &&
              data.getUint8(i + 1) == 0 &&
              data.getUint8(i + 2) == 0;
        }

        // The first photo: how wide at its middle, how tall down its middle.
        var top = 0;
        while (!isRed(300, top)) {
          top++;
        }
        var bottom = top;
        while (isRed(300, bottom + 1)) {
          bottom++;
        }
        final middle = (top + bottom) ~/ 2;
        var left = 0;
        while (!isRed(left, middle)) {
          left++;
        }
        var right = left;
        while (isRed(right + 1, middle)) {
          right++;
        }
        expect(right - left, closeTo(bottom - top, 1), reason: '$n photos');
        // And all of them fit between the top and the words.
        expect(bottom, lessThan(1800 - 280), reason: '$n photos');
      }
    });

    test('classic black is black paper', () async {
      final strip = await renderStrip(
        const StripSpec(paper: StripPaper.strip2x6),
        await photos(2),
      );
      expect(await pixel(strip, 10, 10), const Color(0xFF0E0E0E));
    });

    test('the Van Gogh frame has its painting behind', () async {
      final assets = await loadStripAssets();
      expect(assets.vanGogh, isNotNull);
      final strip = await renderStrip(
        const StripSpec(style: StripStyle.vanGogh, paper: StripPaper.strip2x6),
        await photos(2),
        assets: assets,
      );
      // Not a flat colour in the corner: the sky of the painting.
      final a = await pixel(strip, 6, 6);
      final b = await pixel(strip, 30, 400);
      expect(a == b, isFalse);
    });

    test('the file is a PNG', () async {
      final png = await stripPng(
        await renderStrip(const StripSpec(), await photos(2)),
      );
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
    });
  });

  group('the strip studio', () {
    Widget app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );

    Future<void> settle(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 60 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
    }

    testWidgets('loads the photos, shows the strip, switches frame and paper', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final asked = <String>[];
      await tester.pumpWidget(
        app(
          StripStudioScreen(
            photos: const [
              StripPhoto(path: 'a.jpg', originalPath: 'a_orig.jpg'),
              StripPhoto(path: 'b.jpg'),
            ],
            title: 'Dalat',
            subtitle: '20/10',
            assets: () async => const StripAssets(),
            loader: (path) async {
              asked.add(path);
              return photoBytes(200, 100, 50);
            },
          ),
        ),
      );
      final preview = find.byKey(const ValueKey('strip-preview'));
      await settle(tester, () => preview.evaluate().isNotEmpty);
      expect(preview, findsOneWidget);
      expect(asked, ['a.jpg', 'b.jpg']);
      expect(find.textContaining('4×6 in, then cut'), findsOneWidget);
      // Two photos: the strip twice is chosen, with no word about a limit.
      expect(find.textContaining('uses the first 3'), findsNothing);

      // Every frame is offered on its own, with a little picture of it.
      for (final name in [
        'BLACK FILM',
        'WHITE PAPER',
        'NEO',
        '8-BIT',
        'VAN GOGH',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await settle(
        tester,
        () => find.byType(Image).evaluate().length >= 6, // strip + 5 frames
      );
      expect(find.byType(Image), findsNWidgets(6));

      await tester.tap(find.text('ONE 2×6 IN STRIP'));
      await tester.pump();
      expect(find.textContaining('One 2×6 in strip'), findsOneWidget);

      await tester.tap(find.text('8-BIT'));
      await settle(tester, () => false);
      expect(preview, findsOneWidget);

      // The originals are fetched only when asked for, where there is one.
      await tester.tap(find.text('Use the originals (before the style)'));
      await settle(tester, () => asked.length >= 3);
      expect(asked, ['a.jpg', 'b.jpg', 'a_orig.jpg']);
    });

    testWidgets('four photos or more choose the 2×3 grid; a strip says it '
        'uses three', (tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          StripStudioScreen(
            photos: [for (var i = 0; i < 5; i++) StripPhoto(path: 'p$i.jpg')],
            title: 'x',
            subtitle: '',
            assets: () async => const StripAssets(),
            loader: (path) async => photoBytes(200, 100, 50),
          ),
        ),
      );
      final preview = find.byKey(const ValueKey('strip-preview'));
      await settle(tester, () => preview.evaluate().isNotEmpty);
      expect(find.textContaining('nothing to cut'), findsOneWidget);
      expect(find.textContaining('uses the first 3'), findsNothing);

      await tester.tap(find.text('ONE 2×6 IN STRIP'));
      await tester.pump();
      expect(find.textContaining('uses the first 3 photos'), findsOneWidget);
      expect(find.textContaining('all 5'), findsOneWidget);
    });

    testWidgets('a photo that cannot be loaded says so', (tester) async {
      await tester.pumpWidget(
        app(
          StripStudioScreen(
            photos: const [
              StripPhoto(path: 'a'),
              StripPhoto(path: 'b'),
            ],
            title: 'x',
            subtitle: '',
            assets: () async => const StripAssets(),
            loader: (path) async => null,
          ),
        ),
      );
      await settle(
        tester,
        () => find.textContaining('could not be loaded').evaluate().isNotEmpty,
      );
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });
  });
}
