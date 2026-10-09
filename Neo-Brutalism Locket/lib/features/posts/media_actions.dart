import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:share_plus/share_plus.dart';

/// Save a picture to the phone's photo library or share it with other apps.
/// Both download the full picture first (private links expire).
class MediaActions {
  MediaActions(this._urls, {http.Client? client})
    : _client = client ?? http.Client();

  final MediaUrls? _urls;
  final http.Client _client;

  Future<Uint8List?> _download(String path) async {
    final urls = _urls;
    if (urls == null) return null;
    final url = await urls.resolve('media', path);
    if (url == null) return null;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  /// True when the picture is in the photo library now.
  Future<bool> save(String path) async {
    final bytes = await _download(path);
    if (bytes == null) return false;
    try {
      await Gal.putImageBytes(bytes, name: 'pocket_portrait_${path.hashCode}');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when the share sheet was opened.
  Future<bool> share(String path, {String text = ''}) async {
    final bytes = await _download(path);
    if (bytes == null) return false;
    try {
      final isPng = path.endsWith('.png');
      await SharePlus.instance.share(
        ShareParams(
          text: text.isEmpty ? null : text,
          files: [
            XFile.fromData(
              bytes,
              mimeType: isPng ? 'image/png' : 'image/jpeg',
              name: isPng ? 'photo.png' : 'photo.jpg',
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
