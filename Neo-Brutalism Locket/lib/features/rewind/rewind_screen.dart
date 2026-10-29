import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/square_crop.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_preview.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_timeline.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

enum _Phase {
  starting,
  ready,
  holding,
  picking,
  busy,
  nothingKept,
  noPermission,
}

/// Rewind capture: the camera keeps the last two seconds, the person presses
/// (late or not), then swipes back to the frame they meant and sends it.
/// Pops with the chosen square JPEG, or null when closed.
///
/// With [lockscreen] set it runs in the lock-screen activity: it only
/// shoots and picks, and sending asks the person to unlock first.
class RewindScreen extends StatefulWidget {
  const RewindScreen({
    super.key,
    this.initialLens = CameraLensDirection.back,
    this.lockscreen = false,
    this.backend,
  });

  final CameraLensDirection initialLens;
  final bool lockscreen;

  /// The camera; the real one unless a test hands in a fake.
  final RewindBackend? backend;

  @override
  State<RewindScreen> createState() => _RewindScreenState();
}

class _RewindScreenState extends State<RewindScreen> {
  late final RewindBackend _backend =
      widget.backend ?? MethodChannelRewindBackend();
  StreamSubscription<RewindEvent>? _events;
  Timer? _statsTimer;
  final ScrollController _strip = ScrollController();
  _Phase _phase = _Phase.starting;
  late bool _front = widget.initialLens == CameraLensDirection.front;
  RewindStart? _start;
  RewindTimeline? _timeline;
  int _selected = 0;
  double _drag = 0;
  bool _sending = false;
  Map<String, Object?> _stats = const {};

  static const _thumb = 64.0;
  static const _thumbGap = 8.0;

