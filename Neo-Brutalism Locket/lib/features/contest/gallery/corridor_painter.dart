import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';

/// The colours of the exhibition hall.
abstract final class CorridorColors {
  static const wall = Color(0xFF3E5460); // dark grey-blue
  static const wallFar = Color(0xFF5E7581);
  static const trim = Color(0xFFEDEAE0); // skirting and crown moulding
  static const ceiling = Color(0xFFD5D2C9);
  static const floor = Color(0xFF2B1C15); // dark polished wood
  static const plank = Color(0x33000000);
  static const runner = Color(0xFF6E1F2E);
  static const runnerBorder = Color(0xFFC9A24B);
  static const runnerMotif = Color(0xFF93384A);
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
  });

  final Color wall;
  final Color wallFar;
  final Color ceiling;
  final Color floor;
  final Color floorFar;
  final Color runner;
  final Color runnerBorder;
  final Color runnerMotif;

  /// The round ceiling lights (the Hall of Fame has spot lights instead).
  final bool ceilingLights;

  /// The exhibition corridor: grey-blue walls, dark wood, a burgundy runner.
  static const gallery = CorridorStyle(
    wall: CorridorColors.wall,
    wallFar: CorridorColors.wallFar,
    ceiling: CorridorColors.ceiling,
    floor: CorridorColors.floor,
    floorFar: Color(0xFF3B2A20),
    runner: CorridorColors.runner,
    runnerBorder: CorridorColors.runnerBorder,
    runnerMotif: CorridorColors.runnerMotif,
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
  }) : super(repaint: Listenable.merge([camera, cache]));

  final ValueListenable<double> camera;
  final List<GalleryEntry> entries;
  final List<FrameSlot> slots;
  final EntryImageCache cache;
  final bool lite;
  final CorridorStyle style;

  /// How to dress each frame (null: plain frames, as in the Gallery).
  final FrameDecor Function(GalleryEntry entry)? decorOf;

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
      shaded(style.ceiling, style.wallFar, Offset(size.width / 2, 0)),
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
          p(x, bottom - 0.2, z0),
          p(x, bottom, z0),
          p(x, bottom, z1),
          p(x, bottom - 0.2, z1),
        ]),
        trim,
      );
      canvas.drawPath(
        _poly([
          p(x, top, z0),
          p(x, top + 0.18, z0),
          p(x, top + 0.18, z1),
          p(x, top, z1),
        ]),
        trim,
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
    // Gold borders along both edges.
    final border = Paint()..color = style.runnerBorder;
    for (final side in const [-1.0, 1.0]) {
      final inner = side * (half - 0.07);
      final outer = side * half;
      canvas.drawPath(
        _poly([p(inner, z0), p(outer, z0), p(outer, z1), p(inner, z1)]),
        border,
      );
    }
    if (lite) return;
    // A diamond in the middle of every metre.
    final motif = Paint()..color = style.runnerMotif;
    final first = view.cameraZ.floorToDouble() + 1;
    for (var z = first; z < view.cameraZ + 22; z += 1) {
      final centre = z + 0.5;
      if (centre - view.cameraZ < Corridor.near) continue;
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

  void _lights(Canvas canvas, Projection view) {
    if (!style.ceilingLights) return;
    const top = Corridor.ceilingY;
    final first = (view.cameraZ / 4).floor() * 4 + 4;
    for (var z = first.toDouble(); z < view.cameraZ + 28; z += 4) {
      if (z - view.cameraZ < 1) continue;
      final corners = [
        view.point(-0.3, top, z - 0.2),
        view.point(0.3, top, z - 0.2),
        view.point(0.3, top, z + 0.2),
        view.point(-0.3, top, z + 0.2),
      ];
      if (corners.any((c) => c == null)) continue;
      canvas.drawPath(_poly(corners), Paint()..color = CorridorColors.light);
      if (lite) continue;
      // A pool of light on the carpet below.
      final pool = view.point(0, Corridor.floorY, z);
      if (pool == null) continue;
      final radius = view.focal * 1.1 / (z - view.cameraZ);
      canvas.save();
      canvas.translate(pool.dx, pool.dy);
      canvas.scale(1, 0.28);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, radius, const [
            Color(0x40FFF6D6),
            Color(0x00FFF6D6),
          ]),
      );
      canvas.restore();
    }
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

    final entry = entries[slot.index];
    final decor = decorOf?.call(entry) ?? const FrameDecor();
    if (decor.spot && !lite) _spot(canvas, view, slot, alpha);

    canvas.drawPath(
      _poly(outer),
      Paint()..color = decor.frame.withAlpha(alpha),
    );
    final mat = view.wallQuad(slot, inset: 0.06);
    final picture = view.wallQuad(slot, inset: 0.13);
    if (mat == null || picture == null) return;
    canvas.drawPath(_poly(mat), Paint()..color = decor.mat.withAlpha(alpha));
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
