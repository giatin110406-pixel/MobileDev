import 'dart:typed_data';

import 'color_space.dart';
import 'palettes.dart';

/// A palette with its OKLab values and lightness ordering precomputed.
class PaletteInfo {
  PaletteInfo(this.colors)
    : lab = Float32List(colors.length * 3),
      byRank = List<int>.generate(colors.length, (index) => index),
      rankOf = List<int>.filled(colors.length, 0) {
    for (var i = 0; i < colors.length; i++) {
      srgbToOklab(
        ((colors[i] >> 16) & 0xFF).toDouble(),
        ((colors[i] >> 8) & 0xFF).toDouble(),
        (colors[i] & 0xFF).toDouble(),
        lab,
        i * 3,
      );
    }
    byRank.sort((a, b) => lab[a * 3].compareTo(lab[b * 3]));
    for (var rank = 0; rank < byRank.length; rank++) {
      rankOf[byRank[rank]] = rank;
    }
  }

  final List<int> colors;
  final Float32List lab;

  /// Palette indices ordered from darkest to lightest.
  final List<int> byRank;

  /// Lightness rank (0 = darkest) of each palette index.
  final List<int> rankOf;
}

/// Gradient magnitude of OKLab lightness, normalised so a step of height d
/// gives about d.
Float32List sobelMagnitude(Float32List lab, int width, int height) {
  final output = Float32List(width * height);
  double lightness(int x, int y) =>
      lab[(y.clamp(0, height - 1) * width + x.clamp(0, width - 1)) * 3];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final gx =
          (lightness(x + 1, y - 1) +
              2 * lightness(x + 1, y) +
              lightness(x + 1, y + 1)) -
          (lightness(x - 1, y - 1) +
              2 * lightness(x - 1, y) +
              lightness(x - 1, y + 1));
      final gy =
          (lightness(x - 1, y + 1) +
              2 * lightness(x, y + 1) +
              lightness(x + 1, y + 1)) -
          (lightness(x - 1, y - 1) +
              2 * lightness(x, y - 1) +
              lightness(x + 1, y - 1));
      output[y * width + x] = (gx.abs() + gy.abs()) / 4;
    }
  }
  return output;
}

const _noDitherEdge = 0.10;

/// Ordered-dither mapping to a colour palette using weighted OKLab distance.
/// Dithering is switched off on strong edges so outlines stay clean.
Uint8List mapToColorPalette(
  Float32List lab,
  Float32List edges,
  int width,
  int height,
  PaletteInfo palette, {
  double spread = 0.06,
  Uint8List? noDither,
}) {
  final output = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      final o = index * 3;
      final offset =
          edges[index] > _noDitherEdge ||
              (noDither != null && noDither[index] != 0)
          ? 0.0
          : (bayerThreshold(x, y) - 0.5) * spread;
      final l = lab[o] + offset;
      var best = 0;
      var bestDistance = double.infinity;
      for (var candidate = 0; candidate < palette.colors.length; candidate++) {
        final c = candidate * 3;
        final dl = l - palette.lab[c];
        final da = lab[o + 1] - palette.lab[c + 1];
        final db = lab[o + 2] - palette.lab[c + 2];
        final distance = dl * dl + 1.69 * (da * da + db * db);
        if (distance < bestDistance) {
          bestDistance = distance;
          best = candidate;
        }
      }
      output[index] = best;
    }
  }
  return output;
}
