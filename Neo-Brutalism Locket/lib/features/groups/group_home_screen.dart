import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_view.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_store.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_view.dart';
import 'package:neo_brutalism_locket/features/groups/group_settings_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// One group: its chat and its canvas, side by side as two tabs.
class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({
    required this.groupId,
    required this.groups,
    required this.friends,
    required this.canvasRepository,
    required this.myId,
    this.safety,
    super.key,
  });

  final String groupId;
  final GroupsStore groups;
  final FriendsStore friends;
  final CanvasRepository canvasRepository;
  final String myId;
  final SafetyRepository? safety;

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  late final GroupChatStore _chat = GroupChatStore(
    widget.groups.repository,
    groupId: widget.groupId,
    myId: widget.myId,
  );
  late final CanvasStore _canvas = CanvasStore(
    widget.canvasRepository,
    groupId: widget.groupId,
  );
  bool _showCanvas = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _chat.load();
    _canvas.load();
    widget.groups.addListener(_onGroupsChanged);
  }

  @override
  void dispose() {
    widget.groups.removeListener(_onGroupsChanged);
    _canvas.flushNow();
    _chat.dispose();
    _canvas.dispose();
    super.dispose();
  }

  /// I left, was removed, or the group was dissolved: nothing left to show.
  void _onGroupsChanged() {
    if (_closing || !widget.groups.isLoaded) return;
    if (widget.groups.byId(widget.groupId) != null) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      showNeoSnack(context, AppLocalizations.of(context).gfNotMember);
    });
  }

  Map<String, Person> _members(GroupSummary summary) => {
    for (final member in summary.members) member.person.id: member.person,
  };

  void _openPerson(Person person) {
    if (person.id == widget.myId) return;
    showPersonCard(
      context,
      person: person,
      friends: widget.friends,
      safety: widget.safety,
    );
  }

  Future<void> _openSettings(GroupSummary summary) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => GroupSettingsScreen(
            groupId: widget.groupId,
            groups: widget.groups,
            friends: widget.friends,
            canvas: _canvas,
            myId: widget.myId,
            safety: widget.safety,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.groups,
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
        final members = _members(summary);
        return Scaffold(
          backgroundColor: NeoColors.paper,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      NeoIconButton(
                        icon: Icons.arrow_back,
                        tooltip: AppLocalizations.of(context).backTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      GroupBadge(name: summary.group.name, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NeoFont.display,
                                color: NeoColors.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).memberCount(summary.members.length),
                              style: const TextStyle(
                                color: NeoColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      NeoIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: AppLocalizations.of(
                          context,
                        ).groupSettingsTooltip,
                        onPressed: () => _openSettings(summary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Tab(
                          label: 'CHAT',
                          icon: Icons.chat_bubble_outline,
                          selected: !_showCanvas,
                          onTap: () => setState(() => _showCanvas = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Tab(
                          label: 'CANVAS',
                          icon: Icons.grid_on,
                          selected: _showCanvas,
                          onTap: () => setState(() => _showCanvas = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: IndexedStack(
                    index: _showCanvas ? 1 : 0,
                    children: [
                      GroupChatView(
                        store: _chat,
                        members: members,
                        myId: widget.myId,
                        onOpenPerson: _openPerson,
                      ),
                      CanvasView(
                        store: _canvas,
                        nameOf: (id) => id == widget.myId
                            ? AppLocalizations.of(context).youLabel
                            : members[id]?.displayName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: Haptics.tap(onTap),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? NeoColors.teal : NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: NeoColors.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
