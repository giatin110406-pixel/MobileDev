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
    this.avatarPath,
    this.frameId,
    this.bannerId,
  });

  final String id;
  final String name;
  final String handle;
  final int avatarColor;
  final bool isSample;
  final DateTime addedAt;

  /// Path of their photo in the `avatars` bucket (real friends only).
  final String? avatarPath;

  /// The shop frame and banner they wear (real friends only).
  final String? frameId;
  final String? bannerId;

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
    'avatarPath': avatarPath,
    'frameId': frameId,
    'bannerId': bannerId,
  };

  factory PocketFriend.fromJson(Map<String, dynamic> json) => PocketFriend(
    id: json['id'] as String,
    name: json['name'] as String,
    handle: json['handle'] as String,
    avatarColor: json['avatarColor'] as int,
    isSample: json['isSample'] as bool? ?? false,
    addedAt: DateTime.parse(json['addedAt'] as String),
    avatarPath: json['avatarPath'] as String?,
    frameId: json['frameId'] as String?,
    bannerId: json['bannerId'] as String?,
  );
}

/// A post a friend shared (shown in the feed). Sample posts have no photo and
/// render as a coloured card with [emoji]; real posts carry [imagePath].
/// Daily quest posts carry [questId] and play the quest's music.
class FriendPost {
  const FriendPost({
    required this.id,
    required this.friendId,
    required this.caption,
    required this.createdAt,
    required this.color,
    this.emoji = '',
    this.imagePath,
    this.questId,
  });

  final String id;
  final String friendId;
  final String caption;
  final DateTime createdAt;
  final int color;
  final String emoji;
  final String? imagePath;
  final String? questId;

  Map<String, Object?> toJson() => {
    'id': id,
    'friendId': friendId,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'color': color,
    'emoji': emoji,
    'imagePath': imagePath,
    'questId': questId,
  };

  factory FriendPost.fromJson(Map<String, dynamic> json) => FriendPost(
    id: json['id'] as String,
    friendId: json['friendId'] as String,
    caption: json['caption'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    color: json['color'] as int? ?? 0xFFFFE66D,
    emoji: json['emoji'] as String? ?? '',
    imagePath: json['imagePath'] as String?,
    questId: json['questId'] as String?,
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
    this.replyToPostId,
    this.replyPreview,
    this.reaction,
  });

  final String id;
  final String friendId;
  final String text;
  final String? photoPath;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  /// Set when this message replies to (or reacts on) a feed post.
  final String? replyToPostId;

  /// The post's caption at the time of the reply, shown as a quote.
  final String? replyPreview;

  /// An emoji reaction to the post (the message has no text then).
  final String? reaction;

  bool get isPostReply => replyToPostId != null;

  PocketMessage copyWith({bool? isRead}) => PocketMessage(
    id: id,
    friendId: friendId,
    text: text,
    photoPath: photoPath,
    createdAt: createdAt,
    isMine: isMine,
    isRead: isRead ?? this.isRead,
    replyToPostId: replyToPostId,
    replyPreview: replyPreview,
    reaction: reaction,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'friendId': friendId,
    'text': text,
    'photoPath': photoPath,
    'createdAt': createdAt.toIso8601String(),
    'isMine': isMine,
    'isRead': isRead,
    'replyToPostId': replyToPostId,
    'replyPreview': replyPreview,
    'reaction': reaction,
  };

  factory PocketMessage.fromJson(Map<String, dynamic> json) => PocketMessage(
    id: json['id'] as String,
    friendId: json['friendId'] as String,
    text: json['text'] as String? ?? '',
    photoPath: json['photoPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isMine: json['isMine'] as bool,
    isRead: json['isRead'] as bool? ?? true,
    replyToPostId: json['replyToPostId'] as String?,
    replyPreview: json['replyPreview'] as String?,
    reaction: json['reaction'] as String?,
  );
}

class SocialSnapshot {
  const SocialSnapshot({
    required this.friends,
    required this.messages,
    this.posts = const [],
  });

  final List<PocketFriend> friends;
  final List<PocketMessage> messages;

