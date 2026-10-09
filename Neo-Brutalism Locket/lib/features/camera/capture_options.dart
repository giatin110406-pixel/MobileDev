/// Longest video the camera records (like Locket).
const maxVideoLength = Duration(seconds: 3);

/// The zoom buttons a camera can offer: 0.5× only when the lens goes that
/// wide (most phones expose ultra-wide as a separate camera, so this is often
/// just 1× and 2×).
List<double> zoomPresets(double min, double max) => [
  for (final level in const [0.5, 1.0, 2.0])
    if (level >= min - 0.001 && level <= max + 0.001) level,
];

double clampZoom(double level, double min, double max) =>
    level < min ? min : (level > max ? max : level);

/// "0.5×", "1×", "2×", "1.4×".
String zoomLabel(double level) {
  final rounded = (level * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
  return '$text×';
}

/// Self-timer before a photo.
enum ShotTimer {
  off(0),
  three(3),
  ten(10);

  const ShotTimer(this.seconds);

  final int seconds;

  /// The next setting when the timer button is tapped.
  ShotTimer get next => ShotTimer.values[(index + 1) % ShotTimer.values.length];
}
