import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The frame and banner a friend shows. Friends are local-only for now, so
/// only the sample friends wear anything.
Loadout loadoutFor(PocketFriend friend) => friend.isSample
    ? sampleFriendLoadouts[friend.id] ?? Loadout.empty
    : Loadout(frameId: friend.frameId, bannerId: friend.bannerId);

class FriendDraft {
  const FriendDraft({required this.name, required this.handle});

  final String name;
  final String handle;
}

Future<FriendDraft?> showAddFriendSheet(BuildContext context) =>
    showModalBottomSheet<FriendDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddFriendSheet(),
    );

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({
    required this.friends,
    required this.messages,
    required this.onAddFriend,
    required this.onOpenFriend,
    this.requests,
    this.onRefresh,
    this.online = false,
    this.emptyTitle,
    this.emptyBody,
    this.addLabel,
    this.onlineLabel,
    this.segment,
    super.key,
  });

  /// The Friends | Groups switch (online accounts only).
  final Widget? segment;

  final List<PocketFriend> friends;
  final List<PocketMessage> messages;
  final VoidCallback onAddFriend;
  final ValueChanged<PocketFriend> onOpenFriend;

  /// Pending requests shown above the friends (online mode only).
  final Widget? requests;

  /// Pull-to-refresh (online mode only).
  final Future<void> Function()? onRefresh;

  /// Real accounts instead of local sample profiles (changes labels).
  final bool online;
  final String? emptyTitle;
  final String? emptyBody;
  final String? addLabel;
  final String? onlineLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SocialMasthead(),
          SizedBox(height: segment == null ? 24 : 14),
          if (segment != null) ...[segment!, const SizedBox(height: 14)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).yourPeople,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).friendsTitle,
                      style: const TextStyle(
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
                AppLocalizations.of(context).peopleCount(friends.length),
                color: NeoColors.yellow,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: addLabel ?? AppLocalizations.of(context).friendsAdd,
                  icon: Icons.person_add_alt_1,
                  variant: NeoButtonVariant.primary,
                  expand: true,
                  onPressed: onAddFriend,
                ),
              ),
              const SizedBox(width: 12),
              NeoLabel(
                online
                    ? (onlineLabel ??
                          AppLocalizations.of(context).friendsOnline)
                    : AppLocalizations.of(context).localMode,
                color: NeoColors.teal,
                icon: online ? Icons.cloud_done_outlined : Icons.lock_outline,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _list(context)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      children: [
        ?requests,
        if (friends.isEmpty)
          _emptyFriends(context)
        else
          for (final friend in friends)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FriendTile(
                friend: friend,
                latestMessage: _latestMessage(friend.id),
                unreadCount: _unreadCount(friend.id),
                onTap: () => onOpenFriend(friend),
              ),
            ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }

  PocketMessage? _latestMessage(String friendId) {
    final thread =
        messages.where((message) => message.friendId == friendId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return thread.isEmpty ? null : thread.first;
  }

  int _unreadCount(String friendId) => messages
      .where(
        (message) =>
            message.friendId == friendId && !message.isMine && !message.isRead,
      )
      .length;

  Widget _emptyFriends(BuildContext context) => Container(
    decoration: NeoTheme.panel(color: NeoColors.blue),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.group_add_outlined, size: 42, color: NeoColors.ink),
        const SizedBox(height: 16),
        Text(
          emptyTitle ?? AppLocalizations.of(context).noFriendsOnDevice,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          emptyBody ?? AppLocalizations.of(context).noFriendsOnDeviceBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 10,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        NeoButton(
          label: addLabel ?? AppLocalizations.of(context).friendsAdd,
          icon: Icons.person_add_alt_1,
          variant: NeoButtonVariant.primary,
          onPressed: onAddFriend,
        ),
      ],
    ),
  );
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({
    required this.friends,
    required this.messages,
    required this.onOpenFriend,
    super.key,
  });

  final List<PocketFriend> friends;
  final List<PocketMessage> messages;
  final ValueChanged<PocketFriend> onOpenFriend;

  @override
  Widget build(BuildContext context) {
    final orderedFriends = [...friends]
      ..sort((left, right) {
        final leftMessage = _latestMessage(left.id);
        final rightMessage = _latestMessage(right.id);
        return (rightMessage?.createdAt ?? right.addedAt).compareTo(
          leftMessage?.createdAt ?? left.addedAt,
        );
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SocialMasthead(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).privateThreads,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).inboxTitle,
                      style: const TextStyle(
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
                AppLocalizations.of(context).deviceOnly,
                color: NeoColors.pink,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: orderedFriends.isEmpty
                ? Center(
                    child: NeoLabel(
                      AppLocalizations.of(context).addFriendToStart,
                      color: NeoColors.yellow,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8, right: 4),
                    itemCount: orderedFriends.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final friend = orderedFriends[index];
                      final latest = _latestMessage(friend.id);
                      final unread = messages
                          .where(
                            (message) =>
                                message.friendId == friend.id &&
                                !message.isMine &&
                                !message.isRead,
                          )
                          .length;
                      return _FriendTile(
                        friend: friend,
                        latestMessage: latest,
                        unreadCount: unread,
                        onTap: () => onOpenFriend(friend),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PocketMessage? _latestMessage(String friendId) {
    final thread =
        messages.where((message) => message.friendId == friendId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return thread.isEmpty ? null : thread.first;
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.friend,
    required this.messages,
    required this.onBack,
    required this.onSend,
    required this.onSendLatestPhoto,
    required this.onRemoveFriend,
    this.posts = const [],
    this.onOpenProfile,
    this.allowPhoto = true,
    super.key,
  });

  /// Show the "send latest print" button (local threads only).
  final bool allowPhoto;

  final PocketFriend friend;

  /// Tapping the name or avatar opens the friend's profile.
  final VoidCallback? onOpenProfile;
  final List<PocketMessage> messages;

  /// Feed posts, so a reply can show the post it answers.
  final List<FriendPost> posts;
  final VoidCallback onBack;
  final Future<void> Function(String text, String? photoPath) onSend;
  final VoidCallback onSendLatestPhoto;
  final VoidCallback onRemoveFriend;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void didUpdateWidget(covariant ConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text, null);
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              NeoIconButton(
                icon: Icons.arrow_back,
                tooltip: AppLocalizations.of(context).backToInboxTooltip,
                fill: NeoColors.yellow,
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: widget.onOpenProfile != null,
                  label: AppLocalizations.of(context).openProfileLabel,
                  child: InkWell(
                    onTap: widget.onOpenProfile,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        FriendAvatar(
                          friend: widget.friend,
                          size: 46,
                          showFrame: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.friend.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: NeoColors.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.friend.handle,
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
                  ),
                ),
              ),
              NeoIconButton(
                icon: Icons.person_remove_alt_1,
                tooltip: AppLocalizations.of(context).removeFriendTooltip,
                fill: NeoColors.pink,
                onPressed: widget.onRemoveFriend,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              const Expanded(
                child: Divider(color: NeoColors.ink, thickness: 1.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: NeoLabel(
                  AppLocalizations.of(context).localThread,
                  color: NeoColors.teal,
                ),
              ),
              const Expanded(
                child: Divider(color: NeoColors.ink, thickness: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: NeoLabel(
                      'SAY HELLO TO ${widget.friend.name.toUpperCase()}',
                      color: NeoColors.yellow,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.messages[index];
                    return _MessageBubble(
                      message: message,
                      friend: widget.friend,
                      post: message.isPostReply
                          ? widget.posts
                                .where((p) => p.id == message.replyToPostId)
                                .firstOrNull
                          : null,
                    );
                  },
                ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 20, 12),
        child: Row(
          children: [
            if (widget.allowPhoto) ...[
              NeoIconButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: AppLocalizations.of(context).sendLatestPrintTooltip,
                fill: NeoColors.purple,
                onPressed: widget.onSendLatestPhoto,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: NeoColors.surface,
                  border: Border.all(color: NeoColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: NeoColors.ink,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).writeMessageHint,
                    hintStyle: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 12,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            NeoIconButton(
              icon: Icons.send_rounded,
              tooltip: AppLocalizations.of(context).sendMessageTooltip,
              fill: NeoColors.teal,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.friend,
    this.post,
  });

  final PocketMessage message;
  final PocketFriend friend;
  final FriendPost? post;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isMine ? NeoColors.teal : NeoColors.surface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              border: Border.all(color: NeoColors.ink, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isPostReply) ...[
                  _PostQuote(message: message, friend: friend, post: post),
                  const SizedBox(height: 8),
                ],
                if (message.reaction != null)
                  Text(message.reaction!, style: const TextStyle(fontSize: 34)),
                if (!message.isPostReply &&
                    message.photoPath != null &&
                    File(message.photoPath!).existsSync()) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(message.photoPath!),
                      width: 230,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${message.isMine ? 'YOU' : friend.name.toUpperCase()}  /  ${_time(message.createdAt)}',
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// The post a reply answers: its picture (or card), whose post it was, and the
/// caption. Falls back to the saved caption if the post is gone.
class _PostQuote extends StatelessWidget {
  const _PostQuote({required this.message, required this.friend, this.post});

  final PocketMessage message;
  final PocketFriend friend;
  final FriendPost? post;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final whose = message.isMine
        ? l10n.whosePost(friend.name.split(' ').first.toUpperCase())
        : l10n.yourPost;
    final caption = post?.caption ?? message.replyPreview ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.reaction != null ? 'REACTED TO $whose' : 'REPLIED TO $whose',
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        PostThumbnail(
          post: post,
          imagePath: message.photoPath,
          fallbackText: caption,
          size: 150,
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: 150,
            child: Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small square of a feed post: its photo, or the coloured emoji card that
/// sample posts use. With neither available, a plain card with [fallbackText].
class PostThumbnail extends StatelessWidget {
  const PostThumbnail({
    super.key,
    this.post,
    this.imagePath,
    this.fallbackText = '',
    this.size = 120,
  });

  final FriendPost? post;
  final String? imagePath;
  final String fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = post?.imagePath ?? imagePath;
    final Widget content;
    if (path != null && File(path).existsSync()) {
      content = Image.file(File(path), fit: BoxFit.cover);
    } else if (post != null) {
      content = ColoredBox(
        color: Color(post!.color),
        child: Center(
          child: Text(post!.emoji, style: TextStyle(fontSize: size * 0.4)),
        ),
      );
    } else {
      content = ColoredBox(
        color: NeoColors.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              fallbackText.isEmpty ? 'POST' : fallbackText,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeoColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: content,
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.latestMessage,
    required this.unreadCount,
    required this.onTap,
  });

  final PocketFriend friend;
  final PocketMessage? latestMessage;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = latestMessage == null
        ? l10n.previewStart
        : latestMessage!.reaction != null
        ? l10n.previewReacted(
            latestMessage!.isMine
                ? l10n.previewYou
                : friend.name.split(' ').first,
            latestMessage!.reaction!,
          )
        : latestMessage!.isPostReply
        ? (latestMessage!.isMine
              ? l10n.previewYouReplied(latestMessage!.text)
              : l10n.previewReplied(latestMessage!.text))
        : latestMessage!.photoPath != null
        ? l10n.previewSentPrint
        : (latestMessage!.isMine
              ? l10n.previewYouText(latestMessage!.text)
              : latestMessage!.text);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: NeoTheme.panel(
            color: unreadCount > 0 ? NeoColors.yellow : NeoColors.surface,
            borderWidth: 2,
          ),
          child: Row(
            children: [
              FriendAvatar(friend: friend, size: 42),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            friend.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: NeoColors.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (friend.isSample)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: NeoLabel(
                              AppLocalizations.of(context).sampleLabel,
                              color: NeoColors.pink,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: NeoColors.muted,
                        fontSize: 10,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (unreadCount > 0)
                NeoLabel('$unreadCount', color: NeoColors.teal)
              else
                const Icon(
                  Icons.photo_camera_outlined,
                  color: NeoColors.ink,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.friend,
    required this.size,
    this.showFrame = false,
  });

  final PocketFriend friend;
  final double size;

  /// Draw the avatar frame the friend has equipped (profile, feed, thread).
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final frameId = showFrame ? loadoutFor(friend).frameId : null;
    if (frameId != null || friend.avatarPath != null) {
      return FramedAvatar(
        size: size,
        frameId: frameId,
        child: AvatarFace(
          initials: friend.initials,
          color: Color(friend.avatarColor),
          remotePath: friend.avatarPath,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(friend.avatarColor),
        border: Border.all(color: NeoColors.ink, width: 2),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: NeoColors.ink, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        friend.initials,
        style: const TextStyle(
          color: NeoColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SocialMasthead extends StatelessWidget {
  const _SocialMasthead();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 42,
          height: 42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NeoColors.pink,
              border: Border.fromBorderSide(
                BorderSide(color: NeoColors.ink, width: 2),
              ),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(
              Icons.photo_camera_outlined,
              color: NeoColors.ink,
              size: 22,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POCKET PORTRAIT',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'NEO BRUTAL CAMERA CLUB',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        NeoLabel(
          AppLocalizations.of(context).localLabel,
          color: NeoColors.teal,
          icon: Icons.lock_outline,
        ),
      ],
    );
  }
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final handle = _handleController.text.trim();
    if (name.isEmpty || handle.replaceAll('@', '').isEmpty) return;
    Navigator.of(context).pop(FriendDraft(name: name, handle: handle));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: NeoColors.paper,
          border: Border.all(color: NeoColors.ink, width: 2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NeoColors.ink,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                AppLocalizations.of(context).addAFriend,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              NeoLabel(
                AppLocalizations.of(context).localProfileOnly,
                color: NeoColors.yellow,
              ),
              const SizedBox(height: 20),
              _fieldLabel(AppLocalizations.of(context).displayNameLabel),
              const SizedBox(height: 6),
              _input(
                _nameController,
                AppLocalizations.of(context).friendNameHint,
              ),
              const SizedBox(height: 14),
              _fieldLabel(AppLocalizations.of(context).handleLabel),
              const SizedBox(height: 6),
              _input(_handleController, '@friend.handle'),
              const SizedBox(height: 20),
              NeoButton(
                label: AppLocalizations.of(context).addToFriends,
                icon: Icons.person_add_alt_1,
                variant: NeoButtonVariant.primary,
                expand: true,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: NeoColors.ink,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _input(TextEditingController controller, String hint) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: NeoColors.surface,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: TextField(
      controller: controller,
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: NeoColors.muted, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    ),
  );
}
