import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/widgets.dart' show Matrix4;

/// The shape of the Gallery corridor and the maths to look down it.
///
/// Axes (metres): x to the right, y DOWN (so the ceiling has a negative y), z
/// along the corridor away from the visitor. The visitor stands at x = 0,
/// y = 0 (eye level) and only ever walks along z, so every line that runs along
/// the corridor meets at one vanishing point in the middle of the screen.
abstract final class Corridor {
  /// The walls are at x = -wallX and x = +wallX.
  static const wallX = 1.6;
  static const ceilingY = -1.7;
  static const floorY = 1.5;

  /// Nearer than this is behind the visitor's nose and not drawn.
  static const near = 0.25;

  /// Farthest that is drawn.
  static const far = 34.0;

  /// The first frame starts this far from the entrance.
  static const startZ = 3.0;

  /// Space left free between two frames on a wall.
  static const gap = 0.3;

  /// The height range of the wall that frames may use (skirting and crown
  /// moulding take the rest).
  static const wallTop = -1.45;
  static const wallBottom = 1.1;
}

/// Where one frame hangs: on the left (-1) or right (+1) wall, between z0 and
/// z1 along the corridor and yTop and yBottom in height.
class FrameSlot {
  const FrameSlot({
    required this.index,
    required this.side,
    required this.z0,
    required this.z1,
    required this.yTop,
    required this.yBottom,
  });

  /// Which entry (index into the list that was laid out).
  final int index;
  final int side;
  final double z0;
  final double z1;
  final double yTop;
  final double yBottom;

  double get size => z1 - z0;
}

