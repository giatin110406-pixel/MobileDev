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
  }) : super(repaint: Listenable.merge([camera, cache]));

  final ValueListenable<double> camera;
  final List<GalleryEntry> entries;
  final List<FrameSlot> slots;
  final EntryImageCache cache;
  final bool lite;

  final Map<String, Color> _averages = {};

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
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = CorridorColors.wallFar,
    );

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
      shaded(
        CorridorColors.ceiling,
        CorridorColors.wallFar,
        Offset(size.width / 2, 0),
      ),
    );
    canvas.drawPath(
      floor,
      shaded(
        CorridorColors.floor,
        const Color(0xFF3B2A20),
        Offset(size.width / 2, size.height),
      ),
    );
    canvas.drawPath(
      leftWall,
      shaded(CorridorColors.wall, CorridorColors.wallFar, Offset(0, vp.dy)),
    );
    canvas.drawPath(
      rightWall,
      shaded(
        CorridorColors.wall,
        CorridorColors.wallFar,
        Offset(size.width, vp.dy),
      ),
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
      Paint()..color = CorridorColors.runner,
    );
    // Gold borders along both edges.
    final border = Paint()..color = CorridorColors.runnerBorder;
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
    final motif = Paint()..color = CorridorColors.runnerMotif;
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
        ..shader = ui.Gradient.radial(vp, size.width * 0.5, const [
          Color(0x555E7581),
          Color(0x005E7581),
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

    canvas.drawPath(
      _poly(outer),
      Paint()..color = CorridorColors.frame.withAlpha(alpha),
    );
    final mat = view.wallQuad(slot, inset: 0.06);
    final picture = view.wallQuad(slot, inset: 0.13);
    if (mat == null || picture == null) return;
    canvas.drawPath(
      _poly(mat),
      Paint()..color = CorridorColors.mat.withAlpha(alpha),
    );

    final entry = entries[slot.index];
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

  @override
  bool shouldRepaint(covariant CorridorPainter old) =>
      old.slots != slots ||
      old.entries != entries ||
      old.lite != lite ||
      old.camera != camera;

  /// Kept for tests: how many frames would be drawn at [cameraZ].
  static int framesAt(List<FrameSlot> slots, double cameraZ) =>
      visibleSlots(slots, cameraZ).length;

  static double clampCamera(double z, List<FrameSlot> slots) =>
      z.clamp(0.0, math.max(0.0, corridorLength(slots) - 4));
}
