import 'dart:math' as math;
import 'dart:typed_data';

final Float64List _linearLut = Float64List.fromList(
  List<double>.generate(256, (value) {
    final normalized = value / 255;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }),
);

/// Converts an sRGB colour (0..255 channels) to OKLab and writes
/// L, a, b into [out] starting at [offset]. L is in 0..1.
void srgbToOklab(
  double red,
  double green,
  double blue,
  Float32List out,
  int offset,
) {
  final r = _linearLut[red.round().clamp(0, 255)];
  final g = _linearLut[green.round().clamp(0, 255)];
  final b = _linearLut[blue.round().clamp(0, 255)];
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  out[offset] = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  out[offset + 1] = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  out[offset + 2] = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
}

double _cbrt(double value) => math.pow(value, 1 / 3).toDouble();

/// BT.709 luma of an sRGB colour (0..255 channels), result in 0..255.
double luma709(double red, double green, double blue) =>
    0.2126 * red + 0.7152 * green + 0.0722 * blue;
