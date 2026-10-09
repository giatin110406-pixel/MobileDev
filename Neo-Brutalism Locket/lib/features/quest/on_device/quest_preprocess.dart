import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns a photo into what the image encoder takes: [size] x [size] pixels
/// (short side scaled to [size], then centre-cropped), red/green/blue planes
/// one after another, each value 0..1. The model has no mean/std step.
///
/// Throws [FormatException] when [jpeg] is not an image.
Float32List preprocessQuestPhoto(Uint8List jpeg, int size) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(jpeg);
  } catch (_) {
    // The decoders throw assorted errors on bytes that are not a picture.
    throw const FormatException('not an image');
  }
  if (decoded == null) throw const FormatException('not an image');
  final scale = size / (decoded.width < decoded.height ? decoded.width : decoded.height);
  final width = (decoded.width * scale).round().clamp(size, 1 << 16);
  final height = (decoded.height * scale).round().clamp(size, 1 << 16);
  // Averaging is the right filter when shrinking; the check was measured to
  // give the same verdicts with box, bilinear or even nearest resizing.
  final resized = img.copyResize(
    decoded,
    width: width,
    height: height,
    interpolation: img.Interpolation.average,
  );
  final left = (width - size) ~/ 2;
  final top = (height - size) ~/ 2;
  final plane = size * size;
  final out = Float32List(3 * plane);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final pixel = resized.getPixel(left + x, top + y);
      final i = y * size + x;
      out[i] = pixel.r / 255.0;
      out[plane + i] = pixel.g / 255.0;
      out[2 * plane + i] = pixel.b / 255.0;
    }
  }
  return out;
}
