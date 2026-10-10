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

  /// The first frame starts this far from the entrance (so the wall is covered
  /// right up to the edge of the screen).
  static const startZ = 1.0;

  /// Space left free between two frames on a wall.
  static const gap = 0.14;

  /// The height range of the wall that frames may use (skirting and crown
  /// moulding take the rest).
  static const wallTop = -1.45;
  static const wallBottom = 1.1;
}

/// Where one frame hangs: on the left (-1) or right (+1) wall, between z0 and
/// z1 along the corridor and yTop and yBottom in height. A frame may hold an entry
/// ([index] >= 0) or be a blank canvas waiting for one ([index] == -1).
class FrameSlot {
  const FrameSlot({
    required this.index,
    required this.side,
    required this.z0,
    required this.z1,
    required this.yTop,
    required this.yBottom,
    this.style = 0,
  });

  /// Which entry hangs here (index into the list that was laid out), or -1 for a
  /// blank canvas.
  final int index;
  final int side;
  final double z0;
  final double z1;
  final double yTop;
  final double yBottom;

  /// Which kind of frame (wood, black, white, gold...): a number the painter turns
  /// into colours. The same slot always has the same look.
  final int style;

  double get width => z1 - z0;
  double get height => yBottom - yTop;

  /// The shorter side: frame and mat widths are a share of it.
  double get size => math.min(width, height);

  bool get isBlank => index < 0;

  FrameSlot withEntry(int entry) => FrameSlot(
    index: entry,
    side: side,
    z0: z0,
    z1: z1,
    yTop: yTop,
    yBottom: yBottom,
    style: style,
  );
}

int _hash(int a, int b) {
  var hash = (a * 73856093) ^ (b * 19349663);
  hash &= 0xFFFFFFFF;
  // Mix the bits so that neighbouring numbers do not get patterns.
  hash ^= hash >> 16;
  hash = (hash * 0x85EBCA6B) & 0xFFFFFFFF;
  hash ^= hash >> 13;
  hash = (hash * 0xC2B2AE35) & 0xFFFFFFFF;
  hash ^= hash >> 16;
  return hash;
}

/// A column of the salon wall: as wide as [width], with frames of the given
/// heights one above the other.
class _Column {
  const _Column(this.width, this.heights);

  final double width;
  final List<double> heights;
}

/// The kinds of column, in the order they are picked from. Every column fits the
/// height of the wall (2.55 m) with a small gap between the frames.
const _columns = [
  _Column(0.95, [2.3]), // a tall portrait
  _Column(1.7, [1.7]), // a big landscape
  _Column(1.15, [1.12, 1.12]), // two, one above the other
  _Column(0.8, [0.7, 0.7, 0.7]), // three small ones
  _Column(1.6, [1.05, 1.05]), // two wide ones
  _Column(1.9, [2.0]), // a large one
  _Column(0.9, [1.0, 1.25]), // two uneven ones
  _Column(0.8, [0.7, 0.7, 0.7]), // (small ones are common on a salon wall)
  _Column(1.15, [1.12, 1.12]),
];

/// A frame can show an entry when it is big enough to see and not a thin
/// strip: the painting is square.
bool _fitsEntry(double width, double height) {
  final ratio = width / height;
  return math.min(width, height) >= 0.89 && ratio >= 0.65 && ratio <= 1.55;
}

/// Frames of one wall, from the entrance up to [until] metres, always the same for
/// the same wall: asking for a longer wall only adds columns at the far end.
List<FrameSlot> _wall(int side, double until) {
  final slots = <FrameSlot>[];
  var z = Corridor.startZ;
  var k = 0;
  const wallHeight = Corridor.wallBottom - Corridor.wallTop;
  while (z < until) {
    final hash = _hash(side + 7, k);
    final column = _columns[hash % _columns.length];
    final gaps = (column.heights.length - 1) * Corridor.gap;
    final total = column.heights.fold(0.0, (sum, h) => sum + h) + gaps;
    // The stack hangs in the middle of the wall, a touch up or down.
    final slack = wallHeight - total;
    final jitter = (((hash >> 5) % 11) - 5) / 5 * math.min(slack / 2, 0.12);
    var y = Corridor.wallTop + slack / 2 + jitter;
    for (var row = 0; row < column.heights.length; row++) {
      final h = column.heights[row];
      slots.add(
        FrameSlot(
          index: -1,
          side: side,
          z0: z,
          z1: z + column.width,
          yTop: y,
          yBottom: y + h,
          style: _hash(hash, row + 3) % 5,
        ),
      );
      y += h + Corridor.gap;
    }
    z += column.width + Corridor.gap;
    k++;
  }
  return slots;
}

