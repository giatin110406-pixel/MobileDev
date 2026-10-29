import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/privacy/sensitive_check.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_review.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_rules.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Black and white stripes one pixel wide: anything that blurs them shows.
img.Image stripes(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = x.isEven ? 255 : 0;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

double contrast(img.Image image, int x0, int y0, int x1, int y1) {
  var sum = 0.0;
  var count = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1 - 1; x++) {
      sum += (image.getPixel(x, y).r - image.getPixel(x + 1, y).r).abs();
      count++;
    }
  }
  return sum / count;
}

class FakeScanner implements SensitiveScanner {
  FakeScanner(this.result, {this.fail = false});
  final SensitiveScan result;
  final bool fail;
  final covers = <List<Rect>>[];

  @override
  Future<SensitiveScan> scan(File photo) async {
    if (fail) throw StateError('no OCR');
    return result;
  }

  @override
  Future<File> cover(File photo, List<Rect> boxes) async {
    covers.add(boxes);
    return File('${photo.path}.covered.jpg');
  }
}

const _size = Size(400, 300);
const _phone = SensitiveFinding(
  SensitiveKind.phone,
  Rect.fromLTWH(20, 20, 150, 30),
  '0912345678',
);
const _plate = SensitiveFinding(
  SensitiveKind.plate,
  Rect.fromLTWH(200, 200, 120, 40),
  '51F-123.45',
);

Future<Future<SensitiveDecision?>> open(
  WidgetTester t,
  SensitiveScanner scanner,
  File photo, {
  List<String>? notes,
}) async {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  late Future<SensitiveDecision?> result;
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = reviewSensitive(
            context,
            photo,
            scanner: scanner,
            notify: notes?.add,
          ),
          child: const Text('post'),
        ),
      ),
    ),
  );
  await t.tap(find.text('post'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  return result;
}

void main() {
  late File photo;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sensitive');
    photo = File('${dir.path}/photo.png');
    await photo.writeAsBytes(img.encodePng(stripes(400, 300)));
  });

  group('coverRegions', () {
    test('covers inside the box and leaves the rest alone', () {
      final source = Uint8List.fromList(img.encodePng(stripes(400, 300)));
      final out = img.decodeJpg(
        coverRegions((
          source,
          [(100.0, 100.0, 220.0, 140.0)],
        )),
      )!;
      expect(out.width, 400);
      expect(out.height, 300);
      // The stripes are gone inside...
      expect(contrast(out, 110, 108, 210, 132), lessThan(20));
      // ...and still there well away from it (JPEG softens them a little).
      expect(contrast(out, 10, 200, 80, 280), greaterThan(150));
    });

    test('an EXIF-turned photo is covered where it is seen upright', () {
      // Stored 300 x 400 and marked "turn 90 degrees": seen as 400 x 300.
      final stored = stripes(300, 400);
      stored.exif.imageIfd.orientation = 6;
      final out = img.decodeJpg(
        coverRegions((
          Uint8List.fromList(img.encodeJpg(stored)),
          [(0.0, 0.0, 400.0, 60.0)],
        )),
      )!;
      expect((out.width, out.height), (400, 300));
      expect(out.exif.imageIfd.orientation ?? 1, 1);
    });
  });

  group('reviewSensitive', () {
    testWidgets('nothing found: the photo goes as it is', (t) async {
      final scanner = FakeScanner(const SensitiveScan(size: _size, findings: []));
      final decision = await open(t, scanner, photo);
      expect(find.byType(SensitiveReviewScreen), findsNothing);
      final d = (await decision)!;
      expect(d.photo.path, photo.path);
      expect(d.covered, isFalse);
    });

    testWidgets('the check failing never stops the post, and says so', (
      t,
    ) async {
      final notes = <String>[];
      final scanner = FakeScanner(
        const SensitiveScan(size: _size, findings: []),
        fail: true,
      );
      final decision = await open(t, scanner, photo, notes: notes);
      final d = (await decision)!;
      expect(d.photo.path, photo.path);
      expect(notes, ['The photo could not be checked for private details.']);
    });

    testWidgets('found: every box starts covered and is covered on post', (
      t,
    ) async {
      final scanner = FakeScanner(
        const SensitiveScan(size: _size, findings: [_phone, _plate]),
      );
      final decision = await open(t, scanner, photo);
      expect(find.byType(SensitiveReviewScreen), findsOneWidget);
      expect(find.text('Phone number · COVERED'), findsOneWidget);
      expect(find.text('Licence plate · COVERED'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('sensitive-cover')));
      await t.pump(const Duration(seconds: 1));
      final d = (await decision)!;
      expect(d.covered, isTrue);
      expect(d.photo.path, endsWith('.covered.jpg'));
      expect(scanner.covers.single, [_phone.box, _plate.box]);
    });

    testWidgets('a tapped box is left uncovered', (t) async {
      final scanner = FakeScanner(
        const SensitiveScan(size: _size, findings: [_phone, _plate]),
      );
      final decision = await open(t, scanner, photo);
      await t.tap(find.byKey(const ValueKey('sensitive-box-1')));
      await t.pump();
      expect(find.text('Licence plate · SHOWN'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('sensitive-cover')));
      await t.pump(const Duration(seconds: 1));
      await decision;
      expect(scanner.covers.single, [_phone.box]);
    });

    testWidgets('post without covering sends the photo untouched', (t) async {
      final scanner = FakeScanner(
        const SensitiveScan(size: _size, findings: [_phone]),
      );
      final decision = await open(t, scanner, photo);
      await t.tap(find.byKey(const ValueKey('sensitive-as-is')));
      await t.pump(const Duration(seconds: 1));
      final d = (await decision)!;
      expect(d.covered, isFalse);
      expect(d.photo.path, photo.path);
      expect(scanner.covers, isEmpty);
    });

    testWidgets('going back means not posting', (t) async {
      final scanner = FakeScanner(
        const SensitiveScan(size: _size, findings: [_phone]),
      );
      final decision = await open(t, scanner, photo);
      await t.tap(find.byType(CloseButton));
      await t.pump(const Duration(seconds: 1));
      expect(await decision, isNull);
    });
  });
}
