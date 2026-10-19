import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/starry_night.dart';

/// One background per weekly contest theme, keyed by the theme's English title
/// (the same text the server sends). Eight are painted in the manner of Van Gogh
/// and eight are pixel art; an unknown title falls back to the Starry Night.
CustomPainter contestBackdropPainter(String? themeTitle) =>
    switch (themeTitle) {
      'The Starry Night' => const StarryNightPainter(),
      'Sunflowers' => const _Backdrop(_sunflowers),
      'Café Terrace at Night' => const _Backdrop(_cafeTerrace),
      'Wheatfield with Cypresses' => const _Backdrop(_wheatfield),
      'Almond Blossom' => const _Backdrop(_almondBlossom),
      'The Bedroom in Arles' => const _Backdrop(_bedroomArles),
      'Self-Portrait' => const _Backdrop(_selfPortrait),
      'A Pair of Shoes' => const _Backdrop(_shoes),
      'The 1980s Arcade Cabinet' => const _Backdrop(_arcadeCabinet),
      'The Game Cartridge' => const _Backdrop(_cartridge),
      'The CRT Glow' => const _Backdrop(_crtGlow),
      'The First Gamepad' => const _Backdrop(_gamepad),
      'The Bedroom Computer' => const _Backdrop(_bedroomComputer),
      'The Chiptune Chip' => const _Backdrop(_chiptune),
      'The Coin Arcade' => const _Backdrop(_coinArcade),
      'The Floppy Disk' => const _Backdrop(_floppy),
      _ => const StarryNightPainter(),
    };

/// [child] on top of the backdrop of [themeTitle], under a cream veil so the text
/// on top stays easy to read (see [StarryNight] for what [veil] means).
class ContestBackdrop extends StatelessWidget {
  const ContestBackdrop({
    required this.child,
    this.themeTitle,
    this.veil = 0.5,
    super.key,
  });

  final Widget child;
  final String? themeTitle;
  final double veil;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: contestBackdropPainter(themeTitle)),
        ),
      ),
      Positioned.fill(
        child: ColoredBox(color: NeoColors.surface.withValues(alpha: veil)),
      ),
      child,
    ],
  );
}

typedef _Scene = void Function(Canvas canvas, Size size);

class _Backdrop extends CustomPainter {
  const _Backdrop(this.scene);

  final _Scene scene;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    scene(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Backdrop old) => false;
}

// -- Helpers ---------------------------------------------------------------------

Paint _fill(Color color) => Paint()..color = color;

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

void _gradient(Canvas canvas, Size size, List<Color> colors) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );
}

/// A rectangle given as shares of the width and the height.
void _box(
  Canvas canvas,
  Size size,
  double x,
  double y,
  double w,
  double h,
  Color color,
) => canvas.drawRect(
  Rect.fromLTWH(
    x * size.width,
    y * size.height,
    w * size.width,
    h * size.height,
  ),
  _fill(color),
);

/// Pixel-art rectangles snap to a grid of [cells] cells across the short side.
class _Pixels {
  _Pixels(this.canvas, this.size, {this.cells = 36})
    : cell = size.shortestSide / cells;

  final Canvas canvas;
  final Size size;
  final int cells;
  final double cell;

  /// A block at grid position ([x], [y]) of [w] by [h] cells.
  void block(num x, num y, num w, num h, Color color) => canvas.drawRect(
    Rect.fromLTWH(x * cell, y * cell, w * cell, h * cell),
    _fill(color),
  );

  int get cols => (size.width / cell).ceil() + 1;
  int get rows => (size.height / cell).ceil() + 1;
}

void _star(Canvas canvas, Offset c, double r, Color color) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final radius = i.isEven ? r : r * 0.4;
    final a = i * math.pi / 4;
    final p = c + Offset(math.cos(a), math.sin(a)) * radius;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), _fill(color));
}

// -- Van Gogh --------------------------------------------------------------------

