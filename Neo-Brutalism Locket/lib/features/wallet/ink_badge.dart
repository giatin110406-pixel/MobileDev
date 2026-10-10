import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// How much Ink I have (the canvas currency, not Sunbit).
class InkBadge extends StatelessWidget {
  const InkBadge({required this.amount, super.key});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).inkAmountSemantics(amount),
      child: ExcludeSemantics(
        child: NeoLabel(
          AppLocalizations.of(context).inkAmountLabel(amount),
          color: NeoColors.blue,
          icon: Icons.water_drop,
        ),
      ),
    );
  }
}
