import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// `neolocket://add/<username>` — the invite link people share.
const inviteScheme = 'neolocket';

String inviteLinkFor(String username) => '$inviteScheme://add/$username';

/// The username in an invite link, or null when [uri] is something else.
String? usernameFromInviteLink(Uri uri) {
  if (uri.scheme != inviteScheme || uri.host != 'add') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length != 1) return null;
  final name = segments.single.toLowerCase();
  return RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(name) ? name : null;
}

String friendsFailureText(AppLocalizations l10n, FriendsFailure failure) =>
    switch (failure.kind) {
      FriendsFailureKind.notFound => l10n.friendNotFound,
      FriendsFailureKind.self => l10n.friendSelf,
      FriendsFailureKind.alreadyFriends => l10n.friendAlready,
      FriendsFailureKind.alreadySent => l10n.friendAlreadySent,
      FriendsFailureKind.notAccepting => l10n.friendNotAccepting,
      FriendsFailureKind.tooManyPending => l10n.friendTooManyPending,
      FriendsFailureKind.friendLimit => l10n.friendLimit,
      FriendsFailureKind.theirFriendLimit => l10n.friendTheirLimit,
      FriendsFailureKind.network => l10n.errNetwork,
      FriendsFailureKind.unknown => l10n.friendsGenericError,
    };

/// Runs [request], tells the user how it went (a snack bar) and returns true
/// when it worked.
Future<bool> sendFriendRequestWithFeedback(
  BuildContext context,
  FriendsStore store,
  Person person,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    final result = await store.sendRequest(person.username);
    if (context.mounted) {
      showNeoSnack(
        context,
        result == SendResult.accepted
            ? l10n.nowFriendsWith(person.displayName)
            : l10n.requestSentTo(person.displayName),
      );
    }
    return true;
  } on FriendsFailure catch (failure) {
    if (context.mounted) {
      showNeoSnack(context, friendsFailureText(l10n, failure));
    }
    return false;
  }
}

/// Pending requests: people who asked me (accept / decline) and people I asked
/// (cancel).
class RequestsSection extends StatelessWidget {
  const RequestsSection({
    super.key,
    required this.incoming,
    required this.outgoing,
    required this.onRespond,
    required this.onCancel,
  });

  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  final void Function(FriendRequest request, bool accept) onRespond;
  final ValueChanged<FriendRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    if (incoming.isEmpty && outgoing.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.friendsRequests,
                style: const TextStyle(
                  color: NeoColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            NeoLabel(
              '${incoming.length + outgoing.length}',
              color: NeoColors.pink,
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final request in incoming)
          _RequestTile(
            request: request,
            caption: l10n.friendsIncoming,
            color: NeoColors.yellow,
            actions: [
              NeoButton(
                label: l10n.friendsAccept,
                variant: NeoButtonVariant.accent,
                onPressed: () => onRespond(request, true),
              ),
              NeoButton(
                label: l10n.friendsDecline,
                variant: NeoButtonVariant.outline,
                onPressed: () => onRespond(request, false),
              ),
            ],
          ),
        for (final request in outgoing)
          _RequestTile(
            request: request,
            caption: l10n.friendsOutgoing,
            color: NeoColors.surface,
            actions: [
              NeoButton(
                label: l10n.friendsCancelRequest,
                variant: NeoButtonVariant.outline,
                onPressed: () => onCancel(request),
              ),
            ],
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.caption,
    required this.color,
    required this.actions,
  });

  final FriendRequest request;
  final String caption;
  final Color color;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final friend = request.person.toPocketFriend(since: request.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: NeoTheme.panel(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FriendAvatar(friend: friend, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${friend.handle} · $caption',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

/// Opens the "add friend" sheet. [initialUsername] pre-fills the search (used
/// when someone opens an invite link).
Future<void> showAddFriendOnlineSheet(
  BuildContext context, {
  required FriendsStore store,
  required String myUsername,
  String? initialUsername,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => _AddFriendOnlineSheet(
    store: store,
    myUsername: myUsername,
    initialUsername: initialUsername,
  ),
);

class _AddFriendOnlineSheet extends StatefulWidget {
  const _AddFriendOnlineSheet({
    required this.store,
    required this.myUsername,
    this.initialUsername,
  });

  final FriendsStore store;
  final String myUsername;
  final String? initialUsername;

  @override
  State<_AddFriendOnlineSheet> createState() => _AddFriendOnlineSheetState();
}

class _AddFriendOnlineSheetState extends State<_AddFriendOnlineSheet> {
  late final _query = TextEditingController(text: widget.initialUsername ?? '');
  Timer? _debounce;
  List<Person> _results = const [];
  bool _searching = false;
  bool _searched = false;
  final _sending = <String>{};

  @override
  void initState() {
    super.initState();
    if ((widget.initialUsername ?? '').length >= 2) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final text = _query.text.trim().replaceFirst('@', '');
    if (text.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final found = await widget.store.search(text);
      if (!mounted || _query.text.trim().replaceFirst('@', '') != text) return;
      setState(() {
        _results = found;
        _searched = true;
      });
    } on FriendsFailure catch (failure) {
      if (mounted) {
        showNeoSnack(
          context,
          friendsFailureText(AppLocalizations.of(context), failure),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Person person) async {
    setState(() => _sending.add(person.id));
    final ok = await sendFriendRequestWithFeedback(
      context,
      widget.store,
      person,
    );
    if (!mounted) return;
    setState(() => _sending.remove(person.id));
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _share() {
    final l10n = AppLocalizations.of(context);
    return SharePlus.instance.share(
      ShareParams(
        text: l10n.inviteMessage(
          widget.myUsername,
          inviteLinkFor(widget.myUsername),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(18),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.addFriendTitle,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: NeoTheme.panel(color: NeoColors.paper),
                child: TextField(
                  controller: _query,
                  autofocus: widget.initialUsername == null,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.addFriendHint,
                    prefixText: '@',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _searching && _results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: NeoColors.ink,
                          ),
                        ),
                      )
                    : _searched && _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            l10n.addFriendNoResults,
                            style: const TextStyle(
                              color: NeoColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final person in _results) _resultRow(person),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              NeoButton(
                expand: true,
                label: l10n.addFriendShare,
                icon: Icons.ios_share,
                variant: NeoButtonVariant.outline,
                onPressed: _share,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(Person person) {
    final friend = person.toPocketFriend();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          FriendAvatar(friend: friend, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  friend.handle,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          NeoButton(
            label: l10n.addFriendSend,
            variant: NeoButtonVariant.primary,
            onPressed: _sending.contains(person.id) ? null : () => _add(person),
          ),
        ],
      ),
    );
  }
}