void _sunflowers(Canvas canvas, Size size) {
  _gradient(canvas, size, const [Color(0xFFF7D774), Color(0xFFE9A92B)]);
  final unit = size.shortestSide;
  // Short brush strokes on the wall.
  for (var i = 0; i < 40; i++) {
    final x = (i * 0.37 % 1) * size.width;
    final y = (i * 0.61 % 1) * size.height;
    canvas.drawLine(
      Offset(x, y),
      Offset(x + unit * 0.06, y - unit * 0.02),
      _line(const Color(0x33B7791F), unit * 0.012),
    );
  }
  const flowers = [
    Offset(0.22, 0.16),
    Offset(0.74, 0.28),
    Offset(0.42, 0.46),
    Offset(0.16, 0.68),
    Offset(0.80, 0.78),
    Offset(0.52, 0.90),
  ];
  for (final (index, spot) in flowers.indexed) {
    final c = Offset(spot.dx * size.width, spot.dy * size.height);
    final r = unit * (0.10 + (index % 3) * 0.02);
    canvas.drawLine(
      c,
      Offset(c.dx - r * 0.3, c.dy + r * 2.4),
      _line(const Color(0xFF4F7A2A), unit * 0.014),
    );
    for (var p = 0; p < 14; p++) {
      final a = p * 2 * math.pi / 14 + index;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r * 1.05, 0),
          width: r * 0.8,
          height: r * 0.34,
        ),
        _fill(p.isEven ? const Color(0xFFFFE066) : const Color(0xFFF5B82E)),
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.62, _fill(const Color(0xFF7A4A12)));
    canvas.drawCircle(c, r * 0.36, _fill(const Color(0xFF4B2E0B)));
  }
}

void _cafeTerrace(Canvas canvas, Size size) {
  _gradient(canvas, size, const [Color(0xFF0B1E4D), Color(0xFF24478F)]);
  final unit = size.shortestSide;
  for (final s in const [
    Offset(0.15, 0.08),
    Offset(0.40, 0.14),
    Offset(0.62, 0.06),
    Offset(0.85, 0.16),
    Offset(0.28, 0.26),
    Offset(0.72, 0.32),
  ]) {
    _star(
      canvas,
      Offset(s.dx * size.width, s.dy * size.height),
      unit * 0.03,
      const Color(0xFFFFE66D),
    );
  }
  // The lit terrace: a warm yellow wash with an awning and cobbles.
  final glow = Rect.fromLTWH(
    0,
    size.height * 0.42,
    size.width,
    size.height * 0.58,
  );
  canvas.drawRect(
    glow,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD34D), Color(0xFFE79A1C)],
      ).createShader(glow),
  );
  final awning = Path()
    ..moveTo(0, size.height * 0.42)
    ..lineTo(size.width, size.height * 0.42)
    ..lineTo(size.width, size.height * 0.52)
    ..lineTo(0, size.height * 0.52)
    ..close();
  canvas.drawPath(awning, _fill(const Color(0xFFF2B233)));
  for (var i = 0; i < 9; i++) {
    _box(canvas, size, i * 0.125, 0.42, 0.0625, 0.10, const Color(0xFFD9822B));
  }
  // Lamp.
  canvas.drawLine(
    Offset(size.width * 0.84, size.height * 0.52),
    Offset(size.width * 0.84, size.height * 0.88),
    _line(const Color(0xFF3B2A12), unit * 0.012),
  );
  canvas.drawCircle(
    Offset(size.width * 0.84, size.height * 0.50),
    unit * 0.05,
    _fill(const Color(0xFFFFF3B0)),
  );
  // Cobblestones.
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 10; col++) {
      final dx = (row.isEven ? 0.0 : 0.5) + col;
      final rect = Rect.fromLTWH(
        dx * size.width / 10,
        size.height * (0.66 + row * 0.045),
        size.width / 10 * 0.86,
        size.height * 0.032,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(unit * 0.01)),
        _fill(Color(row.isEven ? 0xFFC77B2A : 0xFFB36A22)),
      );
    }
  }
}

