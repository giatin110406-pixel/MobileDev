import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/background_preset.dart';
import 'package:neo_brutalism_locket/features/image_engine/neo_stylizer.dart';
import 'package:neo_brutalism_locket/features/image_engine/segmentation_mask.dart';

abstract interface class ImageProcessingBackend {
  Uint8List process(
    Uint8List imageBytes, {
    PersonMask? personMask,
    List<int> backgroundRgb = const [78, 205, 196],
  });
}

class DartPaletteProcessingBackend implements ImageProcessingBackend {
  const DartPaletteProcessingBackend();

  @override
  Uint8List process(
    Uint8List imageBytes, {
    PersonMask? personMask,
    List<int> backgroundRgb = const [78, 205, 196],
  }) => stylizePhotoWithMask(
    imageBytes,
    personMask,
    backgroundRgb: backgroundRgb,
  );
}

Uint8List processPhotoInBackground(Uint8List imageBytes) =>
    const DartPaletteProcessingBackend().process(imageBytes);

Uint8List prepareSegmentationImageInBackground(Uint8List imageBytes) {
  final resized = resizeForProcessing(decodePhoto(imageBytes));
  return Uint8List.fromList(img.encodePng(resized, level: 3));
}

Uint8List processPhotoWithMaskInBackground(Map<String, Object?> request) {
  final imageBytes = request['imageBytes'];
  if (imageBytes is! Uint8List) {
    throw const FormatException('Image bytes are required.');
  }

  final confidenceData = request['maskConfidences'];
  final width = request['maskWidth'];
  final height = request['maskHeight'];
  final requestedBackground = request['backgroundRgb'];
  var backgroundRgb = imageBackgroundPresets.first.rgb;
  if (requestedBackground is List<int> && requestedBackground.length == 3) {
    backgroundRgb = requestedBackground;
  }
  PersonMask? personMask;
  if (confidenceData is Float32List && width is int && height is int) {
    if (confidenceData.length == width * height) {
      personMask = PersonMask(
        width: width,
        height: height,
        confidences: confidenceData,
      );
    }
  }
  return const DartPaletteProcessingBackend().process(
    imageBytes,
    personMask: personMask,
    backgroundRgb: backgroundRgb,
  );
}
