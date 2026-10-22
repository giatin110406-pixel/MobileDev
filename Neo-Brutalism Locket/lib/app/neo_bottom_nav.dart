import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';

// ---------------------------------------------------------------------------
// NeoBottomNavTab – data class describing a single tab in the nav bar.
// ---------------------------------------------------------------------------

/// Describes one tab inside [NeoBottomNav].
///
/// Each tab carries two icon variants (outline for idle, filled for active)
/// and an [activeColor]: the colour of the solid pill behind the selected tab.
class NeoBottomNavTab {
  const NeoBottomNavTab({
    required this.label,
    required this.outlineIcon,
    required this.filledIcon,
    required this.activeColor,
    this.prominent = false,
    this.behind,
  });

  /// Accessible name used by tooltips and screen readers.
  final String label;

  /// Icon displayed when the tab is **not** selected.
  final IconData outlineIcon;

  /// Icon displayed when the tab **is** selected.
  final IconData filledIcon;

  /// The colour of the pill behind the icon while the tab is selected.
  final Color activeColor;

  /// The app's main tab: a big round button in [activeColor] at all times,
  /// raised above the bar (see [NeoBottomNav.prominentDocked]).
  final bool prominent;

  /// A tab hidden behind this prominent one: it shows in its place while the
  /// big button is away ([NeoBottomNav.prominentDocked]), and a tap on the
  /// place then means it.
  final NeoBottomNavTab? behind;
}

// ---------------------------------------------------------------------------
// NeoBottomNav – the pill-shaped bottom navigation bar.
// ---------------------------------------------------------------------------

/// A neo-brutalism–styled bottom navigation bar rendered as a rounded pill.
///
/// Only one tab may be selected at a time. Selection is driven externally via
/// [selectedIndex]; tapping a tab calls [onSelected]. The app shell owns haptics.
///
class NeoBottomNav extends StatelessWidget {
  const NeoBottomNav({
    super.key,
    required this.selectedIndex,
    required this.tabs,
    required this.onSelected,
    this.prominentKey,
    this.prominentDocked = false,
  });

  /// Index of the currently selected tab (0-based).
  final int selectedIndex;

  /// Ordered list of tabs to render. Length determines column count.
  final List<NeoBottomNavTab> tabs;

  /// Called with the tapped tab's index when a user selects a tab.
  final ValueChanged<int> onSelected;

  /// On the prominent tab's round button, so its place can be found.
  final Key? prominentKey;

  /// The prominent button is away (it is the camera's shutter right now, or on
  /// its way there): the tab behind it shows in its place.
  final bool prominentDocked;

  /// The bar's width per tab.
  static const double _tabWidth = 80;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 18, top: 4, bottom: 8),
        // Only as wide as its tabs need, in the middle: a short bar for few.
        child: Center(
          heightFactor: 1,
          child: Container(
            width: tabs.length * _tabWidth,
            height: 58,
            decoration: BoxDecoration(
              color: NeoColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: NeoColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: NeoColors.ink,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                return _NeoNavItem(
                  tab: tabs[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                  buttonKey: tabs[index].prominent ? prominentKey : null,
                  docked: tabs[index].prominent && prominentDocked,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NeoNavItem – a single tab inside the bar (private).
// ---------------------------------------------------------------------------

/// An icon-only tab with an accessible name. The selected one sits on a solid
/// coloured pill with a black outline and a small hard shadow, so it stands out.
class _NeoNavItem extends StatelessWidget {
  const _NeoNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.buttonKey,
    this.docked = false,
  });

  final NeoBottomNavTab tab;
  final bool selected;
  final VoidCallback onTap;
  final Key? buttonKey;
  final bool docked;

  /// What the place stands for right now: the tab behind the big button
  /// while that is away.
  NeoBottomNavTab get _shown => docked ? (tab.behind ?? tab) : tab;

  /// The big round button of a [NeoBottomNavTab.prominent] tab, raised above
  /// the bar. While [docked] it is away and the tab behind it shows; its
  /// place (with [buttonKey]) stays, so it can fly back to it.
  Widget _prominent() {
    final circle = OverflowBox(
      maxHeight: 64,
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: SizedBox(
          key: buttonKey,
          width: 64,
          height: 64,
          child: docked
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: tab.activeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: NeoColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: NeoColors.ink,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    selected ? tab.filledIcon : tab.outlineIcon,
                    size: 30,
                    color: NeoColors.ink,
                  ),
                ),
        ),
      ),
    );
    final behind = tab.behind;
    if (!docked || behind == null) return circle;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: NeoColors.surface,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: NeoColors.ink, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: NeoColors.ink,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(behind.outlineIcon, size: 24, color: NeoColors.ink),
        ),
        circle,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Expanded(
      // A little more room so the big button does not crowd its neighbours.
      flex: tab.prominent ? 3 : 2,
      child: Semantics(
        button: true,
        selected: selected && shown == tab,
        label: shown.label,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: shown.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.expand(
              child: Center(
                child: tab.prominent
                    ? _prominent()
                    : AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        width: 52,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected
                              ? tab.activeColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? NeoColors.ink
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: NeoColors.ink,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ]
                              : const [],
                        ),
                        child: Center(
                          child: Icon(
                            selected ? tab.filledIcon : tab.outlineIcon,
                            size: 24,
                            color: NeoColors.ink,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