void _wheatfield(Canvas canvas, Size size) {
  _gradient(canvas, size, const [Color(0xFF6FB1E0), Color(0xFFD6ECF7)]);
  final unit = size.shortestSide;
  // Swirling clouds.
  for (var i = 0; i < 3; i++) {
    final c = Offset(
      size.width * (0.25 + i * 0.28),
      size.height * (0.16 + (i % 2) * 0.1),
    );
    for (var k = 1; k <= 3; k++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: unit * 0.05 * k),
        i + k * 0.8,
        4.4,
        false,
        _line(const Color(0xCCFFFFFF), unit * 0.014),
      );
    }
  }
  // Wheat in rolling bands.
  for (var band = 0; band < 6; band++) {
    final y = size.height * (0.55 + band * 0.08);
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, y);
    for (var x = 0.0; x <= size.width; x += unit * 0.04) {
      path.lineTo(x, y + math.sin(x / unit * 7 + band) * unit * 0.025);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      _fill(
        Color.lerp(const Color(0xFFF0C93E), const Color(0xFFB98A1D), band / 5)!,
      ),
    );
  }
  // Cypress, a dark green flame.
  final cx = size.width * 0.16;
  final top = size.height * 0.14;
  final base = size.height * 0.80;
  final cypress = Path()
    ..moveTo(cx, top)
    ..cubicTo(
      cx + unit * 0.14,
      top + (base - top) * 0.3,
      cx + unit * 0.12,
      top + (base - top) * 0.7,
      cx + unit * 0.05,
      base,
    )
    ..lineTo(cx - unit * 0.05, base)
    ..cubicTo(
      cx - unit * 0.12,
      top + (base - top) * 0.7,
      cx - unit * 0.13,
      top + (base - top) * 0.3,
      cx,
      top,
    )
    ..close();
  canvas.drawPath(cypress, _fill(const Color(0xFF1F4D2B)));
  for (var i = 0; i < 9; i++) {
    final y = top + (base - top) * (0.12 + i * 0.1);
    canvas.drawLine(
      Offset(cx - unit * 0.05, y),
      Offset(cx + unit * 0.04, y - unit * 0.04),
      _line(const Color(0xFF3F7A48), unit * 0.012),
    );
  }
}

void _almondBlossom(Canvas canvas, Size size) {
  _gradient(canvas, size, const [Color(0xFF5FB8E8), Color(0xFF9BD6F0)]);
  final unit = size.shortestSide;
  final branch = _line(const Color(0xFF3A2A1A), unit * 0.02);
  final main = Path()
    ..moveTo(-unit * 0.05, size.height * 0.85)
    ..cubicTo(
      size.width * 0.3,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.5,
      size.width * 1.05,
      size.height * 0.15,
    );
  canvas.drawPath(main, branch);
  final twigs = [
    [0.3, 0.64, 0.38, 0.88],
    [0.5, 0.52, 0.62, 0.78],
    [0.7, 0.34, 0.9, 0.5],
    [0.4, 0.57, 0.3, 0.3],
    [0.62, 0.43, 0.55, 0.16],
  ];
  final blossoms = <Offset>[];
  for (final t in twigs) {
    final a = Offset(t[0] * size.width, t[1] * size.height);
    final b = Offset(t[2] * size.width, t[3] * size.height);
    canvas.drawLine(a, b, _line(const Color(0xFF3A2A1A), unit * 0.012));
    for (var i = 1; i <= 3; i++) {
      blossoms.add(Offset.lerp(a, b, i / 3)!);
    }
  }
  for (final (index, spot) in blossoms.indexed) {
    for (var p = 0; p < 5; p++) {
      final a = p * 2 * math.pi / 5 + index;
      canvas.drawCircle(
        spot + Offset(math.cos(a), math.sin(a)) * unit * 0.025,
        unit * 0.022,
        _fill(index.isEven ? Colors.white : const Color(0xFFFFE3EC)),
      );
    }
    canvas.drawCircle(spot, unit * 0.012, _fill(const Color(0xFFF4A6BC)));
  }
}

