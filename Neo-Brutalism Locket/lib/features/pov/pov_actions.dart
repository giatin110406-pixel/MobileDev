import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Omni POV on the Friends tab: a panel with the two ways in. "My code" shows a QR a
/// friend's camera reads; "Scan" brings up the camera to read a friend's.
class PovActions extends StatelessWidget {
  const PovActions({required this.onShowCode, required this.onScan, super.key});

  final VoidCallback onShowCode;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 24),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: NeoColors.ink,
              ),
              const SizedBox(width: 8),
              const Text(
                'OMNI POV',
                style: TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.povTooltip,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 10,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  label: l10n.povShowCodeButton,
                  icon: Icons.qr_code_2,
                  variant: NeoButtonVariant.accent,
                  expand: true,
                  onPressed: onShowCode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  label: l10n.povScanButton,
                  icon: Icons.qr_code_scanner,
                  variant: NeoButtonVariant.outline,
                  expand: true,
                  onPressed: onScan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
