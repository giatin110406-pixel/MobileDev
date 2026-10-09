import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/posts/media_encoding.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// The first frame of a video as a 360px JPEG.
Future<Uint8List?> makeVideoThumbnail(String videoPath) =>
    VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 360,
      quality: 75,
    );

/// Posts waiting to be uploaded. A post is saved here first and sent from
/// here, so taking a photo with no signal still works: it goes out once the
/// phone is online again, even after the app was closed.
class PostOutbox extends ChangeNotifier {
  PostOutbox({
    required this.repository,
    required this.userId,
    this.maxAttempts = 3,
    this.folder,
    this.encode = encodePhotoForUpload,
    this.videoThumbnail = makeVideoThumbnail,
  });

  final PostsRepository repository;

  /// Keeps one account's queue apart from another's on the same phone.
  final String userId;

  /// A post the server refuses this many times is dropped.
  final int maxAttempts;

  /// Where encoded pictures wait (the app's documents folder by default).
  final Directory? folder;
  final Future<EncodedPhoto> Function(Uint8List bytes, {required bool lossless})
  encode;

  /// A JPEG still of a video for the grid and the widget (null if none).
  final Future<Uint8List?> Function(String videoPath) videoThumbnail;

  List<PendingPost>? _items;
  bool _flushing = false;

  String get _key => 'post_outbox_v1_$userId';

  /// Posts not sent yet.
  Future<List<PendingPost>> pending() async => List.of(await _load());

  Future<List<PendingPost>> _load() async {
    final cached = _items;
    if (cached != null) return cached;
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);
    return _items = stored == null
        ? []
        : [
            for (final item in jsonDecode(stored) as List<dynamic>)
              PendingPost.fromJson(item as Map<String, dynamic>),
          ];
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode([for (final item in _items ?? []) item.toJson()]),
    );
  }

  Future<Directory> _dir() async {
    final base = folder ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}outbox');
    await dir.create(recursive: true);
    return dir;
  }

  /// Encodes [source] (the picture file to send) and queues it. Returns the
  /// new post's id. Nothing is uploaded until [flush].
  Future<String> enqueue({
    required File source,
    required String caption,
    StyleType? style,
    String? questId,
    Map<String, dynamic>? overlay,
    List<String>? recipients,
  }) async {
    final encoded = await encode(
      await source.readAsBytes(),
      lossless: style == StyleType.pixel8bit,
    );
    final dir = await _dir();
    final id = newUuid();
    final base = '${dir.path}${Platform.pathSeparator}$id';
    final mediaFile = '$base.${encoded.extension}';
    final thumbFile = '${base}_thumb.jpg';
    await File(mediaFile).writeAsBytes(encoded.media, flush: true);
    await File(thumbFile).writeAsBytes(encoded.thumb, flush: true);
    final items = await _load();
    items.add(
      PendingPost(
        id: id,
        mediaFile: mediaFile,
        thumbFile: thumbFile,
        extension: encoded.extension,
        caption: caption.trim(),
        style: style,
        questId: questId,
        overlay: overlay,
        recipients: recipients,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    notifyListeners();
    return id;
  }

  /// Copies a recorded [video] (MP4) into the queue with a thumbnail. Videos
  /// are sent as recorded: they skip the photo styles.
  Future<String> enqueueVideo({
    required File video,
    required String caption,
    Map<String, dynamic>? overlay,
    List<String>? recipients,
  }) async {
    final dir = await _dir();
    final id = newUuid();
    final base = '${dir.path}${Platform.pathSeparator}$id';
    final mediaFile = '$base.mp4';
    await video.copy(mediaFile);
    String? thumbFile;
    try {
      final thumb = await videoThumbnail(mediaFile);
      if (thumb != null) {
        thumbFile = '${base}_thumb.jpg';
        await File(thumbFile).writeAsBytes(thumb, flush: true);
      }
    } catch (_) {
      // A video without a still is fine; the grid shows an icon instead.
    }
    final items = await _load();
    items.add(
      PendingPost(
        id: id,
        kind: 'video',
        mediaFile: mediaFile,
        thumbFile: thumbFile,
        extension: 'mp4',
        caption: caption.trim(),
        overlay: overlay,
        recipients: recipients,
        createdAt: DateTime.now(),
      ),
    );
    await _save();
    notifyListeners();
    return id;
  }

  /// Tries to send everything waiting, oldest first. Stops at the first
  /// connection problem (the rest would fail too). Returns how many went out.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final items = await _load();
      for (final item in List.of(items)) {
        try {
          await repository.send(item);
          items.remove(item);
          await _delete(item);
          sent++;
        } on PostsFailure catch (failure) {
          if (failure.retryable) break;
          final index = items.indexOf(item);
          if (item.attempts + 1 >= maxAttempts) {
            items.removeAt(index);
            await _delete(item);
          } else {
            items[index] = item.failedOnce();
          }
        }
        await _save();
      }
      if (sent > 0) notifyListeners();
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<void> _delete(PendingPost item) async {
    for (final path in [item.mediaFile, ?item.thumbFile]) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}
