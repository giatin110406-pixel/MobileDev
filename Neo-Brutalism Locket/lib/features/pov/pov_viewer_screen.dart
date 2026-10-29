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
import 'package:neo_brutalism_locket/features/pov/pov_controls.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

/// Omni POV, watching: I am the one being photographed, and this shows what my friend's
/// camera sees, as the square the photo will have. A flash and a line tell me when the
/// friend took one. I have the camera's controls too: the shutter (cuts a square photo from
/// the picture I receive and hands it to [onShot]), the timer, and the flip and the light
/// of my friend's camera. Closes when either of us ends the session.
class PovViewerScreen extends StatefulWidget {
  const PovViewerScreen({
    required this.store,
    required this.repository,
    required this.friend,
    required this.onShot,
    super.key,
  });

  final PovStore store;
  final PovRepository repository;

  /// The friend whose camera it is (null when not known).
  final PocketFriend? friend;

  /// Saves one photo I took from the picture: a square JPEG.
  final Future<void> Function(Uint8List squareJpeg) onShot;

  @override
  State<PovViewerScreen> createState() => _PovViewerScreenState();
}

class _PovViewerScreenState extends State<PovViewerScreen>
    with WidgetsBindingObserver {
  final _renderer = RTCVideoRenderer();
  PovViewerConnection? _connection;
  bool _hasPicture = false;
  bool _hasFrame = false;
  bool _flash = false;
  int _shots = 0;
  bool _leaving = false;
  bool _snapped = false;
  Timer? _snapTimer;
  bool _busy = false;
  bool _front = false;
  bool _torch = false;
  ShotTimer _timer = ShotTimer.off;
  int? _countdown;
  Timer? _countdownTimer;
  Timer? _awayTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onStore);
    _shots = widget.store.session?.shots ?? 0;
    unawaited(_open());
  }

  Future<void> _open() async {
    final session = widget.store.session;
    if (session == null) return;
    try {
      await _renderer.initialize();
      _renderer.onFirstFrameRendered = () {
        if (mounted) setState(() => _hasFrame = true);
      };
      final ice = await widget.repository.iceServers();
      final connection = PovViewerConnection(
        signal: widget.repository.openSignal(session.id),
        ice: ice,
      );
      _connection = connection;
      connection.remoteStream.addListener(() {
        _renderer.srcObject = connection.remoteStream.value;
        if (mounted) {
          setState(() => _hasPicture = connection.remoteStream.value != null);
        }
      });
      connection.link.addListener(_onLink);
      connection.onBye.listen((_) => _finish(PovEnd.ended));
      connection.onShot.listen(_onShot);
      connection.onGo.listen(_begin);
      connection.onState.listen((state) {
        if (mounted) {
          setState(() {
            _front = state.$1;
            _torch = state.$2;
          });
        }
      });
      await connection.start();
    } catch (error, stack) {
      AppLog.warn('pov_viewer', error, stack);
      _finish(PovEnd.lostConnection);
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

  /// The friend's phone took its photo: the count goes up (my own photo flashes
  /// this screen when it is taken).
  void _onShot(int count) {
    if (!mounted) return;
    if (count > _shots) setState(() => _shots = count);
  }

  void _onStore() {
    if (!mounted) return;
    final session = widget.store.session;
    if (session == null) {
      _close();
      return;
    }
    if (session.shots > _shots) setState(() => _shots = session.shots);
  }

  /// The session is over: tell the store (with [reason] when the phones lost each
  /// other) and leave.
  void _finish(PovEnd reason) {
    if (_leaving) return;
    unawaited(widget.store.end(reason: reason));
    _close();
  }

  void _close() {
    if (_leaving) return;
    _leaving = true;
    if (mounted) Navigator.of(context).pop();
  }

  // Taking photos ----------------------------------------------------------------------

  bool get _ready => _hasFrame && _connection != null;

  /// The shutter was pressed here: both phones take a photo.
  void _press() {
    if (_busy || _countdown != null || !_ready) return;
    final seconds = _timer == ShotTimer.off ? 0 : _timer.seconds;
    _connection?.sendGo(seconds);
    _begin(seconds);
  }

  /// A photo in [seconds] (now when 0), asked for here or by the friend.
  void _begin(int seconds) {
    if (!mounted || _busy || _countdown != null || !_ready) return;
    Haptics.press();
    if (seconds <= 0) {
      unawaited(_capture());
      return;
    }
    setState(() => _countdown = seconds);
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

  /// A square cut from the picture on my screen.
  Future<void> _capture() async {
    final tracks = _connection?.remoteStream.value?.getVideoTracks();
    if (tracks == null || tracks.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _flash = true;
      _snapped = true;
    });
    Haptics.heavy();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    _snapTimer?.cancel();
    _snapTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _snapped = false);
    });
    try {
      final frame = await tracks.first.captureFrame();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'pov_view_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(frame.asUint8List(), flush: true);
      final Uint8List bytes;
      try {
        bytes = await cropShotToSquare(file.path);
      } finally {
        file.delete().ignore();
      }
      await widget.onShot(bytes);
    } catch (error, stack) {
      AppLog.warn('pov_viewer', error, stack);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photoNotSaved)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Away from the app for too long: the session is given up.
    if (state == AppLifecycleState.paused) {
      _awayTimer ??= Timer(povReconnectWindow, () => _finish(PovEnd.ended));
    } else if (state == AppLifecycleState.resumed) {
      _awayTimer?.cancel();
      _awayTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onStore);
    _awayTimer?.cancel();
    _flashTimer?.cancel();
    _snapTimer?.cancel();
    _countdownTimer?.cancel();
    final connection = _connection;
    if (connection != null) {
      connection.link.removeListener(_onLink);
      unawaited(connection.close());
    }
    _renderer.srcObject = null;
    unawaited(_renderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (widget.friend?.name ?? '').toUpperCase();
    final link = _connection?.link.value ?? PovLink.connecting;
    final (label, color) = switch (link) {
      PovLink.live when _hasFrame => (l10n.povLive, NeoColors.lime),
      PovLink.reconnecting => (l10n.povReconnecting, NeoColors.accent),
      PovLink.lost => (l10n.povConnectionLost, NeoColors.coral),
      _ => (l10n.povConnecting, NeoColors.accent),
    };
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
                      tooltip: l10n.povStopWatching,
                      onPressed: () => _finish(PovEnd.ended),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.povViewerTitle(name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeoColors.ink,
                          fontFamily: NeoFont.display,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NeoLabel(
                      label,
                      color: color,
                      icon: link == PovLink.live && _hasFrame
                          ? Icons.circle
                          : Icons.sync,
                    ),
                  ],
                ),
                // The picture takes the middle, the controls sit under the thumb.
                Expanded(
                  child: Center(
                    child: AspectRatio(aspectRatio: 1, child: _picture(l10n)),
                  ),
                ),
                PovSnapLine(snapped: _snapped, note: l10n.povFramingNote),
                Text(
                  l10n.povShotsTaken(_shots),
                  style: const TextStyle(
                    color: NeoColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                PovControls(
                  ready: _ready,
                  busy: _busy,
                  front: _front,
                  torch: _torch,
                  timer: _timer,
                  counting: _countdown != null,
                  onShutter: _press,
                  onTorch: () => _connection?.sendCommand('torch'),
                  onFlip: () => _connection?.sendCommand('flip'),
                  onTimer: () => setState(() => _timer = _timer.next),
                ),
                const SizedBox(height: 18),
                NeoButton(
                  expand: true,
                  label: l10n.povStopWatching,
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

  /// Exactly the square the photo will have: a centred 1:1 crop.
  Widget _picture(AppLocalizations l10n) {
    return Container(
      decoration: NeoTheme.panel(color: NeoColors.ink, radius: 28),
      foregroundDecoration: neoPanelOutline(radius: 28),
      child: NeoPanelClip(
        radius: 28,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasPicture)
              RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.povWaitingPicture(widget.friend?.name ?? ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NeoColors.paper,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            PovFlash(on: _flash),
            if (_countdown != null) PovCountdown(_countdown!),
          ],
        ),
      ),
    );
  }
}
