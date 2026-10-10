import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Your own avatar: your photo (or "YOU") with a frame — the equipped one by
/// default, or [frameId] to preview another.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.state,
    required this.size,
    this.frameId,
    this.previewFrame = false,
    this.remotePath,
  });

  /// The photo on the account, for a phone that has no local copy yet.
  final String? remotePath;

  final PlayerState? state;
  final double size;

  /// With [previewFrame], this frame (even null) replaces the equipped one.
  final String? frameId;
  final bool previewFrame;

  @override
  Widget build(BuildContext context) => FramedAvatar(
    size: size,
    frameId: previewFrame ? frameId : state?.equippedFrame,
    child: AvatarFace(
      initials: AppLocalizations.of(context).youUpper,
      color: NeoColors.pink,
      imagePath: state?.avatarPath,
      remotePath: remotePath,
    ),
  );
}
