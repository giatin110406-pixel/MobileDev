import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/magenta_van_gogh_backend.dart';
import 'package:neo_brutalism_locket/features/image_engine/scene_guess.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';

/// Two dimensions, one description per axis: x = portrait, y = night (twice,
/// so night wins a tie by sum).
SceneLabels _bank({
  List<String> scenes = const ['portrait', 'night', 'night'],
}) {
  final vectors = <double>[1, 0, 0, 1, 0, 1].sublist(0, scenes.length * 2);
  return SceneLabels.parse(
    jsonEncode({
      'dim': 2,
      'logitScale': 10.0,
      'inputSize': 8,
      'scenes': scenes,
    }),
    Float32List.fromList(vectors).buffer.asUint8List(),
  );
}

class _CountingEncoder implements QuestImageEncoder {
  int calls = 0;

  @override
  Future<Float32List> encode(Float32List planes, int size) async {
    calls++;
    return Float32List.fromList([0, 1]);
  }
}

Uint8List _photo(int shade) => Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(shade, 0, 0)),
  ),
);

void main() {
  test('the scene with the most probability wins, summed per scene', () {
    final bank = _bank();
    expect(guessScene(Float32List.fromList([1, 0]), bank), PhotoScene.portrait);
    expect(guessScene(Float32List.fromList([0, 1]), bank), PhotoScene.night);
    // equal similarity to both axes: night has two descriptions, so it wins
    expect(
      guessScene(Float32List.fromList([0.7, 0.7]), bank),
      PhotoScene.night,
    );
  });

  test('a wrong-size embedding or vector file is refused', () {
    expect(() => guessScene(Float32List(3), _bank()), throwsArgumentError);
    expect(
      () => SceneLabels.parse(
        jsonEncode({
          'dim': 2,
          'logitScale': 1,
          'inputSize': 8,
          'scenes': ['sky'],
        }),
        Uint8List(4),
      ),
      throwsFormatException,
    );
  });

  test(
    'the shipped labels cover every scene and match their vectors',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final bank = await SceneLabels.load();
      expect(bank.scenes.toSet(), PhotoScene.values.toSet());
      expect(bank.dimension, 512);
    },
  );

  test('only clear cases suggest a style', () {
    expect(suggestedStyle(PhotoScene.group), StyleType.pixel8bit);
    expect(suggestedStyle(PhotoScene.night), StyleType.vanGogh);
    expect(suggestedStyle(PhotoScene.sky), StyleType.vanGogh);
    expect(suggestedStyle(PhotoScene.portrait), isNull);
    expect(suggestedStyle(PhotoScene.day), isNull);
  });

  test('each scene has its paintings; the same photo keeps its painting', () {
    final photo = _photo(40);
    for (final scene in PhotoScene.values) {
      final path = vanGoghStyleFor(scene, photo);
      expect(vanGoghStylesByScene[scene], contains(path));
      expect(vanGoghStyleFor(scene, Uint8List.fromList(photo)), path);
    }
    // Starry Night is kept for skies only
    for (final scene in [
      PhotoScene.portrait,
      PhotoScene.group,
      PhotoScene.day,
    ]) {
      expect(
        vanGoghStylesByScene[scene]!.any((p) => p.endsWith('starry_night.jpg')),
        isFalse,
      );
    }
  });

  test(
    'the painting gives light and dark only, the colour stays the photo\'s',
    () {
      // a skin-coloured pixel painted as a mid cobalt blue
      final out = paintedPixel(0.1, 0.2, 0.7, 200, 150, 120, 1);
      expect(out.r > out.g && out.g > out.b, isTrue); // still warm, not blue
      expect(out.r - out.b, 200 - 120); // same hue spread as the photo
      // strength 0 leaves the photo as it is
      expect(paintedPixel(0, 0, 0, 200, 150, 120, 0), (r: 200, g: 150, b: 120));
      // clamped at the ends
      expect(paintedPixel(1, 1, 1, 250, 250, 250, 1), (r: 255, g: 255, b: 255));
    },
  );

  test(
    'one photo is encoded once; a failure gives null, not an error',
    () async {
      final encoder = _CountingEncoder();
      final guesser = SceneGuesser(
        encoder: encoder,
        loadLabels: () async => _bank(),
      );
      final photo = _photo(10);
      expect(await guesser.guess(photo), PhotoScene.night);
      expect(await guesser.guess(Uint8List.fromList(photo)), PhotoScene.night);
      expect(encoder.calls, 1);
      await guesser.guess(_photo(200));
      expect(encoder.calls, 2);

      final broken = SceneGuesser(
        encoder: encoder,
        loadLabels: () async => throw StateError('no asset'),
      );
      expect(await broken.guess(photo), isNull);
    },
  );
}
