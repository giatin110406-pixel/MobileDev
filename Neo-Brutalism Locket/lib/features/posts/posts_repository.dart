import 'dart:async';
import 'dart:io';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A post could not be sent or loaded.
class PostsFailure implements Exception {
  const PostsFailure({required this.retryable, this.detail});

  /// True for "no connection / server hiccup": try again later. False when
  /// the server refused the post for good.
  final bool retryable;
  final String? detail;

  @override
  String toString() => 'PostsFailure(retryable: $retryable, $detail)';
}

abstract interface class PostsRepository {
  /// Posts sent to me and posts I sent, newest first.
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30});

  /// Uploads the picture and creates the post. Safe to repeat for the same
  /// [PendingPost.id].
  Future<void> send(PendingPost post);

  /// Fires when someone sends me a post (and the app is running).
  Stream<void> get incoming;

  void dispose();
}

class SupabasePostsRepository implements PostsRepository {
  SupabasePostsRepository({required this.myId});

  final String myId;
  final _incoming = StreamController<void>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Stream<void> get incoming {
    _channel ??= _db
        .channel('post-inbox-$myId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'post_recipients',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'user_id',
            value: myId,
          ),
          callback: (_) => _incoming.add(null),
        )
        .subscribe();
    return _incoming.stream;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _incoming.close();
  }

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) =>
      _guard(() async {
        final cursor = before?.toUtc().toIso8601String();
        var received = _db
            .from('post_recipients')
            .select('created_at, post:posts!inner(${RemotePost.columns})')
            .eq('user_id', myId)
            .filter('post.deleted_at', 'is', null);
        var mine = _db
            .from('posts')
            .select(RemotePost.columns)
            .eq('author_id', myId)
            .filter('deleted_at', 'is', null);
        if (cursor != null) {
          received = received.lt('created_at', cursor);
          mine = mine.lt('created_at', cursor);
        }
        final results = await Future.wait([
          received.order('created_at', ascending: false).limit(limit),
          mine.order('created_at', ascending: false).limit(limit),
        ]);
        final byId = <String, RemotePost>{};
        for (final row in results[0]) {
          final post = RemotePost.fromRow(row['post'] as Map<String, dynamic>);
          byId[post.id] = post;
        }
        for (final row in results[1]) {
          final post = RemotePost.fromRow(row);
          byId[post.id] = post;
        }
        final posts = byId.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts.take(limit).toList();
      });

  @override
  Future<void> send(PendingPost post) => _guard(() async {
    final mediaPath = '$myId/${post.id}.${post.extension}';
    final thumbFile = post.thumbFile;
    final thumbPath = thumbFile == null ? null : '$myId/${post.id}_thumb.jpg';
    final storage = _db.storage.from('media');
    await storage.upload(
      mediaPath,
      File(post.mediaFile),
      fileOptions: sb.FileOptions(contentType: post.contentType, upsert: true),
    );
    if (thumbFile != null && thumbPath != null) {
      await storage.upload(
        thumbPath,
        File(thumbFile),
        fileOptions: const sb.FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
    }
    await _db.rpc(
      'create_post',
      params: {
        'p_id': post.id,
        'p_kind': post.kind,
        'p_media_path': mediaPath,
        'p_thumb_path': thumbPath,
        'p_caption': post.caption,
        'p_style': post.style?.name,
        'p_quest_id': post.questId,
        'p_overlay': post.overlay,
        'p_recipients': post.recipients,
      },
    );
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      // Server-side rule errors (bad_path, caption_too_long, ...) never get
      // better by retrying; 5xx and gateway errors might.
      final code = int.tryParse(error.code ?? '');
      throw PostsFailure(
        retryable: code != null && code >= 500,
        detail: error.message,
      );
    } on sb.StorageException catch (error) {
      final status = int.tryParse(error.statusCode ?? '');
      throw PostsFailure(
        retryable: status == null || status >= 500 || status == 408,
        detail: error.message,
      );
    } on sb.AuthException catch (error) {
      throw PostsFailure(retryable: true, detail: error.message);
    } on PostsFailure {
      rethrow;
    } catch (error) {
      // Socket errors, timeouts, closed connections: just no network.
      throw PostsFailure(retryable: true, detail: '$error');
    }
  }
}
