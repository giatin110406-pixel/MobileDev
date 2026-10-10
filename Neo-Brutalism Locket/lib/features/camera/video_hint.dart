import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teaches "hold the shutter to film" to new users without a tutorial: a hint
/// shows until they have tapped the shutter [showFor] times or filmed once.
abstract final class VideoHint {
  static const _key = 'video_hint_taps';
  static const showFor = 3;

  /// Stored once a video was filmed: the hint has done its job.
  static const _done = 1 << 20;

  static Future<bool> shouldShow() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return (preferences.getInt(_key) ?? 0) < showFor;
    } catch (_) {
      return false;
    }
  }

  /// Counts one shutter tap; true while the hint should still show.
  static Future<bool> countTap() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final taps = (preferences.getInt(_key) ?? 0) + 1;
      await preferences.setInt(_key, taps);
      return taps < showFor;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markFilmed() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_key, _done);
    } catch (_) {
      // The hint just comes back next time.
    }
  }
}

/// A dashed ring just outside the shutter: "this button does more than tap".
class DashedRingPainter extends CustomPainter {
  const DashedRingPainter({this.gap = 7, this.dashes = 18});

  /// How far the ring sits outside the shutter's edge.
  final double gap;
  final int dashes;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 + gap;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.5,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedRingPainter oldDelegate) =>
      oldDelegate.gap != gap || oldDelegate.dashes != dashes;
}
