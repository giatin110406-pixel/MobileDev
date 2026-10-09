import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';

/// My groups and invitations, for the UI. Every action reloads from the server
/// so the screen never shows a guess. Joining, leaving and new messages (the
/// unread count) arrive by themselves.
class GroupsStore extends ChangeNotifier {
  GroupsStore(this.repository) {
    _subscriptions = [
      repository.changes.listen((_) => refresh()),
      repository.incomingMessages.listen((_) => refresh()),
    ];
  }

  final GroupsRepository repository;
  late final List<StreamSubscription<Object?>> _subscriptions;
  GroupsSnapshot _snapshot = const GroupsSnapshot();
  bool _loaded = false;
  bool _loading = false;
  bool _again = false;
  GroupFailure? _loadError;

  GroupsSnapshot get snapshot => _snapshot;
  List<GroupSummary> get groups => _snapshot.groups;
  List<GroupInvite> get incoming => _snapshot.incoming;
  List<GroupInvite> get outgoing => _snapshot.outgoing;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;

  /// Set when the last refresh failed (the old list stays visible).
  GroupFailure? get loadError => _loadError;

  int get totalUnread => groups.fold(0, (sum, g) => sum + g.unread);

  GroupSummary? byId(String id) => _snapshot.byId(id);

  Future<void> refresh() async {
    if (_loading) {
      // Asked again while loading (a message arrived): load once more after.
      _again = true;
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      do {
        _again = false;
        try {
          _snapshot = await repository.load();
          _loaded = true;
          _loadError = null;
        } on GroupFailure catch (failure) {
          _loadError = failure;
        }
      } while (_again);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Throws [GroupFailure]; reloads on success. Returns the new group's id.
  Future<String> create({
    required String name,
    String rules = '',
    int maxMembers = 12,
  }) async {
    final id = await repository.create(
      name: name,
      rules: rules,
      maxMembers: maxMembers,
    );
    await refresh();
    return id;
  }

  Future<void> update(
    GroupSummary group, {
    required String name,
    required String rules,
    required int maxMembers,
  }) async {
    await repository.update(
      group.group.id,
      name: name,
      rules: rules,
      maxMembers: maxMembers,
    );
    await refresh();
  }

  Future<void> invite(GroupSummary group, Person friend) async {
    await repository.invite(group.group.id, friend.id);
    await refresh();
  }

  Future<void> respond(GroupInvite invite, {required bool accept}) async {
    try {
      await repository.respond(invite.id, accept: accept);
    } finally {
      // Also after a refusal: an expired or full invite should disappear.
      await refresh();
    }
  }

  Future<void> revokeInvite(GroupInvite invite) async {
    await repository.revokeInvite(invite.id);
    await refresh();
  }

  Future<void> kick(GroupSummary group, Person person) async {
    await repository.kick(group.group.id, person.id);
    await refresh();
  }

  Future<void> transferOwnership(GroupSummary group, Person person) async {
    await repository.transferOwnership(group.group.id, person.id);
    await refresh();
  }

  Future<void> leave(GroupSummary group) async {
    await repository.leave(group.group.id);
    await refresh();
  }

  Future<void> dissolve(GroupSummary group) async {
    await repository.dissolve(group.group.id);
    await refresh();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    repository.dispose();
    super.dispose();
  }
}
