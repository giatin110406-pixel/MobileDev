import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_labels.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// How a rarity is dressed: each one is its own strap, not just a colour.
///
/// - common: a mint strap with a gloss line;
/// - rare: a violet strap with white dashed stitching and a light sweeping
///   over it now and then;
/// - legendary: a gold strap with ink piping, a quicker sweep of light and two
///   twinkling sparkles.
class _Look {
  const _Look({
    required this.colors,
    required this.text,
    this.textShadow = false,
    this.piping,
    this.dashed = false,
    this.gloss = false,
    this.stars = 0,
    this.shineEvery,
    this.sparkles = false,
  });

  /// The strap's fill, across its width (edge nearest the corner first).
  final List<Color> colors;
  final Color text;

  /// A hard ink drop under light lettering, so it reads on the colour.
  final bool textShadow;

  /// The line run inside both edges (null: none).
  final Color? piping;
  final bool dashed;

  /// A thin light line inside the edge nearest the corner, like a sheen.
  final bool gloss;

  /// Stars around the name on the ribbon: 0, 1 (before it) or 2 (both sides).
  final int stars;

  /// How often a light sweeps along the strap (null: never).
  final Duration? shineEvery;
  final bool sparkles;

  static _Look of(Rarity rarity) => switch (rarity) {
    Rarity.common => const _Look(
      colors: [Color(0xFFD4F3EE), NeoColors.teal],
      text: NeoColors.ink,
      gloss: true,
    ),
    Rarity.rare => const _Look(
      colors: [Color(0xFFA99CFF), NeoColors.purple, Color(0xFF5B4AD8)],
      text: Color(0xFFFFFFFF),
      textShadow: true,
      piping: Color(0xE6FFFFFF),
      dashed: true,
      stars: 1,
      shineEvery: Duration(milliseconds: 3600),
    ),
    Rarity.legendary => const _Look(
      colors: [Color(0xFFFFF0B8), Color(0xFFF7C948), Color(0xFFE8932A)],
      text: NeoColors.ink,
      piping: NeoColors.ink,
      stars: 2,
      shineEvery: Duration(milliseconds: 2400),
      sparkles: true,
    ),
  };

  /// The name, with [withStars] its stars (icons: the app's font has none).
  Widget title(String name, double fontSize, {bool withStars = true}) {
    final shadows = textShadow
        ? const [Shadow(color: NeoColors.ink, offset: Offset(1, 1))]
        : null;
    final star = Icon(
      Icons.star_rounded,
      size: fontSize + 3,
      color: text,
      shadows: shadows,
    );
    final count = withStars ? stars : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count >= 1) ...[star, const SizedBox(width: 2)],
        Text(
          name,
          maxLines: 1,
          style: TextStyle(
            color: text,
            fontFamily: NeoFont.display,
            fontSize: fontSize,
            height: 1,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w900,
            shadows: shadows,
          ),
        ),
        if (count >= 2) ...[const SizedBox(width: 2), star],
      ],
    );
  }

  void pipe(Canvas canvas, Offset from, Offset to) {
    final color = piping;
    if (color == null) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(from, to, paint);
      return;
    }
    const dash = 4.0;
    const gap = 3.0;
    final length = (to - from).distance;
    final step = (to - from) / length;
    for (var d = 0.0; d < length; d += dash + gap) {
      canvas.drawLine(
        from + step * d,
        from + step * math.min(d + dash, length),
        paint,
      );
    }
  }

  /// The fill of [shape], shading from [from] to [to].
  void fill(Canvas canvas, Path shape, Offset from, Offset to) {
    canvas.drawPath(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(from, to, colors, [
          for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
        ]),
    );
  }

  /// The sweep of light at [at] (0 to 1 along [from] → [to]), over [shape].
  void shine(Canvas canvas, Path shape, Offset from, Offset to, double at) {
    canvas.drawPath(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.lerp(from, to, at - 0.14)!,
          Offset.lerp(from, to, at + 0.14)!,
          const [Color(0x00FFFFFF), Color(0xA6FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.5, 1],
        ),
    );
  }
}

final _ink = Paint()..color = NeoColors.ink;
final _outline = Paint()
  ..color = NeoColors.ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2;

/// A four-pointed sparkle at [center], [size] across, scaled by [scale].
void _sparkle(Canvas canvas, Offset center, double size, double scale) {
  if (scale <= 0.05) return;
  final r = size / 2 * scale;
  final w = r * 0.32;
  final star = Path()
    ..moveTo(center.dx, center.dy - r)
    ..quadraticBezierTo(center.dx + w, center.dy - w, center.dx + r, center.dy)
    ..quadraticBezierTo(center.dx + w, center.dy + w, center.dx, center.dy + r)
    ..quadraticBezierTo(center.dx - w, center.dy + w, center.dx - r, center.dy)
    ..quadraticBezierTo(center.dx - w, center.dy - w, center.dx, center.dy - r)
    ..close();
  canvas.drawPath(star, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawPath(
    star,
    Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}

/// Plays the sweep of light (and the sparkles' twinkle) of a look that has
/// them, once every [_Look.shineEvery]; [t] is how far the current sweep is
/// (0 to 1), null between sweeps. Nothing ticks between them, so a still
/// shop draws no frames.
class _Animated extends StatefulWidget {
  const _Animated({required this.look, required this.builder});

  final _Look look;
  final Widget Function(BuildContext context, double? t) builder;

  static const sweep = Duration(milliseconds: 1100);

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _Animated.sweep,
  )..addStatusListener(_status);
  Timer? _next;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_started || still || widget.look.shineEvery == null) return;
    _started = true;
    _wait();
  }

  void _wait() {
    final every = widget.look.shineEvery!;
    _next = Timer(every - _Animated.sweep, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {}); // back to rest
      _wait();
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(
      context,
      _controller.isAnimating ? _controller.value : null,
    ),
  );
}

