import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/history/history_logic.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/search/photo_search.dart';
import 'package:neo_brutalism_locket/features/search/search_query.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Every post I sent or received, as a grid grouped by month. Filter by
/// person on top; tap a picture to open it (the viewer pages through the
/// filtered list). With [search], a field on top finds photos by what they
/// show, who and when ("chó ở biển với Lan năm ngoái").
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
    this.search,
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

  /// Photo search (archive-ai-search-plan.md); null hides the field.
  final PhotoSearch? search;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;
  final _scroll = ScrollController();

  final _searchText = TextEditingController();
  SearchOutcome? _outcome;
  bool _searching = false;
  bool _searchFailed = false;

  /// While the Vietnamese pack downloads.
  bool _downloading = false;
  bool _downloadFailed = false;

  /// "Maybe" photos start short: they are the likeliest wrong ones.
  static const _maybeFirst = 6;
  bool _allMaybe = false;

  bool get _searchActive => _outcome != null || _searching || _searchFailed;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchText.dispose();
    super.dispose();
  }

  /// The friend whose name the person tapped in the text ("with Lan?"); only
  /// for the search it was tapped on, a new search starts without.
  String? _pinned;

  /// [pin]: search again with this friend applied.
  Future<void> _search({String? pin}) async {
    final search = widget.search;
    final text = _searchText.text.trim();
    if (search == null) return;
    if (text.isEmpty) return _clearSearch();
    final vietnamese = Localizations.localeOf(context).languageCode == 'vi';
    _pinned = pin;
    setState(() {
      _allMaybe = false;
      _searching = true;
      _searchFailed = false;
    });
    try {
      final outcome = await search.search(
        text,
        friends: [for (final f in widget.friends) (id: f.id, name: f.name)],
        vietnamese: vietnamese,
        pinFriend: pin,
      );
      if (mounted) setState(() => _outcome = outcome);
    } catch (e, st) {
      AppLog.warn('history_search', e, st);
      if (mounted) setState(() => _searchFailed = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _searchText.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _outcome = null;
      _searchFailed = false;
    });
  }

  Future<void> _downloadLanguagePack() async {
    setState(() {
      _downloading = true;
      _downloadFailed = false;
    });
    try {
      await widget.search!.prepareLanguagePack();
      if (!mounted) return;
      setState(() => _downloading = false);
      await _search(pin: _pinned);
    } catch (e, st) {
      AppLog.warn('history_search', e, st);
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadFailed = true;
        });
      }
    }
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
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              NeoLabel(
                _searchActive
                    ? '${_outcome?.posts.length ?? 0}'
                    : '${shown.length}',
                color: NeoColors.accent,
              ),
            ],
          ),
          if (widget.search != null) ...[
            const SizedBox(height: 12),
            _searchField(l10n),
          ],
          const SizedBox(height: 12),
          if (_searchActive) _queryChips(l10n) else _filters(l10n, filter),
          const SizedBox(height: 4),
          Expanded(
            child: _searchActive
                ? _searchResults(l10n)
                : widget.onRefresh == null
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
        onTap: Haptics.tap(onTap),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.fromLTRB(leading == null ? 12 : 4, 4, 12, 4),
          decoration: BoxDecoration(
            color: selected ? NeoColors.accent : NeoColors.surface,
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

  Widget _searchField(AppLocalizations l10n) => Container(
    height: 44,
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      color: NeoColors.surface,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        const Icon(Icons.search, size: 20, color: NeoColors.ink),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchText,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration.collapsed(
              hintText: l10n.searchHint,
              hintStyle: const TextStyle(color: NeoColors.muted, fontSize: 13),
            ),
          ),
        ),
        if (_searchText.text.isNotEmpty || _searchActive)
          IconButton(
            tooltip: l10n.searchClear,
            icon: const Icon(Icons.close, size: 18, color: NeoColors.ink),
            onPressed: _clearSearch,
          )
        else
          const SizedBox(width: 12),
      ],
    ),
  );

  /// What the search understood as filters: the friend, "mine", the dates.
  Widget _queryChips(AppLocalizations l10n) {
    final outcome = _outcome;
    final query = outcome?.query;
    final friendId = query?.friendId;
    final from = query?.from;
    final until = query?.until;
    final labels = <String>[
      if (friendId != null)
        for (final f in widget.friends)
          if (f.id == friendId) f.name.split(' ').first,
      if (query?.mine ?? false) l10n.searchMine,
      if (from != null && until != null) _dateLabel(from, until),
      if (outcome != null) l10n.searchResults(outcome.posts.length),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final label in labels) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: NeoColors.accent,
                border: Border.all(color: NeoColors.ink, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // A name typed without "with": one tap applies it as a filter.
          for (final friend
              in query?.friendHints ?? const <SearchFriend>[]) ...[
            Semantics(
              button: true,
              child: InkWell(
                onTap: Haptics.tap(() => _search(pin: friend.id)),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: NeoColors.surface,
                    border: Border.all(color: NeoColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.searchWithFriend(
                      friend.name.split(' ').first.toUpperCase(),
                    ),
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// "2025", "10/2025" or "12/10 - 18/10" ([until] is exclusive).
  String _dateLabel(DateTime from, DateTime until) {
    final last = until.subtract(const Duration(days: 1));
    if (from.month == 1 && from.day == 1 && until == DateTime(from.year + 1)) {
      return '${from.year}';
    }
    if (from.day == 1 && until == DateTime(from.year, from.month + 1)) {
      return DateFormat('MM/yyyy').format(from);
    }
    final day = DateFormat('dd/MM');
    return from == last
        ? day.format(from)
        : '${day.format(from)} - ${day.format(last)}';
  }

  Widget _searchResults(AppLocalizations l10n) {
    final outcome = _outcome;
    final posts = outcome?.posts ?? const <RemotePost>[];
    final needsPack = outcome?.needsLanguagePack ?? false;
    final strong = outcome?.strongCount ?? 0;
    return CustomScrollView(
      slivers: [
        if (_searching)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
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
            ),
          )
        else if (_searchFailed)
          SliverToBoxAdapter(child: _notice(l10n.searchFailed))
        else ...[
          if (needsPack) SliverToBoxAdapter(child: _downloadCard(l10n)),
          if (outcome?.declined ?? false)
            SliverToBoxAdapter(child: _notice(l10n.searchCantTell)),
          if (posts.isEmpty && !needsPack && !(outcome?.declined ?? false))
            SliverToBoxAdapter(child: _notice(l10n.searchNoResults)),
          _resultGrid(posts, 0, strong),
          if (strong < posts.length) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 18, 2, 0),
                child: Text(
                  l10n.searchMaybe,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            _resultGrid(
              posts,
              strong,
              _allMaybe
                  ? posts.length
                  : math.min(posts.length, strong + _maybeFirst),
            ),
            if (!_allMaybe && posts.length > strong + _maybeFirst)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: NeoButton(
                      label: l10n.searchSeeMore,
                      variant: NeoButtonVariant.outline,
                      onPressed: () => setState(() => _allMaybe = true),
                    ),
                  ),
                ),
              ),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  /// posts[from..until) as a grid; a tap opens the viewer on all [posts].
  Widget _resultGrid(List<RemotePost> posts, int from, int until) =>
      SliverPadding(
        padding: const EdgeInsets.only(top: 10),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: until - from,
          itemBuilder: (context, index) => _Tile(
            post: posts[from + index],
            onTap: () => widget.onOpen(posts, from + index),
          ),
        ),
      );

  Widget _downloadCard(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: NeoTheme.panel(color: NeoColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _downloadFailed ? l10n.searchDownloadFailed : l10n.searchNeedsModel,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_downloading)
            Text(
              l10n.searchDownloading,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            NeoButton(
              label: l10n.searchDownload,
              icon: Icons.download,
              onPressed: _downloadLanguagePack,
            ),
        ],
      ),
    ),
  );

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: NeoTheme.panel(color: NeoColors.accent),
      child: Text(
        text,
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

  Widget _empty(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: NeoTheme.panel(color: NeoColors.accent),
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
      onTap: Haptics.tap(onTap),
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
                        ? NeoColors.accent
                        : NeoColors.accent,
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
