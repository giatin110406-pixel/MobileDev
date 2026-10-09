import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';

/// Fixtures: raw model outputs of the real BlazeFace .tflite on real photos,
/// plus the boxes MediaPipe's own detector finds (server/eval/blazeface_fixture.py).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/blazeface_$name.json').readAsStringSync())
        as Map<String, dynamic>;

List<FaceBox> decodeFixture(Map<String, dynamic> data) => decodeBlazeFace(
  Float32List.fromList(
    (data['regressors'] as List).cast<num>().map((e) => e.toDouble()).toList(),
  ),
  Float32List.fromList(
    (data['scores'] as List).cast<num>().map((e) => e.toDouble()).toList(),
  ),
  regressorStride: 4,
);

double iou(FaceBox a, List<dynamic> b) {
  final ix =
      (a.right < b[2] ? a.right : b[2]) - (a.left > b[0] ? a.left : b[0]);
  final iy =
      (a.bottom < b[3] ? a.bottom : b[3]) - (a.top > b[1] ? a.top : b[1]);
  if (ix <= 0 || iy <= 0) return 0;
  final inter = ix * iy;
  final areaB = (b[2] - b[0]) * (b[3] - b[1]);
  return inter / (a.area + areaB - inter);
}

void main() {
  test('there are exactly 896 anchors', () {
    expect(blazeFaceAnchors().length, 896);
  });

  test('decoder matches the Python reference box for box', () {
    for (final name in ['photo_02', 'photo_04']) {
      final data = fixture(name);
      final boxes = decodeFixture(data);
      final expected = (data['expected_normalized'] as List).cast<List>();
      expect(boxes.length, expected.length, reason: name);
      for (var i = 0; i < boxes.length; i++) {
        expect(
          boxes[i].left,
          closeTo(expected[i][0] as num, 0.003),
          reason: name,
        );
        expect(
          boxes[i].top,
          closeTo(expected[i][1] as num, 0.003),
          reason: name,
        );
        expect(
          boxes[i].right,
          closeTo(expected[i][2] as num, 0.003),
          reason: name,
        );
        expect(
          boxes[i].bottom,
          closeTo(expected[i][3] as num, 0.003),
          reason: name,
        );
      }
    }
  });

  test(
    'boxes mapped to the 720x1280 photo agree with MediaPipe (IoU > 0.6)',
    () {
      for (final name in ['photo_02', 'photo_04']) {
        final data = fixture(name);
        final size = (data['size'] as List).cast<int>();
        // Same letterbox as the model input: scale by the longer side, centre.
        final scale =
            blazeFaceInputSize / (size[0] > size[1] ? size[0] : size[1]);
        final padX = (blazeFaceInputSize - (size[0] * scale).round()) ~/ 2;
        final padY = (blazeFaceInputSize - (size[1] * scale).round()) ~/ 2;
        final input = BlazeFaceInput(Float32List(0), scale, padX, padY);
        final boxes = decodeFixture(data).map(input.toSource).toList();
        final reference = (data['mediapipe_pixels'] as List).cast<List>();
        expect(boxes, isNotEmpty, reason: name);
        expect(
          iou(boxes.first, reference.first),
          greaterThan(0.6),
          reason: name,
        );
      }
    },
  );

  test('photos without people produce no face', () {
    expect(decodeFixture(fixture('photo_01')), isEmpty);
  });

  test('letterboxing keeps aspect ratio and pads with -1', () {
    final tall = img.Image(width: 64, height: 128);
    final input = blazeFaceInput(tall);
    expect(input.scale, 1.0);
    expect(input.padX, 32);
    expect(input.padY, 0);
    expect(input.tensor[0], -1.0); // padding
    expect(input.tensor.length, 128 * 128 * 3);
  });

  group('subject crop', () {
    test('no face keeps today\'s centred square', () {
      final crop = subjectCrop(720, 1280, const []);
      expect((crop.x, crop.y, crop.side), (0, 280, 720));
    });

    test('a small face is zoomed into a head-and-shoulders square', () {
      final crop = subjectCrop(720, 1280, const [
        FaceBox(300, 400, 400, 520, 0.9),
      ]);
      expect(crop.side, 336); // 2.8 x the larger face side (120)
      // Face stays inside the crop, in its upper half.
      expect(crop.x <= 300 && crop.x + crop.side >= 400, isTrue);
      expect(crop.y < 400 && crop.y + crop.side > 520, isTrue);
      expect(460 - crop.y, lessThan(crop.side / 2));
    });

    test('a big face never exceeds the image', () {
      final crop = subjectCrop(500, 500, const [
        FaceBox(50, 50, 450, 450, 0.9),
      ]);
      expect(crop.side, 500);
      expect((crop.x, crop.y), (0, 0));
    });

    test('several faces are framed together', () {
      final crop = subjectCrop(1000, 1000, const [
        FaceBox(100, 400, 200, 500, 0.9),
        FaceBox(600, 420, 700, 520, 0.9),
      ]);
      expect(crop.x <= 100 && crop.x + crop.side >= 700, isTrue);
    });
  });
}
