import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_8bit_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';

Future<Uint8List> createStylePreview(
  File originalFile,
  StyleType styleType,
) async => compute(stylePreviewInBackground, {
  'bytes': await originalFile.readAsBytes(),
  'styleType': styleType.name,
});

Uint8List stylePreviewInBackground(Map<String, Object?> request) {
  final bytes = request['bytes'];
  final styleName = request['styleType'];
  if (bytes is! Uint8List || styleName is! String) {
    throw const FormatException('Style preview input is incomplete.');
  }

  final image = decodeOrientedImage(bytes);
  final longestSide = image.width > image.height ? image.width : image.height;
  final scale = 160 / longestSide;
  final thumbnail = longestSide > 160
      ? img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.average,
        )
      : image;
  final thumbnailBytes = Uint8List.fromList(img.encodePng(thumbnail, level: 1));

  return switch (styleName) {
    'none' => thumbnailBytes,
    'pixel8bit' => pixel8BitFilterInBackground({
      'bytes': thumbnailBytes,
      'pixelWidth': 32,
      'allowPreview': true,
    }),
    'vanGogh' => mockVanGoghTintInBackground(thumbnailBytes),
    _ => throw const FormatException('Unknown image style.'),
  };
}
