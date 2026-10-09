import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// BlazeFace short-range (MediaPipe) face detector, 128x128 input, 896 anchors.
/// Decoding is plain Dart so it can be unit-tested without native TFLite; the
/// reference fixtures come from server/eval/blazeface_fixture.py.
const blazeFaceInputSize = 128;
const blazeFaceAnchorCount = 896;

class FaceBox {
  const FaceBox(this.left, this.top, this.right, this.bottom, this.score);

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double score;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get area => math.max(0, width) * math.max(0, height);

  @override
  String toString() =>
      'FaceBox(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)}, '
      '${score.toStringAsFixed(2)})';
}

/// Anchor centres (x, y in 0..1) for the short-range model: strides 8,16,16,16
/// give 16x16 cells x 2 anchors plus 8x8 cells x 6 anchors = 896.
List<(double, double)> blazeFaceAnchors() {
  final anchors = <(double, double)>[];
  for (final (stride, perCell) in [(8, 2), (16, 6)]) {
    final cells = blazeFaceInputSize ~/ stride;
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        for (var k = 0; k < perCell; k++) {
          anchors.add(((x + 0.5) / cells, (y + 0.5) / cells));
        }
      }
    }
  }
  assert(anchors.length == blazeFaceAnchorCount);
  return anchors;
}

final _anchors = blazeFaceAnchors();

/// Decodes raw model outputs into boxes in 0..1 coordinates of the 128x128 input.
/// [regressors] holds [regressorStride] values per anchor (the model emits 16:
/// box then 6 keypoints; only the first four are read). [scores] are logits.
List<FaceBox> decodeBlazeFace(
  Float32List regressors,
  Float32List scores, {
  int regressorStride = 16,
  double threshold = 0.5,
  double nmsIoU = 0.3,
}) {
  final candidates = <FaceBox>[];
  for (var i = 0; i < blazeFaceAnchorCount; i++) {
    final probability = 1 / (1 + math.exp(-scores[i].clamp(-100.0, 100.0)));
    if (probability < threshold) continue;
    final o = i * regressorStride;
    final cx = regressors[o] / blazeFaceInputSize + _anchors[i].$1;
    final cy = regressors[o + 1] / blazeFaceInputSize + _anchors[i].$2;
    final w = regressors[o + 2] / blazeFaceInputSize;
    final h = regressors[o + 3] / blazeFaceInputSize;
    candidates.add(
      FaceBox(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, probability),
    );
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));
  final kept = <FaceBox>[];
  for (final box in candidates) {
    if (kept.every((other) => _iou(box, other) <= nmsIoU)) kept.add(box);
  }
  return kept;
}

double _iou(FaceBox a, FaceBox b) {
  final ix = math.max(
    0.0,
    math.min(a.right, b.right) - math.max(a.left, b.left),
  );
  final iy = math.max(
    0.0,
    math.min(a.bottom, b.bottom) - math.max(a.top, b.top),
  );
  final inter = ix * iy;
  final union = a.area + b.area - inter;
  return union <= 0 ? 0 : inter / union;
}

/// Image fitted into the 128x128 model input with black padding (keeps aspect).
class BlazeFaceInput {
  const BlazeFaceInput(this.tensor, this.scale, this.padX, this.padY);

  /// 128*128*3 floats in -1..1.
  final Float32List tensor;
  final double scale;
  final int padX;
  final int padY;

  /// Maps a box in 0..1 model coordinates to source-image pixels.
  FaceBox toSource(FaceBox box) => FaceBox(
    (box.left * blazeFaceInputSize - padX) / scale,
    (box.top * blazeFaceInputSize - padY) / scale,
    (box.right * blazeFaceInputSize - padX) / scale,
    (box.bottom * blazeFaceInputSize - padY) / scale,
    box.score,
  );
}

