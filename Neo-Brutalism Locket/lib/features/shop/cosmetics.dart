import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// Draws pixel art from rows of characters; each character is a cell colour
/// from [palette] (a space is transparent).
void paintSprite(
  Canvas canvas,
  List<String> rows,
  Map<String, Color> palette, {
  required Offset origin,
  required double cell,
}) {
  final paint = Paint()..isAntiAlias = false;
  for (var y = 0; y < rows.length; y++) {
    final row = rows[y];
    for (var x = 0; x < row.length; x++) {
      final color = palette[row[x]];
      if (color == null) continue;
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
        paint,
      );
    }
  }
}

// -- Sunbit coin ---------------------------------------------------------------

const _coinRows = [
  '    oooooo    ',
  '   oollggoo   ',
  '  olggppgggo  ',
  ' olpggppggpgo ',
  'ooggpgppgpggoo',
  'olgggpbbpggggo',
  'ogpppbdbbpppgo',
  'ogpppbbdbpppgo',
  'oggggpbbpggggo',
  'ooggpgppgpggoo',
  ' ogpggppggpgo ',
  '  ogggppgggo  ',
  '   ooggggoo   ',
  '    oooooo    ',
];

const _coinPalette = {
  'o': Color(0xFF6B3F00),
  'g': Color(0xFFE09A12),
  'l': Color(0xFFFFE9A0),
  'p': Color(0xFFFFF176),
  'b': Color(0xFF7A4520),
  'd': Color(0xFF2E1A0C),
};

/// The Sunbit coin: a yellow pixel coin with a sunflower in the middle.
class SunbitCoin extends StatelessWidget {
  const SunbitCoin({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _CoinPainter()),
  );
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) => paintSprite(
    canvas,
    _coinRows,
    _coinPalette,
    origin: Offset.zero,
    cell: size.width / _coinRows.length,
  );

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -- Avatars and frames ----------------------------------------------------------

