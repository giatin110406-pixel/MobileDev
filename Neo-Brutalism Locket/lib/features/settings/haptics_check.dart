import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A small check that tells a tester why the phone does (not) buzz: what the
/// phone reports, and a button for each way of buzzing.
Future<void> showHapticsCheck(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const HapticsCheckDialog(),
);

class HapticsCheckDialog extends StatefulWidget {
  const HapticsCheckDialog({super.key});

  @override
  State<HapticsCheckDialog> createState() => _HapticsCheckDialogState();
}

class _HapticsCheckDialogState extends State<HapticsCheckDialog> {
  late final Future<HapticStatus?> _status = Haptics.status();

  /// Three buzzes in a row, one of each strength, so they can be compared.
  Future<void> _tryAll({required bool viaMotor}) async {
    for (final kind in [HapticKind.light, HapticKind.press, HapticKind.heavy]) {
      await Haptics.test(kind, viaMotor: viaMotor);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: NeoColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: NeoColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      title: Text(
        l10n.hcTitle,
        style: const TextStyle(
          fontFamily: NeoFont.display,
          color: NeoColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: FutureBuilder<HapticStatus?>(
          future: _status,
          builder: (context, snapshot) {
            final status = snapshot.data;
            final waiting = snapshot.connectionState != ConnectionState.done;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(color: NeoColors.ink),
                    ),
                  )
                else if (status == null)
                  _note(l10n.hcUnknown)
                else ...[
                  _line(
                    l10n.hcMotor,
                    status.hasVibrator ? l10n.hcYes : l10n.hcNo,
                    good: status.hasVibrator,
                  ),
                  _line(
                    l10n.hcStrengths,
                    status.hasAmplitudeControl ? l10n.hcYes : l10n.hcNo,
                    good: status.hasAmplitudeControl,
                  ),
                  _line(
                    l10n.hcPhoneSetting,
                    status.touchFeedbackOn ? l10n.hcOn : l10n.hcOff,
                    good: status.touchFeedbackOn,
                  ),
                  _line(l10n.hcAndroid, '${status.sdk}'),
                  const SizedBox(height: 10),
                  _note(
                    !status.hasVibrator
                        ? l10n.hcAdviceNoMotor
                        : !status.touchFeedbackOn
                        ? l10n.hcAdviceOff
                        : l10n.hcAdviceTry,
                  ),
                ],
                const SizedBox(height: 14),
                NeoButton(
                  label: l10n.hcTrySystem,
                  icon: Icons.vibration,
                  expand: true,
                  variant: NeoButtonVariant.outline,
                  onPressed: () => _tryAll(viaMotor: false),
                ),
                const SizedBox(height: 10),
                NeoButton(
                  label: l10n.hcTryDirect,
                  icon: Icons.bolt,
                  expand: true,
                  variant: NeoButtonVariant.accent,
                  onPressed: () => _tryAll(viaMotor: true),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.closeAction),
        ),
      ],
    );
  }

  Widget _line(String label, String value, {bool? good}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        NeoLabel(
          value,
          color: good == null
              ? NeoColors.surface
              : good
              ? NeoColors.teal
              : NeoColors.pink,
        ),
      ],
    ),
  );

  Widget _note(String text) => Text(
    text,
    style: const TextStyle(
      color: NeoColors.muted,
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
  );
}