BlazeFaceInput blazeFaceInput(img.Image image) {
  final side = math.max(image.width, image.height);
  final scale = blazeFaceInputSize / side;
  final width = math.max(1, (image.width * scale).round());
  final height = math.max(1, (image.height * scale).round());
  final padX = (blazeFaceInputSize - width) ~/ 2;
  final padY = (blazeFaceInputSize - height) ~/ 2;
  final resized = img.copyResize(
    image,
    width: width,
    height: height,
    interpolation: img.Interpolation.linear,
  );
  final tensor = Float32List(blazeFaceInputSize * blazeFaceInputSize * 3)
    ..fillRange(0, blazeFaceInputSize * blazeFaceInputSize * 3, -1.0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = resized.getPixel(x, y);
      final o = ((y + padY) * blazeFaceInputSize + x + padX) * 3;
      tensor[o] = (p.r - 127.5) / 127.5;
      tensor[o + 1] = (p.g - 127.5) / 127.5;
      tensor[o + 2] = (p.b - 127.5) / 127.5;
    }
  }
  return BlazeFaceInput(tensor, scale, padX, padY);
}

/// Runs the model from [modelBytes] and returns faces in source-image pixels,
/// largest first. Any failure (missing native library, bad model) yields an
/// empty list so callers fall back to the un-cropped photo.
List<FaceBox> detectFaces(Uint8List modelBytes, img.Image image) {
  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromBuffer(modelBytes);
    final input = blazeFaceInput(image);
    interpreter.getInputTensor(0).data = Uint8List.view(input.tensor.buffer);
    interpreter.invoke();

    Float32List? regressors;
    Float32List? scores;
    for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
      final tensor = interpreter.getOutputTensor(i);
      final values = Uint8List.fromList(tensor.data).buffer.asFloat32List();
      if (tensor.shape.last == 16) regressors = values;
      if (tensor.shape.last == 1) scores = values;
    }
    if (regressors == null || scores == null) return const [];
    final boxes = decodeBlazeFace(
      regressors,
      scores,
    ).map(input.toSource).toList()..sort((a, b) => b.area.compareTo(a.area));
    return boxes;
  } catch (_) {
    return const [];
  } finally {
    interpreter?.close();
  }
}

/// Square crop (in source pixels) used before pixelating.
class SubjectCrop {
  const SubjectCrop(this.x, this.y, this.side);

  final int x;
  final int y;
  final int side;
}

/// Head-and-shoulders square around [faces]; the largest centred square when
/// there is no face. [expand] is crop side / face size; the crop is also moved
/// down by [shiftDown] face-heights so shoulders are kept.
SubjectCrop subjectCrop(
  int width,
  int height,
  List<FaceBox> faces, {
  double expand = 2.8,
  double shiftDown = 0.25,
}) {
  final maxSide = math.min(width, height);
  if (faces.isEmpty) {
    return SubjectCrop(
      (width - maxSide) ~/ 2,
      (height - maxSide) ~/ 2,
      maxSide,
    );
  }
  final left = faces.map((f) => f.left).reduce(math.min);
  final top = faces.map((f) => f.top).reduce(math.min);
  final right = faces.map((f) => f.right).reduce(math.max);
  final bottom = faces.map((f) => f.bottom).reduce(math.max);
  final faceSize = math.max(right - left, bottom - top);
  final side = math.min(maxSide.toDouble(), faceSize * expand);
  final cx = (left + right) / 2;
  final cy = (top + bottom) / 2 + faceSize * shiftDown;
  final x = (cx - side / 2).clamp(0.0, width - side);
  final y = (cy - side / 2).clamp(0.0, height - side);
  return SubjectCrop(x.round(), y.round(), side.round());
}

/// Elliptical face mask on the pixel grid (1 inside), for the crop [crop] of the
/// source image rendered at [grid] x [grid] pixels.
Uint8List faceMask(List<FaceBox> faces, SubjectCrop crop, int grid) {
  final mask = Uint8List(grid * grid);
  final k = grid / crop.side;
  for (final f in faces) {
    final cx = (f.centerX - crop.x) * k;
    final cy = (f.centerY - crop.y) * k;
    final rx = f.width * k * 0.55;
    final ry = f.height * k * 0.6;
    if (rx <= 0 || ry <= 0) continue;
    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        final dx = (x + 0.5 - cx) / rx;
        final dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) mask[y * grid + x] = 1;
      }
    }
  }
  return mask;
}
