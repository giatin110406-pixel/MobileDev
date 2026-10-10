import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_overlay.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/music/quest_music.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/social/reply_bar.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// One page of the feed: a friend's post, one of your own prints or one of
/// your daily quest posts.
class FeedEntry {
  const FeedEntry.post(FriendPost this.post)
    : print = null,
      quest = null,
      remote = null;
  const FeedEntry.print(NeoPhoto this.print)
    : post = null,
      quest = null,
      remote = null;
  const FeedEntry.quest(QuestPost this.quest)
    : post = null,
      print = null,
      remote = null;

  /// A post from the server (one a friend sent me, or one I sent).
  const FeedEntry.remote(RemotePost this.remote)
    : post = null,
      print = null,
      quest = null;

  final FriendPost? post;
  final NeoPhoto? print;
  final QuestPost? quest;
  final RemotePost? remote;

  String get id => post?.id ?? quest?.id ?? remote?.id ?? print!.id;

  DateTime get time =>
      post?.createdAt ??
      quest?.createdAt ??
      remote?.createdAt ??
      print!.createdAt;

  /// Who posted it: a friend's id, or null for me / local items.
  String? get authorId => post?.friendId ?? remote?.authorId;

  /// The style whose music plays on this page; null for posts without music.
  StyleType? get musicStyle {
    if (quest != null) return quest!.style;
    final questId = post?.questId ?? remote?.questId;
    if (questId == null) return null;
    return questById(questId)?.style ?? remote?.style;
  }
}

/// The feed of a signed-in account: posts from the server, newest first.
/// Only people who are still friends (and you) are shown.
List<FeedEntry> buildRemoteFeed(
  List<RemotePost> posts, {
  required String myId,
  required Set<String> friendIds,
}) => [
  for (final post in posts)
    if (post.authorId == myId || friendIds.contains(post.authorId))
      FeedEntry.remote(post),
];

/// Friends' posts, your prints and your quest posts together, newest first.
/// A print that was posted as a quest shows once, as the quest post.
List<FeedEntry> buildFeed(
  List<FriendPost> posts,
  List<NeoPhoto> prints, {
  List<QuestPost> questPosts = const [],
}) {
  final posted = questPosts.map((post) => post.photoId).toSet();
  return [
    ...posts.map(FeedEntry.post),
    ...questPosts.map(FeedEntry.quest),
    ...prints.where((print) => !posted.contains(print.id)).map(FeedEntry.print),
  ]..sort((a, b) => b.time.compareTo(a.time));
}

/// How you look in the feed (your photo and equipped frame).
class FeedSelf {
  const FeedSelf({this.avatarPath, this.frameId, this.userId});

  final String? avatarPath;
  final String? frameId;

  /// Your account id (marks which server posts are yours).
  final String? userId;
}

