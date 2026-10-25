import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Where everything stands on the stage of the Hall of Fame, for a screen of
/// a given size. The painters and the widgets laid over them (the paintings, the
/// name plates) all read their places from here, so they line up.
class StageLayout {
  const StageLayout(this.size);

  final Size size;

  double get width => size.width;
  double get height => size.height;

  /// Where the back curtain meets the stage floor.
  double get horizon => height * 0.46;

  /// Where the columns stand.
  double get baseY => height * 0.74;
  double get shaftWidth => width * 0.13;
  double get capitalWidth => shaftWidth * 1.8;

  double columnHeight(int rank) =>
      height *
      switch (rank) {
        1 => 0.33,
        2 => 0.25,
        _ => 0.19,
      };

  double centerX(int rank) =>
      width *
      switch (rank) {
        1 => 0.5,
        2 => 0.22,
        _ => 0.78,
      };

  /// The top of the column (its abacus).
  double topY(int rank) => baseY - columnHeight(rank);
}

/// When each part of the opening happens, as fractions of the whole animation:
/// first the curtains part, then the columns are built, third place first.
abstract final class StageTiming {
  static double curtains(double t) =>
      Curves.easeInOutCubic.transform(((t - 0.03) / 0.27).clamp(0.0, 1.0));

  static double _start(int rank) => switch (rank) {
    3 => 0.30,
    2 => 0.42,
    _ => 0.54,
  };

  /// How far the column of [rank] is built: 0 to 1.
  static double column(double t, int rank) =>
      ((t - _start(rank)) / 0.30).clamp(0.0, 1.0);

  /// The painting and the name plate appear once the column is up.
  static double plate(double t, int rank) =>
      ((column(t, rank) - 0.9) / 0.1).clamp(0.0, 1.0);
}

// The look of the app: flat colours from its palette, black outlines, and hard
// black shadows offset down and to the right.
const _ink = Color(0xFF000000);
const _paper = Color(0xFFF8EED2);
const _yellow = Color(0xFFF5D06F);
const _coral = Color(0xFFFF6F61);
const _coralDark = Color(0xFFE5574A);
const _teal = Color(0xFF84D0C8);
const _tealDark = Color(0xFF6FBDB4);

/// How far the hard shadows fall.
const _shadow = Offset(4, 4);

Paint _flat(Color colour) => Paint()
  ..color = colour
  ..isAntiAlias = true;

Paint _line([double width = 2]) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// A shape in the app's style: its hard shadow, the flat colour, a black outline.
void _solid(
  Canvas canvas,
  Path shape,
  Color colour, {
  bool shadow = true,
  double outline = 2,
}) {
  if (shadow) canvas.drawPath(shape.shift(_shadow), _flat(_ink));
  canvas.drawPath(shape, _flat(colour));
  canvas.drawPath(shape, _line(outline));
}

/// The stage: a teal back wall, a yellow plank floor, the spot lights and the three
/// columns, built up as [intro] runs.
class StagePainter extends CustomPainter {
  StagePainter({required this.intro}) : super(repaint: intro);

  final Animation<double> intro;

