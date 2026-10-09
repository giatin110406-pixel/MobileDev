import 'dart:typed_data';

import 'color_space.dart';

/// Kuwahara filter (four-quadrant, integral-image based). Flattens texture into
/// painted-looking regions while keeping edges sharp.
Float32List kuwahara(Float32List rgb, int width, int height, {int radius = 2}) {
  final stride = width + 1;
  final size = stride * (height + 1);
  final sumLuma = Float64List(size);
  final sumLumaSquared = Float64List(size);
  final sumRed = Float64List(size);
  final sumGreen = Float64List(size);
  final sumBlue = Float64List(size);

  for (var y = 0; y < height; y++) {
    var rowLuma = 0.0, rowLumaSquared = 0.0;
    var rowRed = 0.0, rowGreen = 0.0, rowBlue = 0.0;
    for (var x = 0; x < width; x++) {
      final o = (y * width + x) * 3;
      final luma = luma709(rgb[o], rgb[o + 1], rgb[o + 2]);
      rowLuma += luma;
      rowLumaSquared += luma * luma;
      rowRed += rgb[o];
      rowGreen += rgb[o + 1];
      rowBlue += rgb[o + 2];
      final here = (y + 1) * stride + x + 1;
      final above = y * stride + x + 1;
      sumLuma[here] = sumLuma[above] + rowLuma;
      sumLumaSquared[here] = sumLumaSquared[above] + rowLumaSquared;
      sumRed[here] = sumRed[above] + rowRed;
      sumGreen[here] = sumGreen[above] + rowGreen;
      sumBlue[here] = sumBlue[above] + rowBlue;
    }
  }

  double box(Float64List sums, int x0, int y0, int x1, int y1) =>
      sums[(y1 + 1) * stride + x1 + 1] -
      sums[y0 * stride + x1 + 1] -
      sums[(y1 + 1) * stride + x0] +
      sums[y0 * stride + x0];

  final output = Float32List(rgb.length);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var bestVariance = double.infinity;
      var bestRed = 0.0, bestGreen = 0.0, bestBlue = 0.0;
      for (var quadrant = 0; quadrant < 4; quadrant++) {
        final x0 = (quadrant & 1) == 0 ? (x - radius).clamp(0, width - 1) : x;
        final x1 = (quadrant & 1) == 0 ? x : (x + radius).clamp(0, width - 1);
        final y0 = (quadrant & 2) == 0 ? (y - radius).clamp(0, height - 1) : y;
        final y1 = (quadrant & 2) == 0 ? y : (y + radius).clamp(0, height - 1);
        final count = ((x1 - x0 + 1) * (y1 - y0 + 1)).toDouble();
        final mean = box(sumLuma, x0, y0, x1, y1) / count;
        final variance =
            box(sumLumaSquared, x0, y0, x1, y1) / count - mean * mean;
        if (variance < bestVariance) {
          bestVariance = variance;
          bestRed = box(sumRed, x0, y0, x1, y1) / count;
          bestGreen = box(sumGreen, x0, y0, x1, y1) / count;
          bestBlue = box(sumBlue, x0, y0, x1, y1) / count;
        }
      }
      final o = (y * width + x) * 3;
      output[o] = bestRed;
      output[o + 1] = bestGreen;
      output[o + 2] = bestBlue;
    }
  }
  return output;
}
