import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// MediaPipe Face Mesh (468 landmarks, 192x192 input, Apache-2.0). Decoding is
/// plain Dart so it can be tested without native TFLite; fixtures come from the
/// same model run in Python.
const faceMeshInputSize = 192;
const faceMeshPointCount = 468;

/// Square region (source pixels) the mesh model looks at: the detected face box
/// grown by 1.5x, centred on the box. The first pass assumes an upright face;
/// [refinedMeshCrop] then levels the eyes for a second pass on tilted faces.
class FaceMeshCrop {
  const FaceMeshCrop(this.cx, this.cy, this.side, [this.angle = 0]);

  final double cx;
  final double cy;
  final double side;

  /// Roll in radians: the crop's x axis points along the eye line.
  final double angle;
}

FaceMeshCrop faceMeshCrop(FaceBox box) => FaceMeshCrop(
  box.centerX,
  box.centerY,
  math.max(box.width, box.height) * 1.5,
);

/// Landmarks in source-image pixels: x0, y0, x1, y1, ...
class FaceMesh {
  const FaceMesh(this.points, this.score);

  final Float32List points;
  final double score;

  double x(int i) => points[i * 2];
  double y(int i) => points[i * 2 + 1];
}

/// Samples the square (cx, cy, side) of [image] into a size x size RGB tensor
/// with values 0..1 (bilinear, black outside the picture).
Float32List squareCropTensor(
  img.Image image,
  double cx,
  double cy,
  double side,
  int size, [
  double angle = 0,
]) {
  final tensor = Float32List(size * size * 3);
  final step = side / size;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final w = image.width;
  final h = image.height;
  (double, double, double) at(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return (0, 0, 0);
    final p = image.getPixel(x, y);
    return (p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
  }

  for (var ty = 0; ty < size; ty++) {
    for (var tx = 0; tx < size; tx++) {
      final ox = (tx + 0.5 - size / 2) * step;
      final oy = (ty + 0.5 - size / 2) * step;
      final sx = cx + cosA * ox - sinA * oy - 0.5;
      final sy = cy + sinA * ox + cosA * oy - 0.5;
      final x0 = sx.floor();
      final y0 = sy.floor();
      final fx = sx - x0;
      final fy = sy - y0;
      final a = at(x0, y0), b = at(x0 + 1, y0);
      final c = at(x0, y0 + 1), d = at(x0 + 1, y0 + 1);
      final o = (ty * size + tx) * 3;
      tensor[o] =
          ((a.$1 * (1 - fx) + b.$1 * fx) * (1 - fy) +
              (c.$1 * (1 - fx) + d.$1 * fx) * fy) /
          255;
      tensor[o + 1] =
          ((a.$2 * (1 - fx) + b.$2 * fx) * (1 - fy) +
              (c.$2 * (1 - fx) + d.$2 * fx) * fy) /
          255;
      tensor[o + 2] =
          ((a.$3 * (1 - fx) + b.$3 * fx) * (1 - fy) +
              (c.$3 * (1 - fx) + d.$3 * fx) * fy) /
          255;
    }
  }
  return tensor;
}

Float32List faceMeshInput(img.Image image, FaceMeshCrop crop) =>
    squareCropTensor(
      image,
      crop.cx,
      crop.cy,
      crop.side,
      faceMeshInputSize,
      crop.angle,
    );

/// Turns the raw model outputs (1404 landmark values in crop pixels, one face
/// logit) into a mesh in source pixels. Null when the model says "no face".
FaceMesh? decodeFaceMesh(
  Float32List landmarks,
  double faceLogit,
  FaceMeshCrop crop,
) {
  final score = 1 / (1 + math.exp(-faceLogit.clamp(-50.0, 50.0)));
  if (score < 0.5 || landmarks.length < faceMeshPointCount * 3) return null;
  final points = Float32List(faceMeshPointCount * 2);
  final k = crop.side / faceMeshInputSize;
  final cosA = math.cos(crop.angle);
  final sinA = math.sin(crop.angle);
  for (var i = 0; i < faceMeshPointCount; i++) {
    final ox = (landmarks[i * 3] - faceMeshInputSize / 2) * k;
    final oy = (landmarks[i * 3 + 1] - faceMeshInputSize / 2) * k;
    points[i * 2] = crop.cx + cosA * ox - sinA * oy;
    points[i * 2 + 1] = crop.cy + sinA * ox + cosA * oy;
  }
  return FaceMesh(points, score);
}

/// Roll of the face in radians, from the line between the eye centres.
double meshRoll(FaceMesh mesh) {
  (double, double) centre(List<int> ids) {
    var x = 0.0, y = 0.0;
    for (final i in ids) {
      x += mesh.x(i);
      y += mesh.y(i);
    }
    return (x / ids.length, y / ids.length);
  }

  final (rx, ry) = centre(const [33, 133]);
  final (lx, ly) = centre(const [362, 263]);
  return math.atan2(ly - ry, lx - rx);
}

/// Second-pass crop for a face tilted more than about 8 degrees, centred on the
/// first mesh and levelled on the eye line; null when the first crop was fine.
FaceMeshCrop? refinedMeshCrop(FaceMeshCrop first, FaceMesh mesh) {
  final roll = meshRoll(mesh);
  if (roll.abs() < 0.14) return null;
  var x = 0.0, y = 0.0;
  for (final i in const [1, 152, 10]) {
    x += mesh.x(i);
    y += mesh.y(i);
  }
  return FaceMeshCrop(x / 3, y / 3, first.side, first.angle + roll);
}

/// Raw outputs of one mesh inference.
class FaceMeshRaw {
  const FaceMeshRaw(this.landmarks, this.faceLogit);

  final Float32List landmarks;
  final double faceLogit;
}

/// Runs the mesh model on [input] (see [faceMeshInput]). Any failure (missing
/// native library, bad model) yields null so the caller skips the face detail.
FaceMeshRaw? runFaceMeshModel(Uint8List modelBytes, Float32List input) {
  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromBuffer(modelBytes);
    interpreter.getInputTensor(0).data = Uint8List.view(input.buffer);
    interpreter.invoke();
    Float32List? landmarks;
    double? logit;
    for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
      final tensor = interpreter.getOutputTensor(i);
      final values = Uint8List.fromList(tensor.data).buffer.asFloat32List();
      if (tensor.shape.last == faceMeshPointCount * 3) landmarks = values;
      if (tensor.shape.last == 1) logit = values.first;
    }
    if (landmarks == null || logit == null) return null;
    return FaceMeshRaw(landmarks, logit);
  } catch (_) {
    return null;
  } finally {
    interpreter?.close();
  }
}

/// Landmark index groups (MediaPipe Face Mesh topology).
const faceOval = <int>[
  10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, //
  378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127,
  162, 21, 54, 103, 67, 109,
];

/// "Left"/"right" are the person's own, as in MediaPipe.
const rightEye = <int>[
  33,
  7,
  163,
  144,
  145,
  153,
  154,
  155,
  133,
  173,
  157,
  158,
  159,
  160,
  161,
  246, //
];
const leftEye = <int>[
  263,
  249,
  390,
  373,
  374,
  380,
  381,
  382,
  362,
  398,
  384,
  385,
  386,
  387,
  388,
  466,
];
const rightEyeCorners = (33, 133);
const leftEyeCorners = (362, 263);

/// Eyebrows, ordered along the brow from the nose outward.
const rightBrow = <int>[55, 65, 52, 53, 46];
const leftBrow = <int>[285, 295, 282, 283, 276];

const outerLips = <int>[
  61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409, 270, 269, 267, 0, //
  37, 39, 40, 185,
];
const innerLips = <int>[
  78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312, 13, //
  82, 81, 80, 191,
];
const mouthCorners = (61, 291);
