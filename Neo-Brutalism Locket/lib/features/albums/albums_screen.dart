import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/albums/albums_repository.dart';
import 'package:neo_brutalism_locket/features/albums/albums_store.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/posts/media_actions.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/strip/strip_render.dart';
import 'package:neo_brutalism_locket/features/strip/strip_studio_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

String _albumFailureText(AppLocalizations l10n, AlbumFailure failure) =>
    switch (failure.kind) {
      AlbumFailureKind.badName => l10n.albumErrName,
      AlbumFailureKind.badWindow => l10n.albumErrWindow,
      AlbumFailureKind.albumLimit => l10n.albumErrLimit,
      AlbumFailureKind.notAllowed => l10n.albumErrNotAllowed,
      AlbumFailureKind.notMember => l10n.gfNotMember,
      _ => l10n.errUnknown,
    };

String _dateRange(BuildContext context, Album album) {
  final l10n = AppLocalizations.of(context);
  final localizations = MaterialLocalizations.of(context);
  // The end is exclusive (midnight after the last day): show the last day.
  final last = album.endsAt.subtract(const Duration(minutes: 1));
  return l10n.albumDateRange(
    localizations.formatShortDate(album.startsAt),
    localizations.formatShortDate(last),
  );
}

/// What the group screen shows under its ALBUM tab: the group's albums, newest
/// event first, and a button to start one.
class AlbumsPanel extends StatelessWidget {
  const AlbumsPanel({
    super.key,
    required this.groupId,
    required this.store,
    required this.members,
    required this.myId,
    required this.iAmOwner,
    required this.mediaUrls,
    required this.actions,
  });

  final String groupId;
  final AlbumsStore store;

  /// Everyone in the group by id (names for the photos).
  final Map<String, Person> members;
  final String myId;
  final bool iAmOwner;
  final MediaUrls? mediaUrls;
  final MediaActions actions;

  Future<void> _create(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final input = await showDialog<({String name, DateTimeRange range})>(
      context: context,
      builder: (_) => const _CreateAlbumDialog(),
    );
    if (input == null || !context.mounted) return;
    try {
      // The last day is whole: the window runs to midnight after it.
      final id = await store.create(
        groupId: groupId,
        name: input.name,
        startsAt: DateTime(
          input.range.start.year,
          input.range.start.month,
          input.range.start.day,
        ),
        endsAt: DateTime(
          input.range.end.year,
          input.range.end.month,
          input.range.end.day + 1,
        ),
      );
      final album = store.byId(id);
      if (album != null && context.mounted) _open(context, album);
    } on AlbumFailure catch (failure) {
      if (context.mounted) {
        showNeoSnack(context, _albumFailureText(l10n, failure));
      }
    }
  }

