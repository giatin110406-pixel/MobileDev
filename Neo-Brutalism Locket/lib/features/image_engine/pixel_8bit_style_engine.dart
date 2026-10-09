import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/cleanup.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/color_space.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/downscale.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/face_detector.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/outline.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/palette_mapper.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/palettes.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/smoothing.dart';
import 'package:neo_brutalism_locket/features/image_engine/pixel_art/tone.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

export 'package:neo_brutalism_locket/features/image_engine/pixel_art/palettes.dart';

const _upscale = 4;

/// Width of the pixel grid. A slower device automatically falls back to
/// [_fallbackGridWidth] when one pass takes more than five seconds.
const pixelGridWidth = 128;
const _fallbackGridWidth = 96;

/// The single 8-bit engine: fully on-device, offline and deterministic.
class Pixel8BitStyleEngine implements StyleEngine {
  const Pixel8BitStyleEngine();

  @override
  Future<StyleOutput> process(
    File originalFile,
    StyleType styleType, {
    StyleProgress? onProgress,
  }) async {
    if (styleType != StyleType.pixel8bit) {
      throw ArgumentError.value(styleType, 'styleType');
    }
    final originalBytes = await originalFile.readAsBytes();
    final faceModel = await _loadFaceModel();
    final stopwatch = Stopwatch()..start();
    var pngBytes = await compute(pixel8BitFilterInBackground, {
      'bytes': originalBytes,
      'pixelWidth': pixelGridWidth,
      'faceModel': faceModel,
    });
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      pngBytes = await compute(pixel8BitFilterInBackground, {
        'bytes': originalBytes,
        'pixelWidth': _fallbackGridWidth,
        'faceModel': faceModel,
      });
    }
    final file = await writeProcessedPng(
      originalFile,
      styleType.name,
      pngBytes,
    );
    return StyleOutput(file, StyleSource.onDevice);
  }
}

Future<Uint8List?> _loadFaceModel() async {
  try {
    final data = await rootBundle.load(
      'assets/models/blaze_face_short_range.tflite',
    );
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null;
  }
}

/// Deterministic pixel-art pipeline:
/// tone mapping -> Kuwahara smoothing -> k-centroid downscale -> palette
/// mapping -> outline -> orphan cleanup -> nearest-neighbour upscale.
Uint8List pixel8BitFilterInBackground(Map<String, Object?> request) {
  final bytes = request['bytes'];
  final pixelWidth = request['pixelWidth'];
  final allowPreview = request['allowPreview'] == true;
  if (bytes is! Uint8List || pixelWidth is! int) {
    throw const FormatException('8-bit filter input is incomplete.');
  }
  if (pixelWidth < (allowPreview ? 16 : 96) || pixelWidth > 192) {
    throw RangeError.range(
      pixelWidth,
      allowPreview ? 16 : 96,
      192,
      'pixelWidth',
    );
  }

  final palette = PaletteInfo(
    (request['palette'] as List<int>?) ?? endesga32Palette,
  );

  final source = decodeOrientedImage(bytes);
  // Head-and-shoulders crop around the detected face; centred square if none.
  final faces = <FaceBox>[
    for (final f in (request['faceBoxes'] as List?) ?? const [])
      FaceBox(f[0], f[1], f[2], f[3], 1),
  ];
  final faceModel = request['faceModel'];
  if (faces.isEmpty && faceModel is Uint8List) {
    faces.addAll(detectFaces(faceModel, source).take(1));
  }
  final crop = subjectCrop(source.width, source.height, faces);
  final square = img.copyCrop(
    source,
    x: crop.x,
    y: crop.y,
    width: crop.side,
    height: crop.side,
  );
  final workingSize = pixelWidth * _upscale;
  final working = img.copyResize(
    square,
    width: workingSize,
    height: workingSize,
    interpolation: img.Interpolation.average,
  );

  final rgb = Float32List(workingSize * workingSize * 3);
  for (var y = 0; y < workingSize; y++) {
    for (var x = 0; x < workingSize; x++) {
      final pixel = working.getPixel(x, y);
      final o = (y * workingSize + x) * 3;
      rgb[o] = pixel.r.toDouble();
      rgb[o + 1] = pixel.g.toDouble();
      rgb[o + 2] = pixel.b.toDouble();
    }
  }

  autoLevels(rgb);
  autoGamma(rgb);
  clarity(rgb, workingSize, workingSize);
  final smooth = kuwahara(rgb, workingSize, workingSize);

  final workingLab = Float32List(workingSize * workingSize * 3);
  for (var i = 0; i < workingSize * workingSize; i++) {
    final o = i * 3;
    srgbToOklab(smooth[o], smooth[o + 1], smooth[o + 2], workingLab, o);
  }
  final mask = faceMask(faces, crop, pixelWidth);
  final lab = kCentroidDownscale(
    workingLab,
    workingSize,
    workingSize,
    _upscale,
    keepDark: mask,
  );
  _faceContrast(lab, mask, pixelWidth);

  for (var i = 0; i < pixelWidth * pixelWidth; i++) {
    lab[i * 3 + 1] *= 1.15;
    lab[i * 3 + 2] *= 1.15;
  }

  final edges = sobelMagnitude(lab, pixelWidth, pixelWidth);
  final indices = mapToColorPalette(
    lab,
    edges,
    pixelWidth,
    pixelWidth,
    palette,
    noDither: mask,
  );
  applyOutline(indices, lab, edges, pixelWidth, pixelWidth, palette);
  removeOrphans(indices, pixelWidth, pixelWidth);

  final outputSize = pixelWidth * _upscale;
  final output = img.Image(
    width: outputSize,
    height: outputSize,
    numChannels: 3,
  );
  for (var y = 0; y < outputSize; y++) {
    for (var x = 0; x < outputSize; x++) {
      final color =
          palette.colors[indices[(y ~/ _upscale) * pixelWidth + x ~/ _upscale]];
      output.setPixelRgb(x, y, color >> 16, (color >> 8) & 0xFF, color & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(output, level: 3));
}

/// Stretches lightness around the face's mean so features separate from skin.
void _faceContrast(Float32List lab, Uint8List mask, int size) {
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < size * size; i++) {
    if (mask[i] != 0) {
      sum += lab[i * 3];
      count++;
    }
  }
  if (count == 0) return;
  final mean = sum / count;
  for (var i = 0; i < size * size; i++) {
    if (mask[i] != 0) lab[i * 3] = mean + (lab[i * 3] - mean) * 1.25;
  }
}
