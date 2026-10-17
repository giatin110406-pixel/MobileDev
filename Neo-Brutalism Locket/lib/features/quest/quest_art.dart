import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/features/contest/starry_night.dart';

/// A small redrawn picture of the story behind each quest: the painting for a
/// Van Gogh quest, the game screen for an 8-bit one. Drawn in code, so there is
/// nothing to download and it scales to any card.
class QuestArt extends StatelessWidget {
  const QuestArt({required this.questId, super.key});

  final String questId;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: QuestArtPainter(questId), size: Size.infinite),
  );
}

class QuestArtPainter extends CustomPainter {
  const QuestArtPainter(this.id);

  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scene = _scenes[id];
    if (scene == null) {
      const StarryNightPainter().paint(canvas, size);
    } else {
      scene(_Pen(canvas, size));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant QuestArtPainter old) => old.id != id;
}

/// Drawing helpers. Free drawing uses x as a share of the width and y and every
/// size as a share of the height; pixel-art drawing uses a grid 20 cells tall,
/// counted from the horizontal centre so it works at any width.
class _Pen {
  _Pen(this.canvas, this.size) : cell = size.height / 20;

  final Canvas canvas;
  final Size size;
  final double cell;

  double get w => size.width;
  double get h => size.height;

  Paint _fill(int argb, {bool aa = true}) => Paint()
    ..color = Color(argb)
    ..isAntiAlias = aa;

  Paint _stroke(int argb, double width) => Paint()
    ..color = Color(argb)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * h
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Offset at(double x, double y) => Offset(x * w, y * h);

  void grad(int top, int bottom, [double from = 0, double to = 1]) {
    final rect = Rect.fromLTRB(0, from * h, w, to * h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(top), Color(bottom)],
        ).createShader(rect),
    );
  }

  void fill(int argb) => canvas.drawRect(Offset.zero & size, _fill(argb));

  void rect(double x, double y, double rw, double rh, int argb) =>
      canvas.drawRect(Rect.fromLTWH(x * w, y * h, rw * w, rh * h), _fill(argb));

  void circle(double x, double y, double r, int argb) =>
      canvas.drawCircle(at(x, y), r * h, _fill(argb));

  void oval(double x, double y, double rx, double ry, int argb) =>
      canvas.drawOval(
        Rect.fromCenter(
          center: at(x, y),
          width: rx * 2 * h,
          height: ry * 2 * h,
        ),
        _fill(argb),
      );

  void poly(List<List<double>> pts, int argb) {
    final path = Path()..moveTo(pts.first[0] * w, pts.first[1] * h);
    for (final p in pts.skip(1)) {
      path.lineTo(p[0] * w, p[1] * h);
    }
    canvas.drawPath(path..close(), _fill(argb));
  }

  void line(double x1, double y1, double x2, double y2, int argb, double lw) =>
      canvas.drawLine(at(x1, y1), at(x2, y2), _stroke(argb, lw));

  /// A wavy stroke across the whole width.
  void wave(double y, double amp, int argb, double lw, {double phase = 0}) {
    final path = Path()..moveTo(-0.05 * w, y * h);
    for (var x = -0.05; x <= 1.05; x += 0.02) {
      path.lineTo(x * w, (y + amp * math.sin(x * w / h * 2.4 + phase)) * h);
    }
    canvas.drawPath(path, _stroke(argb, lw));
  }

  /// A glow: a circle fading from [argb] to nothing.
  void glow(double x, double y, double r, int argb) {
    final centre = at(x, y);
    canvas.drawCircle(
      centre,
      r * h,
      Paint()
        ..shader = RadialGradient(
          colors: [Color(argb), Color(argb).withAlpha(0)],
        ).createShader(Rect.fromCircle(center: centre, radius: r * h)),
    );
  }

  /// A cypress flame: pointed at the top, wide at the base.
  void flame(double x, double top, double base, double half, int argb) {
    final path = Path()
      ..moveTo(x * w, top * h)
      ..cubicTo(
        x * w + half * 1.5 * h,
        (top + (base - top) * 0.35) * h,
        x * w + half * 0.5 * h,
        (base - (base - top) * 0.2) * h,
        x * w + half * h,
        base * h,
      )
      ..lineTo(x * w - half * h, base * h)
      ..cubicTo(
        x * w - half * 0.5 * h,
        (base - (base - top) * 0.2) * h,
        x * w - half * 1.5 * h,
        (top + (base - top) * 0.35) * h,
        x * w,
        top * h,
      );
    canvas.drawPath(path, _fill(argb));
  }

  void crow(double x, double y, double s) {
    final path = Path()
      ..moveTo((x - s) * h, y * h)
      ..quadraticBezierTo((x - s * 0.5) * h, (y - s * 0.7) * h, x * h, y * h)
      ..quadraticBezierTo(
        (x + s * 0.5) * h,
        (y - s * 0.7) * h,
        (x + s) * h,
        y * h,
      );
    canvas.drawPath(path, _stroke(0xFF101010, 0.018));
  }

  // ---- pixel art ----------------------------------------------------------

  void px(double dx, double row, double pw, double ph, int argb) =>
      canvas.drawRect(
        Rect.fromLTWH(w / 2 + dx * cell, row * cell, pw * cell, ph * cell),
        _fill(argb, aa: false),
      );

  void pxFill(int argb) =>
      canvas.drawRect(Offset.zero & size, _fill(argb, aa: false));

  /// A filled disc (or ring, with [hole]) of whole cells around the cell
  /// centre ([dx], [row]).
  void pxDisc(
    double dx,
    double row,
    double r,
    int argb, {
    double hole = 0,
    bool Function(int x, int y)? skip,
  }) {
    final n = r.ceil();
    for (var y = -n; y <= n; y++) {
      for (var x = -n; x <= n; x++) {
        final d = x * x + y * y;
        if (d > r * r || d < hole * hole) continue;
        if (skip != null && skip(x, y)) continue;
        px(dx + x, row + y, 1, 1, argb);
      }
    }
  }

  void pxPoly(List<List<double>> pts, int argb) {
    final path = Path()
      ..moveTo(w / 2 + pts.first[0] * cell, pts.first[1] * cell);
    for (final p in pts.skip(1)) {
      path.lineTo(w / 2 + p[0] * cell, p[1] * cell);
    }
    canvas.drawPath(path..close(), _fill(argb, aa: false));
  }

  /// A sprite drawn from letters; '.' is transparent.
  void sprite(
    List<String> rows,
    double dx,
    double row,
    Map<String, int> palette, {
    double s = 1,
  }) {
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final colour = palette[rows[y][x]];
        if (colour == null) continue;
        px(dx + x * s, row + y * s, s + 0.02, s + 0.02, colour);
      }
    }
  }

  /// Mario-style brick ground over the bottom [rows] rows.
  void bricks(int rows, int argb, int mortar) {
    px(-80, 20 - rows.toDouble(), 160, rows.toDouble(), mortar);
    for (var r = 0; r < rows; r++) {
      for (var c = -40; c < 40; c += 4) {
        px(c + (r.isEven ? 0 : 2) - 0.0, 20 - rows + r + 0.0, 3.8, 0.85, argb);
      }
    }
  }
}

