import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_geometry.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/corridor_painter.dart';
import 'package:neo_brutalism_locket/features/contest/gallery/entry_image_cache.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Walk down the Gallery: swipe up to go forward, down to go back (or use the
/// scroll wheel or the two arrow buttons). The pictures slide past on both
/// walls. Tap one and the visitor walks up to it, stops and turns to face it, still in
/// the corridor, and a card with its name pops up from the bottom. From the card the
/// painting can be opened (to rate and comment) or the visitor can walk on.
class CorridorView extends StatefulWidget {
  const CorridorView({
    required this.entries,
    required this.cache,
    required this.onOpen,
    this.onNearEnd,
    this.initialCameraZ = 0,
    this.layout,
    this.style = CorridorStyle.gallery,
    this.decorOf,
    this.label,
    this.caption,
    super.key,
  });

  final List<GalleryEntry> entries;
  final EntryImageCache cache;
  final ValueChanged<GalleryEntry> onOpen;

  /// Called when the visitor is close to the end of what is loaded.
  final VoidCallback? onNearEnd;
  final double initialCameraZ;

  /// Where the frames hang (the Gallery's salon wall by default).
  final List<FrameSlot> Function(List<GalleryEntry> entries)? layout;
  final CorridorStyle style;
  final FrameDecor Function(GalleryEntry entry)? decorOf;

  /// What a screen reader calls this place.
  final String? label;

  /// A line under the name of the painting on its card (the theme of the contest).
  final String? caption;

  @override
  State<CorridorView> createState() => _CorridorViewState();
}

