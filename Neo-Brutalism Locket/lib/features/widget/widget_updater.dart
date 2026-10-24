import 'package:neo_brutalism_locket/core/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/widget/widget_bridge.dart';
import 'package:neo_brutalism_locket/features/widget/widget_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What one source of widgets shows now.
class _Shown {
  const _Shown({
    required this.postId,
    required this.createdAtMs,
    required this.file,
  });

  final String postId;
  final int createdAtMs;
  final String file;

  Map<String, Object> toJson() => {
    'id': postId,
    'at': createdAtMs,
    'file': file,
  };

  static _Shown? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final file = json['file'];
    if (id is! String || file is! String) return null;
    return _Shown(
      postId: id,
      createdAtMs: json['at'] is int ? json['at'] as int : 0,
      file: file,
    );
  }
}

/// Keeps the home-screen widgets showing the newest photo from a friend: it
/// downloads the picture to this phone and tells the widget. Used by the app
/// (when it loads the feed) and by the background handler (when a friend
/// posts and the app is closed).
///
/// A widget can follow everybody ([allSource]), one friend or one group; a
/// picture is downloaded only for the sources some placed widget follows.
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

  /// {source: what it shows}, as JSON.
  static const _stateKey = 'widget_state_v2';

  /// {group id: [member ids]}, as JSON: the background handler needs it to
  /// tell which group a push belongs to.
  static const _groupsKey = 'widget_groups_v1';

  /// A silent push from the server: show that post. True when a widget was
  /// updated.
  Future<bool> applyData(Map<String, dynamic>? data) async {
    final post = parseWidgetData(data);
    if (post == null) return false;
    var updated = await show(post);
    final author = post.authorId;
    if (author == null) return updated;
    final preferences = await SharedPreferences.getInstance();
    final groups = _readGroups(preferences);
    for (final source in await bridge.activeSources()) {
      final follows = source.startsWith('g_')
          ? groups[source.substring(2)]?.contains(author) ?? false
          : source == friendSource(author);
      if (follows && await show(post, source: source)) updated = true;
    }
    return updated;
  }

  /// Downloads [post]'s picture and puts it on the widgets that follow
  /// [source]. A post older than the one already shown is ignored (messages
  /// can arrive out of order).
  Future<bool> show(WidgetPost post, {String source = allSource}) async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readState(preferences);
    final shown = state[source];
    if (shown?.postId == post.postId) return false;
    if (post.createdAtMs != 0 && post.createdAtMs < (shown?.createdAtMs ?? 0)) {
      return false;
    }

    final bytes = await _bytesFor(post, state);
    if (bytes == null) return false;
    final directory = await _directory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'widget_${source == allSource ? '' : '${source}_'}${post.postId}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    await bridge.show(post, file.path, source: source);

    state[source] = _Shown(
      postId: post.postId,
      createdAtMs: post.createdAtMs,
      file: file.path,
    );
    await _writeState(preferences, state);
    // After the new picture is recorded: another source may still show the old
    // file, and then it stays.
    if (shown != null && shown.file != file.path) {
      await _delete(shown.file, except: state);
    }
    return true;
  }

  /// The app loaded the feed: make sure each widget shows the newest photo
  /// for what it follows, and tell the picker which friends and groups there
  /// are. Does nothing for a widget that already shows the right photo.
  Future<void> refreshFromFeed({
    required List<RemotePost> posts,
    required String myId,
    required Map<String, String> friendNames,
    required MediaUrls urls,
    List<WidgetGroup> groups = const [],
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await _writeGroups(preferences, groups);
    try {
      await bridge.publishChoices([
        for (final entry in friendNames.entries)
          WidgetChoice(key: friendSource(entry.key), label: entry.value),
        for (final group in groups)
          WidgetChoice(key: groupSource(group.id), label: group.name),
      ]);
    } catch (e, st) {
      AppLog.warn('widget_updater', e, st);
    }
    final memberIds = {for (final group in groups) group.id: group.memberIds};
    final sources = {allSource, ...await bridge.activeSources()};
    for (final source in sources) {
      final post = latestPostForSource(
        posts,
        source,
        myId: myId,
        friendIds: friendNames.keys.toSet(),
        groups: memberIds,
      );
      if (post == null) continue;
      if (_readState(preferences)[source]?.postId == post.id) continue;
      final url = await urls.resolve('media', post.thumbPath ?? post.mediaPath);
      if (url == null) continue;
      await show(
        WidgetPost(
          postId: post.id,
          authorId: post.authorId,
          name: friendNames[post.authorId] ?? '',
          caption: post.caption,
          createdAtMs: post.createdAt.millisecondsSinceEpoch,
          imageUrl: url,
        ),
        source: source,
      );
    }
  }

  /// Signed out: leave nothing of the account on the home screen.
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final state = _readState(preferences);
    await preferences.remove(_stateKey);
    await preferences.remove(_groupsKey);
    await bridge.clear(sources: state.keys.where((s) => s != allSource));
    for (final shown in state.values) {
      await _delete(shown.file);
    }
  }

  /// The picture of [post]: the copy another source already holds, or a
  /// download.
  Future<List<int>?> _bytesFor(
    WidgetPost post,
    Map<String, _Shown> state,
  ) async {
    for (final shown in state.values) {
      if (shown.postId != post.postId) continue;
      try {
        return await File(shown.file).readAsBytes();
      } catch (_) {
        break;
      }
    }
    return _download(post.imageUrl);
  }

  /// Deletes [path] unless another source still shows that file.
  Future<void> _delete(String path, {Map<String, _Shown>? except}) async {
    if (except != null && except.values.any((s) => s.file == path)) return;
    try {
      await File(path).delete();
    } catch (e, st) {
      AppLog.warn('widget_updater', e, st);
    }
  }

  Map<String, _Shown> _readState(SharedPreferences preferences) {
    final stored = preferences.getString(_stateKey);
    if (stored == null) return {};
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return {
        for (final entry in json.entries)
          entry.key: ?_Shown.fromJson(entry.value),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeState(
    SharedPreferences preferences,
    Map<String, _Shown> state,
  ) => preferences.setString(
    _stateKey,
    jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
  );

  Map<String, Set<String>> _readGroups(SharedPreferences preferences) {
    final stored = preferences.getString(_groupsKey);
    if (stored == null) return {};
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return {
        for (final entry in json.entries)
          entry.key: {for (final id in entry.value as List) id as String},
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeGroups(
    SharedPreferences preferences,
    List<WidgetGroup> groups,
  ) => preferences.setString(
    _groupsKey,
    jsonEncode({
      for (final group in groups) group.id: group.memberIds.toList(),
    }),
  );

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
