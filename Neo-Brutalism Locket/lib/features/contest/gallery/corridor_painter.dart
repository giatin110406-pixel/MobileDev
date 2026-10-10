import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';

/// The colours of the exhibition hall.
abstract final class CorridorColors {
  static const wall = Color(0xFF53656F); // grey-blue
  static const wallFar = Color(0xFF7B8D97);
  static const trim = Color(0xFFEDEAE0); // skirting and crown moulding
  static const ceiling = Color(0xFFE6E3DA);
  static const floor = Color(0xFF1D1410); // dark polished wood
  static const plank = Color(0x33000000);
  static const runner = Color(0xFFDCCBA3); // a pale runner with a dark border
  static const runnerBorder = Color(0xFF5B4630);
  static const runnerMotif = Color(0xFFC2A56E);
  static const blankCanvas = Color(0xFFF1EEE6);
  static const frame = Color(0xFF17110E);
  static const mat = Color(0xFFF5F2E9);
  static const light = Color(0xFFFFF6D6);
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
    this.ceilingLights = true,
    this.roundMotif = false,
    this.doorway = false,
  });

  final Color wall;
  final Color wallFar;
  final Color ceiling;
  final Color floor;
  final Color floorFar;
  final Color runner;
  final Color runnerBorder;
  final Color runnerMotif;

  /// The recessed ceiling lights (the Hall of Fame has spot lights instead).
  final bool ceilingLights;

  /// Circles on the runner instead of diamonds.
  final bool roundMotif;

  /// A bright doorway at the far end of the corridor.
  final bool doorway;

  /// The exhibition corridor: grey-blue walls, dark wood, a pale runner.
  static const gallery = CorridorStyle(
    wall: CorridorColors.wall,
    wallFar: CorridorColors.wallFar,
    ceiling: CorridorColors.ceiling,
    floor: CorridorColors.floor,
    floorFar: Color(0xFF3B2A20),
    runner: CorridorColors.runner,
    runnerBorder: CorridorColors.runnerBorder,
    runnerMotif: CorridorColors.runnerMotif,
    roundMotif: true,
    doorway: true,
  );

  /// The Hall of Fame: deep night-blue walls, black floor, a royal runner.
  static const hall = CorridorStyle(
    wall: Color(0xFF1B2433),
    wallFar: Color(0xFF2E3A4F),
    ceiling: Color(0xFF12161F),
    floor: Color(0xFF0E0B0A),
    floorFar: Color(0xFF241A14),
    runner: Color(0xFF3B1450),
    runnerBorder: Color(0xFFE2B84A),
    runnerMotif: Color(0xFF5B2A78),
    ceilingLights: false,
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
  FrameDecor(frame: Color(0xFF2B1D14), mat: Color(0xFFF3EFE4)), // walnut
  FrameDecor(frame: Color(0xFF131313), mat: Color(0xFFF8F6F0)), // black
  FrameDecor(frame: Color(0xFFEFECE4), mat: Color(0xFFFAF8F3)), // white
  FrameDecor(frame: Color(0xFF45301F), mat: Color(0xFFEDE6D4)), // espresso
  FrameDecor(frame: Color(0xFF9B7A3C), mat: Color(0xFFF1EBDA)), // antique gold
];

/// The wood and mat of a Gallery frame, from the number the layout gave it.
FrameDecor galleryFrameLook(int style) =>
    _frameLooks[style % _frameLooks.length];