void _bedroomArles(Canvas canvas, Size size) {
  final unit = size.shortestSide;
  _box(canvas, size, 0, 0, 1, 0.62, const Color(0xFF9FCBE0));
  _box(canvas, size, 0, 0.62, 1, 0.38, const Color(0xFFC9803A));
  // Floorboards.
  for (var i = 0; i < 10; i++) {
    canvas.drawLine(
      Offset(0, size.height * (0.64 + i * 0.04)),
      Offset(size.width, size.height * (0.64 + i * 0.04)),
      _line(const Color(0x338A4B14), unit * 0.008),
    );
  }
  // Shutters and window.
  _box(canvas, size, 0.58, 0.10, 0.30, 0.36, const Color(0xFF3F8F4B));
  _box(canvas, size, 0.61, 0.13, 0.11, 0.30, const Color(0xFF9FD6E8));
  _box(canvas, size, 0.74, 0.13, 0.11, 0.30, const Color(0xFF9FD6E8));
  // The bed: frame, mattress, red blanket, pillow.
  _box(canvas, size, 0.06, 0.40, 0.46, 0.34, const Color(0xFFE8B04A));
  _box(canvas, size, 0.08, 0.50, 0.42, 0.18, const Color(0xFFF7E8B5));
  _box(canvas, size, 0.08, 0.58, 0.42, 0.12, const Color(0xFFD7403A));
  _box(canvas, size, 0.09, 0.46, 0.14, 0.07, Colors.white);
  // A chair and framed pictures.
  _box(canvas, size, 0.66, 0.64, 0.14, 0.04, const Color(0xFFE8B04A));
  _box(canvas, size, 0.67, 0.68, 0.02, 0.14, const Color(0xFFE8B04A));
  _box(canvas, size, 0.78, 0.68, 0.02, 0.14, const Color(0xFFE8B04A));
  _box(canvas, size, 0.14, 0.12, 0.12, 0.14, const Color(0xFF5B7FB3));
  _box(canvas, size, 0.30, 0.16, 0.10, 0.12, const Color(0xFFB36A3A));
}

void _selfPortrait(Canvas canvas, Size size) {
  _gradient(canvas, size, const [Color(0xFF1F7C8C), Color(0xFF2F5FA6)]);
  final unit = size.shortestSide;
  final c = Offset(size.width * 0.5, size.height * 0.42);
  // Swirling brushstrokes around the head.
  for (var ring = 1; ring <= 11; ring++) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: unit * 0.09 * ring),
      ring * 0.7,
      math.pi * 1.5,
      false,
      _line(
        ring.isEven ? const Color(0xFF63C5C9) : const Color(0xFF16406E),
        unit * 0.02,
      ),
    );
  }
  // The head: face, beard, a blue coat.
  canvas.drawOval(
    Rect.fromCenter(center: c, width: unit * 0.34, height: unit * 0.44),
    _fill(const Color(0xFFF1B383)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(0, unit * 0.12),
      width: unit * 0.34,
      height: unit * 0.24,
    ),
    _fill(const Color(0xFFD9772B)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c - Offset(0, unit * 0.18),
      width: unit * 0.36,
      height: unit * 0.12,
    ),
    _fill(const Color(0xFFC96A22)),
  );
  canvas.drawCircle(
    c + Offset(-unit * 0.06, -unit * 0.03),
    unit * 0.014,
    _fill(const Color(0xFF1B3A5C)),
  );
  canvas.drawCircle(
    c + Offset(unit * 0.06, -unit * 0.03),
    unit * 0.014,
    _fill(const Color(0xFF1B3A5C)),
  );
  canvas.drawOval(
    Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.68,
      size.width * 0.76,
      size.height * 0.5,
    ),
    _fill(const Color(0xFF2F5FA6)),
  );
}

void _shoes(Canvas canvas, Size size) {
  final unit = size.shortestSide;
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFFB98350));
  for (var i = 0; i < 9; i++) {
    final x = size.width * i / 8;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      _line(const Color(0x558A5A2B), unit * 0.012),
    );
  }
  for (var i = 0; i < 40; i++) {
    final x = (i * 0.29 % 1) * size.width;
    final y = (i * 0.53 % 1) * size.height;
    canvas.drawLine(
      Offset(x, y),
      Offset(x + unit * 0.05, y),
      _line(const Color(0x33603A14), unit * 0.008),
    );
  }
  void shoe(Offset c, double angle, Color body) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final sole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: unit * 0.50,
        height: unit * 0.20,
      ),
      Radius.circular(unit * 0.09),
    );
    canvas.drawRRect(
      sole.shift(Offset(unit * 0.012, unit * 0.014)),
      _fill(const Color(0x66000000)),
    );
    canvas.drawRRect(sole, _fill(const Color(0xFF3B2A1C)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-unit * 0.02, -unit * 0.01),
          width: unit * 0.44,
          height: unit * 0.15,
        ),
        Radius.circular(unit * 0.07),
      ),
      _fill(body),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-unit * 0.14, -unit * 0.01),
        width: unit * 0.12,
        height: unit * 0.09,
      ),
      _fill(const Color(0xFF241810)),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(unit * (0.0 + i * 0.04), -unit * 0.05),
        Offset(unit * (0.02 + i * 0.04), unit * 0.03),
        _line(const Color(0xFFE9D9B5), unit * 0.008),
      );
    }
    canvas.restore();
  }

  shoe(
    Offset(size.width * 0.42, size.height * 0.32),
    -0.35,
    const Color(0xFF6E4B2A),
  );
  shoe(
    Offset(size.width * 0.60, size.height * 0.70),
    0.30,
    const Color(0xFF5A3C20),
  );
}

