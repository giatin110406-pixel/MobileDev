import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';

/// The colours of the exhibition hall: the app's own palette, flat, with black
/// outlines.
abstract final class CorridorColors {
  static const ink = Color(0xFF1A1A1A);
  static const wall = Color(0xFF4ECDC4); // teal
  static const wallFar = Color(0xFF3DAFA7);
  static const trim = Color(0xFFFFE66D); // skirting and crown moulding
  static const ceiling = Color(0xFFFDF2E9);
  static const floor = Color(0xFFECE6C2); // paper
  static const floorAlt = Color(0xFFD9D2A6);
  static const runner = Color(0xFFFF6B6B);
  static const runnerBorder = Color(0xFF1A1A1A);
  static const runnerMotif = Color(0xFFFFE66D);
  static const blankCanvas = Color(0xFFFDF2E9);
  static const frame = Color(0xFF1A1A1A);
  static const mat = Color(0xFFFDF2E9);
  static const light = Color(0xFFFFE66D);
  static const doorLeaf = Color(0xFFF7A072); // orange
}

/// The colours of one hall: the Gallery and the Hall of Fame look different.
class CorridorStyle {
  const CorridorStyle({
    required this.wall,
    required this.wallFar,
    required this.ceiling,
    required this.floor,
    required this.floorFar,
    required this.runner,
    required this.runnerBorder,
    required this.runnerMotif,
    this.trim = CorridorColors.trim,
    this.ceilingLights = true,
    this.roundMotif = false,
    this.doorway = false,
  });

  final Color wall;

  /// The wall in the distance, one step darker.
  final Color wallFar;
  final Color ceiling;
  final Color floor;

  /// The other colour of the chequered floor.
  final Color floorFar;
  final Color runner;
  final Color runnerBorder;
  final Color runnerMotif;
  final Color trim;

  /// The ceiling lamps (the Hall of Fame has spot lights instead).
  final bool ceilingLights;

  /// Circles on the runner instead of diamonds.
  final bool roundMotif;

  /// A door in the wall at the far end of the corridor.
  final bool doorway;

  /// The exhibition corridor: teal walls, a paper floor, a pink runner.
  static const gallery = CorridorStyle(
    wall: CorridorColors.wall,
    wallFar: CorridorColors.wallFar,
    ceiling: CorridorColors.ceiling,
    floor: CorridorColors.floor,
    floorFar: CorridorColors.floorAlt,
    runner: CorridorColors.runner,
    runnerBorder: CorridorColors.runnerBorder,
    runnerMotif: CorridorColors.runnerMotif,
    roundMotif: true,
    doorway: true,
  );
}

/// How one frame is dressed: its wood, its mat, a spot light and a name plate.
class FrameDecor {
  const FrameDecor({
    this.frame = CorridorColors.frame,
    this.mat = CorridorColors.mat,
    this.plaque = const [],
    this.spot = false,
  });

  final Color frame;
  final Color mat;

  /// Up to two short lines for the brass plate under the frame.
  final List<String> plaque;
  final bool spot;
}

const _frameLooks = [
  FrameDecor(frame: Color(0xFF1A1A1A)), // ink
  FrameDecor(frame: Color(0xFFFFE66D)), // yellow
  FrameDecor(frame: Color(0xFFFF6B6B)), // pink
  FrameDecor(frame: Color(0xFFA388EE)), // purple
  FrameDecor(frame: Color(0xFFF7A072)), // orange
];

/// The colour and mat of a Gallery frame, from the number the layout gave it.
FrameDecor galleryFrameLook(int style) =>
    _frameLooks[style % _frameLooks.length];

/// Draws the corridor with one vanishing point, frames on both walls, and the
/// pictures on the frames in real perspective. It repaints when the camera
/// moves or a picture finishes decoding; nothing is rebuilt per frame.
///
/// The room is drawn in flat colours with black outlines. The paintings and the
/// name plates are drawn last, on top.
///
/// [lite] drops the chequered floor, shadows and distance shading for slow phones.
class CorridorPainter extends CustomPainter {
  CorridorPainter({
    required this.camera,
    required this.entries,
    required this.slots,
    required this.cache,
    this.lite = false,
    this.style = CorridorStyle.gallery,
    this.decorOf,
    this.endZ,
  }) : super(repaint: Listenable.merge([camera, cache]));

