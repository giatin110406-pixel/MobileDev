import 'dart:math' as math;
import 'dart:typed_data';

import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_mesh.dart';

/// A landmark group in pixel-grid coordinates.
typedef _Poly = List<(double, double)>;

_Poly _grid(FaceMesh mesh, List<int> ids, SubjectCrop crop, int grid) {
  final k = grid / crop.side;
  return [
    for (final i in ids) ((mesh.x(i) - crop.x) * k, (mesh.y(i) - crop.y) * k),
  ];
}

bool _inside(_Poly poly, double x, double y) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

void _fill(_Poly poly, int grid, void Function(int x, int y) paint) {
  if (poly.length < 3) return;
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  for (final (x, y) in poly) {
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  for (var y = math.max(0, minY.floor()); y <= math.min(grid - 1, maxY); y++) {
    for (
      var x = math.max(0, minX.floor());
      x <= math.min(grid - 1, maxX);
      x++
    ) {
      if (_inside(poly, x + 0.5, y + 0.5)) paint(x, y);
    }
  }
}

/// One-pixel-wide line through [points] (Bresenham between neighbours).
void _line(_Poly points, int grid, void Function(int x, int y) paint) {
  for (var i = 0; i + 1 < points.length; i++) {
    var x0 = points[i].$1.floor(), y0 = points[i].$2.floor();
    final x1 = points[i + 1].$1.floor(), y1 = points[i + 1].$2.floor();
    final dx = (x1 - x0).abs(), dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      if (x0 >= 0 && y0 >= 0 && x0 < grid && y0 < grid) paint(x0, y0);
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }
}

(double, double) _centre(_Poly poly) {
  var x = 0.0, y = 0.0;
  for (final p in poly) {
    x += p.$1;
    y += p.$2;
  }
  return (x / poly.length, y / poly.length);
}

/// Face mask from the mesh's face outline (1 inside), grown a little so the
/// hairline and chin are covered.
Uint8List meshFaceMask(
  List<FaceMesh> meshes,
  SubjectCrop crop,
  int grid, {
  double grow = 1.08,
}) {
  final mask = Uint8List(grid * grid);
  for (final mesh in meshes) {
    final oval = _grid(mesh, faceOval, crop, grid);
    final (cx, cy) = _centre(oval);
    final grown = [
      for (final (x, y) in oval) (cx + (x - cx) * grow, cy + (y - cy) * grow),
    ];
    _fill(grown, grid, (x, y) => mask[y * grid + x] = 1);
  }
  return mask;
}

/// Draws the features that make a face read at 128 px - eyes, brows and mouth -
/// into the OKLab pixel grid, before the palette is applied. They are darkened
/// (not painted a fixed colour) relative to the skin around them, so brows stay
/// brown, lips stay red and the palette picks a matching entry.
///
/// Faces whose eyes are under three grid pixels apart are left alone.
void paintFaceFeatures(
  Float32List lab,
  int grid,
  List<FaceMesh> meshes,
  SubjectCrop crop,
) {
  for (final mesh in meshes) {
    final oval = _grid(mesh, faceOval, crop, grid);
    final skin = _skinLightness(lab, grid, oval);
    if (skin == null) continue;

    final re = _grid(mesh, rightEye, crop, grid);
    final le = _grid(mesh, leftEye, crop, grid);
    final (rx, ry) = _centre(re);
    final (lx, ly) = _centre(le);
    final eyeDistance = math.sqrt(
      (rx - lx) * (rx - lx) + (ry - ly) * (ry - ly),
    );
    if (eyeDistance < 3) continue;

    void darken(int x, int y, double lightness, {double chroma = 1}) {
      final o = (y * grid + x) * 3;
      if (lab[o] > lightness) lab[o] = lightness;
      lab[o + 1] *= chroma;
      lab[o + 2] *= chroma;
    }

    // Eyes. Wide eyes get a light white and a dark iris; small ones a dark bar.
    final eyeWidth = eyeDistance * 0.36;
    for (final eye in [re, le]) {
      final (ex, ey) = _centre(eye);
      if (eyeWidth >= 6) {
        _fill(eye, grid, (x, y) {
          final o = (y * grid + x) * 3;
          if (lab[o] < skin + 0.1) lab[o] = skin + 0.1;
          lab[o + 1] *= 0.3;
          lab[o + 2] *= 0.3;
        });
        final radius = math.max(1.0, eyeWidth * 0.22);
        _fill(
          [
            for (var a = 0; a < 12; a++)
              (
                ex + radius * math.cos(a * math.pi / 6),
                ey + radius * math.sin(a * math.pi / 6),
              ),
          ],
          grid,
          (x, y) => darken(x, y, 0.16, chroma: 0.3),
        );
        _line(
          [...eye, eye.first],
          grid,
          (x, y) => darken(x, y, 0.2, chroma: 0.4),
        );
      } else {
        _fill(eye, grid, (x, y) => darken(x, y, 0.18, chroma: 0.3));
        final cx = ex.floor().clamp(0, grid - 1);
        final cy = ey.floor().clamp(0, grid - 1);
        darken(cx, cy, 0.16, chroma: 0.3);
      }
    }

    // Brows.
    final browTone = skin - 0.2;
    for (final brow in [rightBrow, leftBrow]) {
      final line = _grid(mesh, brow, crop, grid);
      _line(line, grid, (x, y) => darken(x, y, browTone));
    }

    // Mouth: red lips, dark line (or opening) between them.
    final outer = _grid(mesh, outerLips, crop, grid);
    _fill(outer, grid, (x, y) {
      final o = (y * grid + x) * 3;
      if (lab[o] > skin - 0.06) lab[o] = skin - 0.06;
      lab[o + 1] += 0.04;
    });
    final inner = _grid(mesh, innerLips, crop, grid);
    final opening = <int>[];
    _fill(inner, grid, (x, y) => opening.add(y * grid + x));
    if (opening.isNotEmpty) {
      for (final i in opening) {
        if (lab[i * 3] > skin - 0.32) lab[i * 3] = skin - 0.32;
      }
    } else {
      final corner = _grid(mesh, mouthCorners.toList(), crop, grid);
      final middle = _grid(mesh, const [13, 14], crop, grid);
      final (mx, my) = _centre(middle);
      _line(
        [corner[0], (mx, my), corner[1]],
        grid,
        (x, y) => darken(x, y, skin - 0.26),
      );
    }
  }
}

double? _skinLightness(Float32List lab, int grid, _Poly oval) {
  var sum = 0.0;
  var count = 0;
  _fill(oval, grid, (x, y) {
    sum += lab[(y * grid + x) * 3];
    count++;
  });
  return count < 6 ? null : sum / count;
}

extension on (int, int) {
  List<int> toList() => [$1, $2];
}