/// Where the light is along the strap during a sweep at [t].
double _shineAt(double t) => -0.15 + t * 1.3;

/// How big a sparkle is: [phase] staggers the two of them. At rest (no [t])
/// they sit at a middling size.
double _twinkle(double? t, double phase) =>
    t == null ? 0.7 : 0.55 + 0.45 * math.sin((t + phase) * 2 * math.pi).abs();

/// The rarity as a strap slung across the top left corner of a card. Lay it
/// over the card's top left inside a clip of the card's shape: the strap runs
/// off both edges.
class RaritySash extends StatelessWidget {
  const RaritySash({super.key, required this.rarity});

  final Rarity rarity;

  /// The strap lies between the lines x + y = [_near] and x + y = [_far].
  static const double _near = 46;
  static const double _far = 80;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(rarity);
    final name = AppLocalizations.of(context).shopRarityLabel(rarity);
    // The middle of the strap, and how long and thick it is there.
    const middle = (_near + _far) / 2;
    const length = middle * math.sqrt2 - 12;
    // Inside the piping.
    const thickness = (_far - _near) / math.sqrt2 - 9;
    return IgnorePointer(
      child: Semantics(
        label: name,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: _far + 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _Animated(
                    look: look,
                    builder: (context, t) =>
                        CustomPaint(painter: _SashPainter(look, t)),
                  ),
                ),
                Positioned(
                  left: middle / 2 - length / 2,
                  top: middle / 2 - thickness / 2,
                  width: length,
                  height: thickness,
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        // No stars here: the name gets the room.
                        child: look.title(name, 10.5, withStars: false),
                      ),
                    ),
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

class _SashPainter extends CustomPainter {
  _SashPainter(this.look, this.t);

  final _Look look;
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    const near = RaritySash._near;
    const far = RaritySash._far;
    final strap = Path()
      ..moveTo(0, near)
      ..lineTo(near, 0)
      ..lineTo(far, 0)
      ..lineTo(0, far)
      ..close();
    canvas.drawPath(strap.shift(const Offset(2, 2)), _ink);
    // Across the strap: from its corner edge to its far edge.
    look.fill(
      canvas,
      strap,
      const Offset(near / 2, near / 2),
      const Offset(far / 2, far / 2),
    );
    final t = this.t;
    if (t != null) {
      // Along the strap: from its bottom left end to its top right end.
      look.shine(
        canvas,
        strap,
        const Offset(0, far),
        const Offset(far, 0),
        _shineAt(t),
      );
    }
    if (look.gloss) {
      canvas.drawLine(
        const Offset(0, near + 4),
        const Offset(near + 4, 0),
        Paint()
          ..color = const Color(0xB3FFFFFF)
          ..strokeWidth = 2,
      );
    }
    for (final line in const [near + 5.5, far - 5.5]) {
      look.pipe(canvas, Offset(0, line), Offset(line, 0));
    }
    canvas.drawLine(const Offset(0, near), const Offset(near, 0), _outline);
    canvas.drawLine(const Offset(0, far), const Offset(far, 0), _outline);
    if (look.sparkles) {
      // Two sparkles just off the strap's far edge at both ends (clear of
      // the name), twinkling in turn.
      _sparkle(canvas, const Offset(far - 3, 13), 14, _twinkle(t, 0));
      _sparkle(canvas, const Offset(13, far - 3), 14, _twinkle(t, 0.25));
    }
  }

  @override
  bool shouldRepaint(_SashPainter old) => old.look != look || old.t != t;
}

/// The rarity as a short swallow-tailed ribbon, dressed like [RaritySash],
/// for places with no card corner to sling it over.
class RarityRibbon extends StatelessWidget {
  const RarityRibbon({super.key, required this.rarity});

  final Rarity rarity;

  static const double _height = 26;
  static const double _notch = 8;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(rarity);
    return RepaintBoundary(
      child: _Animated(
        look: look,
        builder: (context, t) => CustomPaint(
          painter: _RibbonPainter(look, t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10 + _notch, 2),
            child: SizedBox(
              height: _height - 2,
              child: Center(
                widthFactor: 1,
                child: look.title(
                  AppLocalizations.of(context).shopRarityLabel(rarity),
                  10.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.look, this.t);

  final _Look look;
  final double? t;

  @override
  void paint(Canvas canvas, Size size) {
    // Leave room for the hard shadow under it.
    final w = size.width - 2;
    final h = size.height - 2;
    const notch = RarityRibbon._notch;
    final ribbon = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notch, h / 2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ribbon.shift(const Offset(2, 2)), _ink);
    look.fill(canvas, ribbon, Offset.zero, Offset(0, h));
    final t = this.t;
    if (t != null) {
      look.shine(canvas, ribbon, Offset(0, h), Offset(w, 0), _shineAt(t));
    }
    if (look.gloss) {
      canvas.drawLine(
        const Offset(3, 3.5),
        Offset(w - 3, 3.5),
        Paint()
          ..color = const Color(0xB3FFFFFF)
          ..strokeWidth = 2,
      );
    }
    for (final y in [4.5, h - 4.5]) {
      look.pipe(canvas, Offset(4, y), Offset(w - notch * 0.6 - 4, y));
    }
    canvas.drawPath(ribbon, _outline);
    if (look.sparkles) {
      _sparkle(canvas, Offset(w - 3, 2), 11, _twinkle(t, 0));
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.look != look || old.t != t;
}