  void _open(BuildContext context, Album album) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _scoped(
          AlbumScreen(
            albumId: album.id,
            store: store,
            members: members,
            myId: myId,
            iAmOwner: iAmOwner,
            actions: actions,
          ),
        ),
      ),
    );
  }

  Widget _scoped(Widget child) {
    final urls = mediaUrls;
    return urls == null ? child : MediaUrlsScope(urls: urls, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final albums = store.forGroup(groupId);
        final now = DateTime.now();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            NeoButton(
              expand: true,
              label: l10n.albumNew,
              icon: Icons.add_photo_alternate_outlined,
              variant: NeoButtonVariant.accent,
              onPressed: () => _create(context),
            ),
            const SizedBox(height: 14),
            if (albums.isEmpty && store.loadError != null && !store.isLoaded)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      l10n.albumLoadFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  NeoButton(
                    label: l10n.retry,
                    icon: Icons.refresh,
                    variant: NeoButtonVariant.outline,
                    onPressed: store.isLoading ? null : store.refresh,
                  ),
                ],
              )
            else if (albums.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  l10n.albumsEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            for (final album in albums)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AlbumCard(
                  album: album,
                  open: album.isOpenAt(now),
                  onTap: () => _open(context, album),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.open,
    required this.onTap,
  });

  final Album album;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: Haptics.tap(onTap),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: NeoTheme.panel(color: NeoColors.surface),
        child: Row(
          children: [
            const Icon(Icons.photo_album_outlined, color: NeoColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_dateRange(context, album)} · '
                    '${l10n.albumPhotoCount(album.itemCount)}',
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (open)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NeoColors.accent,
                  border: Border.all(color: NeoColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.albumOpenNow,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateAlbumDialog extends StatefulWidget {
  const _CreateAlbumDialog();

  @override
  State<_CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<_CreateAlbumDialog> {
  final _name = TextEditingController();
  late DateTimeRange _range = () {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return DateTimeRange(start: day, end: day.add(const Duration(days: 2)));
  }();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 1, 12, 31),
    );
    if (picked == null) return;
    // 31 days at most (the server checks too).
    final limit = picked.start.add(const Duration(days: 30));
    setState(
      () => _range = DateTimeRange(
        start: picked.start,
        end: picked.end.isAfter(limit) ? limit : picked.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    return AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        l10n.albumNew,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            maxLength: 40,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.albumNameLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.albumDatesLabel,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          NeoButton(
            expand: true,
            label: l10n.albumDateRange(
              dates.formatShortDate(_range.start),
              dates.formatShortDate(_range.end),
            ),
            icon: Icons.date_range,
            variant: NeoButtonVariant.outline,
            onPressed: _pickDates,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Haptics.tap(() => Navigator.pop(context)),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : Haptics.tap(
                  () => Navigator.pop(context, (
                    name: _name.text.trim(),
                    range: _range,
                  )),
                ),
          child: Text(l10n.albumCreateButton),
        ),
      ],
    );
  }
}

/// One album: its photos in a grid, with adding, downloading and deleting.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({
    super.key,
    required this.albumId,
    required this.store,
    required this.members,
    required this.myId,
    required this.iAmOwner,
    required this.actions,
  });

  final String albumId;
  final AlbumsStore store;
  final Map<String, Person> members;
  final String myId;
  final bool iAmOwner;
  final MediaActions actions;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<AlbumItem>? _items;
  bool _failed = false;
  bool _busy = false;

  /// Picking photos for a strip: the chosen ones, in tap order. Null when not
  /// picking.
  List<String>? _pickedOrNull;
  List<String> get _picked => _pickedOrNull ?? const [];
  bool get _picking => _pickedOrNull != null;

  Album? get _album => widget.store.byId(widget.albumId);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  /// The album was deleted, or its count changed after an add.
  void _onStore() {
    if (!mounted) return;
    if (_album == null && widget.store.isLoaded) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final items = await widget.store.repository.loadItems(widget.albumId);
      if (mounted) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } on AlbumFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool _canRemove(Album album, AlbumItem item) =>
      item.authorId == widget.myId ||
      album.createdBy == widget.myId ||
      widget.iAmOwner;

  Future<void> _addMine(Album album) async {
    final l10n = AppLocalizations.of(context);
    List<RemotePost> mine;
    try {
      mine = await widget.store.repository.myPostsBetween(
        album.startsAt,
        album.endsAt.add(const Duration(days: 1)),
      );
    } on AlbumFailure {
      if (mounted) showNeoSnack(context, l10n.albumLoadFailed);
      return;
    }
    if (!mounted) return;
    final already = {for (final item in _items ?? const []) item.postId};
    final candidates = [
      for (final post in mine)
        if (!already.contains(post.id) && post.createdAt.isBefore(album.endsAt))
          post,
    ];
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _scoped(_PickPostsSheet(posts: candidates)),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final added = await widget.store.addPosts(album, picked);
      await _load();
      if (mounted) showNeoSnack(context, l10n.albumAdded(added));
    } on AlbumFailure catch (failure) {
      if (mounted) showNeoSnack(context, _albumFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _scoped(Widget child) {
    final urls = MediaUrlsScope.maybeOf(context);
    return urls == null ? child : MediaUrlsScope(urls: urls, child: child);
  }

  /// Tapping a photo while picking: in or out of the strip, in tap order.
  void _togglePick(AlbumItem item) {
    if (item.isVideo) {
      showNeoSnack(context, AppLocalizations.of(context).stripNoVideo);
      return;
    }
    final picked = _pickedOrNull;
    if (picked == null) return;
    setState(() {
      if (!picked.remove(item.postId) && picked.length < maxStripPhotos) {
        picked.add(item.postId);
      }
    });
  }

  void _openStudio(Album album) {
    final byId = {
      for (final item in _items ?? const <AlbumItem>[]) item.postId: item,
    };
    final photos = [
      for (final id in _picked)
        if (byId[id] case final item?)
          StripPhoto(path: item.mediaPath, originalPath: item.originalPath),
    ];
    if (photos.length < minStripPhotos) return;
    openStripStudio(
      context,
      photos: photos,
      title: album.name,
      subtitle: _dateRange(context, album),
    );
  }

  Future<void> _confirmDelete(Album album) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeoColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          l10n.albumDeleteTitle,
          style: const TextStyle(
            color: NeoColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.albumDeleteBody,
          style: const TextStyle(color: NeoColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, false)),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: Haptics.tap(() => Navigator.pop(context, true)),
            child: Text(l10n.albumDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.store.delete(album);
    } on AlbumFailure catch (failure) {
      if (mounted) showNeoSnack(context, _albumFailureText(l10n, failure));
    }
  }

  Future<void> _openViewer(
    Album album,
    List<AlbumItem> items,
    int index,
  ) async {
    final removed = await Navigator.of(context).push<AlbumItem>(
      MaterialPageRoute(
        builder: (_) => _scoped(
          _AlbumViewer(
            items: items,
            initial: index,
            members: widget.members,
            actions: widget.actions,
            canRemove: (item) => _canRemove(album, item),
          ),
        ),
      ),
    );
    if (removed == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await widget.store.remove(removed);
      await _load();
      if (mounted) showNeoSnack(context, l10n.albumPhotoRemoved);
    } on AlbumFailure catch (failure) {
      if (mounted) showNeoSnack(context, _albumFailureText(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final album = _album;
    final items = _items;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: album == null
            ? const Center(
                child: CircularProgressIndicator(color: NeoColors.ink),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        NeoIconButton(
                          icon: Icons.arrow_back,
                          tooltip: l10n.backTooltip,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: NeoFont.display,
                                  color: NeoColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${_dateRange(context, album)} · '
                                '${l10n.albumPhotoCount(items?.length ?? album.itemCount)}',
                                style: const TextStyle(
                                  color: NeoColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (album.createdBy == widget.myId || widget.iAmOwner)
                          NeoIconButton(
                            icon: Icons.delete_outline,
                            tooltip: l10n.albumDelete,
                            onPressed: _busy
                                ? null
                                : () => _confirmDelete(album),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: NeoButton(
                            expand: true,
                            label: l10n.albumAddMine,
                            icon: Icons.add_photo_alternate_outlined,
                            variant: NeoButtonVariant.accent,
                            onPressed: _busy ? null : () => _addMine(album),
                          ),
                        ),
                        const SizedBox(width: 10),
                        NeoIconButton(
                          icon: _picking ? Icons.close : Icons.print_outlined,
                          tooltip: _picking ? l10n.cancel : l10n.stripButton,
                          fill: _picking ? NeoColors.paper : NeoColors.accent,
                          onPressed: _busy || (items?.isEmpty ?? true)
                              ? null
                              : () => setState(
                                  () => _pickedOrNull = _picking
                                      ? null
                                      : <String>[],
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (_picking)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.stripPickHint(_picked.length),
                              style: const TextStyle(
                                color: NeoColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          NeoButton(
                            label: l10n.stripNext,
                            icon: Icons.arrow_forward,
                            variant: NeoButtonVariant.primary,
                            onPressed: _picked.length < minStripPhotos
                                ? null
                                : () => _openStudio(album),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(child: _grid(album, items, l10n)),
                ],
              ),
      ),
    );
  }

  Widget _grid(Album album, List<AlbumItem>? items, AppLocalizations l10n) {
    if (items == null) {
      return Center(
        child: _failed
            ? Text(l10n.albumLoadFailed)
            : const CircularProgressIndicator(color: NeoColors.ink),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.albumEmptyItems,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NeoColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final order = _picked.indexOf(item.postId);
        return InkWell(
          onTap: Haptics.tap(
            () =>
                _picking ? _togglePick(item) : _openViewer(album, items, index),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: NeoTheme.panel(color: NeoColors.surface, radius: 10),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.thumbPath != null)
                  RemoteImage(path: item.thumbPath!)
                else if (item.isVideo)
                  const ColoredBox(color: NeoColors.ink)
                else
                  RemoteImage(path: item.mediaPath),
                if (item.isVideo)
                  const Positioned(right: 6, bottom: 6, child: VideoBadge()),
                if (_picking && order < 0)
                  const ColoredBox(color: Color(0x55F8EED2)),
                if (order >= 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: NeoColors.ink,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: NeoColors.accent,
                        child: Text(
                          '${order + 1}',
                          style: const TextStyle(
                            color: NeoColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
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

/// My posts from the album's days, to tick the ones to add. Pops the chosen
/// post ids.
class _PickPostsSheet extends StatefulWidget {
  const _PickPostsSheet({required this.posts});

  final List<RemotePost> posts;

  @override
  State<_PickPostsSheet> createState() => _PickPostsSheetState();
}

class _PickPostsSheetState extends State<_PickPostsSheet> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.albumAddHint,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.posts.isEmpty
                ? Center(
                    child: Text(
                      l10n.albumAddNone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: widget.posts.length,
                    itemBuilder: (context, index) {
                      final post = widget.posts[index];
                      final on = _picked.contains(post.id);
                      return InkWell(
                        onTap: Haptics.tap(
                          () => setState(() {
                            if (!_picked.remove(post.id)) _picked.add(post.id);
                          }),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: on ? 1 : 0.55,
                              child: RemoteImage(
                                path: post.thumbPath ?? post.mediaPath,
                              ),
                            ),
                            if (on)
                              const Positioned(
                                right: 4,
                                bottom: 4,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: NeoColors.accent,
                                  child: Icon(
                                    Icons.check,
                                    size: 15,
                                    color: NeoColors.ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          NeoButton(
            expand: true,
            label: l10n.albumAddConfirm(_picked.length),
            icon: Icons.check,
            variant: NeoButtonVariant.primary,
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.pop(context, Set.of(_picked)),
          ),
        ],
      ),
    );
  }
}

/// Full-screen swipe through the album's photos. Pops the [AlbumItem] the
/// person chose to remove, if any.
class _AlbumViewer extends StatefulWidget {
  const _AlbumViewer({
    required this.items,
    required this.initial,
    required this.members,
    required this.actions,
    required this.canRemove,
  });

  final List<AlbumItem> items;
  final int initial;
  final Map<String, Person> members;
  final MediaActions actions;
  final bool Function(AlbumItem item) canRemove;

  @override
  State<_AlbumViewer> createState() => _AlbumViewerState();
}

class _AlbumViewerState extends State<_AlbumViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  AlbumItem get _item => widget.items[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String path, String done) async {
    final l10n = AppLocalizations.of(context);
    final ok = await widget.actions.save(path);
    if (mounted) showNeoSnack(context, ok ? done : l10n.postSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = _item;
    final author = widget.members[item.authorId]?.displayName;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  NeoIconButton(
                    icon: Icons.arrow_back,
                    tooltip: l10n.backTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      author == null ? '' : l10n.albumBy(author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Center(child: _page(widget.items[index])),
                ),
              ),
            ),
            if (item.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Text(
                  item.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  NeoButton(
                    label: l10n.postMenuSave,
                    icon: Icons.download_rounded,
                    variant: NeoButtonVariant.accent,
                    onPressed: () => _save(item.mediaPath, l10n.postSaved),
                  ),
                  if (item.originalPath != null)
                    NeoButton(
                      label: l10n.postMenuSaveOriginal,
                      icon: Icons.photo_outlined,
                      variant: NeoButtonVariant.outline,
                      onPressed: () =>
                          _save(item.originalPath!, l10n.postOriginalSaved),
                    ),
                  if (widget.canRemove(item))
                    NeoButton(
                      label: l10n.albumRemovePhoto,
                      icon: Icons.remove_circle_outline,
                      variant: NeoButtonVariant.outline,
                      onPressed: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(AlbumItem item) => AspectRatio(
    aspectRatio: 1,
    child: Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: item.isVideo
          ? RemoteVideo(path: item.mediaPath, thumbPath: item.thumbPath)
          : item.originalPath != null
          ? RevealCompare(
              before: RemoteImage(
                path: item.originalPath!,
                previewPath: item.thumbPath,
              ),
              after: RemoteImage(
                path: item.mediaPath,
                previewPath: item.thumbPath,
              ),
            )
          : RemoteImage(path: item.mediaPath, previewPath: item.thumbPath),
    ),
  );
}