  static const _courses = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final layout = StageLayout(size);
    final t = intro.value;
    _backdrop(canvas, layout);
    _floor(canvas, layout);
    for (final rank in const [2, 3, 1]) {
      _spot(canvas, layout, rank, StageTiming.column(t, rank));
    }
    for (final rank in const [2, 3, 1]) {
      _column(canvas, layout, rank, StageTiming.column(t, rank));
    }
  }

  // The hall -----------------------------------------------------------------

  void _backdrop(Canvas canvas, StageLayout l) {
    canvas.drawRect(Offset.zero & l.size, _flat(_teal));
    // Flat panels of the back wall, a darker one every other, with black seams.
    const panels = 9;
    final w = l.width / panels;
    for (var i = 0; i < panels; i++) {
      final rect = Rect.fromLTWH(i * w, 0, w, l.horizon);
      if (i.isOdd) canvas.drawRect(rect, _flat(_tealDark));
      canvas.drawLine(rect.topLeft, rect.bottomLeft, _line(1.5));
    }
  }

  void _floor(Canvas canvas, StageLayout l) {
    final floor = Rect.fromLTRB(0, l.horizon, l.width, l.height);
    canvas.drawRect(floor, _flat(_yellow));
    canvas.save();
    canvas.clipRect(floor);
    final seam = _line(1.5);
    final cx = l.width / 2;
    final vanish = l.horizon - l.height * 0.25;
    final scale = (l.horizon - vanish) / (l.height - vanish);
    for (var k = -9; k <= 9; k++) {
      final bottomX = cx + k * l.width * 0.2;
      canvas.drawLine(
        Offset(cx + (bottomX - cx) * scale, l.horizon),
        Offset(bottomX, l.height),
        seam,
      );
    }
    for (var j = 1; j < 9; j++) {
      final y = l.horizon + (l.height - l.horizon) * math.pow(j / 9, 1.8);
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(l.width, y.toDouble()),
        seam,
      );
    }
    canvas.restore();
    // The edge of the stage: a coral band between two black lines.
    final band = Rect.fromLTWH(0, l.horizon - 5, l.width, 10);
    canvas.drawRect(band, _flat(_coral));
    canvas.drawLine(band.topLeft, band.topRight, _line(2.5));
    canvas.drawLine(band.bottomLeft, band.bottomRight, _line(2.5));
  }

  /// A cone of light from above onto a column, and the pool it makes on the floor:
  /// flat paper colour, see-through.
  void _spot(Canvas canvas, StageLayout l, int rank, double built) {
    final glow = Curves.easeOut.transform(built);
    if (glow <= 0) return;
    final x = l.centerX(rank);
    final cone = Path()
      ..moveTo(x - l.width * 0.03, 0)
      ..lineTo(x + l.width * 0.03, 0)
      ..lineTo(x + l.width * 0.18, l.baseY)
      ..lineTo(x - l.width * 0.18, l.baseY)
      ..close();
    canvas.drawPath(cone, _flat(_paper.withValues(alpha: 0.35 * glow)));
    // A faint pool, no outline, narrow enough not to reach the next column's.
    final pool = Rect.fromCenter(
      center: Offset(x, l.baseY + 2),
      width: l.width * 0.26,
      height: l.height * 0.035,
    );
    canvas.drawOval(pool, _flat(_paper.withValues(alpha: 0.3 * glow)));
  }

  // A column ------------------------------------------------------------------

  void _column(Canvas canvas, StageLayout l, int rank, double p) {
    if (p <= 0) return;
    final cx = l.centerX(rank);
    final h = l.columnHeight(rank);
    final base = l.baseY;
    final sw = l.shaftWidth;
    final cw = l.capitalWidth;

    // Heights of the parts, bottom to top.
    final plinthH = h * 0.10;
    final footH = h * 0.06;
    final shaftH = h * 0.58;
    final neckH = h * 0.03;
    final capH = h * 0.17;
    final abacusH = h * 0.06;
    final shaftBottom = base - plinthH - footH;
    final shaftTop = shaftBottom - shaftH;

    // 1. The plinth and the foot rise out of the floor.
    final rise = Curves.easeOutCubic.transform((p / 0.15).clamp(0.0, 1.0));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, l.width, base + _shadow.dy));
    canvas.translate(0, (1 - rise) * (plinthH + footH + _shadow.dy));
    _block(
      canvas,
      Rect.fromCenter(
        center: Offset(cx, base - plinthH / 2),
        width: sw * 1.75,
        height: plinthH,
      ),
      _paper,
    );
    _block(
      canvas,
      Rect.fromCenter(
        center: Offset(cx, base - plinthH - footH / 2),
        width: sw * 1.4,
        height: footH,
      ),
      _yellow,
    );
    canvas.restore();

    // 2. The shaft is laid in courses of bricks, bottom to top: first every
    // brick's shadow, then the bricks, so no shadow falls across a brick.
    final courseH = shaftH / _courses;
    final bricks = <(Rect, double)>[];
    for (var c = 0; c < _courses; c++) {
      final start = 0.15 + c * (0.70 / _courses);
      final q = ((p - start) / (0.70 / _courses * 2.2)).clamp(0.0, 1.0);
      if (q <= 0) continue;
      final eased = Curves.easeOutCubic.transform(q);
      final y = shaftBottom - (c + 1) * courseH;
      // Two bricks a course; the joint moves from course to course.
      final cut = sw * (c.isEven ? 0.5 : 0.36);
      for (final (brick, from) in [
        (Rect.fromLTWH(cx - sw / 2, y, cut, courseH), -1.0),
        (Rect.fromLTWH(cx - sw / 2 + cut, y, sw - cut, courseH), 1.0),
      ]) {
        final slide = Offset(from * (1 - eased) * sw * 0.7, -(1 - eased) * 12);
        bricks.add((brick.shift(slide), eased));
      }
    }
    for (final (rect, alpha) in bricks) {
      canvas.drawRect(
        rect.shift(_shadow),
        _flat(_ink.withValues(alpha: alpha)),
      );
    }
    for (final (rect, alpha) in bricks) {
      canvas.drawRect(rect, _flat(_paper.withValues(alpha: alpha)));
      canvas.drawRect(rect, _line(1.5)..color = _ink.withValues(alpha: alpha));
    }

    // 3. The neck, the capital and the abacus come down on top.
    final qc = ((p - 0.85) / 0.15).clamp(0.0, 1.0);
    if (qc > 0) {
      final drop = -(1 - Curves.easeOutBack.transform(qc)) * h * 0.45;
      canvas.save();
      canvas.translate(0, drop);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, l.width, l.height),
        Paint()..color = Color.fromRGBO(0, 0, 0, qc),
      );
      _block(
        canvas,
        Rect.fromCenter(
          center: Offset(cx, shaftTop - neckH / 2),
          width: sw * 1.15,
          height: neckH,
        ),
        _yellow,
      );
      _capital(canvas, cx, shaftTop - neckH, capH, sw * 1.15, cw);
      _block(
        canvas,
        Rect.fromCenter(
          center: Offset(cx, shaftTop - neckH - capH - abacusH / 2),
          width: cw * 1.08,
          height: abacusH,
        ),
        _paper,
      );
      canvas.restore();
      canvas.restore();
    }
  }

  void _block(Canvas canvas, Rect rect, Color colour) {
    _solid(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2))),
      colour,
    );
  }

  /// A yellow capital: a flared body, leaves in the middle and a scroll at each
  /// corner, all in black lines.
  void _capital(
    Canvas canvas,
    double cx,
    double bottom,
    double height,
    double bottomWidth,
    double topWidth,
  ) {
    final top = bottom - height;
    final body = Path()
      ..moveTo(cx - bottomWidth / 2, bottom)
      ..quadraticBezierTo(
        cx - bottomWidth * 0.62,
        bottom - height * 0.55,
        cx - topWidth / 2,
        top,
      )
      ..lineTo(cx + topWidth / 2, top)
      ..quadraticBezierTo(
        cx + bottomWidth * 0.62,
        bottom - height * 0.55,
        cx + bottomWidth / 2,
        bottom,
      )
      ..close();
    _solid(canvas, body, _yellow);
    final line = _line(1.5);
    for (var i = -2; i <= 2; i++) {
      final petal = Path()
        ..moveTo(cx + i * bottomWidth * 0.06, bottom)
        ..quadraticBezierTo(
          cx + i * bottomWidth * 0.34,
          bottom - height * 0.55,
          cx + i * bottomWidth * 0.2,
          top + height * 0.25,
        );
      canvas.drawPath(petal, line);
    }
    final radius = height * 0.3;
    for (final side in const [-1.0, 1.0]) {
      final centre = Offset(
        cx + side * (topWidth / 2 - radius * 0.7),
        top + radius * 0.75,
      );
      _solid(
        canvas,
        Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
        _coral,
        shadow: false,
      );
      canvas.drawCircle(centre, radius * 0.55, line);
      canvas.drawCircle(centre, radius * 0.18, _flat(_ink));
    }
  }

  @override
  bool shouldRepaint(covariant StagePainter old) => old.intro != intro;
}