typedef _Scene = void Function(_Pen p);

const _flowerYellow = 0xFFFFC21A;

void _sunflower(_Pen p, double x, double y, double r) {
  for (var k = 0; k < 14; k++) {
    final a = k * math.pi * 2 / 14;
    final tip = Offset(
      x * p.w + math.cos(a) * r * p.h,
      y * p.h + math.sin(a) * r * p.h,
    );
    p.canvas.drawLine(
      Offset(x * p.w, y * p.h),
      tip,
      p._stroke(k.isEven ? _flowerYellow : 0xFFF0A400, r * 0.5),
    );
  }
  p.circle(x, y, r * 0.5, 0xFF6B3E12);
  p.circle(x, y, r * 0.3, 0xFF8A5A1E);
}

void _blossom(_Pen p, double x, double y, double r) {
  p.circle(x, y, r, 0xFFFFFFFF);
  p.circle(x - r * 0.4, y - r * 0.3, r * 0.6, 0xFFFFE3EC);
  p.circle(x, y, r * 0.3, 0xFFFFA9C2);
}

void _heartRow(_Pen p, double dx, double row) => p.sprite(
  const ['.RR.RR.', 'RWRRRRR', 'RRRRRRR', '.RRRRR.', '..RRR..', '...R...'],
  dx,
  row,
  const {'R': 0xFFE8202C, 'W': 0xFFFFFFFF},
);