/// The walls of the Gallery: a salon wall of frames on both sides, one above the
/// other and side by side, in many sizes, all the way down the corridor. It is the
/// same wall whatever the entries are, so the corridor looks like a gallery even when
/// nothing has been submitted: every frame is a blank canvas.
///
/// Entries then take the frames that suit a painting (big enough, not a thin strip),
/// from the entrance to the end, left and right as they come, in the order they
/// were accepted. The wall is made long enough for [entryCount] entries and [spare]
/// frames more (and for at least [atLeast] in all), so there is always more wall.
List<FrameSlot> layoutGallery(
  int entryCount, {
  int atLeast = 36,
  int spare = 16,
}) {
  final wanted = math.max(atLeast, entryCount + spare);
  var until = 24.0;
  List<FrameSlot> all;
  while (true) {
    all = [..._wall(-1, until), ..._wall(1, until)];
    final fit = all.where((s) => _fitsEntry(s.width, s.height)).length;
    if (fit >= wanted || until > 400) break;
    until += 6;
  }
  // The frames that can hold an entry, nearest first (left before right).
  final suitable =
      [
        for (var i = 0; i < all.length; i++)
          if (_fitsEntry(all[i].width, all[i].height)) i,
      ]..sort((a, b) {
        final byDistance = all[a].z0.compareTo(all[b].z0);
        return byDistance != 0
            ? byDistance
            : all[a].side.compareTo(all[b].side);
      });
  for (var entry = 0; entry < entryCount && entry < suitable.length; entry++) {
    all[suitable[entry]] = all[suitable[entry]].withEntry(entry);
  }
  all.sort((a, b) => a.z0.compareTo(b.z0));
  return all;
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
    // The first bay is a little way in, so it is fully on screen at the entrance.
    final z =
        Corridor.startZ + 2.5 + (i ~/ 2) * step + (i.isOdd ? step / 2 : 0);
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
  /// them. [inset] is a share of the frame's shorter side, taken off all round.
  /// Null if any corner is too close.
  List<Offset>? wallQuad(FrameSlot slot, {double inset = 0}) {
    final pad = slot.size * inset;
    return _quad(
      slot.side,
      slot.z0 + pad,
      slot.z1 - pad,
      slot.yTop + pad,
      slot.yBottom - pad,
    );
  }

  /// The corners of the square a painting takes inside its frame: centred, as big
  /// as fits after the frame ([frame]) and the mat ([mat]), both shares of the
  /// frame's shorter side.
  List<Offset>? artQuad(
    FrameSlot slot, {
    double frame = 0.06,
    double mat = 0.08,
  }) {
    final m = slot.size;
    final innerW = slot.width - 2 * m * frame;
    final innerH = slot.height - 2 * m * frame;
    final side = math.min(innerW, innerH) - 2 * m * mat;
    if (side <= 0) return null;
    final zc = (slot.z0 + slot.z1) / 2;
    final yc = (slot.yTop + slot.yBottom) / 2;
    return _quad(
      slot.side,
      zc - side / 2,
      zc + side / 2,
      yc - side / 2,
      yc + side / 2,
    );
  }

  List<Offset>? _quad(
    int wall,
    double z0,
    double z1,
    double top,
    double bottom,
  ) {
    final x = wall * Corridor.wallX;
    // Facing the left wall the picture's left edge is the near one; facing the
    // right wall it is the far one.
    final left = wall < 0 ? z0 : z1;
    final right = wall < 0 ? z1 : z0;
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
    if (slot.isBlank) continue; // a blank canvas has nothing to open
    final quad = projection.wallQuad(slot);
    if (quad != null && pointInQuad(point, quad)) return slot;
  }
  return null;
}
