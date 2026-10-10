import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
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
              color: NeoColors.yellow,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
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
  const StreakChip({super.key, required this.streak, this.onTap});

  final int streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: AppLocalizations.of(context).streakSemantics(streak),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: streak > 0 ? NeoColors.orange : NeoColors.switchOff,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
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
        ),
      ),
    );
  }
}