  /// Friends' posts, newest first.
  final List<FriendPost> posts;
}

class SocialRepository {
  static const _friendsKey = 'pocket_friends_v1';
  static const _messagesKey = 'pocket_messages_v1';
  static const _postsKey = 'pocket_posts_v1';
  static const _questSamplesKey = 'pocket_quest_samples_v1';
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
    final snapshot = await _loadStored(preferences);
    if (preferences.getBool(_questSamplesKey) ?? false) return snapshot;
    // Once per install: the sample friends also did a daily quest.
    final ids = snapshot.friends.map((friend) => friend.id).toSet();
    final updated = SocialSnapshot(
      friends: snapshot.friends,
      messages: snapshot.messages,
      posts: [
        ..._sampleQuestPosts(
          DateTime.now(),
        ).where((post) => ids.contains(post.friendId)),
        ...snapshot.posts,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    await _save(preferences, updated);
    await preferences.setBool(_questSamplesKey, true);
    return updated;
  }

  Future<SocialSnapshot> _loadStored(SharedPreferences preferences) async {
    final storedFriends = preferences.getString(_friendsKey);
    final storedMessages = preferences.getString(_messagesKey);
    final storedPosts = preferences.getString(_postsKey);
    if (storedFriends == null) {
      final seeded = _sampleSnapshot();
      await _save(preferences, seeded);
      return seeded;
    }

    final friends = _decodeList(storedFriends, PocketFriend.fromJson);
    final messages = storedMessages == null
        ? const <PocketMessage>[]
        : _decodeList(storedMessages, PocketMessage.fromJson);
    if (storedPosts == null) {
      // Installs from before the feed existed: give the sample friends posts.
      final ids = friends.map((friend) => friend.id).toSet();
      final snapshot = SocialSnapshot(
        friends: friends,
        messages: messages,
        posts: _samplePosts(
          DateTime.now(),
        ).where((post) => ids.contains(post.friendId)).toList(),
      );
      await _save(preferences, snapshot);
      return snapshot;
    }
    return SocialSnapshot(
      friends: friends,
      messages: messages,
      posts: _decodeList(storedPosts, FriendPost.fromJson),
    );
  }

  /// With a real account the server owns the friend list: make the local
  /// copy match it (dropping the sample friends) and forget threads and posts
  /// of people who are no longer friends.
  Future<SocialSnapshot> replaceFriends(List<PocketFriend> friends) async {
    final snapshot = await load();
    final ids = friends.map((friend) => friend.id).toSet();
    final updated = SocialSnapshot(
      friends: friends,
      messages: snapshot.messages
          .where((message) => ids.contains(message.friendId))
          .toList(),
      posts: snapshot.posts
          .where((post) => ids.contains(post.friendId))
          .toList(),
    );
    await _persist(updated);
    return updated;
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
      posts: snapshot.posts,
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
      posts: snapshot.posts.where((post) => post.friendId != friendId).toList(),
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
    return _append(snapshot, message);
  }

  /// Replies to a friend's post with [text] and/or an emoji [reaction]. The
  /// reply lands in the conversation with the person who posted, quoting the
  /// post. (Local only for now: there is no server to deliver it.)
  Future<SocialSnapshot> replyToPost({
    required String postId,
    String text = '',
    String? reaction,
  }) async {
    final cleanText = text.trim();
    final cleanReaction = reaction?.trim();
    if (cleanText.isEmpty && (cleanReaction == null || cleanReaction.isEmpty)) {
      throw const FormatException('Write a reply or pick an emoji.');
    }
    final snapshot = await load();
    final post = snapshot.posts.where((post) => post.id == postId).firstOrNull;
    if (post == null) throw const FormatException('That post is gone.');
    if (!snapshot.friends.any((friend) => friend.id == post.friendId)) {
      throw const FormatException('Friend not found.');
    }
    final message = PocketMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      friendId: post.friendId,
      text: cleanText,
      photoPath: post.imagePath,
      createdAt: DateTime.now(),
      isMine: true,
      isRead: true,
      replyToPostId: post.id,
      replyPreview: post.caption.isEmpty ? post.emoji : post.caption,
      reaction: cleanText.isEmpty ? cleanReaction : null,
    );
    return _append(snapshot, message);
  }

  Future<SocialSnapshot> markThreadRead(String friendId) async {
    final snapshot = await load();
    final updated = SocialSnapshot(
      friends: snapshot.friends,
      messages: snapshot.messages
          .map(
            (message) => message.friendId == friendId && !message.isMine
                ? message.copyWith(isRead: true)
                : message,
          )
          .toList(),
      posts: snapshot.posts,
    );
    await _persist(updated);
    return updated;
  }

  Future<SocialSnapshot> _append(
    SocialSnapshot snapshot,
    PocketMessage message,
  ) async {
    final updated = SocialSnapshot(
      friends: snapshot.friends,
      messages: [...snapshot.messages, message],
      posts: snapshot.posts,
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
    await preferences.setString(
      _postsKey,
      jsonEncode(snapshot.posts.map((post) => post.toJson()).toList()),
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

  List<FriendPost> _samplePosts(DateTime now) => [
    FriendPost(
      id: 'sample-post-ava',
      friendId: 'sample-ava',
      caption: 'Morning light looked unreal',
      emoji: '☀️',
      color: 0xFFFFE66D,
      createdAt: now.subtract(const Duration(minutes: 12)),
    ),
    FriendPost(
      id: 'sample-post-jules',
      friendId: 'sample-jules',
      caption: 'Coffee walk after class',
      emoji: '☕',
      color: 0xFF4ECDC4,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
    ),
    FriendPost(
      id: 'sample-post-remy',
      friendId: 'sample-remy',
      caption: 'Fresh print from the darkroom',
      emoji: '🎞️',
      color: 0xFFA388EE,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  List<FriendPost> _sampleQuestPosts(DateTime now) => [
    FriendPost(
      id: 'sample-quest-ava',
      friendId: 'sample-ava',
      caption: 'Vẽ thật nhanh trước khi hoa kịp héo 🌻',
      emoji: '🌻',
      color: 0xFF1D3F8F,
      createdAt: now.subtract(const Duration(minutes: 40)),
      questId: 'vg_sunflower',
    ),
    FriendPost(
      id: 'sample-quest-jules',
      friendId: 'sample-jules',
      caption: 'Ăn nấm, to gấp đôi! 🍄',
      emoji: '🍄',
      color: 0xFF5C94FC,
      createdAt: now.subtract(const Duration(hours: 2, minutes: 10)),
      questId: 'px_mushroom',
    ),
  ];

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
    return SocialSnapshot(
      friends: friends,
      messages: messages,
      posts: _samplePosts(now),
    );
  }
}
