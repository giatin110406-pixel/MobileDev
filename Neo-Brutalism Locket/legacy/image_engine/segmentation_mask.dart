import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PersonMask {
  PersonMask({
    required this.width,
    required this.height,
    required Float32List confidences,
  }) : confidences = Float32List.fromList(confidences) {
    if (width <= 0 ||
        height <= 0 ||
        this.confidences.length != width * height) {
      throw ArgumentError('Mask dimensions must match its confidence data.');
    }
  }

  final int width;
  final int height;
  final Float32List confidences;
}

class MaskQuality {
  const MaskQuality({
    required this.foregroundRatio,
    required this.meanForegroundConfidence,
    required this.canReplaceBackground,
  });

  final double foregroundRatio;
  final double meanForegroundConfidence;
  final bool canReplaceBackground;
}

MaskQuality assessMaskQuality(
  PersonMask mask, {
  double threshold = 0.5,
  double minimumForegroundRatio = 0.01,
  double maximumForegroundRatio = 0.995,
  double minimumMeanForegroundConfidence = 0.55,
}) {
  var foregroundCount = 0;
  var foregroundConfidenceTotal = 0.0;
  for (final confidence in mask.confidences) {
    if (confidence >= threshold) {
      foregroundCount++;
      foregroundConfidenceTotal += confidence;
    }
  }

  final foregroundRatio = foregroundCount / mask.confidences.length;
  final meanForegroundConfidence = foregroundCount == 0
      ? 0.0
      : foregroundConfidenceTotal / foregroundCount;
  return MaskQuality(
    foregroundRatio: foregroundRatio,
    meanForegroundConfidence: meanForegroundConfidence,
    canReplaceBackground:
        foregroundRatio >= minimumForegroundRatio &&
        foregroundRatio <= maximumForegroundRatio &&
        meanForegroundConfidence >= minimumMeanForegroundConfidence,
  );
}

PersonMask resizePersonMask(PersonMask source, int width, int height) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Output mask dimensions must be positive.');
  }
  if (source.width == width && source.height == height) return source;

  final output = Float32List(width * height);
  for (var row = 0; row < height; row++) {
    final sourceY = _sourceCoordinate(row, source.height, height);
    final top = sourceY.floor();
    final bottom = (top + 1).clamp(0, source.height - 1);
    final verticalBlend = sourceY - top;
    for (var column = 0; column < width; column++) {
      final sourceX = _sourceCoordinate(column, source.width, width);
      final left = sourceX.floor();
      final right = (left + 1).clamp(0, source.width - 1);
      final horizontalBlend = sourceX - left;
      final topLeft = source.confidences[top * source.width + left];
      final topRight = source.confidences[top * source.width + right];
      final bottomLeft = source.confidences[bottom * source.width + left];
      final bottomRight = source.confidences[bottom * source.width + right];
      final topValue = _lerp(topLeft, topRight, horizontalBlend);
      final bottomValue = _lerp(bottomLeft, bottomRight, horizontalBlend);
      output[row * width + column] = _lerp(
        topValue,
        bottomValue,
        verticalBlend,
      );
    }
  }
  return PersonMask(width: width, height: height, confidences: output);
}

Float32List featherPersonMask(
  PersonMask mask, {
  double threshold = 0.5,
  double softness = 0.2,
}) {
  if (softness <= 0) throw ArgumentError.value(softness, 'softness');
  final halfSoftness = softness / 2;
  final start = threshold - halfSoftness;
  final output = Float32List(mask.confidences.length);
  for (var index = 0; index < mask.confidences.length; index++) {
    final normalized = ((mask.confidences[index] - start) / softness).clamp(
      0.0,
      1.0,
    );
    output[index] = normalized * normalized * (3 - 2 * normalized);
  }
  return output;
}

img.Image replaceBackgroundWithPalette(
  img.Image source,
  PersonMask mask,
  List<int> backgroundRgb, {
  double threshold = 0.5,
  double featherSoftness = 0.2,
}) {
  if (backgroundRgb.length != 3 ||
      backgroundRgb.any((value) => value < 0 || value > 255)) {
    throw ArgumentError.value(backgroundRgb, 'backgroundRgb');
  }
  final quality = assessMaskQuality(mask, threshold: threshold);
  if (!quality.canReplaceBackground) return source;

  final fittedMask = resizePersonMask(mask, source.width, source.height);
  final alpha = featherPersonMask(
    fittedMask,
    threshold: threshold,
    softness: featherSoftness,
  );
  final output = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  for (var row = 0; row < source.height; row++) {
    for (var column = 0; column < source.width; column++) {
      final index = row * source.width + column;
      final pixel = source.getPixel(column, row);
      final personAlpha = alpha[index];
      output.setPixelRgb(
        column,
        row,
        _blend(backgroundRgb[0], pixel.r.toInt(), personAlpha),
        _blend(backgroundRgb[1], pixel.g.toInt(), personAlpha),
        _blend(backgroundRgb[2], pixel.b.toInt(), personAlpha),
      );
    }
  }
  return output;
}

double _sourceCoordinate(int target, int sourceSize, int targetSize) {
  final coordinate = (target + 0.5) * sourceSize / targetSize - 0.5;
  return coordinate.clamp(0.0, (sourceSize - 1).toDouble());
}

double _lerp(double start, double end, double amount) =>
    start + (end - start) * amount;

int _blend(int background, int foreground, double alpha) =>
    (background + (foreground - background) * alpha).round().clamp(0, 255);
