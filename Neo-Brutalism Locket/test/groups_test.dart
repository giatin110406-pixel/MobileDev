import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';

Person person(String name) =>
    Person(id: 'id-$name', username: name, displayName: name);

GroupSummary summary(
  String id, {
  String owner = 'me',
  int unread = 0,
  List<String> others = const [],
}) => GroupSummary(
  group: Group(
    id: id,
    name: 'Group $id',
    rules: '',
    maxMembers: 12,
    createdAt: DateTime(2026, 1, 1),
  ),
  myId: 'id-me',
  unread: unread,
  members: [
    GroupMember(
      person: person(owner),
      role: GroupRole.owner,
      joinedAt: DateTime(2026, 1, 1),
    ),
    for (final name in others)
      GroupMember(
        person: person(name),
        role: GroupRole.member,
        joinedAt: DateTime(2026, 1, 2),
      ),
  ],
);

/// In-memory groups server for tests.
class FakeGroups implements GroupsRepository {
  FakeGroups({List<GroupSummary>? groups, List<GroupInvite>? incoming})
    : groups = groups ?? [],
      incoming = incoming ?? [];

  final List<GroupSummary> groups;
  final List<GroupInvite> incoming;
  final messages = <GroupMessage>[];
  final calls = <String>[];
  final marked = <String>[];
  GroupFailure? failNext;
  var loads = 0;
  final _changes = StreamController<void>.broadcast();
  final _incoming = StreamController<GroupMessage>.broadcast();
  var _counter = 0;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  void pushChange() => _changes.add(null);
  void pushMessage(GroupMessage message) => _incoming.add(message);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<GroupMessage> get incomingMessages => _incoming.stream;

  @override
  Future<GroupsSnapshot> load() async {
    loads++;
    return GroupsSnapshot(groups: List.of(groups), incoming: List.of(incoming));
  }

  @override
  Future<String> create({
    required String name,
    String rules = '',
    int maxMembers = 12,
  }) async {
    _maybeFail();
    final id = 'g${_counter++}';
    calls.add('create:$name');
    groups.add(summary(id, owner: 'me'));
    return id;
  }

  @override
  Future<void> update(
    String groupId, {
    required String name,
    required String rules,
    required int maxMembers,
  }) async {
    _maybeFail();
    calls.add('update:$groupId:$name');
  }

  @override
  Future<void> invite(String groupId, String userId) async {
    _maybeFail();
    calls.add('invite:$groupId:$userId');
  }

  @override
  Future<void> respond(String inviteId, {required bool accept}) async {
    calls.add('respond:$inviteId:$accept');
    incoming.removeWhere((invite) => invite.id == inviteId);
    _maybeFail();
  }

  @override
  Future<void> revokeInvite(String inviteId) async =>
      calls.add('revoke:$inviteId');

  @override
  Future<void> kick(String groupId, String userId) async {
    _maybeFail();
    calls.add('kick:$groupId:$userId');
  }

  @override
  Future<void> transferOwnership(String groupId, String userId) async =>
      calls.add('transfer:$groupId:$userId');

  @override
  Future<void> leave(String groupId) async {
    _maybeFail();
    calls.add('leave:$groupId');
    groups.removeWhere((g) => g.group.id == groupId);
  }

  @override
  Future<void> dissolve(String groupId) async {
    calls.add('dissolve:$groupId');
    groups.removeWhere((g) => g.group.id == groupId);
  }

  @override
  Future<List<GroupMessage>> loadMessages(
    String groupId, {
    int limit = 100,
  }) async {
    _maybeFail();
    return messages.where((m) => m.groupId == groupId).toList();
  }

  @override
  Future<void> sendMessage(String groupId, String body) async {
    _maybeFail();
    calls.add('send:$groupId:$body');
    messages.add(
      GroupMessage(
        id: 'm${_counter++}',
        groupId: groupId,
        kind: GroupMessageKind.text,
        body: body,
        senderId: 'id-me',
        createdAt: DateTime(2026, 1, 1, 12, _counter),
      ),
    );
  }

  @override
  Future<void> markRead(String groupId) async => marked.add(groupId);

  @override
  void dispose() {
    _changes.close();
    _incoming.close();
  }
}

GroupMessage message(String id, String groupId, String body, {String? from}) =>
    GroupMessage(
      id: id,
      groupId: groupId,
      kind: GroupMessageKind.text,
      body: body,
      senderId: from ?? 'id-other',
      createdAt: DateTime(2026, 1, 1, 12),
    );

