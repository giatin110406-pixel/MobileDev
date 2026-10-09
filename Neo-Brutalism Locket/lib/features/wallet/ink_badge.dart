import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// How much Ink I have (the canvas currency, not Sunbit).
class InkBadge extends StatelessWidget {
  const InkBadge({required this.amount, super.key});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$amount mực',
      child: ExcludeSemantics(
        child: NeoLabel(
          '$amount MỰC',
          color: NeoColors.blue,
          icon: Icons.water_drop,
        ),
      ),
    );
  }
}