// -- 8-bit -----------------------------------------------------------------------

void _arcadeCabinet(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF1B1035));
  final p = _Pixels(canvas, size);
  // Neon floor stripes.
  for (var y = 0; y < p.rows; y += 4) {
    p.block(
      0,
      y,
      p.cols,
      1,
      y.isEven && y % 8 == 0
          ? const Color(0xFF3A1F6B)
          : const Color(0xFF2A1750),
    );
  }
  final left = (p.cols - 14) ~/ 2;
  final top = (p.rows * 0.12).round();
  // Cabinet body, marquee, screen, control deck.
  p.block(left, top, 14, 26, const Color(0xFF6A2FB8));
  p.block(left + 1, top + 1, 12, 3, const Color(0xFFFF4FA3));
  p.block(left + 2, top + 5, 10, 9, const Color(0xFF05060F));
  p.block(left + 3, top + 6, 8, 7, const Color(0xFF3DDCFF));
  p.block(left + 5, top + 8, 2, 2, const Color(0xFFFFE066));
  p.block(left + 8, top + 10, 2, 1, const Color(0xFFFF4FA3));
  p.block(left + 1, top + 16, 12, 4, const Color(0xFF2D1560));
  p.block(left + 3, top + 17, 2, 2, const Color(0xFFFF4F4F));
  p.block(left + 7, top + 17, 2, 2, const Color(0xFFFFE066));
  p.block(left + 10, top + 17, 2, 2, const Color(0xFF3DDCFF));
  p.block(left + 1, top + 21, 12, 5, const Color(0xFF4A2290));
  // Stars.
  for (var i = 0; i < 18; i++) {
    p.block(
      (i * 7) % p.cols,
      (i * 11) % (top + 8),
      1,
      1,
      const Color(0xFFFFF3B0),
    );
  }
}

void _cartridge(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF0E5E6F));
  final p = _Pixels(canvas, size);
  // A checkerboard floor.
  for (var y = 0; y < p.rows; y++) {
    for (var x = 0; x < p.cols; x++) {
      if ((x + y) % 2 == 0) p.block(x, y, 1, 1, const Color(0xFF127287));
    }
  }
  void cartridge(int x, int y, Color shell, Color label) {
    p.block(x + 1, y + 1, 12, 15, const Color(0x66000000));
    p.block(x, y, 12, 15, shell);
    p.block(
      x + 1,
      y + 1,
      10,
      1,
      const Color(0xFFFFFFFF).withValues(alpha: 0.25),
    );
    p.block(x + 2, y + 3, 8, 7, label);
    p.block(x + 3, y + 4, 6, 3, const Color(0xFFFFE066));
    p.block(x + 4, y + 7, 4, 1, const Color(0xFF1B1035));
    p.block(x + 1, y + 12, 10, 2, const Color(0xFF2B2B2B));
    p.block(x + 2, y + 13, 8, 1, const Color(0xFFE0B13A));
  }

  cartridge(2, 3, const Color(0xFF8E8E9A), const Color(0xFFFF5A5A));
  cartridge(p.cols - 15, 12, const Color(0xFF7A7A88), const Color(0xFF59C36A));
  cartridge(5, p.rows - 20, const Color(0xFF9A9AA6), const Color(0xFF5A8CFF));
}

