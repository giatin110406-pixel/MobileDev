import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// My groups: invitations first, then the groups, then a button to start one.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({
    required this.store,
    required this.onOpenGroup,
    this.segment,
    this.header,
    super.key,
  });

  final GroupsStore store;
  final ValueChanged<GroupSummary> onOpenGroup;

  /// The Friends | Groups switch, shown above the title.
  final Widget? segment;

  /// A card under the switch (this week's contest).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?segment,
              if (header != null) ...[const SizedBox(height: 14), header!],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.groupsKicker,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.groupsTitle,
                          style: const TextStyle(
                            fontFamily: NeoFont.display,
                            color: NeoColors.ink,
                            fontSize: 26,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NeoLabel(
                    l10n.groupsCount(store.groups.length),
                    color: NeoColors.yellow,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              NeoButton(
                label: l10n.groupCreate,
                icon: Icons.group_add_outlined,
                expand: true,
                onPressed: () => showCreateGroupSheet(context, store: store),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: store.refresh,
                  child: _list(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    if (!store.isLoaded) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: store.loadError == null
                ? const CircularProgressIndicator(color: NeoColors.ink)
                : _ErrorNote(onRetry: store.refresh),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      children: [
        if (store.loadError != null) ...[
          _ErrorNote(onRetry: store.refresh, stale: true),
          const SizedBox(height: 12),
        ],
        if (store.incoming.isNotEmpty) ...[
          const Text(
            'LỜI MỜI VÀO NHÓM',
            style: TextStyle(
              color: NeoColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final invite in store.incoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InviteTile(invite: invite, store: store),
            ),
          const SizedBox(height: 6),
        ],
        if (store.groups.isEmpty)
          const _EmptyGroups()
        else
          for (final summary in store.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GroupTile(
                summary: summary,
                onTap: () => onOpenGroup(summary),
              ),
            ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.onRetry, this.stale = false});

  final Future<void> Function() onRetry;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NeoTheme.panel(color: NeoColors.orange),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stale
                  ? 'Không cập nhật được. Đang hiện dữ liệu cũ.'
                  : 'Không tải được danh sách nhóm.',
              style: const TextStyle(
                color: NeoColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          NeoButton(label: 'THỬ LẠI', onPressed: onRetry),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: NeoTheme.panel(color: NeoColors.surface),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chưa có nhóm nào',
            style: TextStyle(
              fontFamily: NeoFont.display,
              color: NeoColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tạo nhóm với bạn bè để cùng nhắn tin và cùng vẽ một canvas pixel. '
            'Mỗi nhiệm vụ hằng ngày cho bạn 10 mực, mỗi ô vẽ tốn 1 mực.',
            style: TextStyle(
              color: NeoColors.ink,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.summary, required this.onTap});

  final GroupSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = summary.lastMessage;
    final preview = last == null
        ? 'Chưa có tin nhắn'
        : last.kind == GroupMessageKind.system
        ? 'Hoạt động mới trong nhóm'
        : last.body;
    return Semantics(
      button: true,
      label:
          'Nhóm ${summary.group.name}, ${summary.members.length} thành viên'
          '${summary.unread > 0 ? ', ${summary.unread} tin chưa đọc' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: NeoTheme.panel(),
          child: Row(
            children: [
              GroupBadge(name: summary.group.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${summary.members.length}/${summary.group.maxMembers} '
                      'thành viên${summary.iAmOwner ? ' · trưởng nhóm' : ''}',
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.unread > 0)
                NeoLabel('${summary.unread}', color: NeoColors.pink),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatefulWidget {
  const _InviteTile({required this.invite, required this.store});

  final GroupInvite invite;
  final GroupsStore store;

  @override
  State<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends State<_InviteTile> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    setState(() => _busy = true);
    try {
      await widget.store.respond(widget.invite, accept: accept);
      if (mounted && accept) {
        showNeoSnack(context, 'Đã vào nhóm ${widget.invite.groupName}.');
      }
    } on GroupFailure catch (failure) {
      if (mounted) showNeoSnack(context, groupFailureText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: NeoTheme.panel(color: NeoColors.yellow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GroupBadge(name: invite.groupName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${invite.person.displayName} mời bạn vào nhóm',
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: 'TỪ CHỐI',
                  variant: NeoButtonVariant.outline,
                  expand: true,
                  onPressed: _busy ? null : () => _answer(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeoButton(
                  label: 'THAM GIA',
                  expand: true,
                  onPressed: _busy ? null : () => _answer(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name, rules and the member cap. Returns once the group exists.
Future<void> showCreateGroupSheet(
  BuildContext context, {
  required GroupsStore store,
  ValueChanged<String>? onCreated,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => _CreateGroupSheet(store: store, onCreated: onCreated),
);

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.store, this.onCreated});

  final GroupsStore store;
  final ValueChanged<String>? onCreated;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _name = TextEditingController();
  final _rules = TextEditingController();
  int _max = 12;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.store.create(
        name: _name.text,
        rules: _rules.text,
        maxMembers: _max,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated?.call(id);
    } on GroupFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = groupFailureText(failure);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(18),
        decoration: NeoTheme.panel(radius: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TẠO NHÓM MỚI',
                style: TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
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
                  labelText: 'Quy tắc (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
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
                    onPressed: _max > 2 ? () => setState(() => _max--) : null,
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
                    tooltip: 'Tăng',
                    onPressed: _max < 12 ? () => setState(() => _max++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: NeoColors.pink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              NeoButton(
                label: _busy ? 'ĐANG TẠO…' : 'TẠO NHÓM',
                icon: Icons.check,
                expand: true,
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
