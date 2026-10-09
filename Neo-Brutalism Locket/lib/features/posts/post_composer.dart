import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_overlay.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What the person chose in the composer.
class ComposerResult {
  const ComposerResult({required this.caption, this.recipients, this.overlay});

  final String caption;

  /// Time / place labels to show on the post (null for none).
  final Map<String, dynamic>? overlay;

  /// Friend ids; null means "all friends" (including ones added later today).
  final List<String>? recipients;
}

const maxCaptionLength = 80;

/// After a photo is ready: add a caption and pick who gets it. Pops a
/// [ComposerResult], or null when the person backs out.
class PostComposerScreen extends StatefulWidget {
  const PostComposerScreen({
    super.key,
    required this.imagePath,
    required this.friends,
    this.initialCaption = '',
    this.isVideo = false,
    this.placeLookup = const DevicePlaceLookup(),
    this.clock = DateTime.now,
  });

  /// The picture (or, with [isVideo], the MP4) to send.
  final String imagePath;
  final List<Friend> friends;
  final String initialCaption;
  final bool isVideo;
  final PlaceLookup placeLookup;
  final DateTime Function() clock;

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  late final _caption = TextEditingController(text: widget.initialCaption);
  late final Set<String> _selected = {
    for (final friend in widget.friends) friend.person.id,
  };

  /// The time label, fixed when the screen opens (when the shot was taken).
  late final String _time = formatOverlayTime(widget.clock());
  bool _showTime = false;
  String? _place;
  bool _findingPlace = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _all => _selected.length == widget.friends.length;

  void _toggleAll() => setState(() {
    if (_all) {
      _selected.clear();
    } else {
      _selected.addAll(widget.friends.map((friend) => friend.person.id));
    }
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  PostOverlay get _overlay =>
      PostOverlay(time: _showTime ? _time : null, place: _place);

  Future<void> _togglePlace() async {
    if (_place != null) {
      setState(() => _place = null);
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _findingPlace = true);
    try {
      final place = await widget.placeLookup.currentPlace();
      if (mounted) setState(() => _place = place);
    } on PlaceUnavailable catch (error) {
      if (mounted) {
        showNeoSnack(context, switch (error.problem) {
          PlaceProblem.servicesOff => l10n.placeServicesOff,
          PlaceProblem.denied => l10n.placeDenied,
          PlaceProblem.failed => l10n.placeFailed,
        });
      }
    } finally {
      if (mounted) setState(() => _findingPlace = false);
    }
  }

  void _send() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(
      ComposerResult(
        caption: _caption.text.trim(),
        recipients: _all ? null : _selected.toList(),
        overlay: _overlay.toJson(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final noFriends = widget.friends.isEmpty;
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                NeoIconButton(
                  icon: Icons.arrow_back,
                  tooltip: l10n.cancel,
                  fill: NeoColors.yellow,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.composerTitle,
                    style: const TextStyle(
                      color: NeoColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: NeoTheme.panel(
                  color: NeoColors.surface,
                  radius: 40,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.isVideo)
                      LocalVideoPreview(path: widget.imagePath)
                    else
                      Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: OverlayLabels(overlay: _overlay),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _recipientChip(
                  label: '${l10n.overlayTime} $_time',
                  selected: _showTime,
                  onTap: () => setState(() => _showTime = !_showTime),
                ),
                _recipientChip(
                  label: _findingPlace
                      ? l10n.overlayFindingPlace
                      : _place == null
                      ? l10n.overlayPlace
                      : '${l10n.overlayPlace}: $_place',
                  selected: _place != null,
                  onTap: _findingPlace ? () {} : _togglePlace,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: NeoTheme.panel(color: NeoColors.surface),
              child: TextField(
                controller: _caption,
                maxLength: maxCaptionLength,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.composerCaptionHint,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (noFriends)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: NeoTheme.panel(color: NeoColors.blue),
                child: Text(
                  l10n.composerNoFriends,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else ...[
              _recipientChip(
                label: '${l10n.composerAllFriends} (${widget.friends.length})',
                selected: _all,
                onTap: _toggleAll,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  for (final friend in widget.friends) _friendChip(friend),
                ],
              ),
              if (_selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    l10n.composerPickAtLeastOne,
                    style: const TextStyle(
                      color: Color(0xFFC0392B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            NeoButton(
              expand: true,
              label: _all || noFriends
                  ? l10n.composerPostAll
                  : l10n.composerSendToSome(_selected.length),
              icon: Icons.send_rounded,
              variant: NeoButtonVariant.primary,
              onPressed: noFriends || _selected.isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipientChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? NeoColors.teal : NeoColors.surface,
          border: Border.all(color: NeoColors.ink, width: 2),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: NeoColors.ink,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: NeoColors.ink,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _friendChip(Friend friend) {
    final selected = _selected.contains(friend.person.id);
    final pocket = friend.person.toPocketFriend();
    return Semantics(
      button: true,
      selected: selected,
      label: friend.person.displayName,
      child: InkWell(
        onTap: () => _toggle(friend.person.id),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: selected ? 1 : 0.4,
                    child: FriendAvatar(friend: pocket, size: 52),
                  ),
                  if (selected)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: NeoColors.teal,
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: NeoColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                friend.person.displayName.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