/// The curtains of a stage, in the app's coral: two panels that part from the
/// middle and are gathered to the sides with black ropes and yellow tassels, under
/// a scalloped valance. They open as [intro] runs.
class CurtainPainter extends CustomPainter {
  CurtainPainter({required this.intro}) : super(repaint: intro);

  final Animation<double> intro;

  static const _folds = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final open = StageTiming.curtains(intro.value);
    final tie = size.height * 0.60;
    final reach = size.width / 2 * 0.90;

    // How far the inner edge of a panel is pulled from the middle at height [y]:
    // little at the top, most at the rope, a little less below it.
    double pull(double y) {
      final shape = y < tie
          ? 0.45 + 0.55 * Curves.easeInOut.transform((y / tie).clamp(0.0, 1.0))
          : 1.0 - 0.1 * ((y - tie) / (size.height - tie)).clamp(0.0, 1.0);
      return reach * open * shape;
    }

    for (final side in const [-1.0, 1.0]) {
      _panel(canvas, size, side, pull);
    }
    if (open > 0.02) {
      for (final side in const [-1.0, 1.0]) {
        _rope(canvas, size, side, pull(tie), tie, open);
      }
    }
    _valance(canvas, size);
  }

  void _panel(
    Canvas canvas,
    Size size,
    double side,
    double Function(double) pull,
  ) {
    const rows = 28;
    final mid = size.width / 2;
    // The x of fold line [i] at height [y]: from the screen edge (0) to the inner
    // edge.
    double lineX(int i, double y) {
      final inner = mid + side * pull(y);
      final edge = side < 0 ? 0.0 : size.width;
      // Half a pixel over the middle, so the two panels meet when shut.
      final innerX = inner + side * 0.5;
      return edge + (innerX - edge) * (i / _folds);
    }

    Path strip(int from, int to) {
      final path = Path();
      for (var r = 0; r <= rows; r++) {
        final y = size.height * r / rows;
        final x = lineX(from, y);
        r == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      for (var r = rows; r >= 0; r--) {
        final y = size.height * r / rows;
        path.lineTo(lineX(to, y), y);
      }
      return path..close();
    }

    // The whole panel in coral, every other fold a shade darker, black lines
    // between the folds and a thick one down the inner edge.
    canvas.drawPath(strip(0, _folds), _flat(_coral));
    for (var i = 1; i < _folds; i += 2) {
      canvas.drawPath(strip(i, i + 1), _flat(_coralDark));
    }
    for (var i = 1; i <= _folds; i++) {
      final fold = Path();
      for (var r = 0; r <= rows; r++) {
        final y = size.height * r / rows;
        final x = lineX(i, y);
        r == 0 ? fold.moveTo(x, y) : fold.lineTo(x, y);
      }
      canvas.drawPath(fold, _line(i == _folds ? 3 : 1.5));
    }
  }

  /// The black rope round a gathered curtain and its yellow tassel.
  void _rope(
    Canvas canvas,
    Size size,
    double side,
    double pulled,
    double y,
    double open,
  ) {
    final fade = ((open - 0.1) / 0.3).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final mid = size.width / 2;
    final inner = mid + side * pulled;
    final edge = side < 0 ? 0.0 : size.width;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, fade),
    );
    final rope = Path()
      ..moveTo(edge, y - size.height * 0.03)
      ..quadraticBezierTo(
        (edge + inner) / 2,
        y + size.height * 0.035,
        inner,
        y,
      );
    canvas.drawPath(rope, _line(4)..strokeCap = StrokeCap.round);
    final knot = Offset(inner + side * 6, y);
    final tassel = Path()
      ..moveTo(knot.dx - 6, y + 8)
      ..lineTo(knot.dx + 6, y + 8)
      ..lineTo(knot.dx + 9, y + 38)
      ..lineTo(knot.dx - 9, y + 38)
      ..close();
    _solid(canvas, tassel, _yellow, shadow: false);
    for (var k = -1; k <= 1; k++) {
      canvas.drawLine(
        Offset(knot.dx + k * 4, y + 16),
        Offset(knot.dx + k * 4, y + 38),
        _line(1.5),
      );
    }
    _solid(
      canvas,
      Path()..addOval(Rect.fromCircle(center: knot, radius: 7)),
      _yellow,
      shadow: false,
    );
    canvas.restore();
  }

  /// A band across the top with a scalloped edge: coral under a yellow rail, with
  /// a hard shadow.
  void _valance(Canvas canvas, Size size) {
    final band = size.height * 0.05;
    const scallops = 7;
    final width = size.width / scallops;
    final path = Path()
      ..moveTo(-4, -4)
      ..lineTo(size.width + 4, -4)
      ..lineTo(size.width + 4, band);
    for (var i = scallops - 1; i >= 0; i--) {
      path.quadraticBezierTo(
        width * (i + 0.5),
        band + band * 0.9,
        width * i,
        band,
      );
    }
    path
      ..lineTo(-4, band)
      ..close();
    _solid(canvas, path, _coral, outline: 2.5);
    final rail = Rect.fromLTWH(-4, -4, size.width + 8, band * 0.28 + 4);
    canvas.drawRect(rail, _flat(_yellow));
    canvas.drawLine(rail.bottomLeft, rail.bottomRight, _line(2.5));
  }

  @override
  bool shouldRepaint(covariant CurtainPainter old) => old.intro != intro;
}
