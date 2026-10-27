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
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(
            _PixelFlamePainter.cols * 1.25,
            _PixelFlamePainter.rows * 1.25,
          ),
          painter: _PixelFlamePainter(lit: streak > 0, shadow: false),
        ),
        const SizedBox(width: 5),
        Text(
          '$streak',
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    ),
  );

  /// The pixel flame with the count in its belly and a hard shadow.
  Widget _flame(BuildContext context, bool pressed) {
    final cell = context.s(3);
    return CustomPaint(
      size: Size(cell * _PixelFlamePainter.cols, cell * _PixelFlamePainter.rows),
      painter: _PixelFlamePainter(lit: streak > 0, shadow: !pressed),
      child: SizedBox(
        width: cell * _PixelFlamePainter.cols,
        height: cell * _PixelFlamePainter.rows,
        child: Align(
          alignment: const Alignment(0, 0.44),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: cell * 2.5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$streak',
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An 8-bit flame drawn on a pixel grid: ink outline, coral body, a yellow
/// middle and a pale core, with a one-cell hard shadow. The grid is
/// [cols] x [rows] cells (the flame itself is 12 x 14, with a cell of outline
/// around it); the painter scales a cell to the size it is given.
class _PixelFlamePainter extends CustomPainter {
  const _PixelFlamePainter({required this.lit, required this.shadow});

  /// A live streak is coloured; 0 is a grey flame.
  final bool lit;
  final bool shadow;

  static const cols = 14;
  static const rows = 16;

  /// The flame, 12 x 14 cells: one solid body with a single tip that leans
  /// right. No notch cuts into the belly, so the count reads on clean colour.
  static const _mask = [
    '......#.....',
    '.....##.....',
    '.....###....',
    '....####....',
    '...#####....',
    '...######...',
    '..#######...',
    '.#########..',
    '############',
    '############',
    '############',
    '.##########.',
    '..########..',
    '...######...',
  ];

  /// Cell ([c], [r]) of the grid; the body starts one cell in.
  static bool _body(int c, int r) {
    final y = r - 1;
    final x = c - 1;
    return y >= 0 && y < _mask.length && x >= 0 && x < 12 && _mask[y][x] == '#';
  }

  static bool _inside(bool Function(int, int) layer, int c, int r) =>
      layer(c, r) &&
      layer(c - 1, r) &&
      layer(c + 1, r) &&
      layer(c, r - 1) &&
      layer(c, r + 1);

  /// The yellow middle: one cell in from the edge, below the tip.
  static bool _mid(int c, int r) => r - 1 >= 4 && _inside(_body, c, r);

  /// The pale core under the number: one more cell in, in the belly.
  static bool _core(int c, int r) => r - 1 >= 8 && _inside(_mid, c, r);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;
    void put(int c, int r, Color color, [double shift = 0]) {
      canvas.drawRect(
        Rect.fromLTWH(c * cell + shift, r * cell + shift, cell, cell),
        paint..color = color,
      );
    }

    bool edge(int c, int r) =>
        !_body(c, r) &&
        (_body(c - 1, r) ||
            _body(c + 1, r) ||
            _body(c, r - 1) ||
            _body(c, r + 1));

    final outer = lit ? NeoColors.coral : NeoColors.switchOff;
    final middle = lit ? NeoColors.accent : NeoColors.surface;
    final inner = lit ? NeoColors.paper : NeoColors.surface;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (shadow && (_body(c, r) || edge(c, r))) {
          put(c, r, NeoColors.ink, cell);
        }
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (edge(c, r)) {
          put(c, r, NeoColors.ink);
        } else if (_body(c, r)) {
          put(
            c,
            r,
            _core(c, r)
                ? inner
                : _mid(c, r)
                ? middle
                : outer,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelFlamePainter old) =>
      old.lit != lit || old.shadow != shadow;
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
