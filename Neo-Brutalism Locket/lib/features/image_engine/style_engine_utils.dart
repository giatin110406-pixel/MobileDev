import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

img.Image decodeOrientedImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image data.');
  return img.bakeOrientation(decoded);
}

Future<File> writeProcessedPng(
  File originalFile,
  String styleName,
  Uint8List pngBytes,
) async {
  final outputPath =
      '${originalFile.parent.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$styleName.png';
  final outputFile = File(outputPath);
  await outputFile.writeAsBytes(pngBytes, flush: true);
  return outputFile;
}

/// Largest side of a photo picked from the gallery (they can be 12 MP+).
const uploadMaxSide = 1536;

/// Like [cropToSquareJpeg] for gallery photos: the square is also scaled down to
/// [uploadMaxSide] so processing and the laptop upload stay fast.
Uint8List cropToSquareJpegCapped(Uint8List bytes) {
  final image = decodeOrientedImage(bytes);
  final side = image.width < image.height ? image.width : image.height;
  var square = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  if (side > uploadMaxSide) {
    square = img.copyResize(
      square,
      width: uploadMaxSide,
      height: uploadMaxSide,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(img.encodeJpg(square, quality: 92));
}

/// Centre-crops a camera photo to a square (1:1, like the viewfinder) and
/// returns JPEG bytes. EXIF orientation is applied first so "centre" is what
/// the user saw.
Uint8List cropToSquareJpeg(Uint8List bytes) {
  final image = decodeOrientedImage(bytes);
  final side = image.width < image.height ? image.width : image.height;
  final square = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  return Uint8List.fromList(img.encodeJpg(square, quality: 92));
}