class _CorridorViewState extends State<CorridorView>
    with TickerProviderStateMixin {
  late final ValueNotifier<double> _camera = ValueNotifier(
    widget.initialCameraZ,
  );
  // Created in initState, not lazily: a lazy `late final` would first be built
  // inside dispose() when nobody touched it, and a ticker cannot be created
  // from a deactivated element.
  late final AnimationController _motion;

  // Looking at one painting: the walk up to it and the turn toward it ([_focusAnim]),
  // then the card that pops up ([_panelAnim]).
  late final AnimationController _focusAnim;
  late final AnimationController _panelAnim;
  final ValueNotifier<double> _yaw = ValueNotifier(0);
  final ValueNotifier<double> _eye = ValueNotifier(0);
  FrameSlot? _focusSlot;
  GalleryEntry? _focusEntry;
  double _fromZ = 0;
  double _toZ = 0;
  double _toYaw = 0;
  double _toEye = 0;
  late List<FrameSlot> _slots = _layOut();
  bool _lite = false;
  final List<int> _frameMicros = [];

  /// The walls: a salon wall of frames (blank canvases) with the entries hung on
  /// the ones that suit a painting, unless the caller lays the room out itself.
  List<FrameSlot> _layOut() =>
      widget.layout?.call(widget.entries) ??
      layoutGallery(widget.entries.length);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this)
      ..addListener(_onMotion);
    _focusAnim =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1100),
          )
          ..addListener(_onFocusTick)
          ..addStatusListener(_onFocusStatus);
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void didUpdateWidget(CorridorView old) {
    super.didUpdateWidget(old);
    // The walls only depend on how many entries there are.
    if (old.entries.length != widget.entries.length) _slots = _layOut();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _motion.dispose();
    _focusAnim.dispose();
    _panelAnim.dispose();
    _yaw.dispose();
    _eye.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// A phone that needs more than ~22 ms for a frame switches to the lighter
  /// look (no gradients, planks or light pools).
  void _onTimings(List<FrameTiming> timings) {
    if (_lite || !mounted) return;
    for (final timing in timings) {
      _frameMicros.add(timing.totalSpan.inMicroseconds);
    }
    if (_frameMicros.length < 90) return;
    final recent = _frameMicros.sublist(_frameMicros.length - 90);
    final average = recent.reduce((a, b) => a + b) / recent.length;
    if (average > 22000) {
      setState(() => _lite = true);
    }
    if (_frameMicros.length > 400) {
      _frameMicros.removeRange(0, _frameMicros.length - 90);
    }
  }

  /// Where the corridor ends (the end wall with the door).
  double get _end => corridorLength(_slots) + 1;

  /// The visitor stops a few metres before the end wall.
  double get _max => math.max(0, _end - 5);

  void _set(double z) {
    final clamped = z.clamp(0.0, _max);
    _camera.value = clamped;
    if (widget.onNearEnd != null && clamped > _max - 14) widget.onNearEnd!();
  }

  void _onMotion() => _set(_motion.value);

  void _fling(double velocity) {
    _motion.value = _camera.value;
    _motion.animateWith(FrictionSimulation(0.12, _camera.value, velocity));
  }

  void _walk(double metres) {
    _motion.stop();
    _motion.value = _camera.value;
    _motion.animateTo(
      (_camera.value + metres).clamp(0.0, _max),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  static const _metresPerPixel = 0.012;

  // Looking at a painting ---------------------------------------------------------

  bool get _looking => _focusSlot != null;

  /// The visitor walks to the painting, stops level with the middle of its frame and
  /// turns to face it, with the eyes at the height of the painting.
  void _lookAt(FrameSlot slot, GalleryEntry entry) {
    if (_looking) return;
    _motion.stop();
    _focusSlot = slot;
    _focusEntry = entry;
    _fromZ = _camera.value;
    _toZ = ((slot.z0 + slot.z1) / 2).clamp(0.0, _end);
    _toYaw = slot.side * math.pi / 2;
    _toEye = (slot.yTop + slot.yBottom) / 2;
    _panelAnim.value = 0;
    setState(() {});
    _focusAnim.forward(from: 0);
  }

  /// Turns back, walks back to where the visitor was, and the card goes away.
  void _walkOn() {
    if (!_looking) return;
    _panelAnim.reverse();
    _focusAnim.reverse();
  }

  void _onFocusTick() {
    final t = _focusAnim.value;
    // First the walk (and the turn begins part-way through it), then the turn.
    final walk = Curves.easeInOut.transform((t / 0.55).clamp(0.0, 1.0));
    final turn = Curves.easeInOutCubic.transform(
      ((t - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    _camera.value = _fromZ + (_toZ - _fromZ) * walk;
    _yaw.value = _toYaw * turn;
    _eye.value = _toEye * turn;
  }

  void _onFocusStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _panelAnim.forward(from: 0);
    } else if (status == AnimationStatus.dismissed) {
      setState(() {
        _focusSlot = null;
        _focusEntry = null;
      });
    }
  }

  /// A tap while looking at a painting: on the painting it opens it, elsewhere the
  /// visitor walks on.
  void _tapWhileLooking(Offset at, Size size) {
    if (_focusAnim.status != AnimationStatus.completed) return;
    final slot = _focusSlot!;
    final quad = Projection(
      size,
      _camera.value,
      yaw: _yaw.value,
      cameraY: _eye.value,
    ).wallQuad(slot);
    if (quad != null && pointInQuad(at, quad)) {
      widget.onOpen(_focusEntry!);
    } else {
      _walkOn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_looking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _walkOn();
      },
      child: Semantics(
        container: true,
        label:
            widget.label ??
            AppLocalizations.of(
              context,
            ).corridorSemantics(widget.entries.length),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  onPointerSignal: (event) {
                    if (_looking) return;
                    if (event is PointerScrollEvent) {
                      _motion.stop();
                      _set(_camera.value + event.scrollDelta.dy * 0.01);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => _motion.stop(),
                    onVerticalDragUpdate: (d) {
                      if (!_looking) {
                        _set(_camera.value - d.delta.dy * _metresPerPixel);
                      }
                    },
                    onVerticalDragEnd: (d) {
                      if (!_looking) {
                        _fling(
                          -d.velocity.pixelsPerSecond.dy * _metresPerPixel,
                        );
                      }
                    },
                    onTapUp: (d) {
                      if (_looking) {
                        _tapWhileLooking(d.localPosition, size);
                        return;
                      }
                      final slot = hitTest(
                        d.localPosition,
                        _slots,
                        Projection(size, _camera.value),
                      );
                      if (slot != null) {
                        _lookAt(slot, widget.entries[slot.index]);
                      }
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: size,
                        painter: CorridorPainter(
                          camera: _camera,
                          yaw: _yaw,
                          eye: _eye,
                          entries: widget.entries,
                          slots: _slots,
                          cache: widget.cache,
                          lite: _lite,
                          style: widget.style,
                          decorOf: widget.decorOf,
                          endZ: _end,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 16,
                  child: IgnorePointer(
                    ignoring: _looking,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _looking ? 0 : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NeoIconButton(
                            icon: Icons.keyboard_arrow_up,
                            tooltip: AppLocalizations.of(context).walkForward,
                            onPressed: () => _walk(4),
                          ),
                          const SizedBox(height: 10),
                          NeoIconButton(
                            icon: Icons.keyboard_arrow_down,
                            tooltip: AppLocalizations.of(context).walkBack,
                            onPressed: () => _walk(-4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.entries.isNotEmpty)
                  Positioned(
                    left: 12,
                    bottom: 16,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _looking ? 0 : 1,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _camera,
                          builder: (context, z, _) => NeoLabel(
                            _position(z),
                            color: NeoColors.accent,
                            icon: Icons.directions_walk,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_focusEntry != null) _card(context, _focusEntry!),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The card with the painting's name that pops up from the bottom: it slides up with a
  /// little overshoot and fades in.
  Widget _card(BuildContext context, GalleryEntry entry) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: 14,
      right: 14,
      bottom: 18,
      child: AnimatedBuilder(
        animation: _panelAnim,
        builder: (context, child) {
          final pop = Curves.easeOutBack.transform(_panelAnim.value);
          return IgnorePointer(
            ignoring: _panelAnim.value < 0.6,
            child: Opacity(
              opacity: Curves.easeOut.transform(_panelAnim.value),
              child: Transform.translate(
                offset: Offset(0, (1 - pop) * 160),
                child: child,
              ),
            ),
          );
        },
        child: Semantics(
          container: true,
          liveRegion: true,
          label: l10n.galleryEntrySemantics(entry.seq, entry.groupName),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NeoLabel('#${entry.seq}', color: NeoColors.teal),
                    if (widget.caption != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: NeoColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontFamily: NeoFont.display,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                NeoButton(
                  expand: true,
                  label: l10n.galleryFocusDetails,
                  icon: Icons.star_outline,
                  onPressed: () => widget.onOpen(entry),
                ),
                const SizedBox(height: 8),
                NeoButton(
                  expand: true,
                  label: l10n.galleryFocusLeave,
                  icon: Icons.directions_walk,
                  variant: NeoButtonVariant.outline,
                  onPressed: _walkOn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Tranh 12 / 87": the frame nearest ahead of the visitor.
  String _position(double z) {
    // The nearest entry ahead (blank canvases do not count).
    FrameSlot? ahead;
    for (final slot in _slots) {
      if (slot.isBlank) continue;
      if (slot.z1 > z + 0.5 && (ahead == null || slot.z0 < ahead.z0)) {
        ahead = slot;
      }
    }
    final index = (ahead?.index ?? widget.entries.length - 1) + 1;
    // A "+" while more pages are still to be loaded.
    final more = widget.onNearEnd != null ? '+' : '';
    return '$index / ${widget.entries.length}$more';
  }
}