void main() {
  group('GroupsStore', () {
    test('loads my groups and sums the unread messages', () async {
      final repo = FakeGroups(
        groups: [summary('a', unread: 2), summary('b', unread: 3)],
      );
      final store = GroupsStore(repo);
      await store.refresh();
      expect(store.isLoaded, isTrue);
      expect(store.groups.map((g) => g.group.id), ['a', 'b']);
      expect(store.totalUnread, 5);
      expect(store.byId('b')?.unread, 3);
    });

    test('creating a group reloads and returns its id', () async {
      final repo = FakeGroups();
      final store = GroupsStore(repo);
      final id = await store.create(name: 'Team');
      expect(id, 'g0');
      expect(store.groups.single.group.id, 'g0');
      expect(store.groups.single.iAmOwner, isTrue);
    });

    test('a refused action throws and the list stays as it was', () async {
      final repo = FakeGroups(groups: [summary('a')]);
      final store = GroupsStore(repo);
      await store.refresh();
      repo.failNext = const GroupFailure(GroupFailureKind.groupLimit);
      await expectLater(
        store.create(name: 'Another'),
        throwsA(
          isA<GroupFailure>().having(
            (f) => f.kind,
            'kind',
            GroupFailureKind.groupLimit,
          ),
        ),
      );
      expect(store.groups.length, 1);
    });

    test('an invite that fails (expired) still disappears after reload',
        () async {
      final repo = FakeGroups(
        incoming: [
          GroupInvite(
            id: 'i1',
            groupId: 'a',
            groupName: 'Old',
            person: person('boss'),
            incoming: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final store = GroupsStore(repo);
      await store.refresh();
      expect(store.incoming.length, 1);
      repo.failNext = const GroupFailure(GroupFailureKind.expired);
      await expectLater(
        store.respond(store.incoming.single, accept: true),
        throwsA(isA<GroupFailure>()),
      );
      expect(store.incoming, isEmpty);
    });

    test('a change from the server reloads by itself', () async {
      final repo = FakeGroups();
      final store = GroupsStore(repo);
      await store.refresh();
      final before = repo.loads;
      repo.groups.add(summary('new'));
      repo.pushChange();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(repo.loads, greaterThan(before));
      expect(store.groups.single.group.id, 'new');
    });

    test('the owner is first and a member is not the owner', () {
      final mine = summary('a', owner: 'me', others: ['zed']);
      expect(mine.iAmOwner, isTrue);
      final theirs = summary('b', owner: 'zed', others: ['me']);
      expect(theirs.iAmOwner, isFalse);
    });
  });

  group('GroupChatStore', () {
    test('loads messages and marks the group read', () async {
      final repo = FakeGroups()..messages.add(message('1', 'a', 'hello'));
      final chat = GroupChatStore(repo, groupId: 'a', myId: 'id-me');
      await chat.load();
      expect(chat.messages.single.body, 'hello');
      await Future<void>.delayed(Duration.zero);
      expect(repo.marked, ['a']);
    });

    test('shows new messages of this group once, ignores other groups',
        () async {
      final repo = FakeGroups();
      final chat = GroupChatStore(repo, groupId: 'a', myId: 'id-me');
      await chat.load();
      repo.pushMessage(message('1', 'a', 'hi'));
      repo.pushMessage(message('1', 'a', 'hi'));
      repo.pushMessage(message('2', 'b', 'elsewhere'));
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages.map((m) => m.body), ['hi']);
    });

    test('sending stores the message and reloads', () async {
      final repo = FakeGroups();
      final chat = GroupChatStore(repo, groupId: 'a', myId: 'id-me');
      await chat.load();
      await chat.send('  hello team  ');
      expect(repo.calls, ['send:a:hello team']);
      expect(chat.messages.single.body, 'hello team');
      expect(chat.sending, isFalse);
    });

    test('empty text is not sent and a failure surfaces', () async {
      final repo = FakeGroups();
      final chat = GroupChatStore(repo, groupId: 'a', myId: 'id-me');
      await chat.send('   ');
      expect(repo.calls, isEmpty);
      repo.failNext = const GroupFailure(GroupFailureKind.notMember);
      await expectLater(chat.send('hi'), throwsA(isA<GroupFailure>()));
      expect(chat.sending, isFalse);
    });
  });
}
