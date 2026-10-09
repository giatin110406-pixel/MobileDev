import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

abstract interface class VanGoghBackend {
  Future<StyleResult> process(
    Uint8List originalBytes, {
    StyleProgress? onProgress,
  });
}

class MockVanGoghBackend implements VanGoghBackend {
  const MockVanGoghBackend();

  @override
  Future<StyleResult> process(
    Uint8List originalBytes, {
    StyleProgress? onProgress,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final png = await compute(mockVanGoghTintInBackground, originalBytes);
    return StyleResult(png, StyleSource.mock);
  }
}

class VanGoghStyleEngine implements StyleEngine {
  const VanGoghStyleEngine(this.backend);

  final VanGoghBackend backend;

  @override
  Future<StyleOutput> process(
    File originalFile,
    StyleType styleType, {
    StyleProgress? onProgress,
  }) async {
    if (styleType != StyleType.vanGogh) {
      throw ArgumentError.value(styleType, 'styleType');
    }
    final bytes = await originalFile.readAsBytes();
    final result = await backend.process(bytes, onProgress: onProgress);
    final file = await writeProcessedPng(
      originalFile,
      styleType.name,
      result.png,
    );
    return StyleOutput(file, result.source, note: result.note);
  }
}

Uint8List mockVanGoghTintInBackground(Uint8List originalBytes) {
  final source = decodeOrientedImage(originalBytes);
  final output = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final warm = pixel.r > pixel.b;
      output.setPixelRgb(
        x,
        y,
        _tint(pixel.r.toDouble(), warm ? 1.04 : 0.94),
        _tint(pixel.g.toDouble(), 1.02),
        _tint(pixel.b.toDouble(), warm ? 0.92 : 1.05),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(output, level: 3));
}

int _tint(double value, double amount) =>
    (value * amount).round().clamp(0, 255);
