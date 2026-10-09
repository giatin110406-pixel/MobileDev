import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'segmentation_mask.dart';

const imageProcessingPalette = <List<int>>[
  [236, 230, 194],
  [253, 242, 233],
  [255, 107, 107],
  [163, 136, 238],
  [78, 205, 196],
  [255, 230, 109],
  [69, 183, 209],
  [247, 160, 114],
];

Uint8List stylizePhoto(Uint8List input) {
  final decoded = decodePhoto(input);
  final source = resizeForProcessing(decoded);
  return _encodeStylized(source);
}

Uint8List stylizePhotoWithMask(
  Uint8List input,
  PersonMask? personMask, {
  List<int> backgroundRgb = const [78, 205, 196],
}) {
  final decoded = decodePhoto(input);
  var source = resizeForProcessing(decoded);
  if (personMask != null &&
      assessMaskQuality(personMask).canReplaceBackground) {
    source = replaceBackgroundWithPalette(source, personMask, backgroundRgb);
  }
  return _encodeStylized(source);
}

Uint8List _encodeStylized(img.Image source) {
  final luminance = computeLuminance(source);
  final edgeMask = extractEdgeMask(luminance, source.width, source.height);
  final poster = quantizeToPalette(source, edgeMask);
  return Uint8List.fromList(img.encodePng(poster, level: 3));
}

img.Image decodePhoto(Uint8List input) {
  try {
    final decoded = img.decodeImage(input);
    if (decoded == null) throw const FormatException('Unsupported image data');
    return decoded;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Unsupported image data');
  }
}

img.Image resizeForProcessing(img.Image source, {int maxSide = 900}) {
  final longestSide = source.width > source.height
      ? source.width
      : source.height;
  if (longestSide <= maxSide) return source;

  final scale = maxSide / longestSide;
  return img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.average,
  );
}

Float32List computeLuminance(img.Image source) {
  final values = Float32List(source.width * source.height);
  for (var row = 0; row < source.height; row++) {
    for (var column = 0; column < source.width; column++) {
      final pixel = source.getPixel(column, row);
      values[row * source.width + column] =
          0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
    }
  }
  return values;
}

Uint8List extractEdgeMask(
  Float32List luminance,
  int width,
  int height, {
  double threshold = 105,
}) {
  if (luminance.length != width * height) {
    throw ArgumentError.value(
      luminance.length,
      'luminance',
      'Must match dimensions',
    );
  }
  final mask = Uint8List(width * height);
  for (var row = 0; row < height; row++) {
    for (var column = 0; column < width; column++) {
      final left = luminance[row * width + (column > 0 ? column - 1 : column)];
      final right =
          luminance[row * width + (column < width - 1 ? column + 1 : column)];
      final above = luminance[(row > 0 ? row - 1 : row) * width + column];
      final below =
          luminance[(row < height - 1 ? row + 1 : row) * width + column];
      final edgeStrength = (right - left).abs() + (below - above).abs();
      mask[row * width + column] = edgeStrength > threshold ? 1 : 0;
    }
  }
  return mask;
}

img.Image quantizeToPalette(img.Image source, Uint8List edgeMask) {
  final width = source.width;
  final height = source.height;
  if (edgeMask.length != width * height) {
    throw ArgumentError.value(
      edgeMask.length,
      'edgeMask',
      'Must match dimensions',
    );
  }
  final output = img.Image(width: width, height: height, numChannels: 3);
  for (var row = 0; row < height; row++) {
    for (var column = 0; column < width; column++) {
      if (edgeMask[row * width + column] == 1) {
        output.setPixelRgb(column, row, 26, 26, 26);
        continue;
      }
      final pixel = source.getPixel(column, row);
      final color = nearestPaletteColor(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      output.setPixelRgb(column, row, color[0], color[1], color[2]);
    }
  }
  return output;
}

List<int> nearestPaletteColor(int red, int green, int blue) {
  var closest = imageProcessingPalette.first;
  var closestDistance = double.infinity;
  for (final color in imageProcessingPalette) {
    final redDelta = red - color[0];
    final greenDelta = green - color[1];
    final blueDelta = blue - color[2];
    final distance =
        0.30 * redDelta * redDelta +
        0.59 * greenDelta * greenDelta +
        0.11 * blueDelta * blueDelta;
    if (distance < closestDistance) {
      closest = color;
      closestDistance = distance;
    }
  }
  return closest;
}
