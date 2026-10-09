import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// The picture of an entry as RGBA bytes (4 per cell), ready to become an image.
Uint8List rgbaOf(GalleryEntry entry) {
  final rgba = Uint8List(entry.width * entry.height * 4);
  for (var i = 0; i < entry.width * entry.height; i++) {
    final index = i < entry.pixels.length ? entry.pixels[i] : 0;
    final argb = entry.palette[index < entry.palette.length ? index : 0];
    rgba[i * 4] = (argb >> 16) & 0xFF;
    rgba[i * 4 + 1] = (argb >> 8) & 0xFF;
    rgba[i * 4 + 2] = argb & 0xFF;
    rgba[i * 4 + 3] = 0xFF;
  }
  return rgba;
}

/// The average colour of an entry (an opaque ARGB int), drawn instead of the
/// picture when the frame is only a few pixels wide.
int averageArgb(GalleryEntry entry) {
  var red = 0, green = 0, blue = 0;
  final count = entry.pixels.length;
  if (count == 0) return 0xFF000000;
  for (final index in entry.pixels) {
    final argb = entry.palette[index < entry.palette.length ? index : 0];
    red += (argb >> 16) & 0xFF;
    green += (argb >> 8) & 0xFF;
    blue += argb & 0xFF;
  }
  return 0xFF000000 |
      ((red ~/ count) << 16) |
      ((green ~/ count) << 8) |
      (blue ~/ count);
}

typedef PixelDecoder =
    Future<ui.Image> Function(Uint8List rgba, int width, int height);

Future<ui.Image> decodeRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Decoded pictures of entries, kept so the corridor does not decode a picture
/// every frame. Holds at most [capacity] pictures (a whole contest is 100); the
/// one used longest ago is released first, and everything is released when the
/// cache is disposed.
class EntryImageCache extends ChangeNotifier {
  EntryImageCache({this.capacity = 120, PixelDecoder? decoder})
    : _decoder = decoder ?? decodeRgba;

  final int capacity;
  final PixelDecoder _decoder;

  // Insertion order = least recently used first.
  final Map<String, ui.Image> _images = {};
  final Map<String, Future<ui.Image?>> _loading = {};
  bool _disposed = false;

  int get length => _images.length;

  /// The picture if it is ready (marks it as just used), else null.
  ui.Image? peek(String entryId) {
    final image = _images.remove(entryId);
    if (image == null) return null;
    _images[entryId] = image;
    return image;
  }

  /// Decodes the picture (once, however many ask) and tells listeners.
  Future<ui.Image?> load(GalleryEntry entry) {
    final ready = peek(entry.id);
    if (ready != null) return Future.value(ready);
    return _loading[entry.id] ??= _decode(entry);
  }

  Future<ui.Image?> _decode(GalleryEntry entry) async {
    try {
      final image = await _decoder(rgbaOf(entry), entry.width, entry.height);
      if (_disposed) {
        image.dispose();
        return null;
      }
      _images[entry.id] = image;
      _evict();
      notifyListeners();
      return image;
    } finally {
      _loading.remove(entry.id);
    }
  }

  void _evict() {
    while (_images.length > capacity) {
      final oldest = _images.keys.first;
      final image = _images.remove(oldest);
      // A painter may be using it in the frame being drawn: release afterwards.
      if (image != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
