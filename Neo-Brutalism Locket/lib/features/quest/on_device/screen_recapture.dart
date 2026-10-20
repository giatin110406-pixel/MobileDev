import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A photo of a screen shows the display's pixel grid: a few sharp, regularly
/// spaced spikes in the frequency spectrum that a real scene never has. Photos
/// whose [moireStrength] reaches this are refused as a recapture.
///
/// Measured on a handful of photos (see test/quest_screen_recapture_test.dart):
/// real photos stay under 6, screens photographed up close reach 11 to 13.
/// Kept well above the real photos on purpose: a wrong refusal costs the
/// player one of their tries.
const moireReject = 9.0;

const _patch = 256;

// JPEG codes 8x8 blocks, which puts spikes at multiples of 1/8 cycle per
// pixel on both axes. Those say nothing about a screen, so they are skipped.
const _jpegStep = _patch ~/ 8;

final _window = () {
  // Same as numpy.hanning, so the numbers match the notebook prototype.
  final w = Float64List(_patch);
  for (var n = 0; n < _patch; n++) {
    w[n] = 0.5 - 0.5 * math.cos(2 * math.pi * n / (_patch - 1));
  }
  return w;
}();

/// How strongly [image] looks like a photo of a screen: the tallest spike in
/// the frequency spectrum, in natural-log units above what a smooth photo
/// would have at that spatial frequency. Higher is more screen-like.
///
/// Looks at up to nine 256 x 256 crops of the picture at full resolution (the
/// grid is destroyed by shrinking, so this must run on the camera's own
/// pixels) and takes the median over them, so one odd corner cannot decide.
/// Returns 0 when the picture is smaller than one crop.
double moireStrength(img.Image image) {
  if (image.width < _patch || image.height < _patch) return 0;
  final scores = <double>[];
  for (final y in _starts(image.height)) {
    for (final x in _starts(image.width)) {
      scores.add(_patchPeak(image, x, y));
    }
  }
  scores.sort();
  return scores[scores.length ~/ 2];
}

/// Crop origins along one side: centre, then a quarter of the way in from
/// each end.
Set<int> _starts(int length) {
  final last = length - _patch;
  return {
    (length ~/ 2 - _patch ~/ 2).clamp(0, last),
    (length ~/ 4 - _patch ~/ 2).clamp(0, last),
    (3 * length ~/ 4 - _patch ~/ 2).clamp(0, last),
  };
}

double _patchPeak(img.Image image, int left, int top) {
  final re = Float64List(_patch * _patch);
  final im = Float64List(_patch * _patch);
  var mean = 0.0;
  for (var y = 0; y < _patch; y++) {
    for (var x = 0; x < _patch; x++) {
      final p = image.getPixel(left + x, top + y);
      final v = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      re[y * _patch + x] = v;
      mean += v;
    }
  }
  mean /= _patch * _patch;
  for (var y = 0; y < _patch; y++) {
    for (var x = 0; x < _patch; x++) {
      re[y * _patch + x] =
          (re[y * _patch + x] - mean) * _window[y] * _window[x];
    }
  }
  _fft2d(re, im);

  // Whiten by the median log-power at each radius, then take the tallest spike.
  const half = _patch ~/ 2;
  final logPower = Float64List(_patch * _patch);
  final radii = Int32List(_patch * _patch);
  final byRadius = List.generate(half + 1, (_) => <double>[]);
  for (var ky = 0; ky < _patch; ky++) {
    final fy = ky < half ? ky : ky - _patch;
    for (var kx = 0; kx < _patch; kx++) {
      final fx = kx < half ? kx : kx - _patch;
      final i = ky * _patch + kx;
      final r = math.min(
        math.sqrt((fy * fy + fx * fx).toDouble()).floor(),
        half,
      );
      radii[i] = r;
      logPower[i] = math.log(re[i] * re[i] + im[i] * im[i] + 1e-9);
      byRadius[r].add(logPower[i]);
    }
  }
  final median = List<double>.filled(half + 1, 0);
  for (var r = 0; r <= half; r++) {
    final values = byRadius[r];
    if (values.isEmpty) continue;
    values.sort();
    median[r] = values[values.length ~/ 2];
  }
  var peak = double.negativeInfinity;
  for (var ky = 0; ky < _patch; ky++) {
    final fy = ky < half ? ky : ky - _patch;
    for (var kx = 0; kx < _patch; kx++) {
      final fx = kx < half ? kx : kx - _patch;
      final radius = math.sqrt((fy * fy + fx * fx).toDouble()) / _patch;
      if (radius <= 0.06 || radius >= 0.5) continue;
      if (fy % _jpegStep == 0 && fx % _jpegStep == 0) continue;
      final i = ky * _patch + kx;
      peak = math.max(peak, logPower[i] - median[radii[i]]);
    }
  }
  return peak;
}

/// In-place 2-D FFT of a [_patch] x [_patch] grid stored row by row.
void _fft2d(Float64List re, Float64List im) {
  final rowRe = Float64List(_patch);
  final rowIm = Float64List(_patch);
  for (var y = 0; y < _patch; y++) {
    final base = y * _patch;
    rowRe.setRange(0, _patch, re, base);
    rowIm.setRange(0, _patch, im, base);
    _fft(rowRe, rowIm);
    re.setRange(base, base + _patch, rowRe);
    im.setRange(base, base + _patch, rowIm);
  }
  for (var x = 0; x < _patch; x++) {
    for (var y = 0; y < _patch; y++) {
      rowRe[y] = re[y * _patch + x];
      rowIm[y] = im[y * _patch + x];
    }
    _fft(rowRe, rowIm);
    for (var y = 0; y < _patch; y++) {
      re[y * _patch + x] = rowRe[y];
      im[y * _patch + x] = rowIm[y];
    }
  }
}

/// In-place radix-2 FFT of length [_patch].
void _fft(Float64List re, Float64List im) {
  const n = _patch;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    final wr = math.cos(angle);
    final wi = math.sin(angle);
    for (var start = 0; start < n; start += len) {
      var cr = 1.0;
      var ci = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final a = start + k;
        final b = a + len ~/ 2;
        final xr = re[b] * cr - im[b] * ci;
        final xi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
        final next = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = next;
      }
    }
  }
}