  @override
  void initState() {
    super.initState();
    // The preview is turned for an upright screen only.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _events = _backend.events.listen(_onEvent);
    _open();
    if (!kReleaseMode) {
      // The numbers from the plan's measuring table (section 5). Debug and
      // profile builds only; profile is the one to judge smoothness in.
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) async {
        final stats = await _backend.stats();
        if (mounted) setState(() => _stats = stats);
      });
    }
  }

  // Frames whose build + raster took longer than one 60 Hz frame.
  int _slowFrames = 0;
  int _allFrames = 0;

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _allFrames++;
      if (timing.totalSpan > const Duration(microseconds: 16700)) _slowFrames++;
    }
  }

  @override
  void dispose() {
    if (!kReleaseMode) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _statsTimer?.cancel();
    _events?.cancel();
    _strip.dispose();
    _backend.stop();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _phase = _Phase.starting;
      _start = null;
      _timeline = null;
    });
    try {
      final start = await _backend.start(front: _front);
      if (!mounted) return;
      setState(() {
        _start = start;
        _phase = _Phase.ready;
      });
    } on PlatformException catch (e) {
      // The lock-screen screen never asks for the camera permission: it sends
      // the person to the app. In the app the camera page already did.
      if (mounted) {
        setState(
          () => _phase = e.code == 'noPermission' && widget.lockscreen
              ? _Phase.noPermission
              : _Phase.busy,
        );
      }
    }
  }

  void _onEvent(RewindEvent event) {
    if (!mounted) return;
    switch (event) {
      case RewindHolding():
        setState(() => _phase = _Phase.holding);
      case RewindCode():
        // Omni POV reads codes elsewhere (the main camera); the rewind screen does not.
        break;
      case RewindFrozen(:final frames, :final still):
        final timeline = RewindTimeline.tryBuild(frames: frames, still: still);
        setState(() {
          _timeline = timeline;
          _selected = timeline?.defaultIndex ?? 0;
          _phase = timeline == null ? _Phase.nothingKept : _Phase.picking;
        });
        if (timeline != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToThumb());
        }
      case RewindBurst():
        // Only the main camera page shoots in bursts.
        break;
      case RewindError():
        // The frames are already on disk once the person is choosing; a
        // camera that fails now (app in the background) must not take them away.
        if (_phase == _Phase.picking) return;
        setState(
          () => _phase = _phase == _Phase.holding
              ? _Phase.nothingKept
              : _Phase.busy,
        );
    }
  }

  Future<void> _shoot() async {
    if (_phase != _Phase.ready) return;
    Haptics.press();
    await _backend.shutter();
  }

  Future<void> _retake() async {
    await _backend.rearm();
    if (!mounted) return;
    setState(() {
      _timeline = null;
      _phase = _Phase.ready;
    });
  }

  Future<void> _flip() async {
    _front = !_front;
    await _open();
  }

  void _select(int index) {
    final timeline = _timeline;
    if (timeline == null) return;
    final next = index.clamp(0, timeline.entries.length - 1);
    if (next == _selected) return;
    Haptics.select();
    setState(() => _selected = next);
    _scrollToThumb();
  }

  void _scrollToThumb() {
    if (!_strip.hasClients) return;
    final centre = _selected * (_thumb + _thumbGap) + _thumb / 2;
    final target = (centre - _strip.position.viewportDimension / 2).clamp(
      0.0,
      _strip.position.maxScrollExtent,
    );
    _strip.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  // A swipe over the big picture steps through the frames: every 36 logical
  // pixels is one frame, dragging right goes back in time.
  void _onDragUpdate(DragUpdateDetails details) {
    _drag += details.delta.dx;
    const step = 36.0;
    while (_drag >= step) {
      _drag -= step;
      _select(_selected - 1);
    }
    while (_drag <= -step) {
      _drag += step;
      _select(_selected + 1);
    }
  }

  // The camera is let go of before the page closes, so the page below can
  // start its own right away without two cameras on one screen.
  Future<void> _close([Uint8List? bytes]) async {
    await _backend.stop();
    if (widget.lockscreen) {
      // The only screen of its activity: closing it ends the activity.
      await SystemNavigator.pop();
    } else if (mounted) {
      Navigator.of(context).pop(bytes);
    }
  }

  // No camera permission, on the lock screen: unlock, then open the app.
  Future<void> _openAppForCamera() async {
    if (await _backend.dismissKeyguard()) await _backend.handoff(Uint8List(0));
  }

  Future<void> _send() async {
    final timeline = _timeline;
    if (timeline == null || _sending) return;
    final entry = timeline.entries[_selected];
    setState(() => _sending = true);
    try {
      final bytes = entry.isStill
          ? await cropShotToSquare(entry.path)
          : await _backend.finalizeFrame(entry.path, entry.rotation);
      if (widget.lockscreen) {
        // Over the lock screen nothing is sent: unlock first, then the app
        // opens on this picture. If the person backs out, the choice stays.
        if (!await _backend.dismissKeyguard()) {
          if (!mounted) return;
          setState(() => _sending = false);
          showNeoSnack(
            context,
            AppLocalizations.of(context).rewindUnlockToSend,
          );
          return;
        }
        await _backend.handoff(bytes);
        return;
      }
      await _close(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showNeoSnack(context, AppLocalizations.of(context).photoNotSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // The back button goes through _close so the camera is released first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: NeoColors.paper,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeoIconButton(
                        icon: Icons.close,
                        tooltip: l10n.rewindClose,
                        onPressed: _close,
                        fill: NeoColors.coral,
                        size: 44,
                      ),
                      const Spacer(),
                      if (_phase == _Phase.ready)
                        NeoIconButton(
                          icon: Icons.flip_camera_ios_outlined,
                          tooltip: l10n.switchCameraTooltip,
                          onPressed: _flip,
                          fill: NeoColors.accent,
                          size: 44,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Square, but never so tall that the controls below are pushed
                  // off a short screen.
                  Center(
                    child: _square(
                      l10n,
                      math.min(
                        box.maxWidth - 32,
                        math.max(160, box.maxHeight - 290),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: _lower(l10n)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _square(AppLocalizations l10n, double side) {
    final start = _start;
    final timeline = _timeline;
    final Widget content;
    if (_phase == _Phase.picking && timeline != null) {
      content = _picked(timeline.entries[_selected], l10n);
    } else if (start != null &&
        (_phase == _Phase.ready || _phase == _Phase.holding)) {
      content = RewindPreview(start: start);
    } else if (_phase == _Phase.busy ||
        _phase == _Phase.nothingKept ||
        _phase == _Phase.noPermission) {
      content = Center(
        child: Text(
          switch (_phase) {
            _Phase.busy => l10n.rewindCameraBusy,
            _Phase.noPermission => l10n.rewindNoCameraAccess,
            _ => l10n.rewindNothingKept,
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: NeoFont.display,
            color: NeoColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }
    return SizedBox(
      width: side,
      height: side,
      child: Container(
        decoration: NeoTheme.panel(color: NeoColors.surface),
        foregroundDecoration: neoPanelOutline(),
        child: NeoPanelClip(
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (!kReleaseMode && _stats.isNotEmpty)
                Positioned(
                  left: 6,
                  top: 6,
                  child: IgnorePointer(child: _debugStats()),
                ),
              if (_phase == _Phase.holding)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: NeoLabel(
                      l10n.rewindHolding,
                      color: NeoColors.accent,
                      icon: Icons.history_toggle_off,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugStats() {
    String number(Object? value) =>
        value is double ? value.toStringAsFixed(1) : '$value';
    final lines = [
      for (final key in const [
        'keptPerSecond',
        'compressP50Ms',
        'compressP95Ms',
        'avgJpegKb',
        'ringFrames',
        'ringBytes',
        'dropped',
        'nativeHeapMb',
        'analysisWidth',
        'analysisHeight',
        'previewWidth',
        'previewHeight',
        'hqLagMs',
      ])
        '$key ${number(_stats[key])}',
      'slowFrames $_slowFrames/$_allFrames '
          '(${_allFrames == 0 ? 0 : (100 * _slowFrames / _allFrames).round()}%)',
    ];
    return Container(
      color: NeoColors.ink.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(4),
      child: Text(
        lines.join('\n'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          height: 1.2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // The chosen picture, big, with its time and (for a stream frame) the
  // plain statement that it is a little lower in quality.
  Widget _picked(RewindEntry entry, AppLocalizations l10n) {
    final label = rewindOffsetLabel(
      entry.offsetMs,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _drag = 0,
      onHorizontalDragUpdate: _onDragUpdate,
      child: Semantics(
        label: l10n.rewindFrameSemantics(label),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _picture(entry, cacheWidth: 1080),
            Positioned(
              left: 10,
              top: 10,
              child: NeoLabel(label, color: NeoColors.accent),
            ),
            if (!entry.isStill)
              Positioned(
                right: 10,
                top: 10,
                child: NeoLabel(l10n.rewindExtraFrame),
              ),
          ],
        ),
      ),
    );
  }

  // A stream frame is a square JPEG waiting to be turned upright; the still
  // carries its own turn in EXIF.
  Widget _picture(RewindEntry entry, {required int cacheWidth}) {
    final image = Image.file(
      File(entry.path),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
    );
    return entry.isStill
        ? image
        : RotatedBox(quarterTurns: entry.rotation ~/ 90, child: image);
  }

  Widget _lower(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.starting:
      case _Phase.holding:
        return const SizedBox.shrink();
      case _Phase.ready:
        return Column(
          children: [
            Text(
              l10n.rewindHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _shutter(l10n),
            const Spacer(),
          ],
        );
      case _Phase.busy:
        return Align(
          alignment: Alignment.topCenter,
          child: NeoButton(
            label: l10n.retry,
            icon: Icons.refresh,
            variant: NeoButtonVariant.outline,
            onPressed: _open,
          ),
        );
      case _Phase.noPermission:
        return Align(
          alignment: Alignment.topCenter,
          child: NeoButton(
            label: l10n.rewindOpenApp,
            icon: Icons.open_in_new,
            variant: NeoButtonVariant.outline,
            onPressed: _openAppForCamera,
          ),
        );
      case _Phase.nothingKept:
        return Align(
          alignment: Alignment.topCenter,
          child: NeoButton(
            label: l10n.rewindRetake,
            icon: Icons.refresh,
            variant: NeoButtonVariant.outline,
            onPressed: _retake,
          ),
        );
      case _Phase.picking:
        return Column(
          children: [
            SizedBox(height: _thumb + 30, child: _stripOfFrames()),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    label: l10n.rewindRetake,
                    icon: Icons.refresh,
                    variant: NeoButtonVariant.outline,
                    expand: true,
                    onPressed: _sending ? null : _retake,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeoButton(
                    label: l10n.rewindSend,
                    icon: Icons.send,
                    expand: true,
                    onPressed: _sending ? null : _send,
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _shutter(AppLocalizations l10n) => NeoPress(
    haptic: false,
    onTap: _shoot,
    builder: (context, pressed) => Semantics(
      button: true,
      label: l10n.rewindShutterLabel,
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: NeoColors.ink,
          shape: BoxShape.circle,
          border: Border.all(color: NeoColors.ink, width: 2),
          boxShadow: NeoPress.shadow(pressed),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NeoColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: NeoColors.surface, width: 2),
          ),
        ),
      ),
    ),
  );

  Widget _stripOfFrames() {
    final timeline = _timeline!;
    final language = Localizations.localeOf(context).languageCode;
    return ListView.separated(
      controller: _strip,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      itemCount: timeline.entries.length,
      separatorBuilder: (_, _) => const SizedBox(width: _thumbGap),
      itemBuilder: (context, index) {
        final entry = timeline.entries[index];
        final on = index == _selected;
        return GestureDetector(
          onTap: () => _select(index),
          child: SizedBox(
            width: _thumb,
            child: Column(
              children: [
                Container(
                  width: _thumb,
                  height: _thumb,
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(
                      color: NeoColors.ink,
                      width: on ? 3 : 1.5,
                    ),
                  ),
                  child: _picture(entry, cacheWidth: 160),
                ),
                const SizedBox(height: 2),
                Text(
                  rewindOffsetLabel(entry.offsetMs, languageCode: language),
                  style: TextStyle(
                    fontFamily: NeoFont.display,
                    color: NeoColors.ink,
                    fontSize: 10,
                    fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
