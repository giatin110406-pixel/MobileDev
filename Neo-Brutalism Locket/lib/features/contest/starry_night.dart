import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// A night sky in the manner of Van Gogh's Starry Night: swirling blue bands, two
/// big spirals, haloed stars and a crescent moon. Sized by the shorter side of the
/// space it is given, so it looks the same on a card and on a whole screen.
class StarryNightPainter extends CustomPainter {
  const StarryNightPainter();

  static const _sky = [Color(0xFF0B1E4D), Color(0xFF1D3F8F), Color(0xFF2A5298)];
  static const _blues = [
    Color(0xFF6FA8DC),
    Color(0xFFBFD9F2),
    Color(0xFF3D6CC0),
  ];
  static const _gold = Color(0xFFFFE66D);

  // Where the stars are, as shares of the width and the height.
  static const _stars = [
    Offset(0.12, 0.10),
    Offset(0.30, 0.22),
    Offset(0.52, 0.08),
    Offset(0.66, 0.26),
    Offset(0.90, 0.34),
    Offset(0.18, 0.55),
    Offset(0.46, 0.62),
    Offset(0.82, 0.74),
    Offset(0.28, 0.88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final unit = size.shortestSide;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _sky,
        ).createShader(rect),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Flowing bands across the sky.
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.12 + i * 0.16);
      final amplitude = unit * 0.05;
      final path = Path()..moveTo(-unit * 0.1, y);
      for (var x = -unit * 0.1; x < size.width + unit * 0.1; x += unit * 0.05) {
        path.lineTo(x, y + amplitude * math.sin(x / unit * 6 + i * 1.7));
      }
      canvas.drawPath(
        path,
        stroke
          ..color = _blues[i % 3].withAlpha(0x66)
          ..strokeWidth = unit * 0.03,
      );
    }

    // Two big spirals.
    for (final (centre, turn) in [
      (Offset(size.width * 0.3, size.height * 0.36), 0.0),
      (Offset(size.width * 0.74, size.height * 0.6), 1.9),
    ]) {
      for (var r = 0; r < 6; r++) {
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: unit * (0.05 + r * 0.04)),
          turn + r * 0.8,
          math.pi * 1.3,
          false,
          stroke
            ..color = _blues[r % 3]
            ..strokeWidth = unit * 0.026,
        );
      }
    }

    // Stars with halos.
    for (var i = 0; i < _stars.length; i++) {
      final at = Offset(size.width * _stars[i].dx, size.height * _stars[i].dy);
      final radius = unit * (i.isEven ? 0.022 : 0.017);
      canvas.drawCircle(
        at,
        radius * 2.6,
        Paint()..color = _gold.withAlpha(0x44),
      );
      canvas.drawCircle(
        at,
        radius * 1.7,
        Paint()..color = _gold.withAlpha(0x66),
      );
      canvas.drawCircle(at, radius, Paint()..color = _gold);
    }

    // The crescent moon.
    final moon = Offset(size.width * 0.86, size.height * 0.1);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: unit * 0.075)),
      Path()..addOval(
        Rect.fromCircle(
          center: moon.translate(unit * 0.045, -unit * 0.012),
          radius: unit * 0.07,
        ),
      ),
    );
    canvas.drawCircle(
      moon,
      unit * 0.11,
      Paint()..color = _gold.withAlpha(0x33),
    );
    canvas.drawPath(crescent, Paint()..color = _gold);
  }

  @override
  bool shouldRepaint(covariant StarryNightPainter old) => false;
}

/// [child] on top of the Starry Night, with a cream veil in between so the sky shows
/// through but the text on top stays easy to read. [veil] is how much cream: 0 shows
/// the sky as it is, 1 hides it.
class StarryNight extends StatelessWidget {
  const StarryNight({required this.child, this.veil = 0.5, super.key});

  final Widget child;
  final double veil;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: StarryNightPainter()),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(color: NeoColors.surface.withValues(alpha: veil)),
        ),
        child,
      ],
    );
  }
}
