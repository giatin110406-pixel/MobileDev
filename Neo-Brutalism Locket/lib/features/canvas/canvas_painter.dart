import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';

/// Draws the shared canvas: one square per cell. It repaints by itself
/// whenever the [store] changes (no widget rebuild per pixel).
class CanvasPainter extends CustomPainter {
  CanvasPainter(this.store) : super(repaint: store);

  final CanvasStore store;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = store.width;
    final rows = store.height;
    if (columns == 0 || rows == 0) return;
    final cell = size.width / columns;
    final palette = store.palette;
    final fill = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        fill.color = Color(palette[store.colorIndexAt(x, y)]);
        // +0.5 hides hairline seams between neighbouring cells.
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          fill,
        );
      }
    }

    // A faint grid, only when the cells are big enough to want one.
    if (cell >= 8) {
      final grid = Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 0.5;
      for (var i = 1; i < columns; i++) {
        canvas.drawLine(
          Offset(i * cell, 0),
          Offset(i * cell, size.height),
          grid,
        );
      }
      for (var i = 1; i < rows; i++) {
        canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
      }
    }

    // My unsent pixels get a small dot until the server has them.
    final dot = Paint()..color = const Color(0xFF1A1A1A);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (store.isPending(x, y)) {
          canvas.drawCircle(
            Offset((x + 0.5) * cell, (y + 0.5) * cell),
            cell * 0.12,
            dot,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) =>
      oldDelegate.store != store;
}
