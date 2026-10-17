import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/core/print_sound.dart';
import 'package:neo_brutalism_locket/features/photos/archive_screen.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// The stamp slammed on the print after a post. Only a show: it is drawn on top
/// of the screen and never written into the photo or the post.
enum PrintStamp { approved, verified, topSecret }

/// Which stamp a post earns: a passed quest is VERIFIED, every seventh day of a
/// streak is TOP SECRET, anything else APPROVED.
PrintStamp printStampFor({required bool quest, required int streak}) {
  if (quest) return PrintStamp.verified;
  if (streak > 0 && streak % 7 == 0) return PrintStamp.topSecret;
  return PrintStamp.approved;
}

/// The "print effect" switch in Settings. When it is off, or the phone asks for
/// less motion, [playPrintPost] returns at once.
abstract final class PrintEffect {
  static bool enabled = true;
}

/// Plays the post animation over the app and completes when it is over (a tap
/// ends it early). The post itself has already been sent; this never waits on
/// it and never changes it.
Future<void> playPrintPost(
  BuildContext context, {
  required NeoPhoto photo,
  required PrintStamp stamp,
}) async {
  if (!PrintEffect.enabled || MediaQuery.disableAnimationsOf(context)) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) =>
        PrintPostAnimation(photo: photo, stamp: stamp),
  );
}

/// The slot, the sheet that is printed out of it step by step, and the stamp.
class PrintPostAnimation extends StatefulWidget {
  const PrintPostAnimation({
    required this.photo,
    required this.stamp,
    this.onDone,
    super.key,
  });

  final NeoPhoto photo;
  final PrintStamp stamp;

  /// Called once at the end; by default the dialog closes itself.
  final VoidCallback? onDone;

  /// How many jerks the sheet makes coming out.
  static const steps = 7;

  @override
  State<PrintPostAnimation> createState() => _PrintPostAnimationState();
}

class _PrintPostAnimationState extends State<PrintPostAnimation>
    with SingleTickerProviderStateMixin {
  // Share of the whole run: print out, then stamp, then a short hold.
  static const _printEnd = 0.6;
  static const _stampEnd = 0.8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  int _ticks = 0;
  bool _stamped = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_buzz)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
    PrintSound.printOut();
  }

  void _buzz() {
    final t = _controller.value;
    final step = (t / _printEnd * PrintPostAnimation.steps).floor().clamp(
      0,
      PrintPostAnimation.steps,
    );
    if (step > _ticks) {
      _ticks = step;
      Haptics.select();
    }
    if (!_stamped && t >= _printEnd + (_stampEnd - _printEnd) * 0.6) {
      _stamped = true;
      Haptics.heavy();
      PrintSound.stampDown();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    PrintSound.stop();
    final done = widget.onDone;
    if (done != null) {
      done();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final side = (size.width * 0.74).clamp(180.0, 320.0);
    const footer = 46.0;
    final sheetHeight = side + footer;
    final photo = widget.photo;
    final path = photo.processedPath ?? photo.originalPath;
    return Semantics(
      label: printStampLabel(l10n, widget.stamp),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: NeoColors.ink.withValues(alpha: 0.6),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final out = (t / _printEnd).clamp(0.0, 1.0);
                // Whole steps, so it jerks out like a thermal printer.
                final stepped =
                    (out * PrintPostAnimation.steps).floor() /
                    PrintPostAnimation.steps;
                final stampT = ((t - _printEnd) / (_stampEnd - _printEnd))
                    .clamp(0.0, 1.0);
                // Falls from big to its size, with a small bounce.
                final stampScale = stampT == 0
                    ? 0.0
                    : 1 + (1 - Curves.easeIn.transform(stampT)) * 1.6;
                final shake = stampT > 0.55 && stampT < 0.95
                    ? (stampT * 40).floor().isEven
                          ? 3.0
                          : -3.0
                    : 0.0;
                return SizedBox(
                  width: side + 16,
                  height: sheetHeight + 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: NeoColors.ink,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: NeoColors.surface,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: NeoColors.muted,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 20,
                        bottom: 0,
                        child: ClipRect(
                          child: Transform.translate(
                            offset: Offset(shake, -sheetHeight * (1 - stepped)),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _sheet(
                                context,
                                l10n,
                                path,
                                side,
                                footer,
                                stampScale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheet(
    BuildContext context,
    AppLocalizations l10n,
    String path,
    double side,
    double footer,
    double stampScale,
  ) {
    final photo = widget.photo;
    return SizedBox(
      width: side,
      height: side + footer,
      child: Container(
        decoration: NeoTheme.panel(color: NeoColors.surface),
        child: NeoPanelClip(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  SizedBox(
                    width: side,
                    height: side - 4,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: NeoColors.switchOff),
                    ),
                  ),
                  Container(height: 2, color: NeoColors.ink),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.printNumber(
                                photo.id.substring(photo.id.length - 2),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: NeoColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            formatPrintDate(l10n, DateTime.now()),
                            style: const TextStyle(
                              color: NeoColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (stampScale > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: side * 0.3,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Transform.scale(
                        scale: stampScale,
                        child: _stampMark(l10n, widget.stamp),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stampMark(AppLocalizations l10n, PrintStamp stamp) {
    final colour = switch (stamp) {
      PrintStamp.approved => const Color(0xFFD7301F),
      PrintStamp.verified => const Color(0xFF1F6FB8),
      PrintStamp.topSecret => NeoColors.ink,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: NeoColors.surface.withValues(alpha: 0.82),
        border: Border.all(color: colour, width: 4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        printStampLabel(l10n, stamp),
        style: TextStyle(
          color: colour,
          fontFamily: NeoFont.body,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          height: 1.1,
        ),
      ),
    );
  }
}

/// The stamp's words in the app's language.
String printStampLabel(AppLocalizations l10n, PrintStamp stamp) =>
    switch (stamp) {
      PrintStamp.approved => l10n.stampApproved,
      PrintStamp.verified => l10n.stampVerified,
      PrintStamp.topSecret => l10n.stampTopSecret,
    };

/// Three chips to pick the stamp for the post animation. The one the post earns
/// is lit until another is picked. It is only a show, never part of the photo.
class StampPicker extends StatelessWidget {
  const StampPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final PrintStamp selected;
  final ValueChanged<PrintStamp> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const ValueKey('stamp-picker'),
      children: [
        for (final stamp in PrintStamp.values) ...[
          if (stamp != PrintStamp.values.first) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: stamp == selected,
              child: InkWell(
                onTap: Haptics.tap(
                  () => onChanged(stamp),
                  kind: HapticKind.select,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: NeoTheme.panel(
                    color: stamp == selected
                        ? NeoColors.yellow
                        : NeoColors.surface,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      printStampLabel(l10n, stamp),
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontFamily: NeoFont.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
