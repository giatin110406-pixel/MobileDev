import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Everything about one group. The owner can edit it, invite, remove people,
/// hand it over, start a new canvas or close the group. Members see the rules
/// and can leave.
class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({
    required this.groupId,
    required this.groups,
    required this.friends,
    required this.canvas,
    required this.myId,
    this.safety,
    super.key,
  });

  final String groupId;
  final GroupsStore groups;
  final FriendsStore friends;
  final CanvasStore canvas;
  final String myId;
  final SafetyRepository? safety;

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _name = TextEditingController();
  final _rules = TextEditingController();
  int _max = 12;
  bool _loadedFields = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _fill(GroupSummary summary) {
    if (_loadedFields) return;
    _loadedFields = true;
    _name.text = summary.group.name;
    _rules.text = summary.group.rules;
    _max = summary.group.maxMembers;
  }

  /// Runs [action], tells the user what went wrong if it did.
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showNeoSnack(context, done);
      return true;
    } on GroupFailure catch (failure) {
      if (mounted) {
        showNeoSnack(
          context,
          groupFailureText(AppLocalizations.of(context), failure),
        );
      }
    } on CanvasFailure catch (failure) {
      if (mounted) {
        showNeoSnack(
          context,
          canvasFailureText(AppLocalizations.of(context), failure.kind),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: NeoColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(body, style: const TextStyle(color: NeoColors.ink)),
        actions: [
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, false)),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, true)),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save(GroupSummary summary) => _run(
    () => widget.groups.update(
      summary,
      name: _name.text,
      rules: _rules.text,
      maxMembers: _max,
    ),
    done: AppLocalizations.of(context).savedSnack,
  );

  Future<void> _kick(GroupSummary summary, Person person) async {
    if (!await _confirm(
      AppLocalizations.of(context).kickTitle(person.displayName),
      AppLocalizations.of(context).kickBody,
      AppLocalizations.of(context).kickAction,
    )) {
      return;
    }
    await _run(() => widget.groups.kick(summary, person));
  }

  Future<void> _transfer(GroupSummary summary, Person person) async {
    if (!await _confirm(
      AppLocalizations.of(context).transferTitle,
      AppLocalizations.of(context).transferBody(person.displayName),
      AppLocalizations.of(context).transferAction,
    )) {
      return;
    }
    if (!mounted) return;
    final done = AppLocalizations.of(context).transferDone(person.displayName);
    await _run(
      () => widget.groups.transferOwnership(summary, person),
      done: done,
    );
  }

  Future<void> _rollback(Person person) async {
    if (!await _confirm(
      AppLocalizations.of(context).rollbackTitle(person.displayName),
      AppLocalizations.of(context).rollbackBody,
      AppLocalizations.of(context).rollbackAction,
    )) {
      return;
    }
    var restored = 0;
    final ok = await _run(() async {
      restored = await widget.canvas.rollbackUser(
        person.id,
        DateTime.now().subtract(const Duration(hours: 24)),
      );
    });
    if (ok && mounted) {
      showNeoSnack(
        context,
        AppLocalizations.of(context).rollbackDone(restored),
      );
    }
  }

  Future<void> _leave(GroupSummary summary) async {
    if (!await _confirm(
      AppLocalizations.of(context).leaveTitle(summary.group.name),
      AppLocalizations.of(context).leaveBody,
      AppLocalizations.of(context).leaveAction,
    )) {
      return;
    }
    await _run(() => widget.groups.leave(summary));
  }

  Future<void> _dissolve(GroupSummary summary) async {
    if (!await _confirm(
      AppLocalizations.of(context).dissolveTitle(summary.group.name),
      AppLocalizations.of(context).dissolveBody,
      AppLocalizations.of(context).dissolveAction,
    )) {
      return;
    }
    await _run(() => widget.groups.dissolve(summary));
  }

  Future<void> _invite(GroupSummary summary) async {
    final inGroup = {for (final m in summary.members) m.person.id};
    final invited = {for (final i in widget.groups.outgoing) i.person.id};
    final candidates = [
      for (final friend in widget.friends.friends)
        if (!inGroup.contains(friend.person.id) &&
            !invited.contains(friend.person.id))
          friend.person,
    ];
    final picked = await showModalBottomSheet<Person>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FriendPicker(candidates: candidates),
    );
    if (picked == null || !mounted) return;
    final done = AppLocalizations.of(context).invitedSnack(picked.displayName);
    await _run(() => widget.groups.invite(summary, picked), done: done);
  }

  Future<void> _newCanvas() async {
    final choice = await showDialog<({int size, String palette})>(
      context: context,
      builder: (context) => const _NewCanvasDialog(),
    );
    if (choice == null || !mounted) return;
    if (!await _confirm(
      AppLocalizations.of(context).newCanvasConfirmTitle,
      AppLocalizations.of(context).newCanvasConfirmBody,
      AppLocalizations.of(context).newCanvasConfirmAction,
    )) {
      return;
    }
    if (!mounted) return;
    final done = AppLocalizations.of(context).newCanvasDone;
    await _run(
      () => widget.canvas.startNewCanvas(
        size: choice.size,
        paletteId: choice.palette,
      ),
      done: done,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.groups, widget.friends]),
      builder: (context, _) {
        final summary = widget.groups.byId(widget.groupId);
        if (summary == null) {
          return const Scaffold(
            backgroundColor: NeoColors.paper,
            body: Center(
              child: CircularProgressIndicator(color: NeoColors.ink),
            ),
          );
        }
        _fill(summary);
        final owner = summary.iAmOwner;
        final sent = [
          for (final i in widget.groups.outgoing)
            if (i.groupId == summary.group.id) i,
        ];
        return Scaffold(
          backgroundColor: NeoColors.paper,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.arrow_back,
                      tooltip: AppLocalizations.of(context).backTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).groupSettingsTitle,
                        style: const TextStyle(
                          fontFamily: NeoFont.display,
                          color: NeoColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (owner)
                      NeoLabel(
                        AppLocalizations.of(context).ownerBadge,
                        color: NeoColors.yellow,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _section(AppLocalizations.of(context).sectionInfo),
                if (owner) _editForm(summary) else _readOnlyInfo(summary),
                const SizedBox(height: 22),
                _section(
                  AppLocalizations.of(context).sectionMembers(
                    summary.members.length,
                    summary.group.maxMembers,
                  ),
                ),
                for (final member in summary.members)
                  _memberTile(summary, member, owner),
                if (owner) ...[
                  const SizedBox(height: 6),
                  NeoButton(
                    label: AppLocalizations.of(context).inviteToGroup,
                    icon: Icons.person_add_alt_1,
                    expand: true,
                    onPressed: _busy ? null : () => _invite(summary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).inviteNote,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (owner && sent.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _section(AppLocalizations.of(context).sectionPendingInvites),
                  for (final invite in sent) _inviteTile(invite),
                ],
                if (owner) ...[
                  const SizedBox(height: 22),
                  _section('CANVAS'),
                  NeoButton(
                    label: AppLocalizations.of(context).newCanvasButton,
                    icon: Icons.grid_on,
                    variant: NeoButtonVariant.secondary,
                    expand: true,
                    onPressed: _busy ? null : _newCanvas,
                  ),
                ],
                const SizedBox(height: 28),
                NeoButton(
                  label: AppLocalizations.of(context).leaveGroup,
                  icon: Icons.logout,
                  variant: NeoButtonVariant.outline,
                  expand: true,
                  onPressed: _busy ? null : () => _leave(summary),
                ),
                if (owner) ...[
                  const SizedBox(height: 10),
                  NeoButton(
                    label: AppLocalizations.of(context).dissolveGroup,
                    icon: Icons.delete_outline,
                    variant: NeoButtonVariant.accent,
                    expand: true,
                    onPressed: _busy ? null : () => _dissolve(summary),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: NeoColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _readOnlyInfo(GroupSummary summary) => Container(
    padding: const EdgeInsets.all(14),
    decoration: NeoTheme.panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.group.name,
          style: const TextStyle(
            fontFamily: NeoFont.display,
            color: NeoColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          summary.group.rules.isEmpty
              ? AppLocalizations.of(context).rulesNone
              : summary.group.rules,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _editForm(GroupSummary summary) => Container(
    padding: const EdgeInsets.all(14),
    decoration: NeoTheme.panel(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).groupNameLabel,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _rules,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).rulesLabel,
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).groupMaxMembers,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).decrease,
              onPressed: Haptics.tap(
                _max > summary.members.length && _max > 2
                    ? () => setState(() => _max--)
                    : null,
              ),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_max',
              style: const TextStyle(
                fontFamily: NeoFont.display,
                color: NeoColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).increase,
              onPressed: Haptics.tap(
                _max < 12 ? () => setState(() => _max++) : null,
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 6),
        NeoButton(
          label: AppLocalizations.of(context).saveButton,
          icon: Icons.check,
          expand: true,
          onPressed: _busy ? null : () => _save(summary),
        ),
      ],
    ),
  );

  Widget _memberTile(GroupSummary summary, GroupMember member, bool owner) {
    final me = member.person.id == widget.myId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: Haptics.tap(
          me
              ? null
              : () => showPersonCard(
                  context,
                  person: member.person,
                  friends: widget.friends,
                  safety: widget.safety,
                ),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: NeoTheme.panel(),
          child: Row(
            children: [
              PersonBadge(person: member.person),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me
                          ? AppLocalizations.of(
                              context,
                            ).memberYou(member.person.displayName)
                          : member.person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      member.isOwner
                          ? AppLocalizations.of(context).ownerRole
                          : member.person.handle,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (owner && !me)
                PopupMenuButton<String>(
                  tooltip: AppLocalizations.of(context).optionsTooltip,
                  icon: const Icon(Icons.more_vert, color: NeoColors.ink),
                  onSelected: Haptics.tapWith((value) {
                    switch (value) {
                      case 'transfer':
                        _transfer(summary, member.person);
                      case 'rollback':
                        _rollback(member.person);
                      case 'kick':
                        _kick(summary, member.person);
                    }
                  }),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'transfer',
                      child: Text(AppLocalizations.of(context).menuTransfer),
                    ),
                    PopupMenuItem(
                      value: 'rollback',
                      child: Text(AppLocalizations.of(context).menuRollback),
                    ),
                    PopupMenuItem(
                      value: 'kick',
                      child: Text(AppLocalizations.of(context).menuKick),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inviteTile(GroupInvite invite) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: NeoTheme.panel(color: NeoColors.yellow),
      child: Row(
        children: [
          PersonBadge(person: invite.person),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              invite.person.displayName,
              style: const TextStyle(
                color: NeoColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          NeoButton(
            label: AppLocalizations.of(context).revokeInvite,
            variant: NeoButtonVariant.outline,
            onPressed: _busy
                ? null
                : () => _run(() => widget.groups.revokeInvite(invite)),
          ),
        ],
      ),
    ),
  );
}

class _FriendPicker extends StatelessWidget {
  const _FriendPicker({required this.candidates});

  final List<Person> candidates;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(18),
      decoration: NeoTheme.panel(radius: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context).inviteFriendsTitle,
            style: const TextStyle(
              fontFamily: NeoFont.display,
              color: NeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                AppLocalizations.of(context).noOneToInvite,
                style: const TextStyle(
                  color: NeoColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final person in candidates)
                    ListTile(
                      leading: PersonBadge(person: person),
                      title: Text(
                        person.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(person.handle),
                      onTap: Haptics.tap(
                        () => Navigator.of(context).pop(person),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NewCanvasDialog extends StatefulWidget {
  const _NewCanvasDialog();

  @override
  State<_NewCanvasDialog> createState() => _NewCanvasDialogState();
}

class _NewCanvasDialogState extends State<_NewCanvasDialog> {
  int _size = 32;
  String _palette = 'eightbit';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        AppLocalizations.of(context).newCanvasTitle,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).sizeLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final size in const [16, 24, 32])
                ChoiceChip(
                  label: Text('$size×$size'),
                  selected: _size == size,
                  onSelected: Haptics.tapWith(
                    (_) => setState(() => _size = size),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).paletteLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('8-bit'),
                selected: _palette == 'eightbit',
                onSelected: Haptics.tapWith(
                  (_) => setState(() => _palette = 'eightbit'),
                ),
              ),
              ChoiceChip(
                label: const Text('Van Gogh'),
                selected: _palette == 'vangogh',
                onSelected: Haptics.tapWith(
                  (_) => setState(() => _palette = 'vangogh'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context)),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        TextButton(
          onPressed: Haptics.tap(
            () => Navigator.pop(context, (size: _size, palette: _palette)),
          ),
          child: Text(AppLocalizations.of(context).continueButton),
        ),
      ],
    );
  }
}