final Map<String, _Scene> _scenes = {
  // ---- Van Gogh ----
  'vg_grapes': (p) {
    p.grad(0xFFF9D56E, 0xFFF08A4B, 0, 0.55);
    p.circle(0.5, 0.45, 0.17, 0xFFD7301F);
    p.rect(0, 0.52, 1, 0.48, 0xFFB5302A);
    p.poly([
      [0.44, 0.52],
      [0.56, 0.52],
      [0.82, 1],
      [0.18, 1],
    ], 0xFF7B63C9);
    for (var i = 0; i < 5; i++) {
      p.wave(
        0.6 + i * 0.09,
        0.015,
        i.isEven ? 0xFFE8742C : 0xFF7A1F1F,
        0.035,
        phase: i * 1.3,
      );
    }
    for (final f in const [
      [0.3, 0.7],
      [0.36, 0.78],
      [0.68, 0.72],
      [0.74, 0.84],
    ]) {
      p.oval(f[0], f[1], 0.016, 0.055, 0xFF1F2A5C);
      p.circle(f[0], f[1] - 0.07, 0.016, 0xFF1F2A5C);
    }
  },
  'vg_sunflower': (p) {
    p.grad(0xFFF4D35E, 0xFFE0A526);
    for (final x in const [0.3, 0.5, 0.7]) {
      p.line(x, 0.5, 0.5, 0.8, 0xFF5E8A2E, 0.03);
    }
    p.rect(0.455, 0.72, 0.09, 0.3, 0xFFB8741A);
    p.oval(0.5, 0.72, 0.085, 0.03, 0xFF8A5412);
    _sunflower(p, 0.5, 0.3, 0.17);
    _sunflower(p, 0.28, 0.5, 0.13);
    _sunflower(p, 0.72, 0.46, 0.14);
    _sunflower(p, 0.12, 0.28, 0.1);
    _sunflower(p, 0.9, 0.24, 0.1);
  },
  'vg_bed': (p) {
    p.rect(0, 0, 1, 0.68, 0xFFA8CDD8);
    p.rect(0, 0.68, 1, 0.32, 0xFFC8744F);
    p.rect(0.72, 0.12, 0.14, 0.4, 0xFF4F8CA5);
    p.rect(0.735, 0.15, 0.11, 0.34, 0xFF8FC6D8);
    p.rect(0.08, 0.14, 0.1, 0.22, 0xFFE3B23C);
    p.rect(0.09, 0.17, 0.08, 0.16, 0xFF6F9F6A);
    p.rect(0.3, 0.38, 0.03, 0.46, 0xFFE3B23C);
    p.rect(0.3, 0.55, 0.4, 0.29, 0xFFE3B23C);
    p.rect(0.31, 0.57, 0.38, 0.14, 0xFFD1402F);
    p.oval(0.37, 0.52, 0.07, 0.04, 0xFFFFF3D6);
    p.rect(0.68, 0.38, 0.03, 0.46, 0xFFE3B23C);
    p.rect(0.82, 0.55, 0.02, 0.3, 0xFFE3B23C);
    p.rect(0.82, 0.55, 0.12, 0.03, 0xFFE3B23C);
    p.rect(0.92, 0.55, 0.02, 0.3, 0xFFE3B23C);
  },
  'vg_shoes': (p) {
    p.grad(0xFFDCBC70, 0xFF8A6A3B);
    for (final s in const [
      [0.36, 0.62],
      [0.64, 0.5],
    ]) {
      p.oval(s[0], s[1], 0.19, 0.1, 0xFF4A3426);
      p.oval(s[0] + 0.08, s[1] + 0.02, 0.1, 0.08, 0xFF5E4332);
      p.oval(s[0] - 0.1, s[1] - 0.04, 0.08, 0.07, 0xFF2E2018);
      p.rect(s[0] - 0.17, s[1] + 0.075, 0.34, 0.03, 0xFF241810);
      for (var i = 0; i < 4; i++) {
        p.line(
          s[0] - 0.12 + i * 0.045,
          s[1] - 0.1,
          s[0] - 0.08 + i * 0.045,
          s[1] - 0.02,
          0xFFE8D9B0,
          0.014,
        );
      }
    }
  },
  'vg_chair': (p) {
    p.rect(0, 0, 1, 0.62, 0xFF3E7CB1);
    p.rect(0.72, 0.05, 0.16, 0.57, 0xFF3F7F4F);
    p.rect(0, 0.62, 1, 0.38, 0xFFC4553A);
    for (var i = 1; i < 9; i++) {
      p.line(i / 9, 0.62, i * 0.14 - 0.1, 1, 0xFF8A3320, 0.008);
    }
    p.line(0, 0.8, 1, 0.8, 0xFF8A3320, 0.008);
    p.rect(0.41, 0.28, 0.14, 0.04, 0xFFF2C230);
    p.rect(0.41, 0.28, 0.012, 0.24, 0xFFF2C230);
    p.rect(0.535, 0.28, 0.012, 0.24, 0xFFF2C230);
    p.rect(0.41, 0.4, 0.14, 0.02, 0xFFF2C230);
    p.rect(0.38, 0.5, 0.2, 0.05, 0xFFF2C230);
    p.rect(0.39, 0.55, 0.012, 0.3, 0xFFF2C230);
    p.rect(0.565, 0.55, 0.012, 0.3, 0xFFF2C230);
    p.line(0.45, 0.48, 0.52, 0.46, 0xFF5A3A1E, 0.014);
    p.circle(0.53, 0.45, 0.02, 0xFF3A2A1A);
  },
  'vg_almond': (p) {
    p.grad(0xFF4FB3CC, 0xFF9AD8E4);
    const branch = 0xFF3B2A1E;
    p.line(0, 0.95, 0.25, 0.7, branch, 0.035);
    p.line(0.25, 0.7, 0.55, 0.5, branch, 0.03);
    p.line(0.55, 0.5, 0.85, 0.2, branch, 0.025);
    p.line(0.25, 0.7, 0.3, 0.3, branch, 0.022);
    p.line(0.55, 0.5, 0.62, 0.9, branch, 0.02);
    p.line(0.85, 0.2, 1, 0.12, branch, 0.018);
    for (final b in const [
      [0.3, 0.3, 0.07],
      [0.2, 0.5, 0.06],
      [0.42, 0.56, 0.07],
      [0.6, 0.4, 0.08],
      [0.7, 0.72, 0.06],
      [0.82, 0.3, 0.07],
      [0.93, 0.15, 0.055],
      [0.5, 0.2, 0.05],
      [0.1, 0.8, 0.05],
    ]) {
      _blossom(p, b[0], b[1], b[2]);
    }
  },
  'vg_potato': (p) {
    p.fill(0xFF2E2118);
    p.glow(0.5, 0.1, 0.75, 0xFFF2B632);
    p.circle(0.5, 0.1, 0.05, 0xFFFFF3B0);
    p.line(0.5, 0, 0.5, 0.06, 0xFF1A120C, 0.012);
    for (final f in const [
      [0.26, 0xFF5A6B4A],
      [0.4, 0xFF7A4A38],
      [0.6, 0xFF4B5D6E],
      [0.74, 0xFF6B5A3A],
    ]) {
      p.oval(f[0].toDouble(), 0.75, 0.07, 0.14, f[1].toInt());
      p.circle(f[0].toDouble(), 0.5, 0.055, 0xFFC9A47A);
    }
    p.rect(0.18, 0.66, 0.64, 0.05, 0xFF8A5E34);
    p.oval(0.5, 0.64, 0.1, 0.025, 0xFFF4EBD6);
    for (final x in const [0.46, 0.5, 0.54]) {
      p.circle(x, 0.62, 0.025, 0xFFD9A441);
    }
  },
  'vg_cafe': (p) {
    p.grad(0xFF0C1B4D, 0xFF2C4C94, 0, 0.62);
    for (final s in const [
      [0.1, 0.12],
      [0.24, 0.3],
      [0.78, 0.1],
      [0.9, 0.3],
      [0.62, 0.18],
    ]) {
      p.circle(s[0], s[1], 0.035, 0x55FFE66D);
      p.circle(s[0], s[1], 0.018, 0xFFFFE66D);
    }
    p.rect(0.62, 0.3, 0.38, 0.4, 0xFF263E7A);
    p.rect(0.2, 0.34, 0.42, 0.34, 0xFFF2B632);
    p.glow(0.41, 0.52, 0.4, 0x66FFF3B0);
    p.poly([
      [0.2, 0.34],
      [0.62, 0.34],
      [0.66, 0.26],
      [0.16, 0.26],
    ], 0xFFD98A1E);
    for (final x in const [0.27, 0.41, 0.55]) {
      p.rect(x, 0.42, 0.06, 0.2, 0xFFFFE9A0);
    }
    p.grad(0xFFE8A24A, 0xFF8A4A2A, 0.68, 1);
    for (final x in const [0.3, 0.55, 0.8]) {
      p.oval(x, 0.82, 0.07, 0.028, 0xFF4A2A1A);
      p.rect(x - 0.02, 0.82, 0.04, 0.12, 0xFF4A2A1A);
    }
  },
  'vg_bridge': (p) {
    p.grad(0xFF8FD0E8, 0xFFCFEFF4, 0, 0.5);
    p.oval(0.2, 0.15, 0.1, 0.05, 0xFFFFFFFF);
    p.oval(0.75, 0.22, 0.12, 0.05, 0xFFFFFFFF);
    p.rect(0, 0.5, 1, 0.5, 0xFF3E8EC4);
    p.wave(0.68, 0.01, 0xFF8FC8E8, 0.02);
    p.wave(0.82, 0.012, 0xFF2A6FA0, 0.025, phase: 2);
    p.rect(0, 0.45, 0.2, 0.55, 0xFFC8B84A);
    p.rect(0.8, 0.45, 0.2, 0.55, 0xFFC8B84A);
    p.rect(0.2, 0.45, 0.6, 0.04, 0xFF8A5A2B);
    for (final x in const [0.3, 0.5, 0.7]) {
      p.rect(x - 0.006, 0.45, 0.012, 0.3, 0xFF6B431F);
    }
    p.line(0.2, 0.45, 0.5, 0.2, 0xFF8A5A2B, 0.025);
    p.line(0.8, 0.45, 0.5, 0.2, 0xFF8A5A2B, 0.025);
    p.line(0.5, 0.2, 0.5, 0.45, 0xFF8A5A2B, 0.02);
    p.rect(0.58, 0.38, 0.06, 0.07, 0xFF2E2118);
  },
  'vg_boat': (p) {
    p.grad(0xFFBDE4EC, 0xFFE4F3F0, 0, 0.35);
    p.rect(0, 0.35, 1, 0.25, 0xFF2A7FC1);
    p.wave(0.45, 0.012, 0xFFFFFFFF, 0.02);
    p.wave(0.53, 0.014, 0xFF6FB8E8, 0.022, phase: 1);
    p.rect(0, 0.6, 1, 0.4, 0xFFEAD08A);
    for (final b in const [
      [0.25, 0xFFD1402F, 0xFFFFF3D6],
      [0.5, 0xFF2D5FB8, 0xFFFFFFFF],
      [0.75, 0xFFF2C230, 0xFFE8E8E8],
    ]) {
      final x = b[0].toDouble();
      p.line(x, 0.82, x, 0.38, 0xFF4A3426, 0.012);
      p.poly([
        [x + 0.01, 0.4],
        [x + 0.01, 0.75],
        [x + 0.1, 0.75],
      ], b[2].toInt());
      p.poly([
        [x - 0.12, 0.8],
        [x + 0.12, 0.8],
        [x + 0.08, 0.92],
        [x - 0.08, 0.92],
      ], b[1].toInt());
    }
  },
  'vg_selfie': (p) {
    p.fill(0xFF3D8A9E);
    for (var i = 0; i < 7; i++) {
      p.wave(
        0.08 + i * 0.15,
        0.04,
        i.isEven ? 0xFF9BD1C8 : 0xFF2B5F8A,
        0.04,
        phase: i * 0.9,
      );
    }
    p.oval(0.5, 1.02, 0.34, 0.26, 0xFF2D5FA8);
    p.oval(0.5, 0.52, 0.2, 0.3, 0xFFF0C9A0);
    p.oval(0.5, 0.72, 0.18, 0.18, 0xFFD9772B);
    p.oval(0.5, 0.62, 0.09, 0.05, 0xFFF0C9A0);
    p.oval(0.5, 0.28, 0.27, 0.07, 0xFFE8C45A);
    p.oval(0.5, 0.2, 0.15, 0.1, 0xFFE8C45A);
    p.rect(0.35, 0.22, 0.3, 0.035, 0xFFB8461E);
    p.circle(0.43, 0.46, 0.022, 0xFF2B5F8A);
    p.circle(0.57, 0.46, 0.022, 0xFF2B5F8A);
    p.line(0.46, 0.56, 0.54, 0.56, 0xFFB8764E, 0.012);
  },
  'vg_field': (p) {
    p.grad(0xFF14306A, 0xFF4B7AB8, 0, 0.55);
    p.wave(0.14, 0.03, 0xFF0C1B3F, 0.07);
    p.wave(0.3, 0.035, 0xFF1D3F8F, 0.06, phase: 1.5);
    p.rect(0, 0.55, 1, 0.45, 0xFFE6B422);
    p.wave(0.65, 0.02, 0xFFC48A1A, 0.04);
    p.wave(0.78, 0.022, 0xFFF2D04F, 0.04, phase: 2);
    p.wave(0.9, 0.02, 0xFFC48A1A, 0.04, phase: 4);
    p.poly([
      [0.47, 0.55],
      [0.53, 0.55],
      [0.7, 1],
      [0.3, 1],
    ], 0xFF4F7A3A);
    p.poly([
      [0.49, 0.55],
      [0.51, 0.55],
      [0.56, 1],
      [0.44, 1],
    ], 0xFFB5442A);
    for (final c in const [
      [0.2, 0.3, 0.05],
      [0.3, 0.22, 0.04],
      [0.45, 0.4, 0.05],
      [0.62, 0.28, 0.05],
      [0.75, 0.38, 0.04],
      [0.85, 0.2, 0.05],
      [0.55, 0.5, 0.035],
    ]) {
      p.crow(c[0] * p.w / p.h, c[1], c[2]);
    }
  },
  'vg_tree': (p) {
    p.grad(0xFF2E5FA0, 0xFF9FCBE0, 0, 0.8);
    p.wave(0.2, 0.04, 0xFFBFD9F2, 0.035);
    p.wave(0.4, 0.04, 0xFF6FA8DC, 0.04, phase: 1.5);
    p.circle(0.85, 0.2, 0.09, 0x55FFE66D);
    p.circle(0.85, 0.2, 0.06, 0xFFFFE66D);
    p.circle(0.87, 0.18, 0.05, 0xFF4A86B8);
    p.poly([
      [0, 0.8],
      [0.2, 0.62],
      [0.45, 0.78],
      [0.7, 0.6],
      [1, 0.78],
      [1, 1],
      [0, 1],
    ], 0xFF3E6B5A);
    p.flame(0.3, 0.02, 1, 0.11, 0xFF1F4D2C);
    p.flame(0.62, 0.15, 1, 0.08, 0xFF1A4326);
    for (var i = 0; i < 5; i++) {
      p.line(
        0.27 + i * 0.012,
        0.25 + i * 0.13,
        0.33,
        0.33 + i * 0.13,
        0xFF3C7A44,
        0.016,
      );
    }
  },

  // ---- 8-bit ----
  'px_mushroom': (p) {
    p.pxFill(0xFF5C94FC);
    p.px(-80, 15, 160, 2, 0xFF2E9E2E);
    p.px(-18, 13, 8, 2, 0xFF2E9E2E);
    p.px(14, 14, 10, 1, 0xFF2E9E2E);
    for (final c in const [-19.0, 12.0]) {
      p.px(c, 3, 7, 1.5, 0xFFFFFFFF);
      p.px(c + 1, 2, 4, 1.5, 0xFFFFFFFF);
    }
    p.px(14, 11, 5, 6, 0xFF00A800);
    p.px(13, 11, 7, 1.6, 0xFF80D010);
    p.px(-17, 6, 3, 3, 0xFFFFA000);
    p.px(-16.2, 6.6, 1.2, 1.8, 0xFF7A3A00);
    p.bricks(3, 0xFFC84C0C, 0xFF000000);
    p.sprite(
      const [
        '....KKKKKK....',
        '..KKRRRRRRKK..',
        '.KRRWWRRWWRRK.',
        'KRRWWWRRWWWRRK',
        'KRRWWWRRWWWRRK',
        'KRRRWRRRRWRRRK',
        '.KKKKKKKKKKKK.',
        '...KKCCCCKK...',
        '..KCCKCCKCCK..',
        '..KCCKCCKCCK..',
        '...KCCCCCCK...',
        '....KKKKKK....',
      ],
      -7,
      5,
      const {
        'K': 0xFF000000,
        'R': 0xFFE8202C,
        'W': 0xFFFFFFFF,
        'C': 0xFFFFDDB0,
      },
    );
  },
  'px_pizza': (p) {
    p.pxFill(0xFF000014);
    p.px(-60, 1.5, 120, 0.6, 0xFF2121DE);
    p.px(-60, 18, 120, 0.6, 0xFF2121DE);
    p.px(-18, 5, 0.6, 10, 0xFF2121DE);
    p.px(18, 5, 0.6, 10, 0xFF2121DE);
    for (var i = 0; i < 4; i++) {
      p.px(8 + i * 3.0, 9.6, 1, 1, 0xFFFFE6C8);
    }
    p.pxDisc(
      -2,
      10,
      6.5,
      0xFFFFD21A,
      skip: (x, y) => x > 0 && y.abs() <= x * 0.75,
    );
    for (final d in const [
      [-4, 7],
      [-1, 12],
      [-5, 11],
      [-1, 7],
    ]) {
      p.px(d[0].toDouble() - 2, d[1].toDouble(), 1.6, 1.6, 0xFFE8202C);
    }
  },
  'px_apple': (p) {
    p.pxFill(0xFF000014);
    p.px(-60, 1.5, 120, 0.6, 0xFF2121DE);
    p.px(-60, 18, 120, 0.6, 0xFF2121DE);
    for (var i = 0; i < 5; i++) {
      p.px(-22 + i * 2.6, 10, 1, 1, 0xFFFFE6C8);
      p.px(10 + i * 2.6, 10, 1, 1, 0xFFFFE6C8);
    }
    p.pxDisc(-3, 12, 4, 0xFFE02020);
    p.pxDisc(3, 12, 4, 0xFFE02020);
    p.px(-5, 10, 1.5, 1.5, 0xFFFFB0B0);
    p.px(1, 10, 1.5, 1.5, 0xFFFFB0B0);
    p.px(-3, 6, 1, 4, 0xFF2E9E2E);
    p.px(3, 6, 1, 4, 0xFF2E9E2E);
    p.px(-3, 6, 7, 1, 0xFF2E9E2E);
    p.px(0, 4, 3, 2, 0xFF2EC82E);
  },
  'px_controller': (p) {
    p.pxFill(0xFF8C8C9C);
    p.px(-17, 4, 34, 12, 0xFFD2D2D2);
    p.px(-17, 4, 34, 0.8, 0xFFFFFFFF);
    p.px(-17, 15.2, 34, 0.8, 0xFF9A9A9A);
    p.px(-15, 6, 30, 8, 0xFF3A3A3A);
    p.px(-15, 6, 30, 1.2, 0xFFD8202C);
    p.px(-13.4, 9.2, 5, 1.8, 0xFF101010);
    p.px(-11.8, 7.6, 1.8, 5, 0xFF101010);
    p.px(-4, 11.2, 2.6, 0.9, 0xFF9A9A9A);
    p.px(-0.5, 11.2, 2.6, 0.9, 0xFF9A9A9A);
    p.pxDisc(8, 10.4, 1.9, 0xFFD8202C);
    p.pxDisc(12.6, 10.4, 1.9, 0xFFD8202C);
  },
  'px_dog': (p) {
    p.pxFill(0xFF9ED8FF);
    p.px(-80, 14, 160, 6, 0xFF3CA024);
    for (var c = -30; c < 30; c += 3) {
      p.px(c.toDouble(), 12.5 + (c % 2 == 0 ? 0 : 0.8), 1, 2, 0xFF2E8C1C);
    }
    p.px(-9, 11.5, 10, 4, 0xFFC87832);
    p.px(-8, 15, 1.6, 2.5, 0xFFC87832);
    p.px(-1, 15, 1.6, 2.5, 0xFFC87832);
    p.px(-12, 10.4, 3, 1.4, 0xFFC87832);
    p.pxDisc(4, 11, 3.2, 0xFFC87832);
    p.px(6, 10.4, 4, 2.6, 0xFFE0A060);
    p.px(9, 10.4, 1.4, 1.4, 0xFF000000);
    p.px(2, 8.4, 2, 4.4, 0xFF7A4A1E);
    p.px(5.4, 9.4, 0.9, 0.9, 0xFF000000);
    p.pxDisc(13, 4, 1.8, 0xFF1E6B3A);
    p.pxDisc(15.2, 3, 1.2, 0xFF1E8C3A);
    p.px(16.2, 3, 1.4, 0.8, 0xFFF0A020);
    p.px(11, 1.8, 3.2, 1.2, 0xFFFFFFFF);
  },
  'px_bricks': (p) {
    p.pxFill(0xFF000000);
    const colours = [
      0xFFD8202C,
      0xFFF07820,
      0xFFC8B400,
      0xFF2EB82E,
      0xFF2E6FE8,
    ];
    for (var r = 0; r < colours.length; r++) {
      for (var c = -24; c < 24; c += 5) {
        p.px(c.toDouble(), 2 + r * 1.5, 4.6, 1.2, colours[r]);
      }
    }
    p.px(-4, 17.4, 8, 1.2, 0xFF3AA0E8);
    p.px(2, 13, 1.2, 1.2, 0xFFFFFFFF);
    p.px(1, 14.4, 1, 1, 0xFF808080);
  },
  'px_ladder': (p) {
    p.pxFill(0xFF000010);
    const girder = 0xFFE0405A;
    for (final y in const [4.0, 9.0, 14.0, 19.0]) {
      final up = y.toInt().isEven ? -1.2 : 1.2;
      p.pxPoly([
        [-60, y - up * 5],
        [60, y + up * 5],
        [60, y + up * 5 + 1.1],
        [-60, y - up * 5 + 1.1],
      ], girder);
    }
    for (final x in const [-12.0, 10.0, -6.0]) {
      final top = x < 0 ? (x == -12.0 ? 9.5 : 4.0) : 14.0;
      p.px(x, top + 1, 0.7, 4.6, 0xFF30D0E0);
      p.px(x + 3, top + 1, 0.7, 4.6, 0xFF30D0E0);
      for (var r = 0.0; r < 4.4; r += 1.4) {
        p.px(x, top + 1.6 + r, 3.7, 0.6, 0xFF30D0E0);
      }
    }
    p.pxDisc(-2, 12.4, 1.8, 0xFFD08030);
    p.px(-3.4, 12.2, 2.8, 0.5, 0xFF7A4A1E);
    p.pxDisc(16, 7.6, 1.8, 0xFFD08030);
  },
  'px_key': (p) {
    p.pxFill(0xFF0B2B1A);
    p.pxDisc(-7, 10, 4.2, 0xFFF8B800, hole: 2.2);
    p.px(-3, 9.3, 14, 1.5, 0xFFF8B800);
    p.px(8, 10.8, 1.8, 3, 0xFFF8B800);
    p.px(5, 10.8, 1.8, 2.2, 0xFFF8B800);
    p.px(-5, 6.6, 3, 0.8, 0xFFFFE890);
    for (var i = 0; i < 3; i++) {
      _heartRow(p, -12 + i * 8.0, 1.2);
    }
  },
  'px_clock': (p) {
    p.pxFill(0xFFB9C7A0);
    p.pxDisc(0, 10, 8.4, 0xFF1E2A1A, hole: 6.6);
    for (final t in const [
      [0, -6],
      [0, 6],
      [-6, 0],
      [6, 0],
    ]) {
      p.px(
        t[0] - 0.5.toDouble(),
        10 + t[1] - 0.5.toDouble(),
        1.2,
        1.2,
        0xFF1E2A1A,
      );
    }
    p.px(-0.4, 5.6, 1, 5, 0xFF1E2A1A);
    p.px(-0.4, 9.6, 4.6, 1, 0xFF1E2A1A);
    p.pxDisc(0, 10, 1, 0xFF1E2A1A);
    p.px(-15, 18, 30, 0.8, 0xFF1E2A1A);
  },
  'px_box': (p) {
    p.pxFill(0xFF0B0B2B);
    p.px(-9, 0, 0.8, 20, 0xFF8A8AA0);
    p.px(8.4, 0, 0.8, 20, 0xFF8A8AA0);
    const stack = ['.....Y..', 'OO..YYB.', 'OPPYBBB.', 'GGPPPRRR'];
    const palette = {
      'Y': 0xFFF8D020,
      'O': 0xFFF08020,
      'P': 0xFFA040E0,
      'B': 0xFF2E6FE8,
      'G': 0xFF2EC82E,
      'R': 0xFFE02020,
    };
    for (var y = 0; y < stack.length; y++) {
      for (var x = 0; x < stack[y].length; x++) {
        final c = palette[stack[y][x]];
        if (c == null) continue;
        p.px(-8 + x * 2.0, 12 + y * 2.0, 2, 2, 0xFF101030);
        p.px(-7.85 + x * 2.0, 12.15 + y * 2.0, 1.7, 1.7, c);
      }
    }
    for (final b in const [
      [3, 0],
      [4, 0],
      [5, 0],
      [4, 1],
    ]) {
      p.px(-8 + b[0] * 2.0, 3 + b[1] * 2.0, 2, 2, 0xFF101030);
      p.px(-7.85 + b[0] * 2.0, 3.15 + b[1] * 2.0, 1.7, 1.7, 0xFFC060F0);
    }
  },
  'px_motorbike': (p) {
    p.pxFill(0xFF58B0F8);
    p.pxPoly(const [
      [-60, 14],
      [-26, 5],
      [-8, 14],
    ], 0xFF48A048);
    p.pxPoly(const [
      [-14, 14],
      [8, 7],
      [30, 14],
    ], 0xFF389038);
    p.px(-80, 14, 160, 6, 0xFFB86020);
    for (var c = -40; c < 40; c += 6) {
      p.px(c.toDouble(), 17, 3, 0.8, 0xFF8A4414);
    }
    p.pxPoly(const [
      [10, 18],
      [18, 14],
      [18, 18],
    ], 0xFF7A3A10);
    p.pxDisc(-6, 15.5, 2.4, 0xFF101010);
    p.pxDisc(1, 15.5, 2.4, 0xFF101010);
    p.pxDisc(-6, 15.5, 1, 0xFFB8B8B8);
    p.pxDisc(1, 15.5, 1, 0xFFB8B8B8);
    p.px(-5.6, 12.6, 6.4, 1.2, 0xFFE02020);
    p.px(-3, 11.2, 3.4, 1.5, 0xFFE02020);
    p.px(0.5, 11.6, 1.6, 0.7, 0xFF808080);
    p.px(-3.6, 8.2, 2.2, 3.8, 0xFF2A5AE0);
    p.pxDisc(-2.4, 7, 1.4, 0xFFF8C898);
    p.px(-3.8, 5.8, 3, 1.4, 0xFFE02020);
    p.px(-1.4, 10.4, 2.4, 0.8, 0xFF2A5AE0);
  },
  'px_coin': (p) {
    p.pxFill(0xFF5C94FC);
    p.bricks(2, 0xFFC84C0C, 0xFF000000);
    for (final x in const [-8.0, -4.0, 0.0, 4.0, 8.0]) {
      p.px(x, 11, 3.4, 3.4, 0xFFFFA000);
      p.px(x + 1.2, 11.8, 1, 1.8, 0xFF7A3A00);
    }
    for (final c in const [
      [-9.0, 6.0],
      [-5.0, 3.4],
      [-1.0, 2.0],
      [3.0, 3.4],
      [7.0, 6.0],
      [-14.0, 8.0],
      [12.0, 8.0],
    ]) {
      p.px(c[0], c[1], 2.2, 3.6, 0xFFF8B800);
      p.px(c[0] + 0.7, c[1] + 0.5, 0.8, 2.6, 0xFFC87800);
      p.px(c[0], c[1], 0.8, 1.2, 0xFFFFE890);
    }
  },
  'px_sky': (p) {
    p.pxFill(0xFF000000);
    const invader = [
      '..K.....K..',
      '...K...K...',
      '..KKKKKKK..',
      '.KK.KKK.KK.',
      'KKKKKKKKKKK',
      'K.KKKKKKK.K',
      'K.K.....K.K',
      '...KK.KK...',
    ];
    for (var r = 0; r < 2; r++) {
      for (var i = 0; i < 5; i++) {
        p.sprite(invader, -20.5 + i * 8.4, 1.5 + r * 5.5, {
          'K': r == 0 ? 0xFF39E639 : 0xFFFFFFFF,
        }, s: 0.65);
      }
    }
    p.sprite(
      const ['.....K.....', '....KKK....', 'KKKKKKKKKKK', 'KKKKKKKKKKK'],
      -5.5,
      15,
      const {'K': 0xFF39E639},
    );
    p.px(-0.3, 11.4, 0.7, 2.4, 0xFFFFFFFF);
    p.px(-80, 19.2, 160, 0.8, 0xFF39E639);
  },
};
