import 'dart:typed_data';

/// Replaces orphan pixels (different from all four neighbours, which all agree)
/// with the surrounding colour.
void removeOrphans(Uint8List indices, int width, int height) {
  final source = Uint8List.fromList(indices);
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final index = y * width + x;
      final up = source[index - width];
      final down = source[index + width];
      final left = source[index - 1];
      final right = source[index + 1];
      if (up == down && up == left && up == right && source[index] != up) {
        indices[index] = up;
      }
    }
  }
}

/// Replaces pixels that match at most one of their eight neighbours (so also
/// two-pixel specks) when five
/// or more neighbours share another colour: removes the dither speckle left in
/// busy areas while single-pixel details inside flat areas stay untouched.
/// Pixels in [keep] (the face) are not touched.
void removeSpeckles(
  Uint8List indices,
  int width,
  int height, {
  Uint8List? keep,
}) {
  final source = Uint8List.fromList(indices);
  final counts = <int, int>{};
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final index = y * width + x;
      if (keep != null && keep[index] != 0) continue;
      counts.clear();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final v = source[index + dy * width + dx];
          counts[v] = (counts[v] ?? 0) + 1;
        }
      }
      if ((counts[source[index]] ?? 0) > 1) continue;
      var best = source[index];
      var bestCount = 0;
      counts.forEach((value, count) {
        if (count > bestCount) {
          best = value;
          bestCount = count;
        }
      });
      if (bestCount >= 5) indices[index] = best;
    }
  }
}
