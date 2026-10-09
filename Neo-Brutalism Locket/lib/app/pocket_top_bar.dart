import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// The app header: logo, name and optional icon buttons on the right.
class PocketTopBar extends StatelessWidget {
  const PocketTopBar({super.key, this.actions = const []});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: NeoTheme.panel(
            color: NeoColors.pink,
            borderWidth: 2,
            radius: 8,
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            color: NeoColors.ink,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POCKET PORTRAIT',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'NEO BRUTAL CAMERA CLUB',
                style: TextStyle(
                  color: NeoColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (final (index, action) in actions.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          action,
        ],
      ],
    );
  }
}