/// Locket-style feed: swipe up/down between posts. Under a friend's post is
/// the reply bar (message or emoji, sent to your thread with them); your own
/// prints have no reply bar, like Locket. Quest posts play their music while
/// they are on screen.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.entries,
    required this.friends,
    required this.onClose,
    required this.onReplyText,
    required this.onReact,
    required this.onOpenPrint,
    this.self = const FeedSelf(),
    this.onOpenFriend,
    this.onOpenSelf,
    this.musicMuted = false,
    this.onMuteChanged,
    this.musicPlayer,
    this.allowReplies = true,
    this.onReplyRemote,
    this.onReactRemote,
    this.onViewed,
    this.onPostMenu,
    this.activity = const {},
    this.initialPage = 0,
  });

  /// The page to start on (opening a post from the history grid).
  final int initialPage;

  /// Reply (text) to a post from the server. Null hides the reply bar there.
  final Future<void> Function(RemotePost post, String text)? onReplyRemote;

  /// Emoji reaction to a post from the server.
  final Future<void> Function(RemotePost post, String emoji)? onReactRemote;

  /// A post stayed on screen for a second (tell its author).
  final ValueChanged<FeedEntry>? onViewed;

  /// Long-press on a server post (save, share, delete).
  final ValueChanged<RemotePost>? onPostMenu;

  /// Reactions and viewers of my posts, by post id.
  final Map<String, PostActivity> activity;

  final List<FeedEntry> entries;
  final List<PocketFriend> friends;
  final VoidCallback onClose;
  final Future<void> Function(FriendPost post, String text) onReplyText;
  final Future<void> Function(FriendPost post, String emoji) onReact;
  final void Function(NeoPhoto photo) onOpenPrint;
  final FeedSelf self;
  final ValueChanged<PocketFriend>? onOpenFriend;
  final VoidCallback? onOpenSelf;
  final bool musicMuted;
  final ValueChanged<bool>? onMuteChanged;

  /// Defaults to a real audio player, created on the first quest post.
  final MusicPlayer? musicPlayer;

  /// False hides the reply bar (e.g. a single post opened from a profile).
  final bool allowReplies;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  static const double _radius = 40;

  late final MusicPlayer _music = widget.musicPlayer ?? AudioMusicPlayer();
  late int _page = widget.initialPage.clamp(
    0,
    widget.entries.isEmpty ? 0 : widget.entries.length - 1,
  );
  late final PageController _pages = PageController(initialPage: _page);
  bool _foreground = true;
  Timer? _viewedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMusic();
      _scheduleViewed();
    });
  }

  /// After a second on a page, tell the owner it was looked at.
  void _scheduleViewed() {
    _viewedTimer?.cancel();
    final callback = widget.onViewed;
    if (callback == null || _page >= widget.entries.length) return;
    final entry = widget.entries[_page];
    _viewedTimer = Timer(const Duration(seconds: 1), () => callback(entry));
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.entries.length) _page = 0;
    _syncMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMusic();
  }

  @override
  void dispose() {
    _viewedTimer?.cancel();
    _pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.musicPlayer == null) {
      _music.dispose();
    } else {
      _music.stop();
    }
    super.dispose();
  }

  /// Plays the music of the page on screen, or stops it.
  void _syncMusic() {
    if (!mounted) return;
    final entry = _page < widget.entries.length ? widget.entries[_page] : null;
    final style = entry?.musicStyle;
    if (style == null || widget.musicMuted || !_foreground) {
      _music.stop();
    } else {
      _music.play(QuestMusic.trackFor(style, entry!.id));
    }
  }

  bool get _anyMusic => widget.entries.any((entry) => entry.musicStyle != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              NeoIconButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: AppLocalizations.of(context).backToCameraTooltip,
                fill: NeoColors.yellow,
                onPressed: widget.onClose,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).feedLabel,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_anyMusic && widget.onMuteChanged != null) ...[
                NeoIconButton(
                  icon: widget.musicMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  tooltip: widget.musicMuted ? 'Bật nhạc' : 'Tắt nhạc',
                  fill: widget.musicMuted
                      ? NeoColors.switchOff
                      : NeoColors.teal,
                  onPressed: () => widget.onMuteChanged!(!widget.musicMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: widget.entries.isEmpty
                ? Center(
                    child: NeoLabel(
                      AppLocalizations.of(context).noPostsYet,
                      color: NeoColors.yellow,
                    ),
                  )
                : PageView.builder(
                    controller: _pages,
                    scrollDirection: Axis.vertical,
                    itemCount: widget.entries.length,
                    onPageChanged: (page) {
                      _page = page;
                      _syncMusic();
                      _scheduleViewed();
                    },
                    itemBuilder: (context, index) =>
                        _buildPage(widget.entries[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(FeedEntry entry) {
    final post = entry.post;
    final authorId = entry.authorId;
    final friend = authorId == null || authorId == widget.self.userId
        ? null
        : widget.friends.where((friend) => friend.id == authorId).firstOrNull;
    // Photo, poster name and reply bar stay together as one block (name right
    // under the photo, bar right under the name); the photo shrinks to fit.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxHeight - _belowPhoto).clamp(
          120.0,
          constraints.maxWidth,
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onLongPress: entry.remote != null && widget.onPostMenu != null
                  ? () => widget.onPostMenu!(entry.remote!)
                  : null,
              child: Container(
                width: side,
                height: side,
                decoration: NeoTheme.panel(
                  color: NeoColors.surface,
                  borderWidth: 2,
                  radius: _radius,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post != null)
                      _postCard(post)
                    else if (entry.remote != null)
                      _remoteCard(entry.remote!)
                    else if (entry.quest != null)
                      _questCard(entry.quest!)
                    else
                      _printImage(entry.print!),
                    if (entry.musicStyle != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: QuestStyleTag(style: entry.musicStyle!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _poster(friend, entry.time),
            const SizedBox(height: 10),
            _action(entry, post, friend),
          ],
        );
      },
    );
  }

  /// Height of everything under the photo: gaps + name row + reply bar.
  static const double _belowPhoto = 8 + 32 + 10 + 54;

  Widget _poster(PocketFriend? friend, DateTime time) => SizedBox(
    height: 32,
    child: InkWell(
      onTap: friend == null
          ? widget.onOpenSelf
          : widget.onOpenFriend == null
          ? null
          : () => widget.onOpenFriend!(friend),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (friend != null) ...[
            FriendAvatar(friend: friend, size: 32, showFrame: true),
            const SizedBox(width: 8),
          ] else ...[
            FramedAvatar(
              size: 32,
              frameId: widget.self.frameId,
              child: AvatarFace(
                initials: 'YOU',
                color: NeoColors.pink,
                imagePath: widget.self.avatarPath,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              friend?.name ?? 'You',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo(time),
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _action(FeedEntry entry, FriendPost? post, PocketFriend? friend) {
    final remote = entry.remote;
    final isMine = remote != null && remote.authorId == widget.self.userId;
    final questId =
        entry.quest?.questId ?? post?.questId ?? entry.remote?.questId;
    final quest = questId == null ? null : questById(questId);
    return SizedBox(
      height: 54,
      child: Align(
        alignment: Alignment.topCenter,
        child: remote != null && isMine
            ? ActivityStrip(
                activity: widget.activity[remote.id],
                nameOf: _nameOf,
              )
            : remote != null &&
                  friend != null &&
                  widget.allowReplies &&
                  widget.onReplyRemote != null &&
                  widget.onReactRemote != null
            ? ReplyBar(
                hint: AppLocalizations.of(context).replyHint(friend.name.split(' ').first),
                onSendText: (text) => widget.onReplyRemote!(remote, text),
                onReact: (emoji) => widget.onReactRemote!(remote, emoji),
              )
            : post != null && friend != null && widget.allowReplies
            ? ReplyBar(
                hint: AppLocalizations.of(context).replyHint(friend.name.split(' ').first),
                onSendText: (text) => widget.onReplyText(post, text),
                onReact: (emoji) => widget.onReact(post, emoji),
              )
            : entry.print != null
            ? NeoButton(
                label: AppLocalizations.of(context).openPrint,
                icon: Icons.open_in_full,
                variant: NeoButtonVariant.accent,
                onPressed: () => widget.onOpenPrint(entry.print!),
              )
            : quest != null
            ? QuestTitleTag(quest: quest)
            : const SizedBox.shrink(),
      ),
    );
  }

  String _nameOf(String userId) {
    final friend = widget.friends.where((f) => f.id == userId).firstOrNull;
    return friend == null ? '?' : friend.name.split(' ').first;
  }

  Widget _postCard(FriendPost post) {
    final path = post.imagePath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null && File(path).existsSync())
          Image.file(File(path), fit: BoxFit.cover)
        else
          ColoredBox(
            color: Color(post.color),
            child: Center(
              child: Text(post.emoji, style: const TextStyle(fontSize: 96)),
            ),
          ),
        if (post.caption.isNotEmpty) _caption(post.caption),
      ],
    );
  }

  Widget _remoteCard(RemotePost post) => Stack(
    fit: StackFit.expand,
    children: [
      if (post.isVideo)
        RemoteVideo(path: post.mediaPath, thumbPath: post.thumbPath)
      else
        RemoteImage(path: post.mediaPath, previewPath: post.thumbPath),
      Positioned(
        top: 16,
        right: 16,
        child: OverlayLabels(overlay: PostOverlay.fromJson(post.overlay)),
      ),
      if (post.caption.isNotEmpty) _caption(post.caption),
    ],
  );

  Widget _questCard(QuestPost post) => Stack(
    fit: StackFit.expand,
    children: [
      Image.file(
        File(post.imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            AppLocalizations.of(context).imageNotFound,
            style: const TextStyle(
              color: NeoColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      if (post.caption.isNotEmpty) _caption(post.caption),
    ],
  );

  Widget _caption(String caption) => Positioned(
    left: 16,
    right: 16,
    bottom: 18,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: NeoColors.ink.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          caption,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: NeoColors.surface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  Widget _printImage(NeoPhoto photo) => Image.file(
    File(photo.processedPath ?? photo.originalPath),
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Center(
      child: Text(
        AppLocalizations.of(context).imageNotFound,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// Under one of my posts: how many people looked, and who reacted how.
class ActivityStrip extends StatelessWidget {
  const ActivityStrip({
    super.key,
    required this.activity,
    required this.nameOf,
  });

  final PostActivity? activity;
  final String Function(String userId) nameOf;

  @override
  Widget build(BuildContext context) {
    final data = activity;
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.viewerIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: NeoLabel(
                '👀 ${data.viewerIds.length}',
                color: NeoColors.surface,
              ),
            ),
          for (final reaction in data.reactions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: NeoLabel(
                '${reaction.emoji} ${nameOf(reaction.userId)}',
                color: NeoColors.yellow,
              ),
            ),
        ],
      ),
    );
  }
}

/// "♪ VAN GOGH" / "♪ 8-BIT" on a quest post.
class QuestStyleTag extends StatelessWidget {
  const QuestStyleTag({super.key, required this.style});

  final StyleType style;

  @override
  Widget build(BuildContext context) => NeoLabel(
    '♪ ${style.label}',
    color: style == StyleType.vanGogh ? NeoColors.yellow : NeoColors.teal,
  );
}

/// The quest a post completed, e.g. "🍇 Vườn nho đỏ ở Arles (1888)".
class QuestTitleTag extends StatelessWidget {
  const QuestTitleTag({super.key, required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: NeoTheme.panel(color: NeoColors.purple, radius: 999),
    child: Text(
      '${quest.emoji}  ${quest.storyTitle}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String timeAgo(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  return '${elapsed.inDays}d';
}
