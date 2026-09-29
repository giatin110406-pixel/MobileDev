// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:neo_brutalism_locket/features/image_engine/neo_stylizer.dart';
import 'package:neo_brutalism_locket/features/image_engine/segmentation_mask.dart';
import 'package:neo_brutalism_locket/features/image_engine/image_processing_backend.dart';

void main() {
  test('mask quality rejects empty and full-frame foreground masks', () {
    final empty = PersonMask(
      width: 2,
      height: 2,
      confidences: Float32List.fromList([0, 0, 0, 0]),
    );
    final full = PersonMask(
      width: 2,
      height: 2,
      confidences: Float32List.fromList([1, 1, 1, 1]),
    );

    expect(assessMaskQuality(empty).canReplaceBackground, isFalse);
    expect(assessMaskQuality(full).canReplaceBackground, isFalse);
  });

  test('mask feathering softens confidence around the cutoff', () {
    final mask = PersonMask(
      width: 3,
      height: 1,
      confidences: Float32List.fromList([0.4, 0.5, 0.6]),
    );

    final feathered = featherPersonMask(mask, threshold: 0.5, softness: 0.2);

    expect(feathered[0], closeTo(0, 0.001));
    expect(feathered[1], closeTo(0.5, 0.001));
    expect(feathered[2], closeTo(1, 0.001));
  });

  test('trusted mask replaces background and weak mask preserves source', () {
    final source = img.Image(width: 2, height: 1, numChannels: 3)
      ..setPixelRgb(0, 0, 240, 30, 20)
      ..setPixelRgb(1, 0, 12, 24, 36);
    final trusted = PersonMask(
      width: 2,
      height: 1,
      confidences: Float32List.fromList([1, 0]),
    );
    final weak = PersonMask(
      width: 2,
      height: 1,
      confidences: Float32List.fromList([0, 0]),
    );

    final composited = replaceBackgroundWithPalette(source, trusted, const [
      78,
      205,
      196,
    ]);
    final unchanged = replaceBackgroundWithPalette(source, weak, const [
      78,
      205,
      196,
    ]);

    expect(composited.getPixel(0, 0).r.toInt(), 240);
    expect(composited.getPixel(1, 0).r.toInt(), 78);
    expect(composited.getPixel(1, 0).g.toInt(), 205);
    expect(identical(unchanged, source), isTrue);
  });

  test('mask-aware stylizer falls back exactly when mask is absent', () {
    final source = img.Image(width: 4, height: 3);
    final bytes = Uint8List.fromList(img.encodeJpg(source));

    expect(stylizePhotoWithMask(bytes, null), stylizePhoto(bytes));
  });

  test('segmented worker applies palette background and supports fallback', () {
    final source = img.Image(width: 6, height: 2, numChannels: 3);
    for (var row = 0; row < source.height; row++) {
      for (var column = 0; column < source.width; column++) {
        source.setPixelRgb(column, row, 255, 107, 107);
      }
    }
    final imageBytes = Uint8List.fromList(img.encodePng(source));
    final mask = Float32List.fromList([1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0]);
    final segmentedOutput = processPhotoWithMaskInBackground({
      'imageBytes': imageBytes,
      'maskWidth': 6,
      'maskHeight': 2,
      'maskConfidences': mask,
    });
    final fallbackOutput = processPhotoWithMaskInBackground({
      'imageBytes': imageBytes,
      'maskWidth': null,
      'maskHeight': null,
      'maskConfidences': null,
    });
    final segmentedImage = img.decodePng(segmentedOutput)!;

    expect(segmentedImage.getPixel(5, 1).r.toInt(), 78);
    expect(segmentedImage.getPixel(5, 1).g.toInt(), 205);
    expect(segmentedImage.getPixel(5, 1).b.toInt(), 196);
    expect(fallbackOutput, stylizePhoto(imageBytes));

    final yellowOutput = processPhotoWithMaskInBackground({
      'imageBytes': imageBytes,
      'maskWidth': 6,
      'maskHeight': 2,
      'maskConfidences': mask,
      'backgroundRgb': [255, 230, 109],
    });
    final yellowImage = img.decodePng(yellowOutput)!;
    expect(yellowImage.getPixel(5, 1).r.toInt(), 255);
    expect(yellowImage.getPixel(5, 1).g.toInt(), 230);
    expect(yellowImage.getPixel(5, 1).b.toInt(), 109);
  });

  test('edge extraction creates a mask matching image dimensions', () {
    final luminance = Float32List.fromList([0, 0, 255, 0, 0, 255, 0, 0, 255]);

    final edgeMask = extractEdgeMask(luminance, 3, 3, threshold: 100);

    expect(edgeMask, hasLength(9));
    expect(edgeMask.any((value) => value == 1), isTrue);
    expect(() => extractEdgeMask(luminance, 2, 2), throwsArgumentError);
  });

  test('resize keeps source under the working side limit', () {
    final source = img.Image(width: 1800, height: 900);

    final resized = resizeForProcessing(source, maxSide: 900);

    expect(resized.width, 900);
    expect(resized.height, 450);
  });

  test('baseline backend preserves stylizer output', () {
    final image = img.Image(width: 2, height: 2);
    final bytes = Uint8List.fromList(img.encodePng(image));

    expect(
      const DartPaletteProcessingBackend().process(bytes),
      stylizePhoto(bytes),
    );
  });

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

  test('friends and messages persist locally between loads', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SocialRepository();

    final initial = await repository.load();
    expect(initial.friends, hasLength(3));
    final updated = await repository.addFriend(
      name: 'Taylor Reed',
      handle: 'taylor.reed',
    );
    final friend = updated.friends.first;
    await repository.sendMessage(
      friendId: friend.id,
      text: 'See you at the photo walk.',
    );

    final reloaded = await repository.load();
    expect(
      reloaded.friends.any((item) => item.handle == '@taylor.reed'),
      isTrue,
    );
    expect(
      reloaded.messages.any(
        (message) =>
            message.friendId == friend.id &&
            message.text == 'See you at the photo walk.' &&
            message.isMine,
      ),
      isTrue,
    );
  });

  test('opening a local thread clears its unread messages', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SocialRepository();
    final initial = await repository.load();
    final friend = initial.friends.first;
    expect(initial.messages.any((message) => !message.isRead), isTrue);

    final opened = await repository.markThreadRead(friend.id);

    expect(
      opened.messages
          .where((message) => message.friendId == friend.id)
          .every((message) => message.isRead || message.isMine),
      isTrue,
    );
  });

  test(
    'stylizer returns a deterministic PNG and preserves image dimensions',
    () {
      final source = img.Image(width: 12, height: 8);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, x < 6 ? 240 : 20, y * 24, 80);
        }
      }
      final input = Uint8List.fromList(img.encodeJpg(source));

      final first = stylizePhoto(input);
      final second = stylizePhoto(input);
      final output = img.decodePng(first)!;

      expect(output.width, source.width);
      expect(output.height, source.height);
      expect(first, second);

      const allowedColors = {
        'ECE6C2',
        'FDF2E9',
        'FF6B6B',
        'A388EE',
        '4ECDC4',
        'FFE66D',
        '45B7D1',
        'F7A072',
        '1A1A1A',
      };
      final outputColors = <String>{};
      for (var y = 0; y < output.height; y++) {
        for (var x = 0; x < output.width; x++) {
          final pixel = output.getPixel(x, y);
          outputColors.add(
            '${pixel.r.toInt().toRadixString(16).padLeft(2, '0')}'
                    '${pixel.g.toInt().toRadixString(16).padLeft(2, '0')}'
                    '${pixel.b.toInt().toRadixString(16).padLeft(2, '0')}'
                .toUpperCase(),
          );
        }
      }
      expect(outputColors.difference(allowedColors), isEmpty);
    },
  );

  test('stylizer rejects unsupported image data', () {
    expect(
      () => stylizePhoto(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
  });
}
