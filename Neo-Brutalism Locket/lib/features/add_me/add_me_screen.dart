import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/add_me/add_me_backend.dart';
import 'package:neo_brutalism_locket/features/hold_frame/hold_frame_backend.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_preview.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

enum _Step { first, second, merging, merged, refused }

/// "Add me" (session B2): the group photo, then the same frame again with the
/// photographer in it, merged into one. Photo 2 is lined up on photo 1 with
/// the locked-frame guidance of "hold my frame" (B1). Returns the merged
/// square JPEG, or null.
class AddMeScreen extends StatefulWidget {
  const AddMeScreen({super.key, this.camera, this.merger});
  final HoldFrameBackend? camera;
  final AddMeBackend? merger;

  @override
  State<AddMeScreen> createState() => _AddMeScreenState();
}

class _AddMeScreenState extends State<AddMeScreen> with WidgetsBindingObserver {
  late final _camera = widget.camera ?? MethodChannelHoldFrameBackend();
  late final _merger = widget.merger ?? MethodChannelAddMeBackend();
  StreamSubscription<HoldFrameUpdate>? _events;
  Future<void>? _stopping;
  RewindStart? _start;
  bool _opening = true;
  bool _busy = false;
  bool _leaving = false;
  bool _cameraFailed = false;
  _Step _step = _Step.first;
  Uint8List? _first;
  Uint8List? _merged;
  Uint8List? _alternative;
  bool _showAlternative = false;
  bool _firstInFront = false;
  String? _reason;
  HoldFrameUpdate? _alignment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _events = _camera.updates.listen(
      _onUpdate,
      onError: (Object _) => _onUpdate(const HoldFrameUpdate(state: 'error')),
    );
    _open();
    // The models load while the person lines up photo 1.
    _merger.warmUp().catchError((Object _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _shutdown().ignore();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _shutdown() => _stopping ??= _camera.stop();

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _cameraFailed = false;
    });
    try {
      final start = await _camera.start();
      if (!mounted || _leaving) return;
      setState(() {
        _start = start;
        _opening = false;
      });
    } catch (error, stack) {
      AppLog.warn('add_me_camera', error, stack);
      if (mounted && !_leaving) {
        setState(() {
          _opening = false;
          _cameraFailed = true;
        });
      }
    }
  }

  void _onUpdate(HoldFrameUpdate update) {
    if (!mounted || _leaving || _step != _Step.second) return;
    if (update.state == 'error') {
      setState(() => _alignment = const HoldFrameUpdate(state: 'unsure'));
      return;
    }
    setState(() => _alignment = update);
  }

  /// Photo 1: the frame is locked on what the camera sees now, then shot.
  Future<void> _shootFirst() async {
    if (_busy) return;
    setState(() => _busy = true);
    Haptics.press();
    try {
      await _camera.lock();
      final first = await _camera.capture();
      if (!mounted || _leaving) return;
      setState(() {
        _first = first;
        _alignment = null;
        _step = _Step.second;
      });
    } catch (error, stack) {
      AppLog.warn('add_me_first', error, stack);
      _camera.unlock().ignore();
      if (mounted) {
        showNeoSnack(
          context,
          AppLocalizations.of(context).holdFrameFewFeatures,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Photo 2, then the merge.
  Future<void> _shootSecond() async {
    final first = _first;
    if (_busy || first == null) return;
    setState(() => _busy = true);
    Haptics.press();
    try {
      final second = await _camera.capture();
      if (!mounted || _leaving) return;
      setState(() => _step = _Step.merging);
      final outcome = await _merger.merge(first, second);
      if (!mounted || _leaving) return;
      setState(() {
        _merged = outcome.image;
        _alternative = outcome.alternative;
        _firstInFront = outcome.inFront;
        _showAlternative = false;
        _reason = outcome.reason;
        _step = outcome.ok ? _Step.merged : _Step.refused;
      });
      if (outcome.ok) Haptics.select();
    } catch (error, stack) {
      AppLog.warn('add_me_merge', error, stack);
      if (mounted) {
        setState(() {
          _reason = 'failed';
          _step = _Step.refused;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retakeSecond() => setState(() {
    _merged = null;
    _alternative = null;
    _showAlternative = false;
    _reason = null;
    _alignment = null;
    _step = _Step.second;
  });

  Future<void> _startOver() async {
    setState(() {
      _first = null;
      _merged = null;
      _alternative = null;
      _showAlternative = false;
      _reason = null;
      _alignment = null;
      _step = _Step.first;
    });
    try {
      await _camera.unlock();
    } catch (_) {}
  }

  Future<void> _close([Uint8List? bytes]) async {
    if (_leaving) return;
    _leaving = true;
    // Late updates are dropped by _leaving; a slow cancel must not hold the camera.
    _events?.cancel().ignore();
    _events = null;
    try {
      await _shutdown();
    } catch (_) {
    } finally {
      if (mounted) Navigator.of(context).pop(bytes);
    }
  }

  String _reasonText(AppLocalizations l) => switch (_reason) {
    'align_failed' => l.addMeAlignFailed,
    'background_changed' || 'several_changes' => l.addMeBackgroundChanged,
    'no_new_person' => l.addMeNoNewPerson,
    'change_too_large' => l.addMeTooLarge,
    'needs_matting' => l.addMeNeedsMatting,
    _ => l.addMeFailed,
  };

  static bool _closeEnough(HoldFrameUpdate a) =>
      a.state == 'adjust' &&
      a.dx.abs() <= .08 &&
      a.dy.abs() <= .08 &&
      a.roll.abs() <= 5 &&
      (a.scale - 1).abs() <= .1;

  Uint8List? get _shown => _showAlternative ? _alternative : _merged;

  /// Whether the picture on screen has the newcomer in front of the other person.
  bool get _shownInFront => _firstInFront != _showAlternative;

  String _guide(AppLocalizations l) {
    final a = _alignment;
    if (a == null || a.reason == 'stale') return l.holdFrameStale;
    if (a.state == 'unsure') return l.holdFrameUnsure;
    if (a.state == 'aligned') return l.addMeAligned;
    // The merge copes with a frame that is a little off: say so instead of
    // asking for an exact match.
    if (_closeEnough(a)) return l.addMeCloseEnough;
    return [
      if (a.dx.abs() > .03) a.dx > 0 ? l.holdFrameRight : l.holdFrameLeft,
      if (a.dy.abs() > .03) a.dy > 0 ? l.holdFrameDown : l.holdFrameUp,
      if (a.roll.abs() > 2)
        a.roll > 0 ? l.holdFrameClockwise : l.holdFrameCounterclockwise,
      if ((a.scale - 1).abs() > .04)
        a.scale > 1 ? l.holdFrameBack : l.holdFrameCloser,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l.addMeTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            onPressed: _close,
            tooltip: l.closeAction,
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  switch (_step) {
                    _Step.first => l.addMeStep1,
                    _Step.second => l.addMeStep2,
                    _Step.merging => l.addMeMerging,
                    _Step.merged => l.addMeCheckResult,
                    _Step.refused => _reasonText(l),
                  },
                  key: const ValueKey('add-me-text'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: NeoTheme.panel(),
                  child: AspectRatio(aspectRatio: 1, child: _picture()),
                ),
                const SizedBox(height: 16),
                if (_step == _Step.second)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _guide(l),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ..._actions(l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _picture() {
    final merged = _shown;
    if (_step == _Step.merged && merged != null) {
      return Image.memory(merged, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final a = _alignment;
    final guide = a != null && a.state != 'unsure' && a.reason != 'stale';
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_start != null)
            RewindPreview(start: _start!)
          else
            const ColoredBox(color: NeoColors.ink),
          // Photo 1, faint, moved to where its scene is in the view now: the
          // helper turns the phone until it sits on the scene.
          if (_first != null && _step != _Step.first)
            LayoutBuilder(
              builder: (context, box) => Opacity(
                opacity: .35,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      guide ? a.dx * box.maxWidth : 0,
                      guide ? a.dy * box.maxHeight : 0,
                      0,
                      1,
                    )
                    ..rotateZ(guide ? a.roll * math.pi / 180 : 0)
                    ..scaleByDouble(
                      guide ? a.scale : 1,
                      guide ? a.scale : 1,
                      1,
                      1,
                    ),
                  child: Image.memory(
                    _first!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          if (_opening || _busy || _step == _Step.merging)
            const Center(child: CircularProgressIndicator()),
          if (_step == _Step.second &&
              a != null &&
              (a.state == 'aligned' || _closeEnough(a)))
            const Positioned(
              top: 12,
              right: 12,
              child: Icon(Icons.check_circle, color: NeoColors.teal, size: 40),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l) {
    if (_cameraFailed) {
      return [NeoButton(label: l.retry, expand: true, onPressed: _open)];
    }
    if (_start == null) return const [];
    return switch (_step) {
      _Step.first => [
        NeoButton(
          key: const ValueKey('add-me-first'),
          label: l.addMeShootFirst,
          icon: Icons.groups,
          expand: true,
          onPressed: _busy ? null : _shootFirst,
        ),
      ],
      _Step.second => [
        NeoButton(
          key: const ValueKey('add-me-second'),
          label: l.addMeShootSecond,
          icon: Icons.person_add_alt_1,
          expand: true,
          onPressed: _busy ? null : _shootSecond,
        ),
        const SizedBox(height: 10),
        NeoButton(
          label: l.addMeStartOver,
          variant: NeoButtonVariant.outline,
          expand: true,
          onPressed: _busy ? null : _startOver,
        ),
      ],
      _Step.merging => const [],
      _Step.merged => [
        NeoButton(
          key: const ValueKey('add-me-use'),
          label: l.addMeUse,
          icon: Icons.check,
          expand: true,
          onPressed: () => _close(_shown),
        ),
        if (_alternative != null) ...[
          const SizedBox(height: 10),
          NeoButton(
            key: const ValueKey('add-me-layer'),
            label: _shownInFront ? l.addMeBehindThem : l.addMeInFrontOfThem,
            icon: Icons.layers,
            variant: NeoButtonVariant.outline,
            expand: true,
            onPressed: () => setState(() => _showAlternative = !_showAlternative),
          ),
        ],
        const SizedBox(height: 10),
        NeoButton(
          label: l.addMeRetakeSecond,
          variant: NeoButtonVariant.outline,
          expand: true,
          onPressed: _retakeSecond,
        ),
      ],
      _Step.refused => [
        NeoButton(
          key: const ValueKey('add-me-retake'),
          label: l.addMeRetakeSecond,
          expand: true,
          onPressed: _retakeSecond,
        ),
        const SizedBox(height: 10),
        NeoButton(
          label: l.addMeStartOver,
          variant: NeoButtonVariant.outline,
          expand: true,
          onPressed: _startOver,
        ),
      ],
    };
  }
}