  final ValueListenable<double> camera;
  final List<GalleryEntry> entries;
  final List<FrameSlot> slots;
  final EntryImageCache cache;
  final bool lite;
  final CorridorStyle style;

  /// How to dress each frame (null: plain frames, as in the Gallery).
  final FrameDecor Function(GalleryEntry entry)? decorOf;

  /// Where the corridor ends (null: it does not, as far as the eye can see).
  final double? endZ;

  final Map<String, Color> _averages = {};
  final Map<String, TextPainter> _plaques = {};

  Color _average(GalleryEntry entry) =>
      _averages[entry.id] ??= Color(averageArgb(entry));

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  static Paint _outline(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cameraZ = camera.value;
    final view = Projection(size, cameraZ);
    canvas.clipRect(Offset.zero & size);

    final overlay = <void Function(Canvas)>[];
    _hall(canvas, size, view);
    _runner(canvas, view);
    _lights(canvas, view);
    // The end wall hides the floor, runner and lamps that would lie beyond it.
    _end(canvas, view);
    for (final slot in visibleSlots(slots, cameraZ)) {
      _frame(canvas, view, slot, overlay);
    }
    // The paintings and plates go on top.
    for (final draw in overlay) {
      draw(canvas);
    }
  }

  // The hall -----------------------------------------------------------------