/// A round avatar with an optional shop frame drawn over its edge. The photo
/// takes the middle [_photoScale] of the box; the frame owns the rest.
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    required this.size,
    required this.child,
    this.frameId,
  });

  final double size;
  final Widget child;
  final String? frameId;

  static const _photoScale = 0.74;

  @override
  Widget build(BuildContext context) {
    final framed = frameId != null && framePainters.containsKey(frameId);
    final photo = framed ? size * _photoScale : size;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: photo,
            height: photo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NeoColors.surface,
              border: Border.all(color: NeoColors.ink, width: 2),
              boxShadow: framed
                  ? null
                  : const [
                      BoxShadow(
                        color: NeoColors.ink,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          if (framed)
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(size),
                painter: framePainters[frameId]!(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The inside of an avatar circle: a photo, or initials on a colour.
class AvatarFace extends StatelessWidget {
  const AvatarFace({
    super.key,
    required this.initials,
    required this.color,
    this.imagePath,
    this.remotePath,
  });

  final String initials;
  final Color color;

  /// A photo file on this phone.
  final String? imagePath;

  /// Else: a photo in the private `avatars` bucket (on someone's account).
  final String? remotePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final fallback = ColoredBox(
      color: color,
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              initials,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
    if (path == null) {
      final remote = remotePath;
      return remote == null
          ? fallback
          : RemoteImage(bucket: 'avatars', path: remote, placeholder: fallback);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

typedef PainterFactory = CustomPainter Function();

/// Frame painters by shop item id.
final Map<String, PainterFactory> framePainters = {
  'frame_sunflower': () => const _SunflowerFrame(),
  'frame_brush': () => const _BrushFrame(),
  'frame_pixel': () => const _PixelRingFrame(),
  'frame_hearts': () => const _SpriteRingFrame(
    sprite: _heartRows,
    palette: {
      'r': Color(0xFFE63946),
      'w': Color(0xFFFFFFFF),
      'o': NeoColors.ink,
    },
    ring: Color(0xFFFFB3C1),
    count: 8,
  ),
  'frame_gold_coins': () => const _SpriteRingFrame(
    sprite: _smallCoinRows,
    palette: {
      'o': Color(0xFF7A4B00),
      'y': Color(0xFFFFC83D),
      'w': Color(0xFFFFF0A8),
    },
    ring: Color(0xFFFFD166),
    count: 10,
  ),
};

class _SunflowerFrame extends CustomPainter {
  const _SunflowerFrame();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * FramedAvatar._photoScale;
    final petal = Paint()..color = const Color(0xFFFFC83D);
    final petalDark = Paint()..color = const Color(0xFFF4A300);
    final edge = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const petals = 18;
    for (var i = 0; i < petals; i++) {
      final angle = i * 2 * math.pi / petals;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final rect = Rect.fromCenter(
        center: Offset(0, -(inner + (outer - inner) * 0.5)),
        width: (outer - inner) * 0.62,
        height: (outer - inner) * 1.05,
      );
      canvas.drawOval(rect, i.isEven ? petal : petalDark);
      canvas.drawOval(rect, edge);
      canvas.restore();
    }
    // Seed ring right around the photo.
    canvas.drawCircle(
      c,
      inner + 1.5,
      Paint()
        ..color = const Color(0xFF5B3418)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (outer - inner) * 0.28,
    );
    final seed = Paint()..color = const Color(0xFF2E1A0C);
    for (var i = 0; i < 28; i++) {
      final angle = i * 2 * math.pi / 28;
      canvas.drawCircle(
        c + Offset(math.cos(angle), math.sin(angle)) * (inner + 1.5),
        (outer - inner) * 0.05,
        seed,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Swirling Van Gogh brush strokes in blues and yellows.
class _BrushFrame extends CustomPainter {
  const _BrushFrame();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * FramedAvatar._photoScale;
    final band = outer - inner;
    canvas.drawCircle(
      c,
      inner + band / 2,
      Paint()
        ..color = const Color(0xFF1D3F8F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = band,
    );
    const colors = [
      Color(0xFF6FA8DC),
      Color(0xFFFFE66D),
      Color(0xFFBFD9F2),
      Color(0xFF3D6CC0),
    ];
    for (var lane = 0; lane < 4; lane++) {
      final radius = inner + band * (0.18 + lane * 0.22);
      final stroke = Paint()
        ..color = colors[lane]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = band * 0.13;
      for (var i = 0; i < 7; i++) {
        final start = i * 2 * math.pi / 7 + lane * 0.6;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: radius),
          start,
          0.5 + (lane % 2) * 0.25,
          false,
          stroke,
        );
      }
    }
    final edge = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, outer - 1, edge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky pixelated ring in alternating colours.
class _PixelRingFrame extends CustomPainter {
  const _PixelRingFrame();

  @override
  void paint(Canvas canvas, Size size) {
    _paintPixelRing(canvas, size, const [
      Color(0xFF4ECDC4),
      Color(0xFF45B7D1),
      Color(0xFFA388EE),
    ]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pixel cells between the photo and the box edge, outlined in ink.
void _paintPixelRing(Canvas canvas, Size size, List<Color> colors) {
  const cells = 20;
  final cell = size.width / cells;
  final c = size.width / 2;
  final outer = size.width / 2;
  final inner = outer * FramedAvatar._photoScale - cell * 0.3;
  final paint = Paint()..isAntiAlias = false;
  bool inRing(int x, int y) {
    final d = Offset((x + 0.5) * cell - c, (y + 0.5) * cell - c).distance;
    return d >= inner && d <= outer - cell * 0.15;
  }

  for (var y = 0; y < cells; y++) {
    for (var x = 0; x < cells; x++) {
      if (!inRing(x, y)) continue;
      final outline =
          !inRing(x - 1, y) ||
          !inRing(x + 1, y) ||
          !inRing(x, y - 1) ||
          !inRing(x, y + 1);
      paint.color = outline ? NeoColors.ink : colors[(x + y) % colors.length];
      canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
    }
  }
}

const _heartRows = [
  ' oo oo ',
  'orrorro',
  'orwrrro',
  'orrrrro',
  ' orrro ',
  '  oro  ',
  '   o   ',
];

const _smallCoinRows = [
  ' oooo ',
  'oyyyyo',
  'oywyyo',
  'oywyyo',
  'oywyyo',
  'oyyyyo',
  ' oooo ',
];

/// A pixel ring with little sprites (hearts, coins) spaced around it.
class _SpriteRingFrame extends CustomPainter {
  const _SpriteRingFrame({
    required this.sprite,
    required this.palette,
    required this.ring,
    required this.count,
  });

  final List<String> sprite;
  final Map<String, Color> palette;
  final Color ring;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    _paintPixelRing(canvas, size, [
      ring,
      Color.lerp(ring, Colors.white, 0.35)!,
    ]);
    final outer = size.width / 2;
    final inner = outer * FramedAvatar._photoScale;
    final c = size.center(Offset.zero);
    final cell = (outer - inner) * 0.95 / sprite.length;
    final w = sprite.first.length * cell;
    final h = sprite.length * cell;
    final radius = (inner + outer) / 2;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / count;
      final center = c + Offset(math.cos(angle), math.sin(angle)) * radius;
      paintSprite(
        canvas,
        sprite,
        palette,
        origin: center - Offset(w / 2, h / 2),
        cell: cell,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpriteRingFrame oldDelegate) => false;
}

// -- Banners ---------------------------------------------------------------------

/// A profile banner: the equipped shop banner, or plain stripes.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({super.key, this.bannerId, this.height = 120});

  final String? bannerId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final factory = bannerPainters[bannerId] ?? () => const _PlainBanner();
    return Container(
      height: height,
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 12),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: factory(), size: Size.infinite),
    );
  }
}

final Map<String?, PainterFactory> bannerPainters = {
  'banner_starry_night': () => const _StarryNightBanner(),
  'banner_wheat_field': () => const _WheatFieldBanner(),
  'banner_almond': () => const _AlmondBanner(),
  'banner_retro_sky': () => const _RetroSkyBanner(),
  'banner_space': () => const _SpaceBanner(),
};

class _PlainBanner extends CustomPainter {
  const _PlainBanner();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = NeoColors.yellow);
    final stripe = Paint()..color = NeoColors.orange.withValues(alpha: 0.55);
    for (var x = -size.height; x < size.width; x += 28) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + 12, size.height)
          ..lineTo(x + 12 + size.height, 0)
          ..lineTo(x + size.height, 0)
          ..close(),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Deterministic pseudo-random numbers so banners look the same every frame.
class _Rand {
  _Rand(this._state);

  int _state;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

class _StarryNightBanner extends CustomPainter {
  const _StarryNightBanner();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1E4D), Color(0xFF1D3F8F), Color(0xFF2A5298)],
        ).createShader(rect),
    );
    // Swirls.
    final swirl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const swirlColors = [
      Color(0xFF6FA8DC),
      Color(0xFFBFD9F2),
      Color(0xFF3D6CC0),
    ];
    for (var s = 0; s < 3; s++) {
      final center = Offset(size.width * (0.35 + s * 0.2), size.height * 0.42);
      for (var r = 0; r < 4; r++) {
        swirl
          ..color = swirlColors[(s + r) % 3]
          ..strokeWidth = 3.2;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 8.0 + r * 7),
          s * 1.3 + r * 0.9,
          math.pi * 1.25,
          false,
          swirl,
        );
      }
    }
    // Stars with halos, and the moon.
    final halo = Paint()..color = const Color(0x66FFE66D);
    final star = Paint()..color = const Color(0xFFFFE66D);
    final rand = _Rand(7);
    for (var i = 0; i < 9; i++) {
      final p = Offset(
        size.width * (0.08 + rand.next() * 0.8),
        size.height * (0.1 + rand.next() * 0.45),
      );
      canvas.drawCircle(p, 9, halo);
      canvas.drawCircle(p, 4, star);
    }
    final moon = Offset(size.width * 0.9, size.height * 0.24);
    canvas.drawCircle(moon, 16, halo);
    canvas.drawCircle(moon, 11, Paint()..color = const Color(0xFFFFC83D));
    canvas.drawCircle(
      moon + const Offset(5, -3),
      9,
      Paint()..color = const Color(0xFF0B1E4D),
    );
    // Village hills and a cypress like a dark flame.
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, size.height * 0.82)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.62,
          size.width,
          size.height * 0.8,
        )
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = const Color(0xFF14284F),
    );
    final cypress = Path()
      ..moveTo(size.width * 0.1, size.height)
      ..quadraticBezierTo(
        size.width * 0.03,
        size.height * 0.5,
        size.width * 0.12,
        size.height * 0.04,
      )
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.5,
        size.width * 0.17,
        size.height,
      )
      ..close();
    canvas.drawPath(cypress, Paint()..color = const Color(0xFF0D1A12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WheatFieldBanner extends CustomPainter {
  const _WheatFieldBanner();

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.45;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()..color = const Color(0xFF1F4E8C),
    );
    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    final rand = _Rand(11);
    for (var i = 0; i < 70; i++) {
      final p = Offset(rand.next() * size.width, rand.next() * horizon);
      stroke.color = rand.next() > 0.5
          ? const Color(0xFF3D6CC0)
          : const Color(0xFF0F2D5C);
      canvas.drawLine(p, p + Offset(10 + rand.next() * 8, -2), stroke);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()..color = const Color(0xFFE5B92E),
    );
    for (var i = 0; i < 160; i++) {
      final p = Offset(
        rand.next() * size.width,
        horizon + rand.next() * (size.height - horizon),
      );
      stroke.color = [
        const Color(0xFFF2D04B),
        const Color(0xFFC98F1E),
        const Color(0xFFFFE680),
      ][i % 3];
      canvas.drawLine(p, p + Offset(-3 + rand.next() * 6, -9), stroke);
    }
    // Crows.
    final crow = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final p = Offset(
        size.width * (0.15 + rand.next() * 0.7),
        size.height * (0.12 + rand.next() * 0.3),
      );
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - 7, p.dy - 3)
          ..quadraticBezierTo(p.dx - 3, p.dy - 4, p.dx, p.dy)
          ..quadraticBezierTo(p.dx + 3, p.dy - 4, p.dx + 7, p.dy - 3),
        crow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlmondBanner extends CustomPainter {
  const _AlmondBanner();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF7FC4D6),
    );
    final branch = Paint()
      ..color = const Color(0xFF4A3426)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paths = [
      (
        Offset(0, size.height * 0.85),
        Offset(size.width * 0.55, size.height * 0.2),
        6.0,
      ),
      (
        Offset(size.width * 0.3, size.height * 0.55),
        Offset(size.width * 0.5, size.height * 0.95),
        4.0,
      ),
      (
        Offset(size.width, size.height * 0.3),
        Offset(size.width * 0.6, size.height * 0.75),
        5.0,
      ),
      (
        Offset(size.width * 0.78, size.height * 0.5),
        Offset(size.width * 0.85, size.height * 0.05),
        3.5,
      ),
    ];
    final blossoms = <Offset>[];
    for (final (from, to, width) in paths) {
      branch.strokeWidth = width;
      canvas.drawLine(from, to, branch);
      for (var t = 0.25; t <= 1.0; t += 0.25) {
        blossoms.add(Offset.lerp(from, to, t)!);
      }
    }
    final petal = Paint()..color = const Color(0xFFFDF6F0);
    final blush = Paint()..color = const Color(0xFFF7C6D0);
    final heart = Paint()..color = const Color(0xFFB5475E);
    for (final (i, p) in blossoms.indexed) {
      for (var k = 0; k < 5; k++) {
        final angle = k * 2 * math.pi / 5 + i;
        canvas.drawCircle(
          p + Offset(math.cos(angle), math.sin(angle)) * 5,
          4.2,
          k.isEven ? petal : blush,
        );
      }
      canvas.drawCircle(p, 2.2, heart);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _cloudRows = [
  '   wwww     ',
  ' wwwwwwww   ',
  'wwwwwwwwwwww',
  ' wwwwwwwwww ',
];

class _RetroSkyBanner extends CustomPainter {
  const _RetroSkyBanner();

  @override
  void paint(Canvas canvas, Size size) {
    const bands = [
      Color(0xFF5C94FC),
      Color(0xFF6CA0FC),
      Color(0xFF7FB0FC),
      Color(0xFF94C0FC),
    ];
    final bandHeight = size.height / bands.length;
    for (final (i, color) in bands.indexed) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * bandHeight, size.width, bandHeight + 1),
        Paint()..color = color,
      );
    }
    const cell = 4.0;
    for (final (x, y) in [(0.08, 0.12), (0.45, 0.3), (0.75, 0.08)]) {
      paintSprite(
        canvas,
        _cloudRows,
        const {'w': Colors.white},
        origin: Offset(size.width * x, size.height * y),
        cell: cell,
      );
    }
    // Pixel sun.
    final sun = Offset(size.width * 0.9, size.height * 0.45);
    canvas.drawRect(
      Rect.fromCenter(center: sun, width: 20, height: 20),
      Paint()..color = const Color(0xFFFFC83D),
    );
    // Stepped green hills and a brick ground strip.
    final hill = Paint()
      ..color = const Color(0xFF00A800)
      ..isAntiAlias = false;
    final ground = size.height - 14;
    for (var x = 0.0; x < size.width; x += cell) {
      final h = (math.sin(x / size.width * math.pi * 3) * 0.5 + 0.5) * 26 + 8;
      final stepped = (h / cell).floorToDouble() * cell;
      canvas.drawRect(Rect.fromLTWH(x, ground - stepped, cell, stepped), hill);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, 14),
      Paint()..color = const Color(0xFFC84C0C),
    );
    final mortar = Paint()..color = const Color(0xFF2E1A0C);
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, ground, 2, 14), mortar);
    }
    canvas.drawRect(Rect.fromLTWH(0, ground + 6, size.width, 2), mortar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _invaderRows = [
  '  g     g  ',
  '   g   g   ',
  '  ggggggg  ',
  ' gg ggg gg ',
  'ggggggggggg',
  'g ggggggg g',
  'g g     g g',
  '   gg gg   ',
];

const _shipRows = ['     c     ', '    ccc    ', ' ccccccccc ', 'ccccccccccc'];

class _SpaceBanner extends CustomPainter {
  const _SpaceBanner();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0B1A),
    );
    final rand = _Rand(3);
    final star = Paint()..isAntiAlias = false;
    for (var i = 0; i < 60; i++) {
      star.color = i % 4 == 0 ? const Color(0xFFFFE66D) : Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(
          rand.next() * size.width,
          rand.next() * size.height,
          2,
          2,
        ),
        star,
      );
    }
    const cell = 3.0;
    final invaderWidth = _invaderRows.first.length * cell;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 6; col++) {
        paintSprite(
          canvas,
          _invaderRows,
          {'g': row == 0 ? const Color(0xFF39FF14) : const Color(0xFFFF6BD6)},
          origin: Offset(
            size.width * 0.12 + col * (invaderWidth + 14),
            14 + row * 30.0,
          ),
          cell: cell,
        );
      }
    }
    paintSprite(
      canvas,
      _shipRows,
      const {'c': Color(0xFF4ECDC4)},
      origin: Offset(size.width * 0.46, size.height - 18),
      cell: cell,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
