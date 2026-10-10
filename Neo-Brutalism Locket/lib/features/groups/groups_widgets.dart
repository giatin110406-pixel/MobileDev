import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_widgets.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// What went wrong with a group action, in words.
String groupFailureText(AppLocalizations l10n, GroupFailure failure) =>
    switch (failure.kind) {
      GroupFailureKind.notFound => l10n.gfNotFound,
      GroupFailureKind.notOwner => l10n.gfNotOwner,
      GroupFailureKind.notMember => l10n.gfNotMember,
      GroupFailureKind.self => l10n.gfSelf,
      GroupFailureKind.empty => l10n.gfEmpty,
      GroupFailureKind.tooLong => l10n.gfTooLong,
      GroupFailureKind.blockedWord => l10n.gfBlockedWord,
      GroupFailureKind.badName => l10n.gfBadName,
      GroupFailureKind.badSize => l10n.gfBadSize,
      GroupFailureKind.groupLimit => l10n.gfGroupLimit,
      GroupFailureKind.memberLimit => l10n.gfMemberLimit,
      GroupFailureKind.theirGroupLimit => l10n.gfTheirGroupLimit,
      GroupFailureKind.alreadyMember => l10n.gfAlreadyMember,
      GroupFailureKind.alreadyInvited => l10n.gfAlreadyInvited,
      GroupFailureKind.expired => l10n.gfExpired,
      GroupFailureKind.ownerMustTransfer => l10n.gfOwnerMustTransfer,
      GroupFailureKind.network => l10n.gfNetwork,
      GroupFailureKind.unknown => l10n.gfUnknown,
    };

String canvasFailureText(AppLocalizations l10n, CanvasFailureKind kind) =>
    switch (kind) {
      CanvasFailureKind.insufficientInk => l10n.kfInsufficientInk,
      CanvasFailureKind.rateLimited => l10n.kfRateLimited,
      CanvasFailureKind.canvasLocked => l10n.kfCanvasLocked,
      CanvasFailureKind.notFound => l10n.kfNotFound,
      CanvasFailureKind.notOwner => l10n.kfNotOwner,
      CanvasFailureKind.badPixel ||
      CanvasFailureKind.tooManyPixels => l10n.kfBadPixel,
      CanvasFailureKind.badSize => l10n.kfBadSize,
      CanvasFailureKind.network => l10n.kfNetwork,
      CanvasFailureKind.unknown => l10n.gfUnknown,
    };

/// A system line in the chat ("Nam joined").
String systemMessageText(
  AppLocalizations l10n,
  GroupMessage message,
  String name,
) => switch (message.body) {
  'joined' => l10n.sysJoined(name),
  'left' => l10n.sysLeft(name),
  'kicked' => l10n.sysKicked(name),
  'owner_changed' => l10n.sysOwnerChanged(name),
  'entry_submitted' => l10n.sysEntrySubmitted,
  _ => name,
};

const _badgeColors = [
  NeoColors.pink,
  NeoColors.purple,
  NeoColors.teal,
  NeoColors.yellow,
  NeoColors.blue,
  NeoColors.orange,
];

/// A coloured square with the first letter: the group's picture.
class GroupBadge extends StatelessWidget {
  const GroupBadge({required this.name, this.size = 46, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final letter = name.trim().isEmpty
        ? '?'
        : String.fromCharCode(name.trim().runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _badgeColors[hash % _badgeColors.length],
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: NeoColors.ink,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// A person's square picture: their colour and first letter.
class PersonBadge extends StatelessWidget {
  const PersonBadge({required this.person, this.size = 40, super.key});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final friend = person.toPocketFriend();
    final name = person.displayName.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(friend.avatarColor),
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name.isEmpty
            ? '?'
            : String.fromCharCode(name.runes.first).toUpperCase(),
        style: TextStyle(
          color: NeoColors.ink,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Two big buttons that flip between the friends list and the groups.
class FriendsGroupsSwitch extends StatelessWidget {
  const FriendsGroupsSwitch({
    required this.showGroups,
    required this.onChanged,
    this.groupUnread = 0,
    super.key,
  });

  final bool showGroups;
  final ValueChanged<bool> onChanged;
  final int groupUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segment(
            label: AppLocalizations.of(context).tabFriends,
            icon: Icons.people_alt_outlined,
            selected: !showGroups,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Segment(
            label: AppLocalizations.of(context).segmentGroups,
            icon: Icons.groups_2_outlined,
            selected: showGroups,
            badge: groupUnread,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: Haptics.tap(onTap),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? NeoColors.yellow : NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: NeoColors.ink,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: NeoColors.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                NeoLabel('$badge', color: NeoColors.pink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a stranger in a group sees: only the public card. Their photos stay
/// private until you are friends (the database enforces that, not this screen).
Future<void> showPersonCard(
  BuildContext context, {
  required Person person,
  required FriendsStore friends,
  SafetyRepository? safety,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) =>
      _PersonCard(person: person, friends: friends, safety: safety),
);

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.friends,
    required this.safety,
  });

  final Person person;
  final FriendsStore friends;
  final SafetyRepository? safety;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: friends,
      builder: (context, _) {
        final isFriend = friends.friendById(person.id) != null;
        final asked = friends.outgoing.any((r) => r.person.id == person.id);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(18),
          decoration: NeoTheme.panel(radius: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PersonBadge(person: person, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.displayName,
                            style: const TextStyle(
                              fontFamily: NeoFont.display,
                              color: NeoColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            person.handle,
                            style: const TextStyle(
                              color: NeoColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  isFriend
                      ? AppLocalizations.of(context).personFriendsNote
                      : AppLocalizations.of(context).personNotFriendsNote,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                NeoButton(
                  label: isFriend
                      ? AppLocalizations.of(context).personAlreadyFriends
                      : asked
                      ? AppLocalizations.of(context).personRequestSent
                      : AppLocalizations.of(context).personBefriend,
                  icon: isFriend ? Icons.check : Icons.person_add_alt_1,
                  expand: true,
                  onPressed: isFriend || asked
                      ? null
                      : () => sendFriendRequestWithFeedback(
                          context,
                          friends,
                          person,
                        ),
                ),
                if (safety != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: NeoButton(
                          label: AppLocalizations.of(context).reportTitle,
                          icon: Icons.flag_outlined,
                          variant: NeoButtonVariant.outline,
                          expand: true,
                          onPressed: () => _report(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NeoButton(
                          label: AppLocalizations.of(context).blockPerson,
                          icon: Icons.block,
                          variant: NeoButtonVariant.outline,
                          expand: true,
                          onPressed: () => _block(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _report(BuildContext context) async {
    final draft = await showReportSheet(context);
    if (draft == null || !context.mounted) return;
    try {
      await safety!.report(
        userId: person.id,
        reason: draft.reason,
        details: draft.details,
      );
      if (context.mounted) {
        showNeoSnack(context, AppLocalizations.of(context).reportSent);
      }
    } on SafetyFailure {
      if (context.mounted) {
        showNeoSnack(context, AppLocalizations.of(context).reportFailed);
      }
    }
  }

  Future<void> _block(BuildContext context) async {
    if (!await confirmBlock(context, person.displayName) || !context.mounted) {
      return;
    }
    try {
      await safety!.block(person.id);
      await friends.refresh();
      if (context.mounted) {
        Navigator.of(context).pop();
        showNeoSnack(
          context,
          AppLocalizations.of(context).blockedDone(person.displayName),
        );
      }
    } on SafetyFailure {
      if (context.mounted) {
        showNeoSnack(context, AppLocalizations.of(context).blockFailed);
      }
    }
  }
}
