import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';

/// The chat of one group. Messages from the others arrive by themselves;
/// sending reloads so the screen shows what the server really stored.
///
/// This does not own the repository: [GroupsStore] does.
class GroupChatStore extends ChangeNotifier {
  GroupChatStore(this.repository, {required this.groupId, required this.myId}) {
    _subscription = repository.incomingMessages.listen(_onIncoming);
  }

  final GroupsRepository repository;
  final String groupId;
  final String myId;
  StreamSubscription<GroupMessage>? _subscription;
  List<GroupMessage> _messages = const [];
  bool _loaded = false;
  bool _failed = false;
  bool _sending = false;

  /// Oldest first, so the newest sits at the bottom.
  List<GroupMessage> get messages => _messages;
  bool get isLoaded => _loaded;

  /// The last load could not reach the server (old messages stay).
  bool get failed => _failed;
  bool get sending => _sending;

  Future<void> load() async {
    try {
      _messages = await repository.loadMessages(groupId);
      _loaded = true;
      _failed = false;
      unawaited(_markRead());
    } on GroupFailure {
      _failed = true;
    }
    notifyListeners();
  }

  void _onIncoming(GroupMessage message) {
    if (message.groupId != groupId) return;
    if (_messages.any((m) => m.id == message.id)) return;
    _messages = [..._messages, message];
    notifyListeners();
    if (message.senderId != myId) unawaited(_markRead());
  }

  Future<void> _markRead() async {
    try {
      await repository.markRead(groupId);
    } on GroupFailure {
      // The unread badge may stay a little longer; nothing to tell the user.
    }
  }

  /// Throws [GroupFailure].
  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || _sending) return;
    _sending = true;
    notifyListeners();
    try {
      await repository.sendMessage(groupId, text);
      // The realtime echo usually arrives first; load covers the case it did not.
      final fresh = await repository.loadMessages(groupId);
      _messages = fresh;
      _failed = false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
