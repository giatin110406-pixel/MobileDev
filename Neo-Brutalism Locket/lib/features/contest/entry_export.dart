import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:share_plus/share_plus.dart';

/// The painting as a PNG, big and crisp: every cell becomes a square of whole pixels
/// (never smoothed), at least [minSize] pixels wide. Made on the phone, so the
/// server does no work.
Future<Uint8List> renderEntryPng(
  GalleryEntry entry, {
  int minSize = 1024,
}) async {
  final scale = (minSize / entry.width).ceil().clamp(1, 64);
  final width = entry.width * scale;
  final height = entry.height * scale;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..isAntiAlias = false;
  for (var y = 0; y < entry.height; y++) {
    for (var x = 0; x < entry.width; x++) {
      final index = entry.pixels[y * entry.width + x];
      paint.color = ui.Color(
        entry.palette[index < entry.palette.length ? index : 0],
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(
          (x * scale).toDouble(),
          (y * scale).toDouble(),
          scale.toDouble(),
          scale.toDouble(),
        ),
        paint,
      );
    }
  }
  final image = await recorder.endRecording().toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Save a painting to the photo library or share it with other apps.
abstract interface class EntryExporter {
  /// True when the picture is in the photo library now.
  Future<bool> save(GalleryEntry entry);

  /// True when the share sheet was opened.
  Future<bool> share(GalleryEntry entry, {String text = ''});
}

class DeviceEntryExporter implements EntryExporter {
  const DeviceEntryExporter();

  @override
  Future<bool> save(GalleryEntry entry) async {
    try {
      final png = await renderEntryPng(entry);
      await Gal.putImageBytes(png, name: 'gallery_${entry.id}');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> share(GalleryEntry entry, {String text = ''}) async {
    try {
      final png = await renderEntryPng(entry);
      await SharePlus.instance.share(
        ShareParams(
          text: text.isEmpty ? null : text,
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: 'gallery_${entry.seq}.png',
            ),
          ],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
