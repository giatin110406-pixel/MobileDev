import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/history/history_logic.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Every post I sent or received, as a grid grouped by month. Filter by
/// person on top; tap a picture to open it (the viewer pages through the
/// filtered list).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.posts,
    required this.friends,
    required this.myId,
    required this.onOpen,
    this.hasMore = false,
    this.loadingMore = false,
    this.failed = false,
    this.onLoadMore,
    this.onRefresh,
  });

  /// Newest first.
  final List<RemotePost> posts;
  final List<PocketFriend> friends;
  final String myId;

  /// Open [posts] (already filtered) at [index].
  final void Function(List<RemotePost> posts, int index) onOpen;

  final bool hasMore;
  final bool loadingMore;
  final bool failed;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!widget.hasMore || widget.loadingMore) return;
    if (_scroll.position.extentAfter < 400) widget.onLoadMore?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A friend who is no longer a friend cannot stay selected.
    final filter =
        _filter is HistoryFrom &&
            !widget.friends.any(
              (f) => f.id == (_filter as HistoryFrom).friendId,
            )
        ? HistoryFilter.all
        : _filter;
    final shown = filterHistory(
      widget.posts,
      myId: widget.myId,
      filter: filter,
    );
    final months = groupByMonth(shown);
    final locale = Localizations.localeOf(context).toString();

    final grid = CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (shown.isEmpty)
          SliverToBoxAdapter(child: _empty(l10n))
        else
          for (final month in months) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                    locale,
                  ).format(month.month).toUpperCase(),
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: month.posts.length,
              itemBuilder: (context, index) {
                final post = month.posts[index];
                return _Tile(
                  post: post,
                  onTap: () => widget.onOpen(shown, shown.indexOf(post)),
                );
              },
            ),
          ],
        SliverToBoxAdapter(child: _footer(l10n)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.historyTitle,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              NeoLabel('${shown.length}', color: NeoColors.purple),
            ],
          ),
          const SizedBox(height: 12),
          _filters(l10n, filter),
          const SizedBox(height: 4),
          Expanded(
            child: widget.onRefresh == null
                ? grid
                : RefreshIndicator(onRefresh: widget.onRefresh!, child: grid),
          ),
        ],
      ),
    );
  }

  Widget _filters(AppLocalizations l10n, HistoryFilter filter) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Widget? leading,
    }) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.fromLTRB(leading == null ? 12 : 4, 4, 12, 4),
          decoration: BoxDecoration(
            color: selected ? NeoColors.teal : NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?leading,
              if (leading != null) const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            label: l10n.historyAll,
            selected: filter is HistoryAll,
            onTap: () => setState(() => _filter = HistoryFilter.all),
          ),
          const SizedBox(width: 8),
          chip(
            label: l10n.historyMine,
            selected: filter is HistoryMine,
            onTap: () => setState(() => _filter = HistoryFilter.mine),
          ),
          for (final friend in widget.friends) ...[
            const SizedBox(width: 8),
            chip(
              label: friend.name.split(' ').first,
              selected: filter == HistoryFilter.from(friend.id),
              onTap: () =>
                  setState(() => _filter = HistoryFilter.from(friend.id)),
              leading: FriendAvatar(friend: friend, size: 28),
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: NeoTheme.panel(color: NeoColors.blue),
      child: Text(
        widget.failed ? l10n.historyLoadFailed : l10n.historyEmpty,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: NeoColors.ink,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _footer(AppLocalizations l10n) {
    if (widget.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: NeoColors.ink,
            ),
          ),
        ),
      );
    }
    if (widget.failed && widget.posts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: NeoButton(
            label: l10n.retry,
            icon: Icons.refresh,
            variant: NeoButtonVariant.outline,
            onPressed: widget.onLoadMore,
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.post, required this.onTap});

  final RemotePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = post.questId == null ? null : questById(post.questId!)?.style;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 10),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.thumbPath != null)
              RemoteImage(path: post.thumbPath!)
            else if (post.isVideo)
              const ColoredBox(color: NeoColors.ink)
            else
              RemoteImage(path: post.mediaPath),
            if (post.isVideo)
              const Positioned(right: 6, bottom: 6, child: VideoBadge()),
            if (style != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
}
