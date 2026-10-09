import 'dart:async';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A chat message as stored on the server.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.postId,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final String? postId;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    senderId: row['sender_id'] as String,
    recipientId: row['recipient_id'] as String,
    body: row['body'] as String,
    postId: row['post_id'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    readAt: row['read_at'] == null
        ? null
        : DateTime.parse(row['read_at'] as String).toLocal(),
  );
}

enum ChatFailureKind { notFound, empty, tooLong, network, unknown }

class ChatFailure implements Exception {
  const ChatFailure(this.kind);

  final ChatFailureKind kind;

  @override
  String toString() => 'ChatFailure($kind)';
}

abstract interface class ChatRepository {
  /// The latest messages I sent or received, newest first.
  Future<List<ChatMessage>> loadRecent({int limit = 500});

  Future<void> send({
    required String toId,
    required String body,
    String? postId,
  });

  Future<void> markRead(String friendId);

  /// Fires when a friend sends me a message (while the app runs).
  Stream<void> get incoming;

  void dispose();
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({required this.myId});

  final String myId;
  final _incoming = StreamController<void>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Stream<void> get incoming {
    _channel ??= _db
        .channel('chat-$myId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'recipient_id',
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
  Future<List<ChatMessage>> loadRecent({int limit = 500}) => _guard(() async {
    final rows = await _db
        .from('messages')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in rows) ChatMessage.fromRow(row)];
  });

  @override
  Future<void> send({
    required String toId,
    required String body,
    String? postId,
  }) => _guard(
    () => _db.rpc(
      'send_message',
      params: {'p_to': toId, 'p_body': body, 'p_post': postId},
    ),
  );

  @override
  Future<void> markRead(String friendId) =>
      _guard(() => _db.rpc('mark_thread_read', params: {'p_with': friendId}));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw ChatFailure(switch (error.message) {
        'not_found' => ChatFailureKind.notFound,
        'empty' => ChatFailureKind.empty,
        'too_long' => ChatFailureKind.tooLong,
        _ => ChatFailureKind.unknown,
      });
    } catch (_) {
      throw const ChatFailure(ChatFailureKind.network);
    }
  }
}