  Path _poly(List<Offset?> points) {
    final path = Path();
    var first = true;
    for (final point in points) {
      if (point == null) continue;
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _hall(Canvas canvas, Size size, Projection view) {
    final z0 = view.cameraZ + 0.5;
    final z1 = view.cameraZ + Corridor.far;
    const wx = Corridor.wallX;
    const top = Corridor.ceilingY;
    const bottom = Corridor.floorY;
    const ink = CorridorColors.ink;

    Offset p(double x, double y, double z) => view.point(x, y, z)!;

    // The four surfaces between depths [a] and [b].
    Path surface(int kind, double a, double b) => switch (kind) {
      0 => _poly([
        p(-wx, top, a),
        p(wx, top, a),
        p(wx, top, b),
        p(-wx, top, b),
      ]),
      1 => _poly([
        p(-wx, bottom, a),
        p(wx, bottom, a),
        p(wx, bottom, b),
        p(-wx, bottom, b),
      ]),
      2 => _poly([
        p(-wx, top, a),
        p(-wx, bottom, a),
        p(-wx, bottom, b),
        p(-wx, top, b),
      ]),
      _ => _poly([
        p(wx, top, a),
        p(wx, bottom, a),
        p(wx, bottom, b),
        p(wx, top, b),
      ]),
    };

    // Behind everything: the dark end of the corridor.
    canvas.drawRect(Offset.zero & size, _fill(style.wallFar));

    final colours = [style.ceiling, style.floor, style.wall, style.wall];
    for (var k = 0; k < 4; k++) {
      canvas.drawPath(surface(k, z0, z1), _fill(colours[k]));
    }

    // A chequered floor.
    if (!lite) {
      final dark = _fill(style.floorFar);
      final first = z0.floorToDouble();
      for (var z = first; z < z1; z += 1) {
        final a = math.max(z, z0);
        for (var c = -2; c < 2; c++) {
          if ((z.round() + c).isOdd) continue;
          canvas.drawPath(
            _poly([
              p(c * 0.8, bottom, a),
              p((c + 1) * 0.8, bottom, a),
              p((c + 1) * 0.8, bottom, z + 1),
              p(c * 0.8, bottom, z + 1),
            ]),
            dark,
          );
        }
      }
    }

    // Skirting boards and crown moulding, flat colour between black lines.
    final trim = _fill(style.trim);
    for (final side in const [-1.0, 1.0]) {
      final x = side * wx;
      canvas.drawPath(
        _poly([
          p(x, bottom - 0.3, z0),
          p(x, bottom, z0),
          p(x, bottom, z1),
          p(x, bottom - 0.3, z1),
        ]),
        trim,
      );
      canvas.drawPath(
        _poly([
          p(x, top, z0),
          p(x, top + 0.25, z0),
          p(x, top + 0.25, z1),
          p(x, top, z1),
        ]),
        trim,
      );
    }

    // Stepped shading toward the far end: two darker bands.
    if (!lite) {
      final bands = [
        (from: view.cameraZ + 14, to: view.cameraZ + 24, alpha: 0x26),
        (from: view.cameraZ + 24, to: z1, alpha: 0x4D),
      ];
      for (final band in bands) {
        for (var k = 0; k < 4; k++) {
          canvas.drawPath(
            surface(k, band.from, band.to),
            _fill(ink.withAlpha(band.alpha)),
          );
        }
      }
    }

    // The black outlines where wall, floor and ceiling meet, and round the trim.
    final line = _outline(ink);
    for (final side in const [-1.0, 1.0]) {
      final x = side * wx;
      for (final y in [top, top + 0.25, bottom - 0.3, bottom]) {
        canvas.drawLine(p(x, y, z0), p(x, y, z1), line);
      }
    }
  }

  void _runner(Canvas canvas, Projection view) {
    const bottom = Corridor.floorY;
    const half = 0.75;
    final z0 = view.cameraZ + 0.5;
    final z1 = view.cameraZ + Corridor.far;
    Offset p(double x, double z) => view.point(x, bottom, z)!;

    canvas.drawPath(
      _poly([p(-half, z0), p(half, z0), p(half, z1), p(-half, z1)]),
      _fill(style.runner),
    );
    // A thick black border along both edges.
    final border = _fill(style.runnerBorder);
    for (final side in const [-1.0, 1.0]) {
      final outer = side * half;
      final inner = side * (half - 0.12);
      canvas.drawPath(
        _poly([p(inner, z0), p(outer, z0), p(outer, z1), p(inner, z1)]),
        border,
      );
    }
    if (lite) return;
    // A motif in the middle of every metre.
    final motif = _fill(style.runnerMotif);
    final outline = _outline(style.runnerBorder);
    final first = view.cameraZ.floorToDouble() + 1;
    for (var z = first; z < view.cameraZ + 22; z += 1) {
      final centre = z + 0.5;
      if (centre - view.cameraZ < Corridor.near) continue;
      final Path shape;
      if (style.roundMotif) {
        shape = _circleOnFloor(view, 0, centre, 0.3);
      } else {
        shape = _poly([
          view.point(0, bottom, centre - 0.32),
          view.point(0.32, bottom, centre),
          view.point(0, bottom, centre + 0.32),
          view.point(-0.32, bottom, centre),
        ]);
      }
      canvas.drawPath(shape, motif);
      canvas.drawPath(shape, outline);
    }
  }

  /// A circle lying on the floor, as the visitor sees it (an ellipse).
  Path _circleOnFloor(Projection view, double x, double z, double radius) {
    final points = <Offset?>[
      for (var i = 0; i < 16; i++)
        view.point(
          x + radius * math.cos(i * math.pi * 2 / 16),
          Corridor.floorY,
          z + radius * math.sin(i * math.pi * 2 / 16),
        ),
    ];
    return _poly(points);
  }

  void _lights(Canvas canvas, Projection view) {
    if (!style.ceilingLights) return;
    const top = Corridor.ceilingY;
    const spacing = 2.6;
    final first = (view.cameraZ / spacing).floor() * spacing + spacing;
    for (var z = first; z < view.cameraZ + Corridor.far; z += spacing) {
      if (z - view.cameraZ < 0.8) continue;
      // The lamp: a small square in the ceiling, yellow with a black edge.
      final lamp = <Offset?>[
        view.point(-0.2, top, z - 0.2),
        view.point(0.2, top, z - 0.2),
        view.point(0.2, top, z + 0.2),
        view.point(-0.2, top, z + 0.2),
      ];
      if (lamp.any((c) => c == null)) continue;
      final shape = _poly(lamp);
      canvas.drawPath(shape, _fill(CorridorColors.light));
      canvas.drawPath(shape, _outline(CorridorColors.ink));
    }
  }

  /// The far end: a wall with a shut door in it. Far away it is only a dot at
  /// the vanishing point.
  void _end(Canvas canvas, Projection view) {
    final end = endZ;
    if (end == null) return;
    const wx = Corridor.wallX;
    final distance = end - view.cameraZ;
    if (distance < Corridor.near + 0.3) return;
    Offset? at(double x, double y, double z) => view.point(x, y, z);

    if (distance <= Corridor.far) {
      final corners = [
        at(-wx, Corridor.ceilingY, end),
        at(wx, Corridor.ceilingY, end),
        at(wx, Corridor.floorY, end),
        at(-wx, Corridor.floorY, end),
      ];
      if (corners.any((c) => c == null)) return;
      canvas.drawPath(_poly(corners), _fill(style.wall));
      canvas.drawPath(_poly(corners), _outline(CorridorColors.ink));
    }
    if (!style.doorway) return;
    // Seen from afar the door sits just inside the fog.
    final z = math.min(end, view.cameraZ + Corridor.far - 1);
    List<Offset?> rect(double x0, double x1, double y0, double y1) => [
      at(x0, y0, z),
      at(x1, y0, z),
      at(x1, y1, z),
      at(x0, y1, z),
    ];
    final casing = rect(-0.95, 0.95, -1.12, Corridor.floorY);
    final leaf = rect(-0.8, 0.8, -1.0, Corridor.floorY);
    if (casing.any((c) => c == null) || leaf.any((c) => c == null)) return;
    // A shut door: black frame, a coloured leaf with two panels and a knob.
    canvas.drawPath(_poly(casing), _fill(CorridorColors.ink));
    canvas.drawPath(_poly(leaf), _fill(CorridorColors.doorLeaf));
    final line = _outline(CorridorColors.ink);
    for (final panel in [
      rect(-0.55, 0.55, -0.8, 0.0),
      rect(-0.55, 0.55, 0.25, 1.25),
    ]) {
      if (panel.any((c) => c == null)) continue;
      canvas.drawPath(_poly(panel), line);
    }
    final knob = at(0.55, 0.55, z);
    final knobSide = at(0.67, 0.55, z);
    if (knob != null && knobSide != null) {
      final radius = math.max(1.5, (knobSide - knob).distance);
      canvas.drawCircle(knob, radius, _fill(CorridorColors.light));
      canvas.drawCircle(knob, radius, line);
    }
  }

  // Frames --------------------------------------------------------------------

  void _frame(
    Canvas canvas,
    Projection view,
    FrameSlot slot,
    List<void Function(Canvas)> overlay,
  ) {
    final outer = view.wallQuad(slot);
    if (outer == null) return;
    final depth = slot.z0 - view.cameraZ;
    final fade = depth <= 18
        ? 1.0
        : (1 - (depth - 18) / (Corridor.far - 18)).clamp(0.0, 1.0);
    final alpha = (fade * 255).round();
    const ink = CorridorColors.ink;

    final entry = !slot.isBlank && slot.index < entries.length
        ? entries[slot.index]
        : null;
    final decor = entry != null && decorOf != null
        ? decorOf!(entry)
        : galleryFrameLook(slot.style);
    if (entry != null && decor.spot && !lite) _spot(canvas, view, slot, alpha);

    // A hard black shadow, down and a little behind the frame.
    if (!lite) {
      final shadow = view.wallQuad(
        FrameSlot(
          index: -1,
          side: slot.side,
          z0: slot.z0 + 0.05,
          z1: slot.z1 + 0.05,
          yTop: slot.yTop + 0.08,
          yBottom: slot.yBottom + 0.08,
        ),
      );
      if (shadow != null) {
        canvas.drawPath(_poly(shadow), _fill(ink.withAlpha(alpha)));
      }
    }
    final frame = _poly(outer);
    canvas.drawPath(frame, _fill(decor.frame.withAlpha(alpha)));
    canvas.drawPath(frame, _outline(ink.withAlpha(alpha)));
    final mat = view.wallQuad(slot, inset: 0.06);
    if (mat == null) return;
    canvas.drawPath(_poly(mat), _fill(decor.mat.withAlpha(alpha)));
    canvas.drawPath(_poly(mat), _outline(ink.withAlpha(alpha)));

    if (entry == null) {
      // A blank canvas, waiting for a painting.
      final canvasQuad = view.wallQuad(slot, inset: 0.13);
      if (canvasQuad == null) return;
      canvas.drawPath(
        _poly(canvasQuad),
        _fill(CorridorColors.blankCanvas.withAlpha(alpha)),
      );
      if (!lite) {
        canvas.drawPath(_poly(canvasQuad), _outline(ink.withAlpha(alpha)));
      }
      return;
    }

    final picture = view.artQuad(slot);
    if (picture == null) return;
    if (decor.plaque.isNotEmpty && depth < 9) {
      overlay.add((c) => _plate(c, view, slot, entry, decor.plaque));
    }

    final onScreenWidth = (picture[1] - picture[0]).distance;
    final image = onScreenWidth < 3 ? null : cache.peek(entry.id);
    if (onScreenWidth >= 3 && image == null) {
      cache.load(entry); // starts decoding; the cache repaints when it is done
    }
    if (image == null) {
      // Too far to see the detail, or not decoded yet: its average colour.
      canvas.drawPath(_poly(picture), _fill(_average(entry).withAlpha(alpha)));
      canvas.drawPath(_poly(picture), _outline(ink.withAlpha(alpha)));
      return;
    }
    overlay.add((c) {
      c.save();
      c.transform(unitSquareToQuad(picture).storage);
      c.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = Color.fromARGB(alpha, 255, 255, 255),
      );
      c.restore();
      c.drawPath(_poly(picture), _outline(ink.withAlpha(alpha)));
    });
  }

  /// A beam of light from the ceiling onto the painting, flat and see-through.
  void _spot(Canvas canvas, Projection view, FrameSlot slot, int alpha) {
    final x = slot.side * Corridor.wallX;
    final mid = (slot.z0 + slot.z1) / 2;
    final half = slot.size * 0.75;
    final corners = [
      view.point(x, Corridor.ceilingY, mid - 0.15),
      view.point(x, Corridor.ceilingY, mid + 0.15),
      view.point(x, slot.yBottom + 0.5, mid + half),
      view.point(x, slot.yBottom + 0.5, mid - half),
    ];
    if (corners.any((c) => c == null)) return;
    canvas.drawPath(
      _poly(corners),
      _fill(Color.fromARGB((70 * alpha / 255).round(), 255, 230, 109)),
    );
  }

  /// A plate under the frame, with the group, the week and the theme.
  void _plate(
    Canvas canvas,
    Projection view,
    FrameSlot slot,
    GalleryEntry entry,
    List<String> lines,
  ) {
    final x = slot.side * Corridor.wallX;
    final mid = (slot.z0 + slot.z1) / 2;
    final half = slot.size * 0.38;
    final top = slot.yBottom + 0.12;
    final bottom = top + 0.34;
    final near = slot.side < 0 ? mid - half : mid + half;
    final far = slot.side < 0 ? mid + half : mid - half;
    final corners = [
      view.point(x, top, near),
      view.point(x, top, far),
      view.point(x, bottom, far),
      view.point(x, bottom, near),
    ];
    if (corners.any((c) => c == null)) return;
    final quad = [for (final c in corners) c!];

    final text = _plaques.putIfAbsent(entry.id, () {
      return TextPainter(
        text: TextSpan(
          children: [
            for (var i = 0; i < lines.length; i++)
              TextSpan(
                text: i == 0 ? lines[i] : '\n${lines[i]}',
                style: TextStyle(
                  color: CorridorColors.ink,
                  fontFamily: NeoFont.display,
                  fontSize: i == 0 ? 26 : 20,
                  fontWeight: i == 0 ? FontWeight.w900 : FontWeight.w700,
                  height: 1.15,
                ),
              ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: 340);
    });

    canvas.save();
    canvas.transform(unitSquareToQuad(quad).storage);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      _fill(CorridorColors.light),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0.01, 0.03, 0.98, 0.94),
      Paint()
        ..color = CorridorColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.03,
    );
    // The text was laid out in pixels. One scale for both directions keeps the
    // letters undistorted; the plate is plateWidth x plateHeight metres, and the
    // unit square it is drawn on is stretched to that.
    final plateWidth = 2 * half;
    const plateHeight = 0.34;
    final f = math.min(
      0.9 * plateWidth / text.width,
      0.8 * plateHeight / text.height,
    );
    canvas.translate(
      (1 - f * text.width / plateWidth) / 2,
      (1 - f * text.height / plateHeight) / 2,
    );
    canvas.scale(f / plateWidth, f / plateHeight);
    text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CorridorPainter old) =>
      old.slots != slots ||
      old.entries != entries ||
      old.lite != lite ||
      old.style != style ||
      old.camera != camera;

  /// Kept for tests: how many frames would be drawn at [cameraZ].
  static int framesAt(List<FrameSlot> slots, double cameraZ) =>
      visibleSlots(slots, cameraZ).length;

  static double clampCamera(double z, List<FrameSlot> slots) =>
      z.clamp(0.0, math.max(0.0, corridorLength(slots) - 4));
}
