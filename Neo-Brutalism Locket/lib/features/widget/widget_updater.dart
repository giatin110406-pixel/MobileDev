import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/widget/widget_bridge.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the home-screen widget showing the newest photo from a friend: it
/// downloads the picture to this phone and tells the widget. Used by the app
/// (when it loads the feed) and by the background handler (when a friend
/// posts and the app is closed).
class WidgetUpdater {
  WidgetUpdater({
    this.bridge = const HomeWidgetBridge(),
    http.Client? client,
    Future<Directory> Function()? directory,
  }) : _client = client ?? http.Client(),
       _directory = directory ?? getApplicationSupportDirectory;

  final WidgetBridge bridge;
  final http.Client _client;
  final Future<Directory> Function() _directory;

  static const _shownKey = 'widget_post_id';
  static const _shownAtKey = 'widget_created_ms';
  static const _shownFileKey = 'widget_file';

  /// A silent push from the server: show that post. True when the widget was
  /// updated.
  Future<bool> applyData(Map<String, dynamic>? data) async {
    final post = parseWidgetData(data);
    return post != null && await show(post);
  }

  /// Downloads [post]'s picture and puts it on the widget. A post older than
  /// the one already shown is ignored (messages can arrive out of order).
  Future<bool> show(WidgetPost post) async {
    final preferences = await SharedPreferences.getInstance();
    final shownAt = preferences.getInt(_shownAtKey) ?? 0;
    if (preferences.getString(_shownKey) == post.postId) return false;
    if (post.createdAtMs != 0 && post.createdAtMs < shownAt) return false;

    final bytes = await _download(post.imageUrl);
    if (bytes == null) return false;
    final directory = await _directory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}widget_${post.postId}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    await bridge.show(post, file.path);

    final previous = preferences.getString(_shownFileKey);
    if (previous != null && previous != file.path) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
    await preferences.setString(_shownKey, post.postId);
    await preferences.setInt(_shownAtKey, post.createdAtMs);
    await preferences.setString(_shownFileKey, file.path);
    return true;
  }

  /// The app loaded the feed: make sure the widget shows the newest friend
  /// photo. Does nothing when it already does.
  Future<void> refreshFromFeed({
    required List<RemotePost> posts,
    required String myId,
    required Map<String, String> friendNames,
    required MediaUrls urls,
  }) async {
    final post = latestFriendPost(
      posts,
      myId: myId,
      friendIds: friendNames.keys.toSet(),
    );
    if (post == null) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_shownKey) == post.id) return;
    final url = await urls.resolve('media', post.thumbPath ?? post.mediaPath);
    if (url == null) return;
    await show(
      WidgetPost(
        postId: post.id,
        name: friendNames[post.authorId] ?? '',
        caption: post.caption,
        createdAtMs: post.createdAt.millisecondsSinceEpoch,
        imageUrl: url,
      ),
    );
  }

  /// Signed out: leave nothing of the account on the home screen.
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final file = preferences.getString(_shownFileKey);
    await preferences.remove(_shownKey);
    await preferences.remove(_shownAtKey);
    await preferences.remove(_shownFileKey);
    await bridge.clear();
    if (file != null) {
      try {
        await File(file).delete();
      } catch (_) {}
    }
  }

  Future<List<int>?> _download(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200 && response.bodyBytes.isNotEmpty
          ? response.bodyBytes
          : null;
    } catch (_) {
      return null;
    }
  }
}
