import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

/// What one tab of a group shows.
class GroupTabData {
  const GroupTabData({
    required this.label,
    required this.icon,
    required this.color,
    this.info,
    this.badge = 0,
  });

  final String label;
  final IconData icon;

  /// The tab's fill while it is the one selected.
  final Color color;

  /// A short line under the label: what is going on in there ("5 INK").
  final String? info;

  /// A count on the icon (unread messages); 0 for none.
  final int badge;
}

/// The row of tabs under a group's name. A tab is a chunky button: it stands
/// out with a hard shadow, and the selected one is pressed in and filled with its
/// own colour. Tabs with news say so: an unread count, or a line of info.
class GroupTabBar extends StatelessWidget {
  const GroupTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<GroupTabData> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, tab) in tabs.indexed) ...[
        if (index > 0) const SizedBox(width: 10),
        Expanded(
          child: _GroupTab(
            data: tab,
            selected: index == selected,
            onTap: () => onSelect(index),
          ),
        ),
      ],
    ],
  );
}

class _GroupTab extends StatelessWidget {
  const _GroupTab({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final GroupTabData data;
  final bool selected;
  final VoidCallback onTap;

  static const _offset = Offset(3, 3);

  @override
  Widget build(BuildContext context) {
    final info = data.info;
    return Semantics(
      button: true,
      selected: selected,
      label: info == null ? data.label : '${data.label}, $info',
      excludeSemantics: true,
      child: NeoPress(
        onTap: onTap,
        offset: _offset,
        sunken: selected,
        builder: (context, pressed) => AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? data.color : NeoColors.surface,
            border: Border.all(color: NeoColors.ink, width: 2),
            borderRadius: BorderRadius.circular(10),
            boxShadow: NeoPress.shadow(pressed, offset: _offset),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.15 : 1,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: Icon(data.icon, size: 22, color: NeoColors.ink),
                  ),
                  if (data.badge > 0)
                    Positioned(
                      top: -6,
                      right: -14,
                      child: _Badge(count: data.badge),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (info != null)
                Text(
                  info,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 9.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The red count on a tab's icon.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18),
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: NeoColors.coral,
      border: Border.all(color: NeoColors.ink, width: 1.5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
