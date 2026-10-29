import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';

/// One picture on the strip: a stream frame, or the full-quality still.
@immutable
class RewindEntry {
  const RewindEntry({
    required this.path,
    required this.offsetMs,
    required this.rotation,
    required this.isStill,
  });

  final String path;

  /// Milliseconds from the shutter press (negative: before it).
  final int offsetMs;

  /// Clockwise degrees to turn a stream frame upright. The still is turned by
  /// its own EXIF, so this is 0 for it.
  final int rotation;
  final bool isStill;
}

/// A still further from the press than this was timed on another clock than
/// the press (the phone's sensor clock is not always the one the press is read
/// on), so where it belongs is unknown: it is left off the strip rather than
/// shown at a made-up place. The kept frames span 2 s before and 1 s after.
const maxStillOffsetMs = 3000;

/// The frames around the press in time order, with the still placed where it
/// was taken. Pure data, so it can be tested without a camera.
@immutable
class RewindTimeline {
  const RewindTimeline._(this.entries, this.defaultIndex);

  /// Builds the strip, or returns null when there is nothing to show (no
  /// stream frame and no still): the screen then says so plainly.
  static RewindTimeline? tryBuild({
    required List<RewindFrame> frames,
    RewindStill? still,
  }) {
    final entries = <RewindEntry>[
      for (final frame in frames)
        RewindEntry(
          path: frame.path,
          offsetMs: frame.offsetMs,
          rotation: frame.rotation,
          isStill: false,
        ),
    ]..sort((a, b) => a.offsetMs.compareTo(b.offsetMs));
    if (still != null && still.offsetMs.abs() <= maxStillOffsetMs) {
      final entry = RewindEntry(
        path: still.path,
        offsetMs: still.offsetMs,
        rotation: 0,
        isStill: true,
      );
      // After frames at the same instant, before the first later one.
      final at = entries.indexWhere((e) => e.offsetMs > entry.offsetMs);
      entries.insert(at < 0 ? entries.length : at, entry);
    }
    if (entries.isEmpty) return null;
    var chosen = entries.indexWhere((e) => e.isStill);
    if (chosen < 0) {
      // No still: the frame nearest the press (the earlier one on a tie).
      chosen = 0;
      for (var i = 1; i < entries.length; i++) {
        if (entries[i].offsetMs.abs() < entries[chosen].offsetMs.abs()) {
          chosen = i;
        }
      }
    }
    return RewindTimeline._(List.unmodifiable(entries), chosen);
  }

  final List<RewindEntry> entries;

  /// The picture selected when the strip opens.
  final int defaultIndex;

  /// Whether the strip holds the still (otherwise it is stream frames only).
  bool get hasStill => entries.any((e) => e.isStill);
}

/// `-1,2s`, `0` or `+0,6s`: seconds from the press with one decimal. The
/// comma is Vietnamese, the point is English.
String rewindOffsetLabel(int offsetMs, {required String languageCode}) {
  final tenths = (offsetMs.abs() + 50) ~/ 100;
  if (tenths == 0) return '0';
  final sign = offsetMs < 0 ? '-' : '+';
  final point = languageCode == 'vi' ? ',' : '.';
  return '$sign${tenths ~/ 10}$point${tenths % 10}s';
}
