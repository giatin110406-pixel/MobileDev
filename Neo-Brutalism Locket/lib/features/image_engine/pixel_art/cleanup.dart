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