/// Draws the corridor with one vanishing point, frames on both walls, and the
/// pictures on the frames in real perspective. It repaints when the camera
/// moves or a picture finishes decoding; nothing is rebuilt per frame.
///
/// [lite] drops gradients, floor planks and light pools for slow phones.
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

  @override
  void paint(Canvas canvas, Size size) {
    final cameraZ = camera.value;
    final view = Projection(size, cameraZ);
    canvas.clipRect(Offset.zero & size);

    _hall(canvas, size, view);
    _end(canvas, view);
    _runner(canvas, view);
    _lights(canvas, view);
    for (final slot in visibleSlots(slots, cameraZ)) {
      _frame(canvas, view, slot);
    }
    _haze(canvas, size, view);
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
    final vp = view.vanishingPoint;

    Offset p(double x, double y, double z) => view.point(x, y, z)!;

    // Behind everything: the dark end of the corridor.
    canvas.drawRect(Offset.zero & size, Paint()..color = style.wallFar);

    // Ceiling, floor and the two walls.
    final ceiling = _poly([
      p(-wx, top, z0),
      p(wx, top, z0),
      p(wx, top, z1),
      p(-wx, top, z1),
    ]);
    final floor = _poly([
      p(-wx, bottom, z0),
      p(wx, bottom, z0),
      p(wx, bottom, z1),
      p(-wx, bottom, z1),
    ]);
    final leftWall = _poly([
      p(-wx, top, z0),
      p(-wx, bottom, z0),
      p(-wx, bottom, z1),
      p(-wx, top, z1),
    ]);
    final rightWall = _poly([
      p(wx, top, z0),
      p(wx, bottom, z0),
      p(wx, bottom, z1),
      p(wx, top, z1),
    ]);

    Paint shaded(Color near, Color far, Offset from) => Paint()
      ..shader = lite ? null : ui.Gradient.linear(from, vp, [near, far])
      ..color = near;

    canvas.drawPath(
      ceiling,
      // The ceiling stays pale and warm; it only dims a little toward the far end.
      shaded(
        style.ceiling,
        Color.lerp(style.ceiling, style.wallFar, 0.3)!,
        Offset(size.width / 2, 0),
      ),
    );
    canvas.drawPath(
      floor,
      shaded(style.floor, style.floorFar, Offset(size.width / 2, size.height)),
    );
    canvas.drawPath(
      leftWall,
      shaded(style.wall, style.wallFar, Offset(0, vp.dy)),
    );
    canvas.drawPath(
      rightWall,
      shaded(style.wall, style.wallFar, Offset(size.width, vp.dy)),
    );

    // Skirting boards and crown moulding, white.
    final trim = Paint()..color = CorridorColors.trim;
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
      // The shadow under the moulding and a step in the skirting.
      canvas.drawPath(
        _poly([
          p(x, top + 0.25, z0),
          p(x, top + 0.31, z0),
          p(x, top + 0.31, z1),
          p(x, top + 0.25, z1),
        ]),
        Paint()..color = const Color(0x26000000),
      );
      canvas.drawPath(
        _poly([
          p(x, bottom - 0.3, z0),
          p(x, bottom - 0.27, z0),
          p(x, bottom - 0.27, z1),
          p(x, bottom - 0.3, z1),
        ]),
        Paint()..color = const Color(0x22000000),
      );
    }

    if (lite) return;

    // Floor: planks along the corridor and a seam every metre.
    final lines = Paint()
      ..color = CorridorColors.plank
      ..strokeWidth = 1;
    for (var k = -4; k <= 4; k++) {
      final x = k * 0.4;
      canvas.drawLine(p(x, bottom, z0), p(x, bottom, z1), lines);
    }
    final firstSeam = (view.cameraZ).floorToDouble() + 1;
    for (var z = firstSeam; z < view.cameraZ + 24; z += 1) {
      final a = view.point(-wx, bottom, z);
      final b = view.point(wx, bottom, z);
      if (a != null && b != null) canvas.drawLine(a, b, lines);
    }
    // A soft shine in the middle of the floor.
    canvas.drawPath(
      floor,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, vp.dy + (size.height - vp.dy) * 0.55),
          size.width * 0.55,
          const [Color(0x22FFFFFF), Color(0x00FFFFFF)],
        ),
    );
  }

  void _runner(Canvas canvas, Projection view) {
    const bottom = Corridor.floorY;
    const half = 0.75;
    final z0 = view.cameraZ + 0.5;
    final z1 = view.cameraZ + Corridor.far;
    Offset p(double x, double z) => view.point(x, bottom, z)!;

    canvas.drawPath(
      _poly([p(-half, z0), p(half, z0), p(half, z1), p(-half, z1)]),
      Paint()..color = style.runner,
    );
    // A border along both edges: a wide band and a thin line inside it.
    final border = Paint()..color = style.runnerBorder;
    for (final side in const [-1.0, 1.0]) {
      final outer = side * half;
      final inner = side * (half - 0.09);
      canvas.drawPath(
        _poly([p(inner, z0), p(outer, z0), p(outer, z1), p(inner, z1)]),
        border,
      );
      final lineOuter = side * (half - 0.14);
      final lineInner = side * (half - 0.16);
      canvas.drawPath(
        _poly([
          p(lineInner, z0),
          p(lineOuter, z0),
          p(lineOuter, z1),
          p(lineInner, z1),
        ]),
        border,
      );
    }
    if (lite) return;
    // A motif in the middle of every metre, and a row of small ones in the border.
    final motif = Paint()..color = style.runnerMotif;
    final first = view.cameraZ.floorToDouble() + 1;
    for (var z = first; z < view.cameraZ + 22; z += 1) {
      final centre = z + 0.5;
      if (centre - view.cameraZ < Corridor.near) continue;
      if (style.roundMotif) {
        canvas.drawPath(_circleOnFloor(view, 0, centre, 0.3), motif);
        for (final side in const [-1.0, 1.0]) {
          canvas.drawPath(
            _circleOnFloor(view, side * (half - 0.045), centre, 0.03),
            Paint()..color = style.runner,
          );
        }
      } else {
        canvas.drawPath(
          _poly([
            view.point(0, bottom, centre - 0.32),
            view.point(0.32, bottom, centre),
            view.point(0, bottom, centre + 0.32),
            view.point(-0.32, bottom, centre),
          ]),
          motif,
        );
      }
    }
  }

  /// A circle lying on the floor, as the visitor sees it (an ellipse).
  Path _circleOnFloor(Projection view, double x, double z, double radius) {
    final points = <Offset?>[
      for (var i = 0; i < 32; i++)
        view.point(
          x + radius * math.cos(i * math.pi * 2 / 32),
          Corridor.floorY,
          z + radius * math.sin(i * math.pi * 2 / 32),
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
      // The lamp: a small round hole in the ceiling with a bright disc in it.
      final lamp = <Offset?>[
        for (var i = 0; i < 12; i++)
          view.point(
            0.11 * math.cos(i * math.pi * 2 / 12),
            top,
            z + 0.11 * math.sin(i * math.pi * 2 / 12),
          ),
      ];
      if (lamp.any((c) => c == null)) continue;
      canvas.drawPath(_poly(lamp), Paint()..color = CorridorColors.light);
      if (lite) continue;
      // A pool of light on the floor below.
      final pool = view.point(0, Corridor.floorY, z);
      if (pool == null) continue;
      final radius = view.focal * 0.9 / (z - view.cameraZ);
      canvas.save();
      canvas.translate(pool.dx, pool.dy);
      canvas.scale(1, 0.28);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, radius, const [
            Color(0x38FFF6D6),
            Color(0x00FFF6D6),
          ]),
      );
      canvas.restore();
    }
  }

  /// The far end: a wall with a bright doorway (like the opening at the end of a
  /// real gallery hall). Far away it is only a glow at the vanishing point.
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
      canvas.drawPath(_poly(corners), Paint()..color = style.wall);
    }
    if (!style.doorway) return;
    // Seen from afar the door sits just inside the fog.
    final z = math.min(end, view.cameraZ + Corridor.far - 1);
    final casing = [
      at(-0.95, -1.12, z),
      at(0.95, -1.12, z),
      at(0.95, Corridor.floorY, z),
      at(-0.95, Corridor.floorY, z),
    ];
    final door = [
      at(-0.82, -1.0, z),
      at(0.82, -1.0, z),
      at(0.82, Corridor.floorY, z),
      at(-0.82, Corridor.floorY, z),
    ];
    if (casing.any((c) => c == null) || door.any((c) => c == null)) return;
    canvas.drawPath(_poly(casing), Paint()..color = CorridorColors.trim);
    canvas.drawPath(
      _poly(door),
      Paint()
        ..shader = lite
            ? null
            : ui.Gradient.linear(door[0]!, door[3]!, const [
                Color(0xFFFFF6DE),
                Color(0xFFEBD8AE),
              ])
        ..color = const Color(0xFFFFF0CC),
    );
    if (lite) return;
    // A glow around it.
    final centre = Offset(
      (door[0]!.dx + door[1]!.dx) / 2,
      (door[0]!.dy + door[3]!.dy) / 2,
    );
    final radius = (door[1]!.dx - door[0]!.dx) * 1.6;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius, const [
          Color(0x40FFF3D0),
          Color(0x00FFF3D0),
        ]),
    );
  }

  void _haze(Canvas canvas, Size size, Projection view) {
    if (lite) return;
    final vp = view.vanishingPoint;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(vp, size.width * 0.5, [
          style.wallFar.withAlpha(0x55),
          style.wallFar.withAlpha(0),
        ]),
    );
  }

  // Frames --------------------------------------------------------------------

  void _frame(Canvas canvas, Projection view, FrameSlot slot) {
    final outer = view.wallQuad(slot);
    if (outer == null) return;
    final depth = slot.z0 - view.cameraZ;
    final fade = depth <= 18
        ? 1.0
        : (1 - (depth - 18) / (Corridor.far - 18)).clamp(0.0, 1.0);
    final alpha = (fade * 255).round();

    final entry = !slot.isBlank && slot.index < entries.length
        ? entries[slot.index]
        : null;
    final decor = entry != null && decorOf != null
        ? decorOf!(entry)
        : galleryFrameLook(slot.style);
    if (entry != null && decor.spot && !lite) _spot(canvas, view, slot, alpha);

    // A soft shadow on the wall, down and a little behind the frame.
    if (!lite) {
      final shadow = view.wallQuad(
        FrameSlot(
          index: -1,
          side: slot.side,
          z0: slot.z0 + 0.03,
          z1: slot.z1 + 0.03,
          yTop: slot.yTop + 0.07,
          yBottom: slot.yBottom + 0.07,
        ),
      );
      if (shadow != null) {
        canvas.drawPath(
          _poly(shadow),
          Paint()..color = Color.fromARGB((60 * fade).round(), 0, 0, 0),
        );
      }
    }
    canvas.drawPath(
      _poly(outer),
      Paint()..color = decor.frame.withAlpha(alpha),
    );
    final mat = view.wallQuad(slot, inset: 0.06);
    if (mat == null) return;
    canvas.drawPath(_poly(mat), Paint()..color = decor.mat.withAlpha(alpha));

    if (entry == null) {
      // A blank canvas, waiting for a painting.
      final canvasQuad = view.wallQuad(slot, inset: 0.13);
      if (canvasQuad == null) return;
      canvas.drawPath(
        _poly(canvasQuad),
        Paint()..color = CorridorColors.blankCanvas.withAlpha(alpha),
      );
      if (!lite) {
        canvas.drawPath(
          _poly(canvasQuad),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Color.fromARGB((46 * fade).round(), 0, 0, 0),
        );
      }
      return;
    }

    final picture = view.artQuad(slot);
    if (picture == null) return;
    if (decor.plaque.isNotEmpty && depth < 9) {
      _plate(canvas, view, slot, entry, decor.plaque);
    }

    final onScreenWidth = (picture[1] - picture[0]).distance;
    final image = onScreenWidth < 6 ? null : cache.peek(entry.id);
    if (onScreenWidth >= 6 && image == null) {
      cache.load(entry); // starts decoding; the cache repaints when it is done
    }
    if (image == null) {
      // Too far to see the detail, or not decoded yet: its average colour.
      canvas.drawPath(
        _poly(picture),
        Paint()..color = _average(entry).withAlpha(alpha),
      );
      return;
    }
    canvas.save();
    canvas.transform(unitSquareToQuad(picture).storage);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromARGB(alpha, 255, 255, 255),
    );
    canvas.restore();
  }

  /// A cone of light from the ceiling onto the painting.
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
      Paint()
        ..shader = ui.Gradient.linear(corners[0]!, corners[3]!, [
          Color.fromARGB((90 * alpha / 255).round(), 255, 244, 214),
          const Color(0x00FFF4D6),
        ]),
    );
  }

  /// A brass plate under the frame, with the week, the theme and the group.
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
                  color: const Color(0xFF2A1E0A),
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
      Paint()..color = const Color(0xFFD9B35B),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0.01, 0.03, 0.98, 0.94),
      Paint()
        ..color = const Color(0xFF8A6A22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02,
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
