import 'dart:math' as math;
import 'dart:typed_data';

import 'color_space.dart';

/// All functions here work in place on interleaved RGB floats (0..255).

/// Stretches luma between the 0.5th and 99.5th percentiles over every channel,
/// which keeps hue while using the full tonal range.
void autoLevels(Float32List rgb) {
  final histogram = List<int>.filled(256, 0);
  final pixels = rgb.length ~/ 3;
  for (var i = 0; i < pixels; i++) {
    final o = i * 3;
    histogram[luma709(rgb[o], rgb[o + 1], rgb[o + 2]).round().clamp(0, 255)]++;
  }
  final low = _percentile(histogram, pixels, 0.005);
  final high = _percentile(histogram, pixels, 0.995);
  if (high - low < 8) return;
  final scale = 255 / (high - low);
  for (var i = 0; i < rgb.length; i++) {
    rgb[i] = ((rgb[i] - low) * scale).clamp(0, 255);
  }
}

double _percentile(List<int> histogram, int total, double fraction) {
  final target = total * fraction;
  var seen = 0;
  for (var value = 0; value < 256; value++) {
    seen += histogram[value];
    if (seen >= target) return value.toDouble();
  }
  return 255;
}

/// Moves mean luma towards [target] with a gamma limited to [minGamma, maxGamma].
void autoGamma(
  Float32List rgb, {
  double target = 0.47,
  double minGamma = 0.6,
  double maxGamma = 1.6,
}) {
  final pixels = rgb.length ~/ 3;
  var sum = 0.0;
  for (var i = 0; i < pixels; i++) {
    final o = i * 3;
    sum += luma709(rgb[o], rgb[o + 1], rgb[o + 2]);
  }
  final mean = (sum / pixels / 255).clamp(0.02, 0.98);
  final gamma = (math.log(target) / math.log(mean)).clamp(minGamma, maxGamma);
  if ((gamma - 1).abs() < 0.02) return;
  for (var i = 0; i < rgb.length; i++) {
    rgb[i] = 255 * math.pow(rgb[i] / 255, gamma).toDouble();
  }
}

/// Large-radius unsharp mask: boosts local contrast without sharpening noise.
void clarity(Float32List rgb, int width, int height, {double amount = 0.35}) {
  final radius = math.max(1, (width / 128).round());
  final blurred = Float32List.fromList(rgb);
  for (var pass = 0; pass < 3; pass++) {
    _boxBlur(blurred, width, height, radius);
  }
  for (var i = 0; i < rgb.length; i++) {
    rgb[i] = (rgb[i] + amount * (rgb[i] - blurred[i])).clamp(0, 255);
  }
}

void _boxBlur(Float32List data, int width, int height, int radius) {
  final line = Float32List(math.max(width, height));
  for (var channel = 0; channel < 3; channel++) {
    for (var y = 0; y < height; y++) {
      _blurLine(data, channel + y * width * 3, 3, width, radius, line);
    }
    for (var x = 0; x < width; x++) {
      _blurLine(data, channel + x * 3, width * 3, height, radius, line);
    }
  }
}

void _blurLine(
  Float32List data,
  int start,
  int stride,
  int length,
  int radius,
  Float32List line,
) {
  final window = 2 * radius + 1;
  var sum = 0.0;
  for (var k = -radius; k <= radius; k++) {
    sum += data[start + k.clamp(0, length - 1) * stride];
  }
  for (var i = 0; i < length; i++) {
    line[i] = sum / window;
    sum += data[start + (i + radius + 1).clamp(0, length - 1) * stride];
    sum -= data[start + (i - radius).clamp(0, length - 1) * stride];
  }
  for (var i = 0; i < length; i++) {
    data[start + i * stride] = line[i];
  }
}
