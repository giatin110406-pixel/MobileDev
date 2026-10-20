import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/quest/on_device/quest_preprocess.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/screen_recapture.dart';

/// Photos sorted by hand into server/eval/quest_test/{real,screen,other}.
/// `screen` are pictures of a display, `other` show something the quest did
/// not ask for (the model, not the pixel-grid test, is what rejects those).
Map<String, double> strengths(String kind, {int? shortSide}) {
  final out = <String, double>{};
  final files = Directory('server/eval/quest_test/$kind')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => !f.path.endsWith('.avif'));
  for (final file in files) {
    var photo = decodeQuestPhoto(file.readAsBytesSync());
    if (shortSide != null && photo.width.clamp(0, photo.height) > shortSide) {
      // What an Android camera at ResolutionPreset.high hands over (the app now uses veryHigh, 1080p).
      photo = img.copyResize(
        photo,
        width: photo.width < photo.height ? shortSide : null,
        height: photo.height <= photo.width ? shortSide : null,
        interpolation: img.Interpolation.linear,
      );
    }
    out[file.uri.pathSegments.last] = moireStrength(photo);
  }
  return out;
}

void main() {
  final real = strengths('real');
  final screen = strengths('screen');
  final other = strengths('other');

  test('prints what the grid test sees', () {
    String row(String k, Map<String, double> m) => m.entries
        .map(
          (e) =>
              '$k ${e.key.padRight(12).substring(0, 12)} ${e.value.toStringAsFixed(1)}',
        )
        .join('\n');
    // ignore: avoid_print
    print(
      [
        row('real  ', real),
        row('screen', screen),
        row('other ', other),
      ].join('\n'),
    );
  });

  test('prints the same at 720 px, as a phone at ResolutionPreset.high', () {
    final small = {
      for (final kind in ['real', 'screen', 'other'])
        ...strengths(
          kind,
          shortSide: 720,
        ).map((k, v) => MapEntry('$kind/$k', v)),
    };
    // ignore: avoid_print
    print(
      small.entries
          .map(
            (e) =>
                '${e.key.padRight(34).substring(0, 34)} ${e.value.toStringAsFixed(1)}',
          )
          .join('\n'),
    );
  });

  test('real photos and unrelated photos pass', () {
    for (final entry in {...real, ...other}.entries) {
      expect(entry.value, lessThan(moireReject), reason: entry.key);
    }
  });

  test('screens photographed with a visible pixel grid are refused', () {
    // Two of the three. The grapes screenshot has no visible grid (it was
    // shrunk), so only the model's own "on a screen" labels can see it.
    final refused = screen.entries.where((e) => e.value >= moireReject);
    expect(refused.length, greaterThanOrEqualTo(2));
  });

  test('a picture smaller than one crop scores 0', () {
    expect(moireStrength(img.Image(width: 100, height: 100)), 0);
  });
}
