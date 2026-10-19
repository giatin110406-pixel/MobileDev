import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_mesh.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// MediaPipe Selfie Segmentation (general model, 256x256 in and out, Apache-2.0):
/// per pixel, how likely it belongs to a person.
const segmentationSize = 256;

/// The picture's centred square [side]x[side] at (x, y), as model input.
Float32List segmentationInput(img.Image image, int x, int y, int side) =>
    squareCropTensor(
      image,
      x + side / 2,
      y + side / 2,
      side.toDouble(),
      segmentationSize,
    );

/// Runs the model on [input]; null on any failure (no native library, bad model).
Float32List? runSegmentationModel(Uint8List modelBytes, Float32List input) {
  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromBuffer(modelBytes);
    interpreter.getInputTensor(0).data = Uint8List.view(input.buffer);
    interpreter.invoke();
    final tensor = interpreter.getOutputTensor(0);
    return Uint8List.fromList(tensor.data).buffer.asFloat32List();
  } catch (_) {
    return null;
  } finally {
    interpreter?.close();
  }
}

/// Averages the 256x256 person probability onto a [grid]x[grid] mask (0..1).
Float32List personMaskToGrid(Float32List raw, int grid) {
  final out = Float32List(grid * grid);
  final k = segmentationSize / grid;
  for (var y = 0; y < grid; y++) {
    final y0 = (y * k).floor();
    final y1 = ((y + 1) * k).ceil().clamp(y0 + 1, segmentationSize);
    for (var x = 0; x < grid; x++) {
      final x0 = (x * k).floor();
      final x1 = ((x + 1) * k).ceil().clamp(x0 + 1, segmentationSize);
      var sum = 0.0;
      for (var sy = y0; sy < y1; sy++) {
        for (var sx = x0; sx < x1; sx++) {
          sum += raw[sy * segmentationSize + sx];
        }
      }
      out[y * grid + x] = sum / ((y1 - y0) * (x1 - x0));
    }
  }
  return out;
}

/// True when a person fills a believable part of the picture: a handful of
/// stray pixels (or the whole frame) means the model found nobody.
bool hasPerson(Float32List mask) {
  var inside = 0;
  for (final v in mask) {
    if (v >= 0.5) inside++;
  }
  final share = inside / mask.length;
  return share >= 0.04 && share <= 0.97;
}
