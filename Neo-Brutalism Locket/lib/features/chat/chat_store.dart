import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';

/// The signed-in person's chat messages. New messages from friends arrive by
/// themselves (realtime); sending reloads so the screen shows what the
/// server really stored.
class ChatStore extends ChangeNotifier {
  ChatStore(this.repository, {required this.myId}) {
    _subscription = repository.incoming.listen((_) => refresh());
  }

  final ChatRepository repository;
  final String myId;
  StreamSubscription<void>? _subscription;
  List<ChatMessage> _messages = const [];
  bool _loading = false;
  bool _again = false;
  bool _failed = false;

  /// Newest first, as the server returned them.
  List<ChatMessage> get messages => _messages;

  /// The last refresh could not reach the server (old messages stay).
  bool get failed => _failed;

  String otherOf(ChatMessage message) =>
      message.senderId == myId ? message.recipientId : message.senderId;

  int unreadFrom(String friendId) =>
      _messages.where((m) => m.senderId == friendId && m.readAt == null).length;

  /// The messages in the shape the chat screens use. [captionOf] gives the
  /// caption of a post the message is about, if known.
  List<PocketMessage> asPocketMessages({
    String? Function(String postId)? captionOf,
  }) {
    final ordered = [..._messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final m in ordered)
        PocketMessage(
          id: m.id,
          friendId: otherOf(m),
          text: m.body,
          createdAt: m.createdAt,
          isMine: m.senderId == myId,
          isRead: m.senderId == myId || m.readAt != null,
          replyToPostId: m.postId,
          replyPreview: m.postId == null
              ? null
              : (captionOf?.call(m.postId!) ?? ''),
        ),
    ];
  }

  Future<void> refresh() async {
    // Asked again while loading (say a new message arrived): load once more
    // when this load ends, so the newest data is not missed.
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    _again = false;
    try {
      _messages = await repository.loadRecent();
      _failed = false;
    } on ChatFailure {
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (_again) await refresh();
  }

  /// Throws [ChatFailure] when the message could not be sent.
  Future<void> send({
    required String toId,
    required String body,
    String? postId,
  }) async {
    await repository.send(toId: toId, body: body, postId: postId);
    await refresh();
  }

  /// Marks the conversation read now (the badge drops at once) and tells the
  /// server.
  Future<void> markRead(String friendId) async {
    if (unreadFrom(friendId) == 0) return;
    final now = DateTime.now();
    _messages = [
      for (final m in _messages)
        m.senderId == friendId && m.readAt == null
            ? ChatMessage(
                id: m.id,
                senderId: m.senderId,
                recipientId: m.recipientId,
                body: m.body,
                createdAt: m.createdAt,
                postId: m.postId,
                readAt: now,
              )
            : m,
    ];
    notifyListeners();
    try {
      await repository.markRead(friendId);
    } on ChatFailure {
      // The badge comes back on the next refresh if the server missed it.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
