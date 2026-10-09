import 'dart:async';

import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_repository.dart';

/// In-memory chat server for tests.
class FakeChat implements ChatRepository {
  FakeChat({this.myId = 'me', List<ChatMessage>? messages})
    : messages = messages ?? [];

  final String myId;
  final List<ChatMessage> messages; // newest first
  final sent = <({String to, String body, String? postId})>[];
  final marked = <String>[];
  ChatFailure? failSend;
  final _incoming = StreamController<void>.broadcast();
  var _counter = 0;

  @override
  Future<List<ChatMessage>> loadRecent({int limit = 500}) async =>
      List.of(messages);

  @override
  Future<void> send({
    required String toId,
    required String body,
    String? postId,
  }) async {
    final failure = failSend;
    if (failure != null) throw failure;
    sent.add((to: toId, body: body, postId: postId));
    messages.insert(
      0,
      ChatMessage(
        id: 'm${_counter++}',
        senderId: myId,
        recipientId: toId,
        body: body,
        postId: postId,
        createdAt: DateTime(2026, 1, 1, 12, _counter),
      ),
    );
  }

  @override
  Future<void> markRead(String friendId) async {
    marked.add(friendId);
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.senderId == friendId && m.readAt == null) {
        messages[i] = ChatMessage(
          id: m.id,
          senderId: m.senderId,
          recipientId: m.recipientId,
          body: m.body,
          createdAt: m.createdAt,
          postId: m.postId,
          readAt: DateTime(2026, 1, 2),
        );
      }
    }
  }

  /// A friend writes to me.
  void receive(String from, String body) {
    messages.insert(
      0,
      ChatMessage(
        id: 'm${_counter++}',
        senderId: from,
        recipientId: myId,
        body: body,
        createdAt: DateTime(2026, 1, 1, 13, _counter),
      ),
    );
    _incoming.add(null);
  }

  @override
  Stream<void> get incoming => _incoming.stream;

  @override
  void dispose() => _incoming.close();
}

/// In-memory reactions / views for tests.
class FakeInteractions implements InteractionsRepository {
  FakeInteractions({
    Map<String, PostActivity>? activity,
    Map<String, String>? mine,
  }) : activity = activity ?? {},
       mine = mine ?? {};

  final Map<String, PostActivity> activity;
  final Map<String, String> mine;
  final reacted = <String, String?>{};
  final viewed = <String>[];
  final deleted = <String>[];
  InteractionFailure? failReact;
  final _changes = StreamController<void>.broadcast();

  @override
  Future<void> react(String postId, String? emoji) async {
    final failure = failReact;
    if (failure != null) throw failure;
    reacted[postId] = emoji;
    if (emoji == null) {
      mine.remove(postId);
    } else {
      mine[postId] = emoji;
    }
  }

  @override
  Future<void> markViewed(String postId) async => viewed.add(postId);

  @override
  Future<void> deletePost(
    String postId, {
    required List<String> filePaths,
  }) async => deleted.add(postId);

  @override
  Future<Map<String, PostActivity>> loadActivity(
    List<String> myPostIds,
  ) async => {
    for (final id in myPostIds)
      if (activity.containsKey(id)) id: activity[id]!,
  };

  @override
  Future<Map<String, String>> loadMyReactions(List<String> postIds) async => {
    for (final id in postIds)
      if (mine.containsKey(id)) id: mine[id]!,
  };

  void someoneReacted() => _changes.add(null);

  @override
  Stream<void> get reactionsChanged => _changes.stream;

  @override
  void dispose() => _changes.close();
}
