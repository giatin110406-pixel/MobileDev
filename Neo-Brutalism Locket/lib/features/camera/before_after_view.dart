import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A shot before and after its style: swipe left on the picture for the
/// styled print, right for the original (a tap switches too). Until the
/// style is ready only the original shows.
class BeforeAfterView extends StatefulWidget {
  const BeforeAfterView({
    super.key,
    required this.originalPath,
    required this.styledPath,
    required this.styleLabel,
    required this.showStyled,
    required this.onChanged,
  });

  final String originalPath;

  /// Null while the style is being applied (or when there is none).
  final String? styledPath;

  /// The style's name, shown on the styled side (`8-BIT`, `VAN GOGH`).
  final String styleLabel;

  /// Which side is on screen.
  final bool showStyled;
  final ValueChanged<bool> onChanged;

  @override
  State<BeforeAfterView> createState() => _BeforeAfterViewState();
}

class _BeforeAfterViewState extends State<BeforeAfterView> {
  late final PageController _pages = PageController(initialPage: _targetPage);

  bool get _hasStyled => widget.styledPath != null;
  int get _targetPage => _hasStyled && widget.showStyled ? 1 : 0;

  @override
  void didUpdateWidget(covariant BeforeAfterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The style just finished, or the side was changed from outside: follow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      final current = _pages.page?.round() ?? 0;
      if (current == _targetPage) return;
      _pages.animateToPage(
        _targetPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_hasStyled) widget.onChanged(!widget.showStyled);
  }

  Widget _picture(String path) => Image.file(
    File(path),
    key: ValueKey(path),
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Center(
      child: Text(
        AppLocalizations.of(context).imageNotFound,
        style: const TextStyle(
          color: NeoColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final styled = widget.styledPath;
    final onStyled = _hasStyled && widget.showStyled;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: PageView(
            controller: _pages,
            physics: _hasStyled
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => widget.onChanged(page == 1),
            children: [
              _picture(widget.originalPath),
              if (styled != null) _picture(styled),
            ],
          ),
        ),
        if (_hasStyled) ...[
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              child: NeoLabel(
                onStyled
                    ? widget.styleLabel
                    : AppLocalizations.of(context).originalLabel,
                color: onStyled ? NeoColors.teal : NeoColors.surface,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final active in [!onStyled, onStyled])
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? NeoColors.ink : NeoColors.surface,
                        border: Border.all(color: NeoColors.ink, width: 1.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
