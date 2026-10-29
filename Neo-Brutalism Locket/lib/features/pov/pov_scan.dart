import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/pov/pov_text.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// What one look at a camera frame found.
class PovScanResult {
  const PovScanResult({this.code, this.otherQr = false});

  /// An Omni POV code, if the frame showed one.
  final String? code;

  /// The frame showed a QR code, but not one of ours.
  final bool otherQr;
}

/// How the camera frame is turned, for ML Kit (degrees clockwise). [sensor] is the
/// camera's own orientation and [device] how the phone is held; back camera only.
int povScanRotation(int sensor, DeviceOrientation device) {
  final held = switch (device) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return (sensor - held + 360) % 360;
}

/// Reads Omni POV codes out of the frames of the main camera (ML Kit, on the phone, no
/// network). It looks at a few frames a second, one at a time, so the viewfinder stays
/// smooth. The camera has to deliver NV21 frames (see `imageFormatGroup` of the
/// controller).
class PovCodeReader {
  PovCodeReader({
    BarcodeScanner? scanner,
    this.every = const Duration(milliseconds: 250),
  }) : _scanner = scanner ?? BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  final BarcodeScanner _scanner;

  /// The least time between two looks.
  final Duration every;

  bool _busy = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Looks at [image] (null when it is skipped: too soon, or one is being read).
  Future<PovScanResult?> look(
    CameraImage image, {
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
  }) async {
    final now = DateTime.now();
    if (_busy || now.difference(_last) < every) return null;
    if (image.format.group != ImageFormatGroup.nv21 ||
        image.planes.length != 1) {
      return null;
    }
    _busy = true;
    _last = now;
    try {
      final plane = image.planes.first;
      final rotation =
          InputImageRotationValue.fromRawValue(
            povScanRotation(sensorOrientation, deviceOrientation),
          ) ??
          InputImageRotation.rotation0deg;
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final found = await _scanner.processImage(input);
      var other = false;
      for (final barcode in found) {
        final text = barcode.rawValue;
        if (text == null) continue;
        final code = povCodeFromText(text);
        if (code != null) return PovScanResult(code: code);
        other = true;
      }
      return other ? const PovScanResult(otherQr: true) : null;
    } catch (error, stack) {
      AppLog.warn('pov_scan', error, stack);
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> close() => _scanner.close();
}

/// Laid over the viewfinder while it looks for a code: four corners to aim with, and a
/// line saying what to do.
class PovScanOverlay extends StatelessWidget {
  const PovScanOverlay({
    required this.onClose,
    this.notOurs = false,
    super.key,
  });

  final VoidCallback onClose;

  /// A QR code that is not an Omni POV one is in view.
  final bool notOurs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(54),
            child: CustomPaint(painter: _CornersPainter(notOurs: notOurs)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 52,
          child: IgnorePointer(
            child: Center(
              child: NeoLabel(
                notOurs ? l10n.povScanNotOurs : l10n.povScanHint,
                color: notOurs ? NeoColors.coral : NeoColors.accent,
                icon: Icons.qr_code_scanner,
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 0,
          right: 0,
          child: Center(
            child: Tooltip(
              message: l10n.povClose,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: NeoColors.ink.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: NeoColors.surface, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: NeoColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter({required this.notOurs});

  final bool notOurs;

  @override
  void paint(Canvas canvas, Size size) {
    final arm = size.shortestSide * 0.2;
    final line = Paint()
      ..color = notOurs ? NeoColors.coral : NeoColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;
    final edge = Paint()
      ..color = NeoColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.square;
    final box = Offset.zero & size;
    for (final paint in [edge, line]) {
      final path = Path()
        ..moveTo(box.left, box.top + arm)
        ..lineTo(box.left, box.top)
        ..lineTo(box.left + arm, box.top)
        ..moveTo(box.right - arm, box.top)
        ..lineTo(box.right, box.top)
        ..lineTo(box.right, box.top + arm)
        ..moveTo(box.right, box.bottom - arm)
        ..lineTo(box.right, box.bottom)
        ..lineTo(box.right - arm, box.bottom)
        ..moveTo(box.left + arm, box.bottom)
        ..lineTo(box.left, box.bottom)
        ..lineTo(box.left, box.bottom - arm);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.notOurs != notOurs;
}

/// B has a code (from a scan, or a link opened by another camera app): whose is it?
/// B is asked, with their name, before anything is shared; then the session starts
/// (and the camera page opens the connection by itself). Returns true when it did.
Future<bool> joinPovWithCode(
  BuildContext context, {
  required PovStore store,
  required String code,
  required List<PocketFriend> friends,
}) async {
  final l10n = AppLocalizations.of(context);
  final peek = await store.peek(code);
  if (!context.mounted) return false;
  if (peek == null) {
    final failure = store.error;
    store.clearNotice();
    if (failure != null) showNeoSnack(context, povFailureText(l10n, failure));
    return false;
  }
  final friend = friends.where((f) => f.id == peek.viewerId).firstOrNull;
  final yes = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConfirmSheet(peek: peek, friend: friend),
  );
  if (yes != true || !context.mounted) return false;
  final joined = await store.join(code);
  if (!joined && context.mounted) {
    final failure = store.error;
    store.clearNotice();
    if (failure != null) showNeoSnack(context, povFailureText(l10n, failure));
  }
  return joined;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.peek, required this.friend});

  final PovPeek peek;
  final PocketFriend? friend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = (friend?.name ?? peek.displayName).toUpperCase();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: NeoTheme.panel(color: NeoColors.accent, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (friend != null) ...[
                  FriendAvatar(friend: friend!, size: 48),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.povConfirmTitle(name),
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.povConfirmNote,
              style: const TextStyle(
                color: NeoColors.ink,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NeoButton(
                    expand: true,
                    label: l10n.povAllow,
                    variant: NeoButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeoButton(
                    expand: true,
                    label: l10n.povDeny,
                    variant: NeoButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
