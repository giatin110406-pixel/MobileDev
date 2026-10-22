import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Whose posts the feed shows: everyone (friends and me), only me, or one
/// friend.
class FeedFilter {
  const FeedFilter.everyone() : _kind = _Kind.everyone, friendId = null;
  const FeedFilter.mine() : _kind = _Kind.mine, friendId = null;
  const FeedFilter.friend(String this.friendId) : _kind = _Kind.friend;

  final _Kind _kind;
  final String? friendId;

  bool get isEveryone => _kind == _Kind.everyone;
  bool get isMine => _kind == _Kind.mine;

  /// Whether a post by [authorId] shows. A null author, or [myId], is me.
  bool allows(String? authorId, String? myId) => switch (_kind) {
    _Kind.everyone => true,
    _Kind.mine => authorId == null || authorId == myId,
    _Kind.friend => authorId == friendId,
  };

  @override
  bool operator ==(Object other) =>
      other is FeedFilter && other._kind == _kind && other.friendId == friendId;

  @override
  int get hashCode => Object.hash(_kind, friendId);
}

enum _Kind { everyone, mine, friend }

/// The pill that picks the [FeedFilter]; opens a small menu under itself.
class FeedFilterPill extends StatelessWidget {
  const FeedFilterPill({
    super.key,
    required this.filter,
    required this.friends,
    required this.onChanged,
  });

  final FeedFilter filter;
  final List<PocketFriend> friends;
  final ValueChanged<FeedFilter> onChanged;

  String _label(AppLocalizations l10n) {
    if (filter.isEveryone) return l10n.feedFilterEveryone;
    if (filter.isMine) return l10n.feedFilterMine;
    final friend = friends.where((f) => f.id == filter.friendId).firstOrNull;
    return friend?.name.split(' ').first ?? l10n.feedFilterEveryone;
  }

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final urls = MediaUrlsScope.maybeOf(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final picked = await showMenu<FeedFilter>(
      context: context,
      color: NeoColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + box.size.height + 6,
        overlay.size.width - topLeft.dx - box.size.width,
        0,
      ),
      constraints: const BoxConstraints(minWidth: 200, maxHeight: 360),
      items: [
        _item(l10n.feedFilterEveryone, const FeedFilter.everyone(), urls),
        _item(l10n.feedFilterMine, const FeedFilter.mine(), urls),
        if (friends.isNotEmpty) const PopupMenuDivider(height: 8),
        for (final friend in friends)
          _item(friend.name, FeedFilter.friend(friend.id), urls),
      ],
    );
    if (picked != null && picked != filter) onChanged(picked);
  }

  /// The picture for a choice: an icon for everyone / just me, the friend's
  /// profile photo for a friend.
  Widget _leading(FeedFilter value, double size, [MediaUrls? urls]) {
    if (value.isEveryone || value.isMine) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value.isEveryone ? NeoColors.accent : NeoColors.coral,
          shape: BoxShape.circle,
          border: Border.all(color: NeoColors.ink, width: 2),
        ),
        child: Icon(
          value.isEveryone ? Icons.groups_rounded : Icons.person_rounded,
          size: size * 0.6,
          color: NeoColors.ink,
        ),
      );
    }
    final friend = friends.where((f) => f.id == value.friendId).firstOrNull;
    if (friend == null) return _leading(const FeedFilter.everyone(), size);
    final avatar = FriendAvatar(
      friend: friend,
      size: size,
      showFrame: true,
      shadow: false,
    );
    // The menu is its own route, outside the app's picture links: carry them in
    // or the profile photo shows as initials until the friend is picked.
    return urls == null ? avatar : MediaUrlsScope(urls: urls, child: avatar);
  }

  PopupMenuItem<FeedFilter> _item(
    String text,
    FeedFilter value,
    MediaUrls? urls,
  ) => PopupMenuItem<FeedFilter>(
    value: value,
    height: 52,
    child: Row(
      children: [
        _leading(value, 38, urls),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (value == filter)
          const Icon(Icons.check, size: 18, color: NeoColors.ink),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Builder(
      builder: (context) => Semantics(
        button: true,
        label: l10n.feedFilterTitle,
        value: _label(l10n),
        child: NeoPress(
          onTap: () => _open(context),
          offset: const Offset(3, 3),
          builder: (context, pressed) => Container(
            height: 54,
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.only(left: 8, right: 12),
            decoration: NeoTheme.panel(color: NeoColors.surface, radius: 999)
                .copyWith(
                  boxShadow: NeoPress.shadow(
                    pressed,
                    offset: const Offset(3, 3),
                  ),
                ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _leading(filter, 38),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: NeoFont.display,
                      color: NeoColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 26,
                  color: NeoColors.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
