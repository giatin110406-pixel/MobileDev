import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// A one-shot burst of chunky neo-brutalist confetti. Call [ConfettiState.fire]
/// (via a GlobalKey) or set [autoFire].
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.autoFire = false});

  final bool autoFire;

  @override
  State<Confetti> createState() => ConfettiState();
}

class ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    if (widget.autoFire) fire();
  }

  void fire() {
    final random = math.Random();
    const colors = [
      NeoColors.pink,
      NeoColors.yellow,
      NeoColors.teal,
      NeoColors.purple,
      NeoColors.blue,
      NeoColors.orange,
    ];
    setState(() {
      _pieces = List.generate(
        70,
        (i) => _Piece(
          x: 0.5 + (random.nextDouble() - 0.5) * 0.3,
          vx: (random.nextDouble() - 0.5) * 1.4,
          vy: -0.9 - random.nextDouble() * 0.9,
          spin: (random.nextDouble() - 0.5) * 14,
          size: 6 + random.nextDouble() * 8,
          color: colors[i % colors.length],
        ),
      );
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isAnimating
            ? CustomPaint(
                painter: _ConfettiPainter(_pieces, _controller.value),
                size: Size.infinite,
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 2.2;
    final fill = Paint();
    final edge = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final piece in pieces) {
      final x = (piece.x + piece.vx * t) * size.width;
      final y = (0.62 + piece.vy * t + gravity * t * t / 2) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * t);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size,
        height: piece.size * 0.6,
      );
      fill.color = piece.color.withValues(alpha: (1.4 - t).clamp(0, 1));
      canvas.drawRect(rect, fill);
      canvas.drawRect(
        rect,
        edge..color = NeoColors.ink.withValues(alpha: (1.4 - t).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.pieces != pieces;
}
