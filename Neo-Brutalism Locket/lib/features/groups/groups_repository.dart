import 'dart:async';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum GroupRole { owner, member }

/// A group as its members see it.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.rules,
    required this.maxMembers,
    required this.createdAt,
    this.avatarPath,
  });

  final String id;
  final String name;
  final String rules;
  final int maxMembers;
  final DateTime createdAt;
  final String? avatarPath;

  static const columns = 'id, name, avatar_path, rules, max_members, created_at';

  factory Group.fromRow(Map<String, dynamic> row) => Group(
    id: row['id'] as String,
    name: row['name'] as String,
    rules: (row['rules'] as String?) ?? '',
    maxMembers: row['max_members'] as int? ?? 12,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    avatarPath: row['avatar_path'] as String?,
  );
}

class GroupMember {
  const GroupMember({
    required this.person,
    required this.role,
    required this.joinedAt,
  });

  final Person person;
  final GroupRole role;
  final DateTime joinedAt;

  bool get isOwner => role == GroupRole.owner;
}

/// A group with the people in it and what I have not read yet.
class GroupSummary {
  const GroupSummary({
    required this.group,
    required this.members,
    required this.myId,
    this.unread = 0,
    this.lastMessage,
  });

  final Group group;

  /// Owner first, then by joining date.
  final List<GroupMember> members;
  final String myId;
  final int unread;
  final GroupMessage? lastMessage;

  GroupMember? get owner {
    for (final member in members) {
      if (member.isOwner) return member;
    }
    return null;
  }

  bool get iAmOwner => owner?.person.id == myId;
}

/// An invitation. For a received one [person] is who invited me; for a sent
/// one it is who I invited.
class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.person,
    required this.incoming,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final Person person;
  final bool incoming;
  final DateTime createdAt;
}

class GroupsSnapshot {
  const GroupsSnapshot({
    this.groups = const [],
    this.incoming = const [],
    this.outgoing = const [],
  });

  final List<GroupSummary> groups;
  final List<GroupInvite> incoming;
  final List<GroupInvite> outgoing;

  GroupSummary? byId(String id) {
    for (final summary in groups) {
      if (summary.group.id == id) return summary;
    }
    return null;
  }
}

