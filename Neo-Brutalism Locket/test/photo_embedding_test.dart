import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';
import 'package:neo_brutalism_locket/features/search/photo_embedding.dart';
import 'package:image/image.dart' as img;

int _half(double value) {
  final bytes = float16Bytes(Float32List.fromList([value]));
  return bytes[0] | (bytes[1] << 8);
}

class _FakeEncoder implements QuestImageEncoder {
  _FakeEncoder(this.vector);
  final Float32List vector;

  @override
  Future<Float32List> encode(Float32List planes, int size) async => vector;
}

void main() {
  test('float16 bits match IEEE 754 half precision', () {
    expect(_half(1), 0x3c00);
    expect(_half(-2), 0xc000);
    expect(_half(0.5), 0x3800);
    expect(_half(0.1), 0x2e66);
    expect(_half(65504), 0x7bff); // largest half
    expect(_half(70000), 0x7c00); // too big: infinity
    expect(_half(6e-8), 0x0001); // smallest subnormal
    expect(_half(1e-8), 0x0000); // too small: zero
    expect(_half(-0.0), 0x8000);
  });

  test('a unit vector survives float16 to well within search precision', () {
    final random = math.Random(1);
    final v = Float32List.fromList([
      for (var i = 0; i < embeddingDimension; i++) random.nextDouble() - 0.5,
    ]);
    var norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    for (var i = 0; i < v.length; i++) {
      v[i] /= math.sqrt(norm);
    }
    final back = float32FromFloat16Bytes(float16Bytes(v));
    var dot = 0.0;
    for (var i = 0; i < v.length; i++) {
      dot += v[i] * back[i];
    }
    expect(back.length, embeddingDimension);
    expect(dot, closeTo(1, 1e-5));
  });

  test('a photo becomes 1024 bytes of base64; failures give null', () async {
    final photo = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 300, height: 200)),
    );
    final vector = Float32List(embeddingDimension)..[0] = 1;
    final b64 = await embedPhotoForSearch(photo, encoder: _FakeEncoder(vector));
    expect(base64Decode(b64!).length, embeddingBytes);
    expect(float32FromFloat16Bytes(base64Decode(b64))[0], 1);

    expect(
      await embedPhotoForSearch(
        Uint8List.fromList([1, 2, 3]),
        encoder: _FakeEncoder(vector),
      ),
      isNull,
      reason: 'not a picture',
    );
    expect(
      await embedPhotoForSearch(photo, encoder: _FakeEncoder(Float32List(3))),
      isNull,
      reason: 'wrong size from the model',
    );
  });
}
