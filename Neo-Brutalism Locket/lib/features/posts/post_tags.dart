import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Where post tags ("with Lan") are read and taken off.
abstract interface class PostTagsSource {
  /// Tagged user ids for each of [postIds] that has any.
  Future<Map<String, List<String>>> tagsOf(List<String> postIds);

  /// Takes my own name off [postId].
  Future<void> removeMine(String postId);
}

class SupabasePostTagsSource implements PostTagsSource {
  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<Map<String, List<String>>> tagsOf(List<String> postIds) async {
    if (postIds.isEmpty) return const {};
    final rows = await _db
        .from('post_tags')
        .select('post_id, user_id')
        .inFilter('post_id', postIds);
    final tags = <String, List<String>>{};
    for (final row in rows) {
      (tags[row['post_id'] as String] ??= []).add(row['user_id'] as String);
    }
    return tags;
  }

  @override
  Future<void> removeMine(String postId) =>
      _db.rpc('remove_my_tag', params: {'p_post': postId});
}

/// The tags of the posts in the feed, for the "with Lan" line on a post. A
/// database without tags (or no connection) just shows none.
class PostTagsStore extends ChangeNotifier {
  PostTagsStore(this.source, {required this.myId});

  final PostTagsSource source;
  final String myId;
  Map<String, List<String>> _tags = const {};

  /// Tagged user ids, by post id.
  Map<String, List<String>> get tags => _tags;

  Future<void> load(List<RemotePost> posts) async {
    try {
      _tags = await source.tagsOf([for (final p in posts) p.id]);
      notifyListeners();
    } catch (e, st) {
      AppLog.warn('post_tags', e, st);
    }
  }

  /// Takes my name off [postId]. It leaves the screen at once; if the server
  /// refuses, it comes back and the failure is rethrown.
  Future<void> removeMine(String postId) async {
    final before = _tags;
    final rest = [...?before[postId]]..remove(myId);
    _tags = {...before, postId: rest};
    notifyListeners();
    try {
      await source.removeMine(postId);
    } catch (_) {
      _tags = before;
      notifyListeners();
      rethrow;
    }
  }
}
