import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/scene_guess.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Van Gogh style via Magenta arbitrary image stylization (two TFLite models):
/// a style-prediction net turns the reference painting into a 100-d vector,
/// and a style-transform net applies that vector to the photo.
///
/// The reference painting follows the kind of photo ([vanGoghStylesByScene]);
/// Starry Night only for skies, or when the scene could not be guessed.
///
/// Any failure (missing asset, unexpected tensors, runtime error) falls back
/// to [fallback] so the capture flow never breaks.
class MagentaVanGoghBackend implements VanGoghBackend {
  const MagentaVanGoghBackend({
    this.predictModelPath = 'assets/models/magenta_style_predict.tflite',
    this.transformModelPath = 'assets/models/magenta_style_transform.tflite',
    this.styleImagePath = 'assets/styles/van_gogh_starry_night.jpg',
    this.styleStrength = 0.85,
    this.guessScene = guessPhotoScene,
    this.fallback = const MockVanGoghBackend(),
  });

  final String predictModelPath;
  final String transformModelPath;

  /// Used when the scene is unknown.
  final String styleImagePath;

  /// Null when the guess failed; [styleImagePath] is used then.
  final Future<PhotoScene?> Function(Uint8List photo) guessScene;

  /// 0..1 share of the painting's light and dark applied to the photo.
  /// Lower keeps faces safer.
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
      final scene = await guessScene(originalBytes);
      final styleImage = await rootBundle.load(
        scene == null ? styleImagePath : vanGoghStyleFor(scene, originalBytes),
      );
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

/// Public-domain paintings, 256 px (server/styles/van_gogh/SOURCES.md). Soft
/// paintings for faces so skin does not turn into blue swirls.
const vanGoghStylesByScene = <PhotoScene, List<String>>{
  PhotoScene.portrait: [
    'assets/styles/van_gogh_almond_blossom.jpg',
    'assets/styles/van_gogh_irises.jpg',
  ],
  PhotoScene.group: [
    'assets/styles/van_gogh_almond_blossom.jpg',
    'assets/styles/van_gogh_irises.jpg',
  ],
  PhotoScene.day: [
    'assets/styles/van_gogh_harvest.jpg',
    'assets/styles/van_gogh_sunflowers.jpg',
    'assets/styles/van_gogh_wheatfield_cypresses.jpg',
    'assets/styles/van_gogh_bedroom_arles.jpg',
  ],
  PhotoScene.night: [
    'assets/styles/van_gogh_cafe_terrace_night.jpg',
    'assets/styles/van_gogh_starry_night_rhone.jpg',
  ],
  PhotoScene.sky: [
    'assets/styles/van_gogh_starry_night.jpg',
    'assets/styles/van_gogh_wheatfield_cypresses.jpg',
  ],
};

/// The painting for [scene]; the same photo always gets the same one.
String vanGoghStyleFor(PhotoScene scene, Uint8List photo) {
  final choices = vanGoghStylesByScene[scene]!;
  var hash = photo.length;
  for (var i = 0; i < photo.length; i += 4093) {
    hash = (hash * 31 + photo[i]) & 0x3fffffff;
  }
  return choices[hash % choices.length];
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
        final painted = paintedPixel(
          output[o],
          output[o + 1],
          output[o + 2],
          original.r,
          original.g,
          original.b,
          s,
        );
        result.setPixelRgb(x, y, painted.r, painted.g, painted.b);
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

/// One output pixel: only the painting's light and dark (its brush strokes)
/// is taken, the colour stays the photo's. The model's own colours come from
/// the reference painting (blue faces from Starry Night), so they are dropped:
/// the photo's pixel moves by the change in brightness, [strength] of it.
/// [sr]..[sb] are the model output (0..1), [r]..[b] the photo (0..255).
@visibleForTesting
({int r, int g, int b}) paintedPixel(
  double sr,
  double sg,
  double sb,
  num r,
  num g,
  num b,
  double strength,
) {
  double luma(num red, num green, num blue) =>
      0.299 * red + 0.587 * green + 0.114 * blue;
  final painted = luma(
    sr.clamp(0.0, 1.0) * 255.0,
    sg.clamp(0.0, 1.0) * 255.0,
    sb.clamp(0.0, 1.0) * 255.0,
  );
  final shift = (painted - luma(r, g, b)) * strength;
  int channel(num value) => (value + shift).round().clamp(0, 255);
  return (r: channel(r), g: channel(g), b: channel(b));
}
