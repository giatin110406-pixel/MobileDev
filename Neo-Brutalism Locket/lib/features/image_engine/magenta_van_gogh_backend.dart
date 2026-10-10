import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Van Gogh style via Magenta arbitrary image stylization (two TFLite models):
/// a style-prediction net turns the reference painting into a 100-d vector,
/// and a style-transform net applies that vector to the photo.
///
/// Any failure (missing asset, unexpected tensors, runtime error) falls back
/// to [fallback] so the capture flow never breaks.
class MagentaVanGoghBackend implements VanGoghBackend {
  const MagentaVanGoghBackend({
    this.predictModelPath = 'assets/models/magenta_style_predict.tflite',
    this.transformModelPath = 'assets/models/magenta_style_transform.tflite',
    this.styleImagePath = 'assets/styles/van_gogh_starry_night.jpg',
    this.styleStrength = 0.85,
    this.fallback = const MockVanGoghBackend(),
  });

  final String predictModelPath;
  final String transformModelPath;
  final String styleImagePath;

  /// 0..1 blend of stylized output over the original. Lower keeps faces safer.
  final double styleStrength;
  final VanGoghBackend fallback;

  @override
  Future<StyleResult> process(
    Uint8List originalBytes, {
    StyleProgress? onProgress,
  }) async {
    try {
      final predictModel = await rootBundle.load(predictModelPath);
      final transformModel = await rootBundle.load(transformModelPath);
      final styleImage = await rootBundle.load(styleImagePath);
      final png = await compute(
        _runMagenta,
        _MagentaRequest(
          predictModel: predictModel.buffer.asUint8List(
            predictModel.offsetInBytes,
            predictModel.lengthInBytes,
          ),
          transformModel: transformModel.buffer.asUint8List(
            transformModel.offsetInBytes,
            transformModel.lengthInBytes,
          ),
          styleImage: styleImage.buffer.asUint8List(
            styleImage.offsetInBytes,
            styleImage.lengthInBytes,
          ),
          content: originalBytes,
          strength: styleStrength.clamp(0.0, 1.0).toDouble(),
        ),
      );
      return StyleResult(png, StyleSource.magenta);
    } catch (error, stack) {
      debugPrint('Magenta Van Gogh failed, using fallback: $error\n$stack');
      final result = await fallback.process(
        originalBytes,
        onProgress: onProgress,
      );
      return StyleResult(result.png, result.source, note: 'magenta:failed');
    }
  }
}

class _MagentaRequest {
  const _MagentaRequest({
    required this.predictModel,
    required this.transformModel,
    required this.styleImage,
    required this.content,
    required this.strength,
  });

  final Uint8List predictModel;
  final Uint8List transformModel;
  final Uint8List styleImage;
  final Uint8List content;
  final double strength;
}

Uint8List _runMagenta(_MagentaRequest request) {
  final bottleneck = _predictStyle(request);
  return _transform(request, bottleneck);
}

Float32List _predictStyle(_MagentaRequest request) {
  final interpreter = Interpreter.fromBuffer(request.predictModel);
  try {
    final inputShape = interpreter.getInputTensor(0).shape; // [1, H, W, 3]
    final height = inputShape[1];
    final width = inputShape[2];
    final style = img.copyResize(
      img.decodeImage(request.styleImage)!,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    interpreter.getInputTensor(0).data = _toBytes(_imageToFloats(style));
    interpreter.invoke();
    return _fromBytes(interpreter.getOutputTensor(0).data);
  } finally {
    interpreter.close();
  }
}

Uint8List _transform(_MagentaRequest request, Float32List bottleneck) {
  final interpreter = Interpreter.fromBuffer(request.transformModel);
  try {
    // Resolve inputs by shape so tensor order does not matter.
    var contentIndex = -1;
    var styleIndex = -1;
    final inputCount = interpreter.getInputTensors().length;
    for (var i = 0; i < inputCount; i++) {
      final shape = interpreter.getInputTensor(i).shape;
      if (shape.length == 4 && shape[3] == 3) {
        contentIndex = i;
      } else {
        styleIndex = i;
      }
    }
    if (contentIndex < 0 || styleIndex < 0) {
      throw StateError('Unexpected transform input tensors.');
    }

    final contentShape = interpreter.getInputTensor(contentIndex).shape;
    final height = contentShape[1];
    final width = contentShape[2];

    // Model input is fixed-size: center-crop to the target aspect, then resize.
    final source = decodeOrientedImage(request.content);
    final cropped = _centerCrop(source, width / height);
    final input = img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );

    interpreter.getInputTensor(contentIndex).data = _toBytes(
      _imageToFloats(input),
    );
    interpreter.getInputTensor(styleIndex).data = _toBytes(bottleneck);
    interpreter.invoke();
    final output = _fromBytes(interpreter.getOutputTensor(0).data);
    if (output.length < width * height * 3) {
      throw StateError('Unexpected transform output size.');
    }

    final result = img.Image(width: width, height: height, numChannels: 3);
    final s = request.strength;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final o = (y * width + x) * 3;
        final original = input.getPixel(x, y);
        result.setPixelRgb(
          x,
          y,
          _blend(output[o], original.r, s),
          _blend(output[o + 1], original.g, s),
          _blend(output[o + 2], original.b, s),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(result, level: 3));
  } finally {
    interpreter.close();
  }
}

img.Image _centerCrop(img.Image source, double aspect) {
  final sourceAspect = source.width / source.height;
  if ((sourceAspect - aspect).abs() < 0.001) return source;
  if (sourceAspect > aspect) {
    final w = (source.height * aspect).round();
    return img.copyCrop(
      source,
      x: (source.width - w) ~/ 2,
      y: 0,
      width: w,
      height: source.height,
    );
  }
  final h = (source.width / aspect).round();
  return img.copyCrop(
    source,
    x: 0,
    y: (source.height - h) ~/ 2,
    width: source.width,
    height: h,
  );
}

Float32List _imageToFloats(img.Image image) {
  final data = Float32List(image.width * image.height * 3);
  var i = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      data[i++] = p.r / 255.0;
      data[i++] = p.g / 255.0;
      data[i++] = p.b / 255.0;
    }
  }
  return data;
}

Uint8List _toBytes(Float32List floats) =>
    floats.buffer.asUint8List(floats.offsetInBytes, floats.lengthInBytes);

Float32List _fromBytes(Uint8List bytes) {
  final copy = Uint8List.fromList(bytes);
  return copy.buffer.asFloat32List(0, copy.length ~/ 4);
}

int _blend(double stylized, num original, double strength) {
  final styled = stylized.clamp(0.0, 1.0) * 255.0;
  return math.max(
    0,
    math.min(255, (styled * strength + original * (1 - strength)).round()),
  );
}
