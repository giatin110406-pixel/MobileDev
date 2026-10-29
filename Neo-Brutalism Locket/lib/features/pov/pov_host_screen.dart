import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/features/camera/square_crop.dart';
import 'package:neo_brutalism_locket/features/pov/pov_connection.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

/// Omni POV, showing: I am taking the photos, and a friend watches my camera. The
/// camera is opened here for the connection (the camera page lets go of it first), and
/// this page looks like it: the square viewfinder, the shutter, the flip, the light and
/// the timer. Each photo is cut to the same square the friend sees and handed to
/// [onShot], which saves it. Photos can be taken as long as the session lasts.
class PovHostScreen extends StatefulWidget {
  const PovHostScreen({
    required this.store,
    required this.repository,
    required this.viewer,
    required this.onShot,
    super.key,
  });

  final PovStore store;
  final PovRepository repository;

  /// The friend who is watching (null when not known).
  final PocketFriend? viewer;

  /// Saves one photo: a square JPEG.
  final Future<void> Function(Uint8List squareJpeg) onShot;

  @override
  State<PovHostScreen> createState() => _PovHostScreenState();
}

class _PovHostScreenState extends State<PovHostScreen>
    with WidgetsBindingObserver {
  final _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  MediaStreamTrack? _track;
  PovHostConnection? _connection;

  bool _ready = false;
  bool _flash = false;
  bool _shutterDown = false;
  bool _busy = false;
  bool _torch = false;
  bool _front = false;
  ShotTimer _timer = ShotTimer.off;
  int? _countdown;
  Timer? _countdownTimer;
  int _shots = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    unawaited(_open());
  }

  Future<void> _open() async {
    final session = widget.store.session;
    if (session == null) return;
    try {
      await _renderer.initialize();
      final stream = await _openCamera();
      _stream = stream;
      _track = stream.getVideoTracks().first;
      _renderer.srcObject = stream;
      if (mounted) setState(() => _ready = true);
      final ice = await widget.repository.iceServers();
      final connection = PovHostConnection(
        signal: widget.repository.openSignal(session.id),
        ice: ice,
        camera: stream,
      );
      _connection = connection;
      connection.link.addListener(_onLink);
      connection.onBye.listen((_) => _finish(PovEnd.ended));
      await connection.start();
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).povCameraFailed)),
        );
      }
      _finish(PovEnd.lostConnection);
    }
  }

  /// The camera page has just let go of the camera, which the phone may take a moment
  /// to give back: try a few times.
  Future<MediaStream> _openCamera() async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': 'environment',
            'width': {'ideal': 1920},
            'height': {'ideal': 1080},
            'frameRate': {'ideal': 30},
          },
        });
      } catch (error, stack) {
        AppLog.warn('pov_host', error, stack);
        if (attempt >= 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  void _onLink() {
    if (!mounted) return;
    if (_connection?.link.value == PovLink.lost) {
      _finish(PovEnd.lostConnection);
    } else {
      setState(() {});
    }
  }

  void _onStore() {
    if (!mounted) return;
    if (widget.store.session == null) {
      _close();
      return;
    }
    final shots = widget.store.session!.shots;
    if (shots > _shots) setState(() => _shots = shots);
  }

  void _finish(PovEnd reason) {
    if (_leaving) return;
    unawaited(widget.store.end(reason: reason));
    _close();
  }

  void _close() {
    if (_leaving) return;
    _leaving = true;
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A camera cannot run in the background: the session ends.
    if (state == AppLifecycleState.paused) _finish(PovEnd.ended);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    _countdownTimer?.cancel();
    final connection = _connection;
    if (connection != null) {
      connection.link.removeListener(_onLink);
      unawaited(connection.close());
    }
    unawaited(_release());
    super.dispose();
  }

  /// Lets go of the camera (the camera page opens it again).
  Future<void> _release() async {
    final stream = _stream;
    _renderer.srcObject = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {
          // Already stopped.
        }
      }
      await stream.dispose();
    }
    await _renderer.dispose();
  }

  // Taking photos ----------------------------------------------------------------------

  void _press() {
    if (_busy || _countdown != null || !_ready) return;
    Haptics.press();
    if (_timer == ShotTimer.off) {
      unawaited(_capture());
      return;
    }
    setState(() => _countdown = _timer.seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        timer.cancel();
        setState(() => _countdown = null);
        unawaited(_capture());
      } else {
        setState(() => _countdown = left);
      }
    });
  }

  Future<void> _capture() async {
    final track = _track;
    if (track == null || _busy) return;
    setState(() {
      _busy = true;
      _flash = true;
    });
    Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    try {
      final frame = await track.captureFrame();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'pov_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(frame.asUint8List(), flush: true);
      final Uint8List bytes;
      try {
        // The same centred square the friend is looking at.
        bytes = await cropShotToSquare(file.path);
      } finally {
        file.delete().ignore();
      }
      await widget.onShot(bytes);
      _shots++;
      unawaited(widget.store.reportShot());
      _connection?.sendShot(_shots);
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoNotSaved)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flip() async {
    final track = _track;
    if (track == null || _busy) return;
    try {
      await Helper.switchCamera(track);
      if (mounted) {
        setState(() {
          _front = !_front;
          _torch = false;
        });
      }
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
    }
  }

  Future<void> _toggleTorch() async {
    final track = _track;
    if (track == null || _front) return;
    try {
      if (!await track.hasTorch()) return;
      await track.setTorch(!_torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (error, stack) {
      AppLog.warn('pov_host', error, stack);
    }
  }

  // The page --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (widget.viewer?.name ?? '').toUpperCase();
    final link = _connection?.link.value ?? PovLink.connecting;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(PovEnd.ended);
      },
      child: Scaffold(
        backgroundColor: NeoColors.paper,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    NeoIconButton(
                      icon: Icons.close,
                      tooltip: l10n.povHostStop,
                      onPressed: () => _finish(PovEnd.ended),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: NeoLabel(
                          link == PovLink.reconnecting
                              ? l10n.povReconnecting
                              : l10n.povHostWatching(name),
                          color: link == PovLink.reconnecting
                              ? NeoColors.accent
                              : NeoColors.teal,
                          icon: Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    NeoLabel(
                      l10n.povHostShots(_shots),
                      color: NeoColors.surface,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AspectRatio(aspectRatio: 1, child: _viewfinder()),
                const Spacer(),
                _controls(l10n),
                const SizedBox(height: 14),
                NeoButton(
                  expand: true,
                  label: l10n.povHostStop,
                  variant: NeoButtonVariant.outline,
                  onPressed: () => _finish(PovEnd.ended),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    return Container(
      decoration: NeoTheme.panel(color: NeoColors.surface, radius: 40),
      foregroundDecoration: neoPanelOutline(radius: 40),
      child: NeoPanelClip(
        radius: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              const Center(
                child: CircularProgressIndicator(color: NeoColors.ink),
              ),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _flash ? 0.85 : 0,
                duration: const Duration(milliseconds: 120),
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            if (_countdown != null)
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: NeoTheme.panel(
                    color: NeoColors.accent,
                    radius: 999,
                  ),
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontFamily: NeoFont.display,
                      color: NeoColors.ink,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: NeoIconButton(
              icon: _torch ? Icons.flash_on : Icons.flash_off,
              tooltip: l10n.flashTooltip,
              onPressed: _front || !_ready ? null : _toggleTorch,
              fill: _torch ? NeoColors.accent : NeoColors.surface,
              size: 54,
            ),
          ),
        ),
        _shutter(l10n),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NeoIconButton(
                  icon: Icons.flip_camera_ios_outlined,
                  tooltip: l10n.switchCameraTooltip,
                  onPressed: _ready ? _flip : null,
                  fill: NeoColors.accent,
                  size: 54,
                ),
                const SizedBox(height: 8),
                NeoIconButton(
                  icon: switch (_timer) {
                    ShotTimer.off => Icons.timer_off_outlined,
                    ShotTimer.three => Icons.timer_3,
                    ShotTimer.ten => Icons.timer_10,
                  },
                  tooltip: _timer == ShotTimer.off
                      ? l10n.timerOff
                      : l10n.timerSeconds(_timer.seconds),
                  onPressed: _countdown != null
                      ? null
                      : () => setState(() => _timer = _timer.next),
                  fill: _timer == ShotTimer.off
                      ? NeoColors.surface
                      : NeoColors.coral,
                  size: 40,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The same button as on the camera page.
  Widget _shutter(AppLocalizations l10n) {
    final disabled = _busy || !_ready || _countdown != null;
    return Semantics(
      button: true,
      label: l10n.takePhotoLabel,
      child: Listener(
        onPointerDown: (_) => setState(() => _shutterDown = true),
        onPointerUp: (_) => setState(() => _shutterDown = false),
        onPointerCancel: (_) => setState(() => _shutterDown = false),
        child: GestureDetector(
          onTap: disabled ? null : _press,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(7),
            transform: Matrix4.translationValues(
              _shutterDown && !disabled ? 4 : 0,
              _shutterDown && !disabled ? 4 : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: disabled ? NeoColors.switchOff : NeoColors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: NeoColors.ink, width: 2),
              boxShadow: disabled || _shutterDown
                  ? const []
                  : const [
                      BoxShadow(
                        color: NeoColors.ink,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NeoColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: NeoColors.surface, width: 2),
              ),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(17),
                      child: CircularProgressIndicator(
                        color: NeoColors.ink,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