void _crtGlow(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF050B07));
  final unit = size.shortestSide;
  final screen = Rect.fromLTWH(
    size.width * 0.06,
    size.height * 0.05,
    size.width * 0.88,
    size.height * 0.90,
  );
  final glow = Paint()
    ..shader = RadialGradient(
      colors: const [Color(0xFF39FF7A), Color(0xFF0B5A2A), Color(0xFF031308)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(screen);
  canvas.drawRRect(
    RRect.fromRectAndRadius(screen, Radius.circular(unit * 0.12)),
    glow,
  );
  // Scanlines.
  final line = _fill(const Color(0x55000000));
  for (var y = screen.top; y < screen.bottom; y += unit * 0.018) {
    canvas.drawRect(
      Rect.fromLTWH(screen.left, y, screen.width, unit * 0.008),
      line,
    );
  }
  // A prompt.
  final p = _Pixels(canvas, size);
  p.block(4, 5, 10, 2, const Color(0xFFB8FFD0));
  p.block(4, 9, 16, 1, const Color(0xFF7DFFAA));
  p.block(4, 12, 12, 1, const Color(0xFF7DFFAA));
  p.block(4, 15, 3, 2, const Color(0xFFB8FFD0));
  // Bezel.
  canvas.drawRRect(
    RRect.fromRectAndRadius(screen, Radius.circular(unit * 0.12)),
    _line(const Color(0xFF1E1E22), unit * 0.05),
  );
}

void _gamepad(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF263B8F));
  final p = _Pixels(canvas, size);
  for (var y = 0; y < p.rows; y += 2) {
    for (var x = (y ~/ 2).isEven ? 0 : 2; x < p.cols; x += 4) {
      p.block(x, y, 1, 1, const Color(0xFF3550B8));
    }
  }
  final cx = (p.cols - 28) ~/ 2;
  final cy = (p.rows * 0.30).round();
  // Body.
  p.block(cx, cy, 28, 12, const Color(0xFFD9D6D0));
  p.block(cx - 1, cy + 2, 1, 8, const Color(0xFFD9D6D0));
  p.block(cx + 28, cy + 2, 1, 8, const Color(0xFFD9D6D0));
  p.block(cx, cy + 11, 28, 2, const Color(0xFF9C9A95));
  // D-pad.
  p.block(cx + 3, cy + 5, 7, 2, const Color(0xFF222222));
  p.block(cx + 5.5, cy + 3, 2, 6, const Color(0xFF222222));
  // Select / start.
  p.block(cx + 12, cy + 8, 2, 1, const Color(0xFF555555));
  p.block(cx + 15, cy + 8, 2, 1, const Color(0xFF555555));
  // A and B.
  p.block(cx + 19, cy + 6, 3, 3, const Color(0xFFE5393A));
  p.block(cx + 23, cy + 6, 3, 3, const Color(0xFFE5393A));
  // The cord.
  p.block(cx + 13, cy + 13, 2, p.rows - cy - 13, const Color(0xFF111111));
}

void _bedroomComputer(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 0.70, const Color(0xFF16213E));
  _box(canvas, size, 0, 0.70, 1, 0.30, const Color(0xFF6B4A2B));
  final p = _Pixels(canvas, size);
  // The window and a few pixel stars.
  p.block(2, 3, 9, 9, const Color(0xFF0B1226));
  p.block(2, 7, 9, 1, const Color(0xFF16213E));
  p.block(6, 3, 1, 9, const Color(0xFF16213E));
  p.block(4, 5, 1, 1, const Color(0xFFFFF3B0));
  p.block(8, 9, 1, 1, const Color(0xFFFFF3B0));
  final deskY = (p.rows * 0.70).round();
  // The monitor and the beige tower.
  final mx = (p.cols * 0.40).round();
  final my = deskY - 17;
  p.block(mx, my, 18, 14, const Color(0xFFD8CFB8));
  p.block(mx + 2, my + 2, 14, 10, const Color(0xFF1C3CA0));
  p.block(mx + 3, my + 4, 6, 1, const Color(0xFFFFFFFF));
  p.block(mx + 3, my + 6, 9, 1, const Color(0xFFFFFFFF));
  p.block(mx + 3, my + 8, 4, 1, const Color(0xFFFFFFFF));
  p.block(mx + 7, my + 14, 4, 3, const Color(0xFFBDB49C));
  p.block(mx - 3, deskY - 2, 24, 2, const Color(0xFFD8CFB8));
  p.block(mx - 1, deskY - 3, 20, 1, const Color(0xFF8E8671));
  // Desk edge.
  p.block(0, deskY, p.cols, 1, const Color(0xFF3F2A15));
  // A lamp glow.
  p.block(p.cols - 8, deskY - 8, 3, 8, const Color(0xFF3A3A3A));
  p.block(p.cols - 10, deskY - 11, 7, 3, const Color(0xFFFFD34D));
}

