import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PocketFriend {
  const PocketFriend({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarColor,
    required this.isSample,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String handle;
  final int avatarColor;
  final bool isSample;
  final DateTime addedAt;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'handle': handle,
    'avatarColor': avatarColor,
    'isSample': isSample,
    'addedAt': addedAt.toIso8601String(),
  };

  factory PocketFriend.fromJson(Map<String, dynamic> json) => PocketFriend(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    avatarColor: json['avatarColor'] as int,
    isSample: json['isSample'] as bool? ?? false,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}

class PocketMessage {
  const PocketMessage({
    required this.id,
    required this.friendId,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
    this.photoPath,
  });

  final String id;
  final String friendId;
  final String text;
  final String? photoPath;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  Map<String, Object?> toJson() => {
    'id': id,
    'friendId': friendId,
    'text': text,
    'photoPath': photoPath,
    'createdAt': createdAt.toIso8601String(),
    'isMine': isMine,
    'isRead': isRead,
  };

  factory PocketMessage.fromJson(Map<String, dynamic> json) => PocketMessage(
    id: json['id'] as String,
    friendId: json['friendId'] as String,
    text: json['text'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isMine: json['isMine'] as bool,
    isRead: json['isRead'] as bool? ?? true,
  );
}

class SocialSnapshot {
  const SocialSnapshot({required this.friends, required this.messages});

  final List<PocketFriend> friends;
  final List<PocketMessage> messages;
}

class SocialRepository {
  static const _friendsKey = 'pocket_friends_v1';
  static const _messagesKey = 'pocket_messages_v1';
  static const _avatarColors = [
    0xFFFF6B6B,
    0xFFA388EE,
    0xFF4ECDC4,
    0xFFFFE66D,
    0xFF45B7D1,
    0xFFF7A072,
  ];

  Future<SocialSnapshot> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedFriends = preferences.getString(_friendsKey);
    final storedMessages = preferences.getString(_messagesKey);
    if (storedFriends == null) {
      final seeded = _sampleSnapshot();
      await _save(preferences, seeded);
      return seeded;
    }

    return SocialSnapshot(
      friends: _decodeList(storedFriends, PocketFriend.fromJson),
      messages: storedMessages == null
          ? const []
          : _decodeList(storedMessages, PocketMessage.fromJson),
    );
  }

  Future<SocialSnapshot> addFriend({
    required String name,
    required String handle,
  }) async {
    final cleanName = name.trim();
    final cleanHandle = _normalizeHandle(handle);
    if (cleanName.isEmpty || cleanHandle.length < 2) {
      throw const FormatException('Enter a name and handle.');
    }

    final snapshot = await load();
    if (snapshot.friends.any(
      (friend) => friend.handle.toLowerCase() == cleanHandle.toLowerCase(),
    )) {
      throw const FormatException('That handle is already in your friends.');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final friend = PocketFriend(
      id: id,
      name: cleanName,
      handle: cleanHandle,
      avatarColor:
          _avatarColors[snapshot.friends.length % _avatarColors.length],
      isSample: false,
      addedAt: DateTime.now(),
    );
    final updated = SocialSnapshot(
      friends: [friend, ...snapshot.friends],
      messages: snapshot.messages,
    );
    await _persist(updated);
    return updated;
  }

  Future<SocialSnapshot> removeFriend(String friendId) async {
    final snapshot = await load();
    final updated = SocialSnapshot(
      friends: snapshot.friends
          .where((friend) => friend.id != friendId)
          .toList(),
      messages: snapshot.messages
          .where((message) => message.friendId != friendId)
          .toList(),
    );
    await _persist(updated);
    return updated;
  }

  Future<SocialSnapshot> sendMessage({
    required String friendId,
    String text = '',
    String? photoPath,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty && photoPath == null) {
      throw const FormatException('Write a message or attach a print.');
    }

    final snapshot = await load();
    if (!snapshot.friends.any((friend) => friend.id == friendId)) {
      throw const FormatException('Friend not found.');
    }
    final message = PocketMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      friendId: friendId,
      text: cleanText,
      photoPath: photoPath,
      createdAt: DateTime.now(),
      isMine: true,
      isRead: true,
    );
    final updated = SocialSnapshot(
      friends: snapshot.friends,
      messages: [...snapshot.messages, message],
    );
    await _persist(updated);
    return updated;
  }

  Future<SocialSnapshot> markThreadRead(String friendId) async {
    final snapshot = await load();
    final updated = SocialSnapshot(
      friends: snapshot.friends,
      messages: snapshot.messages
          .map(
            (message) => message.friendId == friendId && !message.isMine
                ? PocketMessage(
                    id: message.id,
                    friendId: message.friendId,
                    text: message.text,
                    photoPath: message.photoPath,
                    createdAt: message.createdAt,
                    isMine: false,
                    isRead: true,
                  )
                : message,
          )
          .toList(),
    );
    await _persist(updated);
    return updated;
  }

  Future<void> _persist(SocialSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await _save(preferences, snapshot);
  }

  Future<void> _save(
    SharedPreferences preferences,
    SocialSnapshot snapshot,
  ) async {
    await preferences.setString(
      _friendsKey,
      jsonEncode(snapshot.friends.map((friend) => friend.toJson()).toList()),
    );
    await preferences.setString(
      _messagesKey,
      jsonEncode(snapshot.messages.map((message) => message.toJson()).toList()),
    );
  }

  List<T> _decodeList<T>(
    String value,
    T Function(Map<String, dynamic>) fromJson,
  ) => (jsonDecode(value) as List<dynamic>)
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();

  String _normalizeHandle(String handle) {
    final cleaned = handle.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    if (cleaned.isEmpty) return cleaned;
    return cleaned.startsWith('@') ? cleaned : '@$cleaned';
  }

  SocialSnapshot _sampleSnapshot() {
    final now = DateTime.now();
    final friends = [
      PocketFriend(
        id: 'sample-ava',
        name: 'Ava Chen',
        handle: '@ava.chen',
        avatarColor: _avatarColors[0],
        isSample: true,
        addedAt: now.subtract(const Duration(days: 4)),
      ),
      PocketFriend(
        id: 'sample-jules',
        name: 'Jules Kim',
        handle: '@jules.kim',
        avatarColor: _avatarColors[2],
        isSample: true,
        addedAt: now.subtract(const Duration(days: 2)),
      ),
      PocketFriend(
        id: 'sample-remy',
        name: 'Remy Park',
        handle: '@remy.park',
        avatarColor: _avatarColors[1],
        isSample: true,
        addedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    final messages = [
      PocketMessage(
        id: 'sample-message-ava',
        friendId: 'sample-ava',
        text: 'Morning light looked unreal today.',
        createdAt: now.subtract(const Duration(minutes: 8)),
        isMine: false,
        isRead: false,
      ),
      PocketMessage(
        id: 'sample-message-jules',
        friendId: 'sample-jules',
        text: 'Coffee walk after class?',
        createdAt: now.subtract(const Duration(hours: 1)),
        isMine: false,
        isRead: true,
      ),
      PocketMessage(
        id: 'sample-message-remy',
        friendId: 'sample-remy',
        text: 'That print turned out so good.',
        createdAt: now.subtract(const Duration(hours: 2)),
        isMine: false,
        isRead: true,
      ),
    ];
    return SocialSnapshot(friends: friends, messages: messages);
  }
}
