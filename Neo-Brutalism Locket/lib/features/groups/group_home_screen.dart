import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/albums/albums_screen.dart';
import 'package:neo_brutalism_locket/features/albums/albums_store.dart';
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
import 'package:neo_brutalism_locket/features/groups/group_tabs.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/features/posts/media_actions.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// One group: its chat and its canvas, side by side as two tabs.
class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({
    required this.groupId,
    required this.groups,
    required this.friends,
    required this.canvasRepository,
    required this.myId,
    this.safety,
    this.albums,
    this.mediaUrls,
    super.key,
  });

  final String groupId;
  final GroupsStore groups;
  final FriendsStore friends;
  final CanvasRepository canvasRepository;
  final String myId;
  final SafetyRepository? safety;

  /// The group's event albums; null (no ALBUM tab) when not available.
  final AlbumsStore? albums;
  final MediaUrls? mediaUrls;

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
  late final MediaActions _actions = MediaActions(widget.mediaUrls);

  /// 0 chat, 1 canvas, 2 albums.
  int _tab = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _chat.load();
    _canvas.load();
    widget.albums?.refresh();
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

  /// The tabs, each with what is going on in it: unread messages, my Ink,
  /// albums open now.
  List<GroupTabData> _tabs(BuildContext context, GroupSummary summary) {
    final l10n = AppLocalizations.of(context);
    final albums = widget.albums;
    final now = DateTime.now();
    final openAlbums = albums == null
        ? 0
        : albums.forGroup(widget.groupId).where((a) => a.isOpenAt(now)).length;
    return [
      GroupTabData(
        label: 'CHAT',
        icon: Icons.chat_bubble_outline,
        color: NeoColors.accent,
        badge: summary.unread,
      ),
      GroupTabData(
        label: 'CANVAS',
        icon: Icons.grid_on,
        color: NeoColors.coral,
        info: _canvas.status == CanvasStatus.ready
            ? l10n.inkAmountLabel(_canvas.ink)
            : null,
      ),
      if (albums != null)
        GroupTabData(
          label: l10n.groupTabAlbums,
          icon: Icons.photo_album_outlined,
          color: NeoColors.teal,
          info: openAlbums > 0 ? l10n.groupTabOpenAlbums(openAlbums) : null,
        ),
    ];
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 19, 0),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_canvas, ?widget.albums]),
                    builder: (context, _) => GroupTabBar(
                      selected: _tab,
                      onSelect: (index) => setState(() => _tab = index),
                      tabs: _tabs(context, summary),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
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
                      if (widget.albums != null)
                        AlbumsPanel(
                          groupId: widget.groupId,
                          store: widget.albums!,
                          members: members,
                          myId: widget.myId,
                          iAmOwner: summary.iAmOwner,
                          mediaUrls: widget.mediaUrls,
                          actions: _actions,
                        )
                      else
                        const SizedBox.shrink(),
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
