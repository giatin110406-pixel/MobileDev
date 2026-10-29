import 'dart:async';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_preview.dart';

/// Step 1 trial screen: the live preview, a shutter and, in debug builds, the
/// numbers the native side measures (see the plan's section 5).
class RewindScreen extends StatefulWidget {
  const RewindScreen({
    super.key,
    this.initialLens = CameraLensDirection.back,
    this.lockscreen = false,
    this.backend,
  });

  final CameraLensDirection initialLens;
  final bool lockscreen;
  final RewindBackend? backend;

  @override
  State<RewindScreen> createState() => _RewindScreenState();
}

class _RewindScreenState extends State<RewindScreen> {
  late final RewindBackend _backend =
      widget.backend ?? MethodChannelRewindBackend();
  StreamSubscription<RewindEvent>? _events;
  Timer? _statsTimer;
  RewindStart? _start;
  String _status = '';
  Map<String, Object?> _stats = const {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _events = _backend.events.listen((event) {
      if (!mounted) return;
      setState(() {
        _status = switch (event) {
          RewindHolding() => 'holding',
          RewindFrozen(:final frames, :final still) =>
            'frozen: ${frames.length} frames, still ${still?.offsetMs}ms',
          RewindError(:final code, :final message) => 'error $code $message',
        };
      });
    });
    _open();
    if (kDebugMode) {
      _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (
        _,
      ) async {
        final stats = await _backend.stats();
        if (mounted) setState(() => _stats = stats);
      });
    }
  }

  Future<void> _open() async {
    try {
      final start = await _backend.start(
        front: widget.initialLens == CameraLensDirection.front,
      );
      if (mounted) setState(() => _start = start);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _status = 'error ${e.code}');
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _events?.cancel();
    _backend.stop();
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (start != null) RewindPreview(start: start),
            if (kDebugMode)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    [
                      _status,
                      for (final e in _stats.entries) '${e.key}: ${e.value}',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            NeoButton(
              label: 'SHUTTER',
              onPressed: start == null ? null : _backend.shutter,
            ),
          ],
        ),
      ),
    );
  }
}
