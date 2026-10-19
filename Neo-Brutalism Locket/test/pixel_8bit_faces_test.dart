import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_8bit_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/cleanup.dart';

Uint8List photo() {
  final image = img.Image(width: 400, height: 300);
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 400; x++) {
      image.setPixelRgb(x, y, x * 255 ~/ 400, y * 255 ~/ 300, 120);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List render(List<List<double>> boxes) => pixel8BitFilterInBackground({
  'bytes': photo(),
  'pixelWidth': 96,
  'faceBoxes': boxes,
});

void main() {
  paletteTests();
  test('removeSpeckles fixes a pixel that matches no neighbour', () {
    final indices = Uint8List(25)..fillRange(0, 25, 3);
    indices[12] = 9;
    removeSpeckles(indices, 5, 5);
    expect(indices[12], 3);
  });

  test('removeSpeckles leaves a 2x2 detail and the kept face alone', () {
    final detail = Uint8List(25)..fillRange(0, 25, 3);
    for (final i in [11, 12, 16, 17]) {
      detail[i] = 9;
    }
    removeSpeckles(detail, 5, 5);
    expect([detail[11], detail[12], detail[16], detail[17]], [9, 9, 9, 9]);

    final face = Uint8List(25)..fillRange(0, 25, 3);
    face[12] = 9;
    final keep = Uint8List(25)..[12] = 1;
    removeSpeckles(face, 5, 5, keep: keep);
    expect(face[12], 9);
  });

  test('a tiny or weak face gets no face treatment', () {
    final none = render(const []);
    // 20 px wide in a 300 px frame is under 7%.
    expect(
      render(const [
        [100, 100, 120, 120, 0.9],
      ]),
      none,
    );
    // Big enough but a weak detection.
    expect(
      render(const [
        [100, 80, 220, 200, 0.5],
      ]),
      none,
    );
  });

  test('a clear face gets the face treatment', () {
    expect(
      render(const [
        [250, 60, 370, 180, 0.9],
      ]),
      isNot(render(const [])),
    );
  });
}

void paletteTests() {
  test('a picture uses at most 18 colours', () {
    final png = img.decodePng(
      pixel8BitFilterInBackground({'bytes': photo(), 'pixelWidth': 96}),
    )!;
    final colours = <int>{};
    for (final p in png) {
      colours.add((p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt());
    }
    expect(colours.length, lessThanOrEqualTo(18));
  });
}
