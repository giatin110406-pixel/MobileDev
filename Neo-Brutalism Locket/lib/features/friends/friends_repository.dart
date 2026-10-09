import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Another person as other people see them.
class Person {
  const Person({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarPath,
    this.frameId,
    this.bannerId,
  });

  final String id;
  final String username;
  final String displayName;

  /// Path in the `avatars` bucket.
  final String? avatarPath;
  final String? frameId;
  final String? bannerId;

  String get handle => '@$username';

  static const columns =
      'id, username, display_name, avatar_path, frame_id, banner_id';

  factory Person.fromRow(Map<String, dynamic> row) => Person(
    id: row['id'] as String,
    username: (row['username'] as String?) ?? '',
    displayName:
        (row['display_name'] as String?) ?? (row['username'] as String? ?? '?'),
    avatarPath: row['avatar_path'] as String?,
    frameId: row['frame_id'] as String?,
    bannerId: row['banner_id'] as String?,
  );

  static const _colors = [
    0xFFFF6B6B,
    0xFFA388EE,
    0xFF4ECDC4,
    0xFFFFE66D,
    0xFF45B7D1,
    0xFFF7A072,
  ];

  /// The shape the existing friend screens use. The avatar colour comes from
  /// the id, so a person looks the same on every device.
  PocketFriend toPocketFriend({DateTime? since}) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return PocketFriend(
      id: id,
      name: displayName,
      handle: handle,
      avatarColor: _colors[hash % _colors.length],
      isSample: false,
      addedAt: since ?? DateTime.fromMillisecondsSinceEpoch(0),
      avatarPath: avatarPath,
      frameId: frameId,
      bannerId: bannerId,
    );
  }
}

class Friend {
  const Friend({required this.person, required this.since});

  final Person person;
  final DateTime since;
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.person,
    required this.incoming,
    required this.createdAt,
  });

  final String id;

  /// The other side: who asked me (incoming) or whom I asked.
  final Person person;
  final bool incoming;
  final DateTime createdAt;
}

class FriendsSnapshot {
  const FriendsSnapshot({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
  });

  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
}

enum FriendsFailureKind {
  notFound,
  self,
  alreadyFriends,
  alreadySent,
  notAccepting,
  tooManyPending,
  friendLimit,
  theirFriendLimit,
  network,
  unknown,
}

class FriendsFailure implements Exception {
  const FriendsFailure(this.kind);

  final FriendsFailureKind kind;

  @override
  String toString() => 'FriendsFailure($kind)';
}

/// What sending a request did.
enum SendResult {
  /// A request is now waiting for the other person.
  sent,

  /// They had already asked me, so we are friends now.
  accepted,
}

abstract interface class FriendsRepository {
  Future<FriendsSnapshot> load();

  /// People whose username starts with [query] (at least 2 characters).
  Future<List<Person>> search(String query);

  Future<SendResult> sendRequest(String username);

  Future<void> respond(String requestId, {required bool accept});

  Future<void> cancel(String requestId);

  Future<void> removeFriend(String personId);
}

class SupabaseFriendsRepository implements FriendsRepository {
  SupabaseFriendsRepository({required this.myId});

  final String myId;

  sb.SupabaseClient get _db => Backend.client;

  static const _personSelect = Person.columns;

  @override
  Future<FriendsSnapshot> load() => _guard(() async {
    final results = await Future.wait([
      _db
          .from('friendships')
          .select(
            'created_at, '
            'a:profiles!friendships_user_a_fkey($_personSelect), '
            'b:profiles!friendships_user_b_fkey($_personSelect)',
          )
          .order('created_at'),
      _db
          .from('friend_requests')
          .select(
            'id, from_id, created_at, '
            'from:profiles!friend_requests_from_id_fkey($_personSelect), '
            'to:profiles!friend_requests_to_id_fkey($_personSelect)',
          )
          .eq('status', 'pending')
          .order('created_at', ascending: false),
    ]);

    final friends = <Friend>[
      for (final row in results[0])
        Friend(
          person: Person.fromRow(
            (row['a']['id'] == myId ? row['b'] : row['a'])
                as Map<String, dynamic>,
          ),
          since: DateTime.parse(row['created_at'] as String),
        ),
    ];
    final incoming = <FriendRequest>[];
    final outgoing = <FriendRequest>[];
    for (final row in results[1]) {
      final isIncoming = row['from_id'] != myId;
      final request = FriendRequest(
        id: row['id'] as String,
        person: Person.fromRow(
          (isIncoming ? row['from'] : row['to']) as Map<String, dynamic>,
        ),
        incoming: isIncoming,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
      (isIncoming ? incoming : outgoing).add(request);
    }
    return FriendsSnapshot(
      friends: friends,
      incoming: incoming,
      outgoing: outgoing,
    );
  });

  @override
  Future<List<Person>> search(String query) => _guard(() async {
    final rows = await _db.rpc('search_profiles', params: {'p_query': query});
    return [
      for (final row in rows as List<dynamic>)
        Person.fromRow(row as Map<String, dynamic>),
    ];
  });

  @override
  Future<SendResult> sendRequest(String username) => _guard(() async {
    final result = await _db.rpc(
      'send_friend_request',
      params: {'p_username': username},
    );
    return result == 'accepted' ? SendResult.accepted : SendResult.sent;
  });

  @override
  Future<void> respond(String requestId, {required bool accept}) => _guard(
    () => _db.rpc(
      'respond_friend_request',
      params: {'p_id': requestId, 'p_accept': accept},
    ),
  );

  @override
  Future<void> cancel(String requestId) => _guard(
    () => _db.rpc('cancel_friend_request', params: {'p_id': requestId}),
  );

  @override
  Future<void> removeFriend(String personId) =>
      _guard(() => _db.rpc('remove_friend', params: {'p_user': personId}));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw FriendsFailure(kindOfMessage(error.message));
    } on sb.AuthException {
      throw const FriendsFailure(FriendsFailureKind.unknown);
    } catch (error) {
      if (error is FriendsFailure) rethrow;
      // Socket / timeout / client errors: the phone could not reach the server.
      throw const FriendsFailure(FriendsFailureKind.network);
    }
  }

  /// The RPCs raise short codes (see the friends migration) as the message.
  static FriendsFailureKind kindOfMessage(String message) => switch (message) {
    'not_found' => FriendsFailureKind.notFound,
    'self' => FriendsFailureKind.self,
    'already_friends' => FriendsFailureKind.alreadyFriends,
    'already_sent' => FriendsFailureKind.alreadySent,
    'not_accepting' => FriendsFailureKind.notAccepting,
    'too_many_pending' => FriendsFailureKind.tooManyPending,
    'friend_limit' => FriendsFailureKind.friendLimit,
    'their_friend_limit' => FriendsFailureKind.theirFriendLimit,
    _ => FriendsFailureKind.unknown,
  };
}
