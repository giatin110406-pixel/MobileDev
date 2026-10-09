import 'dart:typed_data';

/// k-centroid (k = 2) downscale in OKLab. Each [factor]x[factor] block becomes the
/// centre of its dominant colour cluster, which keeps edges crisp instead of
/// averaging them into mud. Fully deterministic: clusters start at the block's
/// darkest and lightest pixels.
///
/// Where [keepDark] is set (the face), a darker minority cluster that covers at
/// least a quarter of the block and is clearly darker wins, so eyes, brows and
/// lips survive instead of being averaged into skin.
Float32List kCentroidDownscale(
  Float32List lab,
  int width,
  int height,
  int factor, {
  Uint8List? keepDark,
}) {
  final outWidth = width ~/ factor;
  final outHeight = height ~/ factor;
  final output = Float32List(outWidth * outHeight * 3);
  final blockSize = factor * factor;

  for (var by = 0; by < outHeight; by++) {
    for (var bx = 0; bx < outWidth; bx++) {
      var darkest = 0, lightest = 0;
      var darkL = double.infinity, lightL = -double.infinity;
      for (var j = 0; j < blockSize; j++) {
        final o =
            (((by * factor) + j ~/ factor) * width + bx * factor + j % factor) *
            3;
        if (lab[o] < darkL) {
          darkL = lab[o];
          darkest = o;
        }
        if (lab[o] > lightL) {
          lightL = lab[o];
          lightest = o;
        }
      }
      final c0 = [lab[darkest], lab[darkest + 1], lab[darkest + 2]];
      final c1 = [lab[lightest], lab[lightest + 1], lab[lightest + 2]];
      var n0 = 0, n1 = 0;

      for (var iteration = 0; iteration < 3; iteration++) {
        final s0 = [0.0, 0.0, 0.0], s1 = [0.0, 0.0, 0.0];
        n0 = 0;
        n1 = 0;
        for (var j = 0; j < blockSize; j++) {
          final o =
              (((by * factor) + j ~/ factor) * width +
                  bx * factor +
                  j % factor) *
              3;
          final d0 = _distance(lab, o, c0);
          final d1 = _distance(lab, o, c1);
          final target = d1 < d0 ? s1 : s0;
          target[0] += lab[o];
          target[1] += lab[o + 1];
          target[2] += lab[o + 2];
          if (d1 < d0) {
            n1++;
          } else {
            n0++;
          }
        }
        if (n0 > 0) {
          for (var k = 0; k < 3; k++) {
            c0[k] = s0[k] / n0;
          }
        }
        if (n1 > 0) {
          for (var k = 0; k < 3; k++) {
            c1[k] = s1[k] / n1;
          }
        }
      }

      var winner = n1 > n0 ? c1 : c0;
      if (keepDark != null && keepDark[by * outWidth + bx] != 0) {
        final minDark = (blockSize + 3) ~/ 4;
        if (n0 >= minDark && n1 > n0 && c1[0] - c0[0] > 0.12) winner = c0;
      }
      final out = (by * outWidth + bx) * 3;
      output[out] = winner[0];
      output[out + 1] = winner[1];
      output[out + 2] = winner[2];
    }
  }
  return output;
}

double _distance(Float32List lab, int offset, List<double> centre) {
  final l = lab[offset] - centre[0];
  final a = lab[offset + 1] - centre[1];
  final b = lab[offset + 2] - centre[2];
  return l * l + a * a + b * b;
}
