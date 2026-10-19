import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';

/// Draws the shared canvas: one rectangle per cell (square when the canvas keeps
/// its shape). It repaints by itself
/// whenever the [store] changes (no widget rebuild per pixel).
class CanvasPainter extends CustomPainter {
  CanvasPainter(this.store) : super(repaint: store);

  final CanvasStore store;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = store.width;
    final rows = store.height;
    if (columns == 0 || rows == 0) return;
    final cellW = size.width / columns;
    final cellH = size.height / rows;
    final palette = store.palette;
    final fill = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        fill.color = Color(palette[store.colorIndexAt(x, y)]);
        // +0.5 hides hairline seams between neighbouring cells.
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          fill,
        );
      }
    }

    // A faint grid, only when the cells are big enough to want one.
    if (cellW >= 8) {
      final grid = Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 0.5;
      for (var i = 1; i < columns; i++) {
        canvas.drawLine(
          Offset(i * cellW, 0),
          Offset(i * cellW, size.height),
          grid,
        );
      }
      for (var i = 1; i < rows; i++) {
        canvas.drawLine(
          Offset(0, i * cellH),
          Offset(size.width, i * cellH),
          grid,
        );
      }
    }

    // My unsent pixels get a small dot until the server has them.
    final dot = Paint()..color = const Color(0xFF000000);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (store.isPending(x, y)) {
          canvas.drawCircle(
            Offset((x + 0.5) * cellW, (y + 0.5) * cellH),
            cellW * 0.12,
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
