import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_features.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_mesh.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/person_mask.dart';

/// Fixtures: raw output of the real face_landmark.tflite (run in Python on the
/// crop this code builds) next to MediaPipe's own landmarks for the same photo.
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/facemesh_$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final name in ['photo_02']) {
    test('$name: decoded landmarks agree with MediaPipe', () {
      final data = fixture(name);
      final b = (data['box'] as List)
          .cast<num>()
          .map((e) => e.toDouble())
          .toList();
      final box = FaceBox(b[0], b[1], b[2], b[3], 1);
      final mesh = decodeFaceMesh(
        Float32List.fromList(
          (data['landmarks'] as List)
              .cast<num>()
              .map((e) => e.toDouble())
              .toList(),
        ),
        (data['logit'] as num).toDouble(),
        faceMeshCrop(box),
      )!;
      final reference = (data['mediapipe'] as List).cast<List>();
      var total = 0.0;
      for (var i = 0; i < faceMeshPointCount; i++) {
        final dx = mesh.x(i) - (reference[i][0] as num);
        final dy = mesh.y(i) - (reference[i][1] as num);
        total += math.sqrt(dx * dx + dy * dy);
      }
      expect(total / faceMeshPointCount / box.width, lessThan(0.065));
    });
  }

  test('a "no face" logit gives no mesh', () {
    expect(
      decodeFaceMesh(Float32List(1404), -5, const FaceMeshCrop(50, 50, 100)),
      isNull,
    );
  });

  test('a rotated crop maps landmarks back through the rotation', () {
    // Landmark 0 one eye-width right of the crop centre, in a crop rolled 90 deg.
    final raw = Float32List(1404);
    raw[0] = 96 + 20;
    raw[1] = 96;
    final mesh = decodeFaceMesh(
      raw,
      5,
      const FaceMeshCrop(100, 100, 192, math.pi / 2),
    )!;
    expect(mesh.x(0), closeTo(100, 1e-3));
    expect(mesh.y(0), closeTo(120, 1e-3));
  });

  test('a face level enough needs no second pass; a tilted one does', () {
    FaceMesh tilted(double roll) {
      final p = Float32List(faceMeshPointCount * 2);
      for (final (ids, x) in [
        ([33, 133], -20.0),
        ([362, 263], 20.0),
      ]) {
        for (final i in ids) {
          p[i * 2] = x * math.cos(roll);
          p[i * 2 + 1] = x * math.sin(roll);
        }
      }
      return FaceMesh(p, 1);
    }

    const crop = FaceMeshCrop(0, 0, 100);
    expect(refinedMeshCrop(crop, tilted(0.05)), isNull);
    final second = refinedMeshCrop(crop, tilted(0.5))!;
    expect(second.angle, closeTo(0.5, 1e-6));
  });

  test('person mask: averaged onto the grid, and "nobody" is recognised', () {
    final raw = Float32List(segmentationSize * segmentationSize);
    for (var y = 0; y < segmentationSize; y++) {
      for (var x = segmentationSize ~/ 2; x < segmentationSize; x++) {
        raw[y * segmentationSize + x] = 1;
      }
    }
    final grid = personMaskToGrid(raw, 16);
    expect(grid[0], 0);
    expect(grid[15], 1);
    expect(hasPerson(grid), isTrue);
    expect(hasPerson(Float32List(256)), isFalse);
    expect(hasPerson(Float32List(256)..fillRange(0, 256, 1)), isFalse);
  });

  test('features darken the eyes and redden the lips on a synthetic face', () {
    const grid = 64;
    const crop = SubjectCrop(0, 0, 64);
    final p = Float32List(faceMeshPointCount * 2);
    void ring(List<int> ids, double cx, double cy, double rx, double ry) {
      for (var k = 0; k < ids.length; k++) {
        final a = 2 * math.pi * k / ids.length;
        p[ids[k] * 2] = cx + rx * math.cos(a);
        p[ids[k] * 2 + 1] = cy + ry * math.sin(a);
      }
    }

    ring(faceOval, 32, 32, 26, 30);
    ring(rightEye, 22, 26, 4, 1.5);
    ring(leftEye, 42, 26, 4, 1.5);
    ring(outerLips, 32, 44, 7, 3);
    ring(innerLips, 32, 44, 5, 1);
    final mesh = FaceMesh(p, 1);

    final lab = Float32List(grid * grid * 3);
    for (var i = 0; i < grid * grid; i++) {
      lab[i * 3] = 0.8;
      lab[i * 3 + 1] = 0.05;
      lab[i * 3 + 2] = 0.05;
    }
    paintFaceFeatures(lab, grid, [mesh], crop);

    double l(int x, int y) => lab[(y * grid + x) * 3];
    expect(l(22, 26), lessThan(0.3), reason: 'right eye is dark');
    expect(l(42, 26), lessThan(0.3), reason: 'left eye is dark');
    expect(l(32, 44), lessThan(0.6), reason: 'mouth is darker than skin');
    expect(l(32, 14), closeTo(0.8, 1e-6), reason: 'forehead is untouched');
    final mask = meshFaceMask([mesh], crop, grid);
    expect(mask[32 * grid + 32], 1);
    expect(mask[0], 0);
  });
}
