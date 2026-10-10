import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Double-tap a picture to react: the [emoji] pops up where the finger landed,
/// drifts up and fades, and [onDoubleTap] sends the reaction.
///
/// With no [onDoubleTap] (your own post, nobody to react to) the picture just
/// ignores double taps. [onLongPress] passes through, so the post menu still
/// opens.
class DoubleTapHeart extends StatefulWidget {
  const DoubleTapHeart({
    required this.child,
    required this.emoji,
    this.onDoubleTap,
    this.onLongPress,
    super.key,
  });

  final Widget child;
  final String emoji;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  @override
  State<DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _Burst {
  _Burst(this.id, this.at, this.tilt);

  final int id;
  final Offset at;
  final double tilt;
}

class _DoubleTapHeartState extends State<DoubleTapHeart> {
  static const _size = 72.0;
  static const _life = Duration(milliseconds: 900);

  final _random = math.Random();
  final _bursts = <_Burst>[];
  Offset _lastDown = Offset.zero;
  int _nextId = 0;

  void _react() {
    final react = widget.onDoubleTap;
    if (react == null) return;
    Haptics.press();
    react();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    setState(() {
      _bursts.add(
        _Burst(_nextId++, _lastDown, (_random.nextDouble() - 0.5) * 0.5),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _lastDown = details.localPosition,
      onDoubleTap: widget.onDoubleTap == null ? null : _react,
      onLongPress: widget.onLongPress,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          for (final burst in _bursts)
            Positioned(
              key: ValueKey(burst.id),
              left: burst.at.dx - _size / 2,
              top: burst.at.dy - _size / 2,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: _life,
                  onEnd: () {
                    if (mounted) setState(() => _bursts.remove(burst));
                  },
                  builder: (context, t, child) {
                    // Pops in with a little overshoot, then floats up and fades.
                    final pop = Curves.elasticOut.transform(
                      (t * 3).clamp(0, 1),
                    );
                    final fade = t < 0.55 ? 1.0 : 1 - (t - 0.55) / 0.45;
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -70 * t),
                        child: Transform.rotate(
                          angle: burst.tilt,
                          child: Transform.scale(scale: pop, child: child),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: _size, height: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
