import 'dart:typed_data';

import 'palette_mapper.dart';

const _outlineEdge = 0.16;

/// Darkens pixels on the dark side of strong edges by one palette step so
/// shapes read clearly at low resolution.
void applyOutline(
  Uint8List indices,
  Float32List lab,
  Float32List edges,
  int width,
  int height,
  PaletteInfo palette,
) {
  double lightness(int x, int y) =>
      lab[(y.clamp(0, height - 1) * width + x.clamp(0, width - 1)) * 3];
  final result = Uint8List.fromList(indices);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      if (edges[index] < _outlineEdge) continue;
      final neighbours =
          (lightness(x - 1, y) +
              lightness(x + 1, y) +
              lightness(x, y - 1) +
              lightness(x, y + 1)) /
          4;
      if (lab[index * 3] >= neighbours - 0.02) continue;
      final rank = palette.rankOf[indices[index]];
      if (rank > 0) result[index] = palette.byRank[rank - 1];
    }
  }
  indices.setAll(0, result);
}
