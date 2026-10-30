import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// The round SHOOT button of the menu bar and the camera's shutter are one
/// button: going to the camera it flies up out of the bar and becomes the
/// shutter, leaving the camera it flies back down. This draws it on the way,
/// over everything, from [from] to [to] (global rects).
///
/// [up] is the direction: from the bar button (yellow disc, thin outline,
/// camera icon) to the shutter (ink ring, yellow middle, no icon), or back.
class ShutterFlight extends StatefulWidget {
  const ShutterFlight({
    super.key,
    required this.from,
    required this.to,
    required this.up,
    required this.onDone,
  });

  final Rect from;
  final Rect to;
  final bool up;
  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 280);

  @override
  State<ShutterFlight> createState() => _ShutterFlightState();
}

class _ShutterFlightState extends State<ShutterFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ShutterFlight.duration,
  )..forward().whenComplete(widget.onDone);

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
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          // 0 = the bar button, 1 = the shutter, whichever way it flies.
          final shutterness = widget.up ? t : 1 - t;
          final center = Offset.lerp(widget.from.center, widget.to.center, t)!;
          // It swells a little mid-flight, as if lifted off the screen.
          final swell = 1 + 0.12 * (1 - (2 * t - 1) * (2 * t - 1));
          final size =
              lerpDouble(widget.from.shortestSide, widget.to.shortestSide, t)! *
              swell;
          // The ink ring grows from the bar button's outline to the shutter's.
          final ring = lerpDouble(3, 9, shutterness)!;
          return Stack(
            children: [
              Positioned(
                left: center.dx - size / 2,
                top: center.dy - size / 2,
                width: size,
                height: size,
                child: Container(
                  padding: EdgeInsets.all(ring),
                  decoration: const BoxDecoration(
                    color: NeoColors.ink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: NeoColors.ink,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: NeoColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Opacity(
                      opacity: (1 - shutterness * 1.6).clamp(0.0, 1.0),
                      child: Icon(
                        Icons.photo_camera,
                        size: size * 0.45,
                        color: NeoColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
