import 'dart:async';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Someone's emoji on a post.
class Reaction {
  const Reaction({
    required this.postId,
    required this.userId,
    required this.emoji,
  });

  final String postId;
  final String userId;
  final String emoji;
}

/// What happened to one of MY posts: who reacted and who looked at it.
class PostActivity {
  const PostActivity({this.reactions = const [], this.viewerIds = const {}});

  final List<Reaction> reactions;
  final Set<String> viewerIds;

  bool get isEmpty => reactions.isEmpty && viewerIds.isEmpty;
}

abstract interface class InteractionsRepository {
  /// Sets (or, with a null [emoji], removes) my reaction to a post I received.
  Future<void> react(String postId, String? emoji);

  /// Tells the author I opened the post. Safe to repeat.
  Future<void> markViewed(String postId);

  /// Deletes my post for everyone and removes its files.
  Future<void> deletePost(String postId, {required List<String> filePaths});

  /// Reactions and viewers of the given posts of mine.
  Future<Map<String, PostActivity>> loadActivity(List<String> myPostIds);

  /// My own reactions to posts I received, by post id.
  Future<Map<String, String>> loadMyReactions(List<String> postIds);

  /// Fires when someone reacts to a post of mine (while the app runs).
  Stream<void> get reactionsChanged;

  void dispose();
}

class InteractionFailure implements Exception {
  const InteractionFailure({this.detail});

  final String? detail;

  @override
  String toString() => 'InteractionFailure($detail)';
}

class SupabaseInteractionsRepository implements InteractionsRepository {
  SupabaseInteractionsRepository({required this.myId});

  final String myId;
  final _changes = StreamController<void>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Stream<void> get reactionsChanged {
    // Row-level security means only reactions on my own posts reach me.
    _channel ??= _db
        .channel('reactions-$myId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'post_reactions',
          callback: (_) => _changes.add(null),
        )
        .subscribe();
    return _changes.stream;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _changes.close();
  }

  @override
  Future<void> react(String postId, String? emoji) => _guard(
    () =>
        _db.rpc('react_to_post', params: {'p_post': postId, 'p_emoji': emoji}),
  );

  @override
  Future<void> markViewed(String postId) =>
      _guard(() => _db.rpc('mark_post_viewed', params: {'p_post': postId}));

  @override
  Future<void> deletePost(String postId, {required List<String> filePaths}) =>
      _guard(() async {
        await _db.rpc('delete_post', params: {'p_post': postId});
        try {
          await _db.storage.from('media').remove(filePaths);
        } catch (_) {
          // The post is already gone for everyone; leftover files are harmless.
        }
      });

  @override
  Future<Map<String, PostActivity>> loadActivity(List<String> myPostIds) =>
      _guard(() async {
        if (myPostIds.isEmpty) return const {};
        final results = await Future.wait([
          _db
              .from('post_reactions')
              .select('post_id, user_id, emoji')
              .inFilter('post_id', myPostIds),
          _db
              .from('post_views')
              .select('post_id, viewer_id')
              .inFilter('post_id', myPostIds),
        ]);
        final reactions = <String, List<Reaction>>{};
        for (final row in results[0]) {
          final postId = row['post_id'] as String;
          (reactions[postId] ??= []).add(
            Reaction(
              postId: postId,
              userId: row['user_id'] as String,
              emoji: row['emoji'] as String,
            ),
          );
        }
        final viewers = <String, Set<String>>{};
        for (final row in results[1]) {
          (viewers[row['post_id'] as String] ??= {}).add(
            row['viewer_id'] as String,
          );
        }
        return {
          for (final id in {...reactions.keys, ...viewers.keys})
            id: PostActivity(
              reactions: reactions[id] ?? const [],
              viewerIds: viewers[id] ?? const {},
            ),
        };
      });

  @override
  Future<Map<String, String>> loadMyReactions(List<String> postIds) =>
      _guard(() async {
        if (postIds.isEmpty) return const {};
        final rows = await _db
            .from('post_reactions')
            .select('post_id, emoji')
            .eq('user_id', myId)
            .inFilter('post_id', postIds);
        return {
          for (final row in rows)
            row['post_id'] as String: row['emoji'] as String,
        };
      });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw InteractionFailure(detail: error.message);
    } catch (error) {
      throw InteractionFailure(detail: '$error');
    }
  }
}
