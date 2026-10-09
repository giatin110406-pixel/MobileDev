import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A pixel picture drawn square by square (crisp at any size).
class PixelArt extends StatelessWidget {
  const PixelArt({
    required this.width,
    required this.height,
    required this.palette,
    required this.pixels,
    this.semanticLabel,
    super.key,
  });

  final int width;
  final int height;

  /// ARGB colours; a cell is an index into this list.
  final List<int> palette;
  final Uint8List pixels;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: AspectRatio(
        aspectRatio: width / height,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PixelArtPainter(width, height, palette, pixels),
          ),
        ),
      ),
    );
  }
}

class _PixelArtPainter extends CustomPainter {
  const _PixelArtPainter(this.width, this.height, this.palette, this.pixels);

  final int width;
  final int height;
  final List<int> palette;
  final Uint8List pixels;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / width;
    final cellH = size.height / height;
    final paint = Paint();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        if (index >= pixels.length) return;
        final colour = pixels[index];
        paint.color = Color(palette[colour < palette.length ? colour : 0]);
        // +0.5 hides hairline seams between neighbours.
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter old) =>
      old.pixels != pixels || old.palette != palette || old.width != width;
}