void _chiptune(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF0F4D2E));
  final p = _Pixels(canvas, size);
  // Copper traces.
  const trace = Color(0xFF2E9B5A);
  for (var i = 0; i < 6; i++) {
    final y = 2 + i * 6;
    p.block(0, y, p.cols * 0.4, 1, trace);
    p.block(p.cols * 0.4, y, 1, 3, trace);
    p.block(p.cols * 0.4, y + 3, p.cols * 0.25, 1, trace);
    p.block(p.cols * 0.7, y - 2, 1, 4, trace);
  }
  // The chip: black body, legs, a dot and a note.
  final cx = (p.cols - 14) ~/ 2;
  final cy = (p.rows * 0.34).round();
  for (var i = 0; i < 6; i++) {
    p.block(cx - 2, cy + 1 + i * 2, 2, 1, const Color(0xFFC9C9C9));
    p.block(cx + 14, cy + 1 + i * 2, 2, 1, const Color(0xFFC9C9C9));
  }
  p.block(cx, cy, 14, 13, const Color(0xFF15151A));
  p.block(cx + 1, cy + 1, 2, 2, const Color(0xFF3A3A44));
  p.block(cx + 6, cy + 4, 2, 5, const Color(0xFFFFE066));
  p.block(cx + 4, cy + 8, 3, 2, const Color(0xFFFFE066));
  p.block(cx + 8, cy + 4, 3, 1, const Color(0xFFFFE066));
  // Solder dots.
  for (var i = 0; i < 20; i++) {
    p.block(
      (i * 5) % p.cols,
      (i * 13 + 3) % p.rows,
      1,
      1,
      const Color(0xFFDADADA),
    );
  }
}

void _coinArcade(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF2B1A12));
  final p = _Pixels(canvas, size);
  for (var y = 0; y < p.rows; y += 3) {
    p.block(0, y, p.cols, 1, const Color(0xFF3A2519));
  }
  void coin(num x, num y) {
    p.block(x + 1, y, 4, 1, const Color(0xFF8A5A00));
    p.block(x, y + 1, 6, 4, const Color(0xFFFFC83D));
    p.block(x + 1, y + 5, 4, 1, const Color(0xFF8A5A00));
    p.block(x + 1, y + 1, 1, 1, const Color(0xFFFFF0A8));
    p.block(x + 2, y + 2, 2, 2, const Color(0xFFE09A12));
  }

  for (var row = 0; row < 6; row++) {
    for (var col = 0; col < 5; col++) {
      final x = 1 + col * 8 + (row.isOdd ? 4 : 0);
      final y = 2 + row * 8.0;
      if (x + 6 < p.cols && y + 6 < p.rows) coin(x, y);
    }
  }
  // Sparkles.
  for (var i = 0; i < 8; i++) {
    final x = (i * 9 + 5) % p.cols;
    final y = (i * 7 + 2) % p.rows;
    p.block(x, y, 1, 1, Colors.white);
    p.block(x - 1, y, 3, 1, const Color(0x99FFFFFF));
  }
}

void _floppy(Canvas canvas, Size size) {
  _box(canvas, size, 0, 0, 1, 1, const Color(0xFF16808C));
  final p = _Pixels(canvas, size);
  for (var y = 0; y < p.rows; y++) {
    if (y % 6 == 0) p.block(0, y, p.cols, 1, const Color(0xFF1B93A0));
  }
  void disk(int x, int y, Color shell) {
    p.block(x + 1, y + 1, 14, 14, const Color(0x66000000));
    p.block(x, y, 14, 14, shell);
    p.block(x + 12, y, 2, 2, const Color(0xFF16808C));
    p.block(x + 3, y, 8, 5, const Color(0xFFC9CED6));
    p.block(x + 8, y + 1, 2, 3, const Color(0xFF2B2B33));
    p.block(x + 2, y + 7, 10, 7, const Color(0xFFF2EFE4));
    p.block(x + 3, y + 9, 8, 1, const Color(0xFF9A9A9A));
    p.block(x + 3, y + 11, 5, 1, const Color(0xFF9A9A9A));
  }

  disk(3, 3, const Color(0xFF2D4EA8));
  disk(p.cols - 17, 14, const Color(0xFFD9423B));
  disk(6, p.rows - 19, const Color(0xFF2E2E36));
}
