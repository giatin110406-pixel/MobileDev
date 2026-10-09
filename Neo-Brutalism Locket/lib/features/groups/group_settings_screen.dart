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
      if (mounted) showNeoSnack(context, groupFailureText(failure));
    } on CanvasFailure catch (failure) {
      if (mounted) showNeoSnack(context, canvasFailureText(failure.kind));
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
    done: 'Đã lưu.',
  );

  Future<void> _kick(GroupSummary summary, Person person) async {
    if (!await _confirm(
      'Mời ${person.displayName} ra khỏi nhóm?',
      'Họ sẽ không đọc được tin nhắn của nhóm nữa. Những ô họ đã vẽ vẫn giữ nguyên.',
      'Mời ra',
    )) {
      return;
    }
    await _run(() => widget.groups.kick(summary, person));
  }

  Future<void> _transfer(GroupSummary summary, Person person) async {
    if (!await _confirm(
      'Chuyển quyền trưởng nhóm?',
      '${person.displayName} sẽ là trưởng nhóm mới. Bạn trở thành thành viên thường.',
      'Chuyển quyền',
    )) {
      return;
    }
    await _run(
      () => widget.groups.transferOwnership(summary, person),
      done: '${person.displayName} là trưởng nhóm mới.',
    );
  }

  Future<void> _rollback(Person person) async {
    if (!await _confirm(
      'Hoàn tác nét vẽ của ${person.displayName}?',
      'Những ô họ vẽ trong 24 giờ qua và chưa bị ai vẽ đè sẽ quay về màu trước đó. '
          'Mực của họ không được hoàn lại.',
      'Hoàn tác',
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
    if (ok && mounted) showNeoSnack(context, 'Đã hoàn tác $restored ô.');
  }

  Future<void> _leave(GroupSummary summary) async {
    if (!await _confirm(
      'Rời nhóm ${summary.group.name}?',
      'Bạn sẽ không đọc được tin nhắn và canvas của nhóm nữa.',
      'Rời nhóm',
    )) {
      return;
    }
    await _run(() => widget.groups.leave(summary));
  }

  Future<void> _dissolve(GroupSummary summary) async {
    if (!await _confirm(
      'Giải tán nhóm ${summary.group.name}?',
      'Cả nhóm sẽ mất quyền xem tin nhắn và canvas. Không thể hoàn tác.',
      'Giải tán',
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
    if (picked == null) return;
    await _run(
      () => widget.groups.invite(summary, picked),
      done: 'Đã mời ${picked.displayName}.',
    );
  }

  Future<void> _newCanvas() async {
    final choice = await showDialog<({int size, String palette})>(
      context: context,
      builder: (context) => const _NewCanvasDialog(),
    );
    if (choice == null || !mounted) return;
    if (!await _confirm(
      'Bắt đầu canvas mới?',
      'Canvas hiện tại được lưu lại và không vẽ thêm được nữa. Canvas mới bắt đầu trống.',
      'Tạo canvas',
    )) {
      return;
    }
    await _run(
      () => widget.canvas.startNewCanvas(
        size: choice.size,
        paletteId: choice.palette,
      ),
      done: 'Đã tạo canvas mới.',
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
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cài đặt nhóm',
                        style: TextStyle(
                          color: NeoColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (owner) const NeoLabel('TRƯỞNG NHÓM', color: NeoColors.yellow),
                  ],
                ),
                const SizedBox(height: 18),
                _section('THÔNG TIN'),
                if (owner) _editForm(summary) else _readOnlyInfo(summary),
                const SizedBox(height: 22),
                _section(
                  'THÀNH VIÊN (${summary.members.length}/${summary.group.maxMembers})',
                ),
                for (final member in summary.members)
                  _memberTile(summary, member, owner),
                if (owner) ...[
                  const SizedBox(height: 6),
                  NeoButton(
                    label: 'MỜI BẠN VÀO NHÓM',
                    icon: Icons.person_add_alt_1,
                    expand: true,
                    onPressed: _busy ? null : () => _invite(summary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chỉ mời được bạn bè của bạn. Lời mời hết hạn sau 7 ngày.',
                    style: TextStyle(
                      color: NeoColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (owner && sent.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _section('LỜI MỜI ĐANG CHỜ'),
                  for (final invite in sent)
                    _inviteTile(invite),
                ],
                if (owner) ...[
                  const SizedBox(height: 22),
                  _section('CANVAS'),
                  NeoButton(
                    label: 'TẠO CANVAS MỚI',
                    icon: Icons.grid_on,
                    variant: NeoButtonVariant.secondary,
                    expand: true,
                    onPressed: _busy ? null : _newCanvas,
                  ),
                ],
                const SizedBox(height: 28),
                NeoButton(
                  label: 'RỜI NHÓM',
                  icon: Icons.logout,
                  variant: NeoButtonVariant.outline,
                  expand: true,
                  onPressed: _busy ? null : () => _leave(summary),
                ),
                if (owner) ...[
                  const SizedBox(height: 10),
                  NeoButton(
                    label: 'GIẢI TÁN NHÓM',
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
            color: NeoColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          summary.group.rules.isEmpty
              ? 'Nhóm chưa đặt quy tắc.'
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
          decoration: const InputDecoration(
            labelText: 'Tên nhóm',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _rules,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Quy tắc',
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Số thành viên tối đa',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Giảm',
              onPressed: _max > summary.members.length && _max > 2
                  ? () => setState(() => _max--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_max',
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            IconButton(
              tooltip: 'Tăng',
              onPressed: _max < 12 ? () => setState(() => _max++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 6),
        NeoButton(
          label: 'LƯU',
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
        onTap: me
            ? null
            : () => showPersonCard(
                context,
                person: member.person,
                friends: widget.friends,
                safety: widget.safety,
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
                          ? '${member.person.displayName} (bạn)'
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
                      member.isOwner ? 'Trưởng nhóm' : member.person.handle,
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
                  tooltip: 'Tuỳ chọn',
                  icon: const Icon(Icons.more_vert, color: NeoColors.ink),
                  onSelected: (value) {
                    switch (value) {
                      case 'transfer':
                        _transfer(summary, member.person);
                      case 'rollback':
                        _rollback(member.person);
                      case 'kick':
                        _kick(summary, member.person);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'transfer',
                      child: Text('Chuyển quyền trưởng nhóm'),
                    ),
                    PopupMenuItem(
                      value: 'rollback',
                      child: Text('Hoàn tác nét vẽ (24 giờ)'),
                    ),
                    PopupMenuItem(value: 'kick', child: Text('Mời ra khỏi nhóm')),
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
            label: 'THU HỒI',
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
          const Text(
            'MỜI BẠN BÈ',
            style: TextStyle(
              color: NeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Không còn người bạn nào để mời. Chỉ mời được bạn bè của bạn.',
                style: TextStyle(
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
                      onTap: () => Navigator.of(context).pop(person),
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
      title: const Text(
        'Canvas mới',
        style: TextStyle(color: NeoColors.ink, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kích thước',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final size in const [16, 24, 32])
                ChoiceChip(
                  label: Text('$size×$size'),
                  selected: _size == size,
                  onSelected: (_) => setState(() => _size = size),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bảng màu',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('8-bit'),
                selected: _palette == 'eightbit',
                onSelected: (_) => setState(() => _palette = 'eightbit'),
              ),
              ChoiceChip(
                label: const Text('Van Gogh'),
                selected: _palette == 'vangogh',
                onSelected: (_) => setState(() => _palette = 'vangogh'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (size: _size, palette: _palette)),
          child: const Text('Tiếp tục'),
        ),
      ],
    );
  }
}