int _hash(String text) {
  var hash = 0;
  for (final unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  // Mix the bits so that ids that only differ a little (1, 2, 3...) do not get
  // sizes that follow a pattern.
  hash ^= hash >> 16;
  hash = (hash * 0x85EBCA6B) & 0xFFFFFFFF;
  hash ^= hash >> 13;
  hash = (hash * 0xC2B2AE35) & 0xFFFFFFFF;
  hash ^= hash >> 16;
  return hash;
}

const _sizes = [0.9, 1.3, 1.7];

/// Hangs the entries along both walls, like a salon wall: sizes vary (picked
/// from the entry's id, never from its score, so nobody is favoured), small
/// frames sometimes stack in pairs, and no two frames overlap. The first entry
/// goes on the left and they alternate.
List<FrameSlot> layoutFrames(List<String> entryIds) {
  final slots = <FrameSlot>[];
  for (final side in const [-1, 1]) {
    final mine = <int>[
      for (var i = 0; i < entryIds.length; i++)
        if ((i % 2 == 0 ? -1 : 1) == side) i,
    ];
    var z = Corridor.startZ;
    var i = 0;
    while (i < mine.length) {
      final index = mine[i];
      final hash = _hash(entryIds[index]);
      final size = _sizes[hash % _sizes.length];
      final nextIsSmall =
          i + 1 < mine.length &&
          _sizes[_hash(entryIds[mine[i + 1]]) % _sizes.length] == _sizes.first;
      if (size == _sizes.first && nextIsSmall) {
        // Two small frames, one above the other.
        slots.add(
          FrameSlot(
            index: index,
            side: side,
            z0: z,
            z1: z + size,
            yTop: -1.4,
            yBottom: -1.4 + size,
          ),
        );
        slots.add(
          FrameSlot(
            index: mine[i + 1],
            side: side,
            z0: z,
            z1: z + size,
            yTop: 0.15,
            yBottom: 0.15 + size,
          ),
        );
        z += size + Corridor.gap;
        i += 2;
        continue;
      }
      // A single frame, a little above or below eye level.
      final jitter = ((hash >> 4) % 21 - 10) / 10; // -1..1
      var centre = -0.15 + jitter * 0.2;
      centre = centre.clamp(
        Corridor.wallTop + size / 2,
        Corridor.wallBottom - size / 2,
      );
      slots.add(
        FrameSlot(
          index: index,
          side: side,
          z0: z,
          z1: z + size,
          yTop: centre - size / 2,
          yBottom: centre + size / 2,
        ),
      );
      z += size + Corridor.gap;
      i++;
    }
  }
  return slots;
}

/// The Hall of Fame: every painting has a bay of its own and is twice as big as an
/// ordinary frame. They alternate left and right, in the order given (newest week
/// first), with room around each one for a spot light and a name plate.
List<FrameSlot> layoutHall(int count) {
  const size = 2.0;
  const step = size + 1.5;
  const centre = -0.2;
  final slots = <FrameSlot>[];
  for (var i = 0; i < count; i++) {
    final z =
        Corridor.startZ + 0.5 + (i ~/ 2) * step + (i.isOdd ? step / 2 : 0);
    slots.add(
      FrameSlot(
        index: i,
        side: i.isEven ? -1 : 1,
        z0: z,
        z1: z + size,
        yTop: centre - size / 2,
        yBottom: centre + size / 2,
      ),
    );
  }
  return slots;
}

/// How far the corridor reaches (the end of the last frame).
double corridorLength(List<FrameSlot> slots) =>
    slots.fold(Corridor.startZ, (end, slot) => math.max(end, slot.z1));

/// Looking down the corridor from [cameraZ] onto a screen of [size].
class Projection {
  Projection(this.size, this.cameraZ)
    : cx = size.width / 2,
      cy = size.height * 0.46,
      focal = size.width * 0.85;

  final Size size;
  final double cameraZ;

  /// The vanishing point (where the corridor ends, in the picture).
  final double cx;
  final double cy;
  final double focal;

  Offset get vanishingPoint => Offset(cx, cy);

  /// The screen position of a point of the corridor, or null if it is behind
  /// (or too close to) the visitor.
  Offset? point(double x, double y, double z) {
    final depth = z - cameraZ;
    if (depth < Corridor.near) return null;
    return Offset(cx + focal * x / depth, cy + focal * y / depth);
  }

  /// The four corners of a frame on its wall, in picture order: top-left,
  /// top-right, bottom-right, bottom-left, as a visitor facing that wall sees
  /// them. Null if any corner is too close.
  List<Offset>? wallQuad(FrameSlot slot, {double inset = 0}) {
    final x = slot.side * Corridor.wallX;
    final pad = slot.size * inset;
    final z0 = slot.z0 + pad;
    final z1 = slot.z1 - pad;
    final top = slot.yTop + pad;
    final bottom = slot.yBottom - pad;
    // Facing the left wall the picture's left edge is the near one; facing the
    // right wall it is the far one.
    final left = slot.side < 0 ? z0 : z1;
    final right = slot.side < 0 ? z1 : z0;
    final corners = [
      point(x, top, left),
      point(x, top, right),
      point(x, bottom, right),
      point(x, bottom, left),
    ];
    if (corners.any((corner) => corner == null)) return null;
    return [for (final corner in corners) corner!];
  }
}

/// The matrix that maps the unit square (0,0)-(1,1) onto [quad] (corners in
/// the order top-left, top-right, bottom-right, bottom-left), with real
/// perspective. Draw an image into Rect.fromLTWH(0, 0, 1, 1) after
/// canvas.transform(...) and it lands on the quad.
Matrix4 unitSquareToQuad(List<Offset> quad) {
  final x0 = quad[0].dx, y0 = quad[0].dy;
  final x1 = quad[1].dx, y1 = quad[1].dy;
  final x2 = quad[2].dx, y2 = quad[2].dy;
  final x3 = quad[3].dx, y3 = quad[3].dy;
  final sx = x0 - x1 + x2 - x3;
  final sy = y0 - y1 + y2 - y3;
  double a, b, d, e, g, h;
  if (sx.abs() < 1e-9 && sy.abs() < 1e-9) {
    a = x1 - x0;
    b = x3 - x0;
    d = y1 - y0;
    e = y3 - y0;
    g = 0;
    h = 0;
  } else {
    final dx1 = x1 - x2, dx2 = x3 - x2;
    final dy1 = y1 - y2, dy2 = y3 - y2;
    final den = dx1 * dy2 - dx2 * dy1;
    g = (sx * dy2 - dx2 * sy) / den;
    h = (dx1 * sy - sx * dy1) / den;
    a = x1 - x0 + g * x1;
    b = x3 - x0 + h * x3;
    d = y1 - y0 + g * y1;
    e = y3 - y0 + h * y3;
  }
  // Column-major: columns are what (u, v, z, 1) contribute to (x, y, z, w).
  return Matrix4(a, d, 0, g, b, e, 0, h, 0, 0, 1, 0, x0, y0, 0, 1);
}

/// Where the unit square's point (u, v) lands under [matrix] (with the
/// perspective divide), for tests and hit-testing.
Offset applyToUnit(Matrix4 matrix, double u, double v) {
  final m = matrix.storage;
  final w = m[3] * u + m[7] * v + m[15];
  return Offset(
    (m[0] * u + m[4] * v + m[12]) / w,
    (m[1] * u + m[5] * v + m[13]) / w,
  );
}

/// Whether [point] is inside the convex [quad] (either winding).
bool pointInQuad(Offset point, List<Offset> quad) {
  var positive = false;
  var negative = false;
  for (var i = 0; i < quad.length; i++) {
    final a = quad[i];
    final b = quad[(i + 1) % quad.length];
    final cross =
        (b.dx - a.dx) * (point.dy - a.dy) - (b.dy - a.dy) * (point.dx - a.dx);
    if (cross > 0) positive = true;
    if (cross < 0) negative = true;
    if (positive && negative) return false;
  }
  return true;
}

/// The frames to draw now, farthest first (so nearer ones paint over them).
List<FrameSlot> visibleSlots(List<FrameSlot> slots, double cameraZ) {
  final visible = [
    for (final slot in slots)
      if (slot.z0 - cameraZ >= Corridor.near &&
          slot.z0 - cameraZ <= Corridor.far)
        slot,
  ];
  visible.sort((a, b) => b.z0.compareTo(a.z0));
  return visible;
}

/// The frame under [point], looking from the nearest to the farthest, or null.
FrameSlot? hitTest(Offset point, List<FrameSlot> slots, Projection projection) {
  final nearestFirst = visibleSlots(slots, projection.cameraZ).reversed;
  for (final slot in nearestFirst) {
    final quad = projection.wallQuad(slot);
    if (quad != null && pointInQuad(point, quad)) return slot;
  }
  return null;
}
