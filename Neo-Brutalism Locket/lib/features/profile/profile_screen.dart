import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/music/quest_music.dart';
import 'package:neo_brutalism_locket/features/profile/player_avatar.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';

/// Banner with the avatar overlapping its bottom-left corner.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.bannerId,
    required this.avatar,
    this.onAvatarTap,
  });

  final String? bannerId;
  final Widget avatar;
  final VoidCallback? onAvatarTap;

  static const double avatarSize = 104;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130 + avatarSize / 2,
    child: Stack(
      children: [
        ProfileBanner(bannerId: bannerId, height: 130),
        Positioned(
          left: 14,
          bottom: 0,
          child: GestureDetector(onTap: onAvatarTap, child: avatar),
        ),
      ],
    ),
  );
}

/// Your profile tab: banner, framed avatar, streak, Sunbit, the shop and every
/// quest you completed.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    this.session,
    this.remoteQuestPosts,
    this.onOpenRemote,
    this.onOpenSettings,
  });

  /// Opens the settings (with an account only).
  final VoidCallback? onOpenSettings;

  /// With an account: my quest posts from the server, newest first. When set
  /// they replace the ones kept on this phone.
  final List<RemotePost>? remoteQuestPosts;

  /// Open [posts] at [index] in the viewer.
  final void Function(List<RemotePost> posts, int index)? onOpenRemote;

  final PlayerStore store;

  /// The signed-in account (name, username, sign out); null without a backend.
  final AccountSession? session;

  Future<void> _changeAvatar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uploadFailed = AppLocalizations.of(context).avatarUploadFailed;
    final changeFailed = AppLocalizations.of(context).avatarChangeFailed;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(18),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).avatarTitle,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            NeoButton(
              expand: true,
              label: AppLocalizations.of(context).avatarTakePhoto,
              icon: Icons.photo_camera_outlined,
              variant: NeoButtonVariant.accent,
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            NeoButton(
              expand: true,
              label: AppLocalizations.of(context).avatarFromLibrary,
              icon: Icons.photo_library_outlined,
              variant: NeoButtonVariant.outline,
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return;
      final bytes = await compute(
        cropToSquareJpegCapped,
        await picked.readAsBytes(),
      );
      await store.setAvatar(bytes);
      final session = this.session;
      if (session != null) {
        try {
          await session.uploadAvatar(bytes);
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(uploadFailed)));
        }
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(changeFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final state = store.state;
        final remote = remoteQuestPosts;
        final posts = remote != null
            ? const <QuestPost>[]
            : state?.questPosts ?? const <QuestPost>[];
        final count = remote?.length ?? posts.length;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverList.list(
                children: [
                  ProfileHeader(
                    bannerId: state?.equippedBanner,
                    onAvatarTap: () => _changeAvatar(context),
                    avatar: PlayerAvatar(
                      state: state,
                      size: ProfileHeader.avatarSize,
                      remotePath: session?.profile.avatarPath,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session?.profile.displayName ??
                                  AppLocalizations.of(context).youLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: NeoFont.display,
                                color: NeoColors.ink,
                                fontSize: 26,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (session?.profile.username != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '@${session!.profile.username}',
                                style: const TextStyle(
                                  color: NeoColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StreakChip(streak: store.streak),
                      const SizedBox(width: 8),
                      SunbitBadge(
                        balance: store.balance,
                        onTap: () => openShop(context, store),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: NeoButton(
                          expand: true,
                          label: AppLocalizations.of(context).shopLabel,
                          icon: Icons.storefront_outlined,
                          variant: NeoButtonVariant.primary,
                          onPressed: () => openShop(context, store),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeoButton(
                          expand: true,
                          label: AppLocalizations.of(context).avatarChange,
                          icon: Icons.face_retouching_natural,
                          variant: NeoButtonVariant.outline,
                          onPressed: () => _changeAvatar(context),
                        ),
                      ),
                    ],
                  ),
                  if (session != null && onOpenSettings != null) ...[
                    const SizedBox(height: 12),
                    NeoButton(
                      expand: true,
                      label: AppLocalizations.of(context).settingsTitle,
                      icon: Icons.settings_outlined,
                      variant: NeoButtonVariant.outline,
                      onPressed: onOpenSettings,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).questsDoneTitle,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      NeoLabel('$count', color: NeoColors.purple),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (count == 0)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: NeoTheme.panel(color: NeoColors.blue),
                      child: Text(
                        AppLocalizations.of(context).questsNoneYet,
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: count,
                itemBuilder: (context, index) {
                  if (remote != null) {
                    final post = remote[index];
                    return _Tile(
                      style: questById(post.questId ?? '')?.style,
                      onTap: () => onOpenRemote?.call(remote, index),
                      child: RemoteImage(
                        path: post.thumbPath ?? post.mediaPath,
                      ),
                    );
                  }
                  final post = posts[index];
                  return _Tile(
                    style: post.style,
                    onTap: () => openPostViewer(
                      context,
                      store: store,
                      entry: FeedEntry.quest(post),
                    ),
                    child: Image.file(
                      File(post.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A friend's profile: their banner, framed avatar and posts.
class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({
    super.key,
    required this.friend,
    required this.posts,
    required this.store,
    this.onBlock,
    this.onReport,
  });

  /// Block this person / report them. Null without an account.
  final Future<void> Function()? onBlock;
  final Future<void> Function()? onReport;

  final PocketFriend friend;

  /// Only this friend's posts, newest first.
  final List<FriendPost> posts;
  final PlayerStore store;

  @override
  Widget build(BuildContext context) {
    final loadout = loadoutFor(friend);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      NeoIconButton(
                        icon: Icons.arrow_back,
                        tooltip: AppLocalizations.of(context).backTooltip,
                        fill: NeoColors.yellow,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (friend.isSample)
                        NeoLabel(
                          AppLocalizations.of(context).sampleLabel,
                          color: NeoColors.teal,
                        ),
                      if (onBlock != null || onReport != null)
                        PopupMenuButton<String>(
                          tooltip: AppLocalizations.of(context).menuTooltip,
                          icon: const Icon(
                            Icons.more_vert,
                            color: NeoColors.ink,
                          ),
                          onSelected: (value) {
                            if (value == 'block') onBlock?.call();
                            if (value == 'report') onReport?.call();
                          },
                          itemBuilder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return [
                              if (onReport != null)
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(l10n.reportPerson),
                                ),
                              if (onBlock != null)
                                PopupMenuItem(
                                  value: 'block',
                                  child: Text(l10n.blockPerson),
                                ),
                            ];
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ProfileHeader(
                    bannerId: loadout.bannerId,
                    avatar: FriendAvatar(
                      friend: friend,
                      size: ProfileHeader.avatarSize,
                      showFrame: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    friend.name,
                    style: const TextStyle(
                      fontFamily: NeoFont.display,
                      color: NeoColors.ink,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.handle,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).postsTitle,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      NeoLabel('${posts.length}', color: NeoColors.purple),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final path = post.imagePath;
                  final entry = FeedEntry.post(post);
                  return _Tile(
                    style: entry.musicStyle,
                    onTap: () => openPostViewer(
                      context,
                      store: store,
                      entry: entry,
                      friend: friend,
                    ),
                    child: path != null && File(path).existsSync()
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : ColoredBox(
                            color: Color(post.color),
                            child: Center(
                              child: Text(
                                post.emoji,
                                style: const TextStyle(
                                  fontFamily: NeoFont.display,
                                  fontSize: 34,
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child, required this.onTap, this.style});

  final Widget child;
  final VoidCallback onTap;

  /// Set for quest posts (shows a ♪ corner).
  final StyleType? style;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 10),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (style != null)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: style == StyleType.vanGogh
                      ? NeoColors.yellow
                      : NeoColors.teal,
                  border: Border.all(color: NeoColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '♪',
                  style: TextStyle(
                    color: NeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// One post full screen, with its quest music (same rules as the feed).
Future<void> openPostViewer(
  BuildContext context, {
  required PlayerStore store,
  required FeedEntry entry,
  PocketFriend? friend,
  MusicPlayer? musicPlayer,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => FeedScreen(
            entries: [entry],
            friends: [?friend],
            self: FeedSelf(
              avatarPath: store.state?.avatarPath,
              frameId: store.state?.equippedFrame,
            ),
            onClose: () => Navigator.of(context).pop(),
            onReplyText: (post, text) async {},
            onReact: (post, emoji) async {},
            onOpenPrint: (_) {},
            allowReplies: false,
            musicMuted: store.state?.musicMuted ?? false,
            onMuteChanged: store.setMusicMuted,
            musicPlayer: musicPlayer,
          ),
        ),
      ),
    ),
  ),
);
