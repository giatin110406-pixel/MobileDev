import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A layer that lets emojis float up the screen, Locket-style, when you react to
/// a post. Put it on top of the page (it ignores touches) and call
/// [EmojiRainLayerState.burst] through its [GlobalKey].
class EmojiRainLayer extends StatefulWidget {
  const EmojiRainLayer({super.key});

  @override
  State<EmojiRainLayer> createState() => EmojiRainLayerState();
}

class _Burst {
  _Burst(this.id, this.emoji, this.particles);

  final int id;
  final String emoji;
  final List<_Particle> particles;
}

class _Particle {
  _Particle(this.x, this.delay, this.size, this.rise, this.sway, this.phase);

  /// Share of the width where it starts.
  final double x;

  /// Share of the animation to wait before it appears.
  final double delay;
  final double size;

  /// Share of the height it climbs.
  final double rise;

  /// How far it wobbles sideways, as a share of the width.
  final double sway;
  final double phase;
}

class EmojiRainLayerState extends State<EmojiRainLayer> {
  static const _life = Duration(milliseconds: 2400);
  static const _count = 16;

  final _random = math.Random();
  final _bursts = <_Burst>[];
  int _nextId = 0;

  /// Floats a bunch of [emoji] up from the bottom, around [centerX] (a share of
  /// the width; the middle by default).
  void burst(String emoji, {double centerX = 0.5}) {
    if (!mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return;
    }
    final particles = [
      for (var i = 0; i < _count; i++)
        _Particle(
          (centerX + (_random.nextDouble() - 0.5) * 0.8).clamp(0.06, 0.94),
          _random.nextDouble() * 0.35,
          30 + _random.nextDouble() * 34,
          0.55 + _random.nextDouble() * 0.4,
          0.02 + _random.nextDouble() * 0.05,
          _random.nextDouble() * math.pi * 2,
        ),
    ];
    setState(() => _bursts.add(_Burst(_nextId++, emoji, particles)));
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final burst in _bursts)
            Positioned.fill(
              key: ValueKey(burst.id),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _life,
                onEnd: () {
                  if (mounted) setState(() => _bursts.remove(burst));
                },
                builder: (context, t, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final p in burst.particles)
                      _particle(burst.emoji, p, t, box.biggest),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _particle(String emoji, _Particle p, double t, Size area) {
    final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    // Pops in with a little overshoot, climbs steadily, fades near the top.
    final pop = Curves.elasticOut.transform((local * 4).clamp(0.0, 1.0));
    final fade = local < 0.6 ? 1.0 : 1 - (local - 0.6) / 0.4;
    final climb = Curves.easeOut.transform(local) * p.rise * area.height;
    final sway = math.sin(local * math.pi * 3 + p.phase) * p.sway * area.width;
    return Positioned(
      left: p.x * area.width - p.size / 2 + sway,
      bottom: 70 + climb - p.size / 2,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: math.sin(local * math.pi * 2 + p.phase) * 0.3,
          child: Transform.scale(
            scale: pop,
            child: Text(emoji, style: TextStyle(fontSize: p.size, height: 1)),
          ),
        ),
      ),
    );
  }
}
