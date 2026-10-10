import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// A chunky progress bar in the app's style: an ink-bordered track with a hard
/// shadow, a flat fill with diagonal hatching, an optional label and percent.
///
/// With a [value] it fills up. Without one a block sweeps back and forth; that
/// is the only animation, and it stands still when the phone asks for less
/// motion.
class NeoProgress extends StatefulWidget {
  const NeoProgress({
    this.value,
    this.label,
    this.color = NeoColors.teal,
    this.showPercent = true,
    this.height = 16,
    super.key,
  });

  /// 0..1, or null while nobody knows how far it is.
  final double? value;
  final String? label;
  final Color color;
  final bool showPercent;
  final double height;

  @override
  State<NeoProgress> createState() => _NeoProgressState();
}

class _NeoProgressState extends State<NeoProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _indeterminate => widget.value == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
  }

  @override
  void didUpdateWidget(covariant NeoProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
  }

  void _syncSweep() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_indeterminate && !still) {
      if (!_sweep.isAnimating) _sweep.repeat(reverse: true);
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value?.clamp(0.0, 1.0);
    final percent = value == null ? null : (value * 100).round();
    final label = widget.label;
    return Semantics(
      label: label,
      value: percent == null ? null : '$percent%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null || (widget.showPercent && percent != null))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (label != null)
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontFamily: NeoFont.display,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.showPercent && percent != null)
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontFamily: NeoFont.display,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: NeoColors.surface,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => CustomPaint(
                painter: _BarPainter(
                  color: widget.color,
                  value: value,
                  sweep: _sweep.value,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.color,
    required this.value,
    required this.sweep,
  });

  final Color color;
  final double? value;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final double left;
    final double width;
    if (value == null) {
      width = size.width * 0.35;
      left = (size.width - width) * sweep;
    } else {
      left = 0;
      width = size.width * value!;
    }
    if (width <= 0) return;
    final fill = Rect.fromLTWH(left, 0, width, size.height);
    canvas.save();
    canvas.clipRect(fill);
    canvas.drawRect(fill, Paint()..color = color);
    // Diagonal hatching, fixed to the bar so a growing fill does not shimmer.
    final hatch = Paint()
      ..color = NeoColors.ink.withValues(alpha: 0.22)
      ..strokeWidth = 3;
    for (var x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatch,
      );
    }
    canvas.restore();
    // A hard edge where the fill stops, like a cut paper strip.
    if (value != null && value! < 1) {
      canvas.drawLine(
        Offset(width, 0),
        Offset(width, size.height),
        Paint()
          ..color = NeoColors.ink
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.color != color || old.value != value || old.sweep != sweep;
}
