import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/core/responsive.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The Sunbit balance pill. It bounces and floats "+N" whenever the balance
/// goes up.
class SunbitBadge extends StatefulWidget {
  const SunbitBadge({super.key, required this.balance, this.onTap});

  final int balance;
  final VoidCallback? onTap;

  @override
  State<SunbitBadge> createState() => _SunbitBadgeState();
}

class _SunbitBadgeState extends State<SunbitBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _gain = 0;

  @override
  void didUpdateWidget(covariant SunbitBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.balance > oldWidget.balance) {
      _gain = widget.balance - oldWidget.balance;
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: '${widget.balance} Sunbit',
      child: NeoPress(
        onTap: widget.onTap,
        offset: const Offset(2, 2),
        builder: (context, pressed) => AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final t = _bounce.value;
            // Two damped hops.
            final scale = _bounce.isAnimating
                ? 1 + 0.32 * math.sin(t * math.pi * 3) * (1 - t)
                : 1.0;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.scale(scale: scale, child: child),
                if (_bounce.isAnimating)
                  Positioned(
                    top: -18 - 16 * t,
                    child: Opacity(
                      opacity: (1 - t).clamp(0, 1),
                      child: Text(
                        '+$_gain',
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: BoxDecoration(
              color: NeoColors.accent,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: NeoPress.shadow(pressed, offset: const Offset(2, 2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SunbitCoin(size: 18),
                const SizedBox(width: 6),
                Text(
                  '${widget.balance}',
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "🔥 N" — the current quest streak.
class StreakChip extends StatelessWidget {
  const StreakChip({
    super.key,
    required this.streak,
    this.onTap,
    this.round = false,
  });

  final int streak;
  final VoidCallback? onTap;

  /// A flame with the count inside (the camera header) instead of the slim
  /// pill.
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: AppLocalizations.of(context).streakSemantics(streak),
      child: NeoPress(
        onTap: onTap,
        offset: const Offset(2, 2),
        builder: (context, pressed) =>
            round ? _flame(context, pressed) : _pill(pressed),
      ),
    );
  }

  Widget _pill(bool pressed) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: streak > 0 ? NeoColors.coral : NeoColors.switchOff,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(999),
      boxShadow: NeoPress.shadow(pressed, offset: const Offset(2, 2)),
    ),
    child: Text(
      '🔥 $streak',
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
    ),
  );

  /// The flame: thick ink outline, hard shadow, the count in its belly.
  Widget _flame(BuildContext context, bool pressed) => CustomPaint(
    size: Size(context.s(42), context.s(46)),
    painter: _FlamePainter(
      color: streak > 0 ? NeoColors.coral : NeoColors.switchOff,
      core: streak > 0 ? NeoColors.accent : NeoColors.surface,
      shadow: pressed ? Offset.zero : const Offset(3, 3),
    ),
    child: SizedBox(
      width: context.s(42),
      height: context.s(46),
      child: Align(
        alignment: const Alignment(0, 0.45),
        child: Text(
          '$streak',
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter({
    required this.color,
    required this.core,
    required this.shadow,
  });

  final Color color;
  final Color core;
  final Offset shadow;

  /// A flame in a box of [w]×[h]: a tip leaning right, a round belly.
  static Path _flame(double w, double h) {
    double x(double v) => v * w;
    double y(double v) => v * h;
    return Path()
      ..moveTo(x(0.58), y(0.02))
      ..cubicTo(x(0.54), y(0.24), x(0.10), y(0.36), x(0.10), y(0.68))
      ..cubicTo(x(0.10), y(0.88), x(0.28), y(0.98), x(0.50), y(0.98))
      ..cubicTo(x(0.72), y(0.98), x(0.90), y(0.88), x(0.90), y(0.64))
      ..cubicTo(x(0.90), y(0.48), x(0.82), y(0.40), x(0.76), y(0.34))
      ..cubicTo(x(0.76), y(0.46), x(0.70), y(0.50), x(0.66), y(0.48))
      ..cubicTo(x(0.70), y(0.30), x(0.62), y(0.14), x(0.58), y(0.02))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final body = _flame(
      size.width - 3,
      size.height - 3,
    ).shift(const Offset(1.5, 1.5));
    canvas.drawPath(body.shift(shadow), Paint()..color = NeoColors.ink);
    canvas.drawPath(body, Paint()..color = color);
    // The lighter core under the number.
    canvas.save();
    canvas.translate(size.width * 0.2, size.height * 0.34);
    canvas.drawPath(
      _flame(size.width * 0.6, size.height * 0.62),
      Paint()..color = core,
    );
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = NeoColors.ink,
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.color != color || old.core != core || old.shadow != shadow;
}

/// A small round icon button for the status row, drawn like the streak and
/// Sunbit pills beside it.
class StatusIconButton extends StatelessWidget {
  const StatusIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill = NeoColors.accent,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color fill;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: NeoPress(
      onTap: onPressed,
      offset: const Offset(2, 2),
      builder: (context, pressed) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: NeoColors.ink, width: 2),
          boxShadow: NeoPress.shadow(pressed, offset: const Offset(2, 2)),
        ),
        child: Icon(icon, size: 16, color: NeoColors.ink),
      ),
    ),
  );
}
