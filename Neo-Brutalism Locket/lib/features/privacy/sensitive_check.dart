import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    hide TextLine;
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/privacy/sensitive_rules.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/screen_recapture.dart';
import 'package:path_provider/path_provider.dart';

/// What the check found in one photo.
class SensitiveScan {
  const SensitiveScan({
    required this.size,
    required this.findings,
    this.lines = const [],
  });

  /// The photo upright, in pixels (the boxes are in this space).
  final Size size;
  final List<SensitiveFinding> findings;

  /// Every line of text that was read (for measuring the check).
  final List<TextLine> lines;
}

/// Looks for private details in a photo before it is sent.
abstract class SensitiveScanner {
  Future<SensitiveScan> scan(File photo);

  /// Writes a copy of [photo] with [boxes] covered; returns the new file.
  Future<File> cover(File photo, List<Rect> boxes);
}

/// On the phone: ML Kit reads the text (Latin script, on device, offline),
/// the pixel-grid test says whether it is a photo of a screen.
class OnDeviceSensitiveScanner implements SensitiveScanner {
  OnDeviceSensitiveScanner();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<SensitiveScan> scan(File photo) async {
    final bytes = await photo.readAsBytes();
    // The boxes must be in the same upright space the blur works in, so the
    // text is read from an upright copy when the file is turned by EXIF.
    final look = await compute(_look, bytes);
    var source = photo;
    File? upright;
    if (look.upright != null) {
      upright = File(
        '${(await getTemporaryDirectory()).path}/sensitive_upright_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await upright.writeAsBytes(look.upright!);
      source = upright;
    }
    try {
      final text = await _recognizer.processImage(
        InputImage.fromFilePath(source.path),
      );
      final lines = [
        for (final block in text.blocks)
          for (final line in block.lines) TextLine(line.text, line.boundingBox),
      ];
      return SensitiveScan(
        size: look.size,
        findings: findSensitive(lines, screen: look.moire >= moireReject),
        lines: lines,
      );
    } finally {
      if (upright != null && await upright.exists()) await upright.delete();
    }
  }

  @override
  Future<File> cover(File photo, List<Rect> boxes) async {
    final covered = await compute(coverRegions, (
      await photo.readAsBytes(),
      [for (final b in boxes) (b.left, b.top, b.right, b.bottom)],
    ));
    final out = File(
      '${(await getTemporaryDirectory()).path}/covered_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(covered);
    return out;
  }

  void close() => _recognizer.close();
}

({Size size, double moire, Uint8List? upright}) _look(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  final turned = decoded.exif.imageIfd.orientation;
  final image = img.bakeOrientation(decoded);
  return (
    size: Size(image.width.toDouble(), image.height.toDouble()),
    moire: moireStrength(image),
    upright: turned != null && turned != 1
        ? Uint8List.fromList(img.encodeJpg(image, quality: 92))
        : null,
  );
}

/// Covers each box (left, top, right, bottom in upright pixels) so what was
/// there cannot be read back: coarse blocks first, then a blur over them so
/// it looks soft rather than like a mosaic. The result is upright, without
/// EXIF.
Uint8List coverRegions(
  (Uint8List, List<(double, double, double, double)>) job,
) {
  final decoded = img.decodeImage(job.$1);
  if (decoded == null) throw const FormatException('Not an image');
  final image = img.bakeOrientation(decoded);
  image.exif = img.ExifData();
  for (final (l, t, r, b) in job.$2) {
    final pad = math.max(4.0, (b - t) * .15);
    final left = (l - pad).floor().clamp(0, image.width - 1);
    final top = (t - pad).floor().clamp(0, image.height - 1);
    final right = (r + pad).ceil().clamp(left + 1, image.width);
    final bottom = (b + pad).ceil().clamp(top + 1, image.height);
    final width = right - left;
    final height = bottom - top;
    final patch = img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    // Blocks half a text line tall: no letter survives that.
    final block = math.max(6, math.min(width, height) ~/ 2);
    img.pixelate(patch, size: block);
    img.gaussianBlur(patch, radius: math.max(3, block ~/ 2));
    img.compositeImage(image, patch, dstX: left, dstY: top);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}