enum GroupMessageKind { text, system }

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.senderId,
  });

  final String id;
  final String groupId;
  final GroupMessageKind kind;

  /// Text: what was typed. System: a code (joined, left, kicked,
  /// owner_changed) about the person in [senderId].
  final String body;
  final String? senderId;
  final DateTime createdAt;

  factory GroupMessage.fromRow(Map<String, dynamic> row) => GroupMessage(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    kind: row['kind'] == 'system'
        ? GroupMessageKind.system
        : GroupMessageKind.text,
    body: row['body'] as String,
    senderId: row['sender_id'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}

enum GroupFailureKind {
  notFound,
  notOwner,
  notMember,
  self,
  empty,
  tooLong,
  blockedWord,
  badName,
  badSize,
  groupLimit,
  memberLimit,
  theirGroupLimit,
  alreadyMember,
  alreadyInvited,
  expired,
  ownerMustTransfer,
  network,
  unknown,
}

class GroupFailure implements Exception {
  const GroupFailure(this.kind);

  final GroupFailureKind kind;

  @override
  String toString() => 'GroupFailure($kind)';
}

abstract interface class GroupsRepository {
  /// My groups with their members, and the invitations to and from me.
  Future<GroupsSnapshot> load();

  Future<String> create({
    required String name,
    String rules = '',
    int maxMembers = 12,
  });

  Future<void> update(
    String groupId, {
    required String name,
    required String rules,
    required int maxMembers,
  });

  Future<void> invite(String groupId, String userId);

  Future<void> respond(String inviteId, {required bool accept});

  Future<void> revokeInvite(String inviteId);

  Future<void> kick(String groupId, String userId);

  Future<void> transferOwnership(String groupId, String userId);

  Future<void> leave(String groupId);

  Future<void> dissolve(String groupId);

  /// Newest last.
  Future<List<GroupMessage>> loadMessages(String groupId, {int limit = 100});

  Future<void> sendMessage(String groupId, String body);

  Future<void> markRead(String groupId);

  /// Fires when members or invitations change (while the app runs).
  Stream<void> get changes;

  /// Every new message in my groups.
  Stream<GroupMessage> get incomingMessages;

  void dispose();
}

class SupabaseGroupsRepository implements GroupsRepository {
  SupabaseGroupsRepository({required this.myId});

  final String myId;
  final _changes = StreamController<void>.broadcast();
  final _messages = StreamController<GroupMessage>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  void _listen() {
    _channel ??= _db
        .channel('groups-$myId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            try {
              _messages.add(GroupMessage.fromRow(payload.newRecord));
            } catch (_) {
              // A malformed row must not break the stream.
            }
          },
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (_) => _changes.add(null),
        )
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_invites',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'invitee_id',
            value: myId,
          ),
          callback: (_) => _changes.add(null),
        )
        .subscribe();
  }

  @override
  Stream<void> get changes {
    _listen();
    return _changes.stream;
  }

  @override
  Stream<GroupMessage> get incomingMessages {
    _listen();
    return _messages.stream;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _changes.close();
    _messages.close();
  }

  @override
  Future<GroupsSnapshot> load() => _guard(() async {
    final results = await Future.wait([
      _db.from('groups').select(Group.columns).order('created_at'),
      _db
          .from('group_members')
          .select(
            'group_id, role, joined_at, '
            'person:profiles!group_members_user_id_fkey(${Person.columns})',
          )
          .order('joined_at'),
      _db
          .from('group_invites')
          .select(
            'id, group_id, inviter_id, invitee_id, created_at, '
            'inviter:profiles!group_invites_inviter_id_fkey(${Person.columns}), '
            'invitee:profiles!group_invites_invitee_id_fkey(${Person.columns}), '
            'group:groups(name)',
          )
          .eq('status', 'pending')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false),
      _db.from('group_reads').select('group_id, last_read_at'),
      _db
          .from('group_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(300),
    ]);

    final membersByGroup = <String, List<GroupMember>>{};
    for (final row in results[1]) {
      final member = GroupMember(
        person: Person.fromRow(row['person'] as Map<String, dynamic>),
        role: row['role'] == 'owner' ? GroupRole.owner : GroupRole.member,
        joinedAt: DateTime.parse(row['joined_at'] as String).toLocal(),
      );
      (membersByGroup[row['group_id'] as String] ??= []).add(member);
    }
    final readAt = <String, DateTime>{
      for (final row in results[3])
        row['group_id'] as String: DateTime.parse(
          row['last_read_at'] as String,
        ).toLocal(),
    };
    final messages = [
      for (final row in results[4]) GroupMessage.fromRow(row),
    ]; // newest first

    final groups = <GroupSummary>[];
    for (final row in results[0]) {
      final group = Group.fromRow(row);
      final members = membersByGroup[group.id];
      // Invitees can read the group row but are not members yet.
      if (members == null) continue;
      members.sort((a, b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return a.joinedAt.compareTo(b.joinedAt);
      });
      final mine = messages.where((m) => m.groupId == group.id);
      final since = readAt[group.id];
      groups.add(
        GroupSummary(
          group: group,
          members: members,
          myId: myId,
          lastMessage: mine.isEmpty ? null : mine.first,
          unread: mine
              .where(
                (m) =>
                    m.kind == GroupMessageKind.text &&
                    m.senderId != myId &&
                    (since == null || m.createdAt.isAfter(since)),
              )
              .length,
        ),
      );
    }

    final incoming = <GroupInvite>[];
    final outgoing = <GroupInvite>[];
    for (final row in results[2]) {
      final isIncoming = row['invitee_id'] == myId;
      final invite = GroupInvite(
        id: row['id'] as String,
        groupId: row['group_id'] as String,
        groupName: (row['group'] as Map<String, dynamic>?)?['name'] as String? ??
            '?',
        person: Person.fromRow(
          (isIncoming ? row['inviter'] : row['invitee']) as Map<String, dynamic>,
        ),
        incoming: isIncoming,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
      (isIncoming ? incoming : outgoing).add(invite);
    }
    return GroupsSnapshot(
      groups: groups,
      incoming: incoming,
      outgoing: outgoing,
    );
  });

  @override
  Future<String> create({
    required String name,
    String rules = '',
    int maxMembers = 12,
  }) => _guard(() async {
    final id = await _db.rpc(
      'create_group',
      params: {'p_name': name, 'p_rules': rules, 'p_max_members': maxMembers},
    );
    return id as String;
  });

  @override
  Future<void> update(
    String groupId, {
    required String name,
    required String rules,
    required int maxMembers,
  }) => _guard(
    () => _db.rpc(
      'update_group',
      params: {
        'p_group': groupId,
        'p_name': name,
        'p_rules': rules,
        'p_max_members': maxMembers,
      },
    ),
  );

  @override
  Future<void> invite(String groupId, String userId) => _guard(
    () => _db.rpc(
      'invite_to_group',
      params: {'p_group': groupId, 'p_user': userId},
    ),
  );

  @override
  Future<void> respond(String inviteId, {required bool accept}) => _guard(
    () => _db.rpc(
      'respond_group_invite',
      params: {'p_id': inviteId, 'p_accept': accept},
    ),
  );

  @override
  Future<void> revokeInvite(String inviteId) =>
      _guard(() => _db.rpc('revoke_group_invite', params: {'p_id': inviteId}));

  @override
  Future<void> kick(String groupId, String userId) => _guard(
    () => _db.rpc(
      'kick_member',
      params: {'p_group': groupId, 'p_user': userId},
    ),
  );

  @override
  Future<void> transferOwnership(String groupId, String userId) => _guard(
    () => _db.rpc(
      'transfer_ownership',
      params: {'p_group': groupId, 'p_user': userId},
    ),
  );

  @override
  Future<void> leave(String groupId) =>
      _guard(() => _db.rpc('leave_group', params: {'p_group': groupId}));

  @override
  Future<void> dissolve(String groupId) =>
      _guard(() => _db.rpc('dissolve_group', params: {'p_group': groupId}));

  @override
  Future<List<GroupMessage>> loadMessages(String groupId, {int limit = 100}) =>
      _guard(() async {
        final rows = await _db
            .from('group_messages')
            .select()
            .eq('group_id', groupId)
            .order('created_at', ascending: false)
            .limit(limit);
        return [for (final row in rows.reversed) GroupMessage.fromRow(row)];
      });

  @override
  Future<void> sendMessage(String groupId, String body) => _guard(
    () => _db.rpc(
      'send_group_message',
      params: {'p_group': groupId, 'p_body': body},
    ),
  );

  @override
  Future<void> markRead(String groupId) =>
      _guard(() => _db.rpc('mark_group_read', params: {'p_group': groupId}));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw GroupFailure(kindOfMessage(error.message));
    } on sb.AuthException {
      throw const GroupFailure(GroupFailureKind.unknown);
    } catch (error) {
      if (error is GroupFailure) rethrow;
      throw const GroupFailure(GroupFailureKind.network);
    }
  }

  /// The RPCs raise short codes (see the groups migration) as the message.
  static GroupFailureKind kindOfMessage(String message) => switch (message) {
    'not_found' => GroupFailureKind.notFound,
    'not_owner' => GroupFailureKind.notOwner,
    'not_member' => GroupFailureKind.notMember,
    'self' => GroupFailureKind.self,
    'empty' => GroupFailureKind.empty,
    'too_long' => GroupFailureKind.tooLong,
    'blocked_word' => GroupFailureKind.blockedWord,
    'bad_name' => GroupFailureKind.badName,
    'bad_size' => GroupFailureKind.badSize,
    'group_limit' => GroupFailureKind.groupLimit,
    'member_limit' => GroupFailureKind.memberLimit,
    'their_group_limit' => GroupFailureKind.theirGroupLimit,
    'already_member' => GroupFailureKind.alreadyMember,
    'already_invited' => GroupFailureKind.alreadyInvited,
    'expired' => GroupFailureKind.expired,
    'owner_must_transfer' => GroupFailureKind.ownerMustTransfer,
    _ => GroupFailureKind.unknown,
  };
}
