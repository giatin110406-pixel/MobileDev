import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/pov/pov_text.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Omni POV, asking: a QR code that the friend taking the photo scans with the camera of
/// their app. The sheet waits and closes (with true) when they do. Closing it before then
/// closes the code.
Future<bool> showPovQrSheet(
  BuildContext context, {
  required PovStore store,
}) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PovQrSheet(store: store),
  );
  if (accepted != true && store.isWaiting) await store.closeCode();
  store.clearNotice();
  return accepted == true;
}

class PovQrSheet extends StatefulWidget {
  const PovQrSheet({required this.store, super.key});

  final PovStore store;

  @override
  State<PovQrSheet> createState() => _PovQrSheetState();
}

class _PovQrSheetState extends State<PovQrSheet> {
  Timer? _tick;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    // The countdown.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.store.isWaiting) setState(() {});
    });
    unawaited(widget.store.openCode());
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    if (widget.store.isWatching && !_closing) {
      _closing = true;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  Future<void> _renew() async {
    widget.store.clearNotice();
    await widget.store.openCode();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = widget.store;
    final code = store.code;

    final Widget body;
    if (code != null) {
      body = _codeView(l10n, code);
    } else if (store.error != null) {
      body = _problem(l10n, povFailureText(l10n, store.error!));
    } else if (store.lastEnd == PovEnd.expired) {
      body = _problem(l10n, l10n.povQrExpired);
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: NeoColors.ink)),
      );
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.povQrTitle,
              style: const TextStyle(
                color: NeoColors.ink,
                fontFamily: NeoFont.display,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            body,
          ],
        ),
      ),
    );
  }

  Widget _codeView(AppLocalizations l10n, PovCode code) {
    final left = code.expiresAt.difference(DateTime.now());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          // Black on white with a wide quiet zone: what a scanner reads best.
          child: Semantics(
            label: l10n.povQrTitle,
            image: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: NeoTheme.panel(
                color: Colors.white,
                radius: 12,
                borderWidth: 3,
              ),
              child: QrImageView(
                // The link it carries, for tests to find.
                key: ValueKey(povLinkFor(code.code)),
                data: povLinkFor(code.code),
                size: 220,
                backgroundColor: Colors.white,
                gapless: true,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: NeoLabel(
            l10n.povQrLeft(povClock(left)),
            color: NeoColors.accent,
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.povQrIntro,
          style: const TextStyle(
            color: NeoColors.muted,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        NeoButton(
          expand: true,
          label: l10n.povClose,
          variant: NeoButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Widget _problem(AppLocalizations l10n, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        NeoButton(
          expand: true,
          label: l10n.povQrNew,
          onPressed: widget.store.busy ? null : _renew,
        ),
        const SizedBox(height: 8),
        NeoButton(
          expand: true,
          label: l10n.povClose,
          variant: NeoButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
