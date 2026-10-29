import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the camera told us when it started.
@immutable
class RewindStart {
  const RewindStart({
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientation,
    required this.front,
    required this.handlesCropAndRotation,
    this.minZoom = 1,
    this.maxZoom = 1,
  });

  factory RewindStart.fromMap(Map<Object?, Object?> map) => RewindStart(
    textureId: (map['textureId']! as num).toInt(),
    previewWidth: (map['previewWidth']! as num).toInt(),
    previewHeight: (map['previewHeight']! as num).toInt(),
    sensorOrientation: (map['sensorOrientation']! as num).toInt(),
    front: map['lensFacing'] == 'front',
    handlesCropAndRotation: map['handlesCropAndRotation'] == true,
    minZoom: (map['minZoom'] as num?)?.toDouble() ?? 1,
    maxZoom: (map['maxZoom'] as num?)?.toDouble() ?? 1,
  );

  final int textureId;

  /// The preview buffer as the sensor delivers it (wider than tall).
  final int previewWidth;
  final int previewHeight;
  final int sensorOrientation;
  final bool front;

  /// The engine already turns and crops the texture, so Dart must not.
  final bool handlesCropAndRotation;

  /// The lens's zoom ratios (1 and 1 when it cannot zoom).
  final double minZoom;
  final double maxZoom;
}

/// A shot taken by the main camera: the full-quality still, already on disk.
@immutable
class RewindShot {
  const RewindShot({
    required this.shotId,
    required this.path,
    required this.withBurst,
  });

  factory RewindShot.fromMap(Map<Object?, Object?> map) => RewindShot(
    shotId: map['shotId']! as String,
    path: map['path']! as String,
    withBurst: map['burst'] == true,
  );

  final String shotId;

  /// The JPEG; its EXIF says how to turn it upright.
  final String path;

  /// The frames around the press will follow as a [RewindBurst].
  final bool withBurst;
}

/// A camera frame kept from the stream, as a square JPEG file.
@immutable
class RewindFrame {
  const RewindFrame({
    required this.path,
    required this.offsetMs,
    required this.rotation,
  });

  factory RewindFrame.fromMap(Map<Object?, Object?> map) => RewindFrame(
    path: map['path']! as String,
    offsetMs: (map['offsetMs']! as num).toInt(),
    rotation: (map['rotation']! as num).toInt(),
  );

  final String path;

  /// Milliseconds from the shutter press (negative: before it).
  final int offsetMs;

  /// Clockwise degrees to turn the picture so it stands upright.
  final int rotation;
}

/// The full-quality still taken at the press.
@immutable
class RewindStill {
  const RewindStill({required this.path, required this.offsetMs});

  factory RewindStill.fromMap(Map<Object?, Object?> map) => RewindStill(
    path: map['path']! as String,
    offsetMs: (map['offsetMs']! as num).toInt(),
  );

  /// The JPEG; its EXIF says how to turn it upright.
  final String path;
  final int offsetMs;
}

sealed class RewindEvent {
  const RewindEvent();
}

/// The shutter went; the last second of frames is still being collected.
class RewindHolding extends RewindEvent {
  const RewindHolding();
}

/// Omni POV: a QR code is in view of the main camera (the raw text of the code).
class RewindCode extends RewindEvent {
  const RewindCode(this.value);

  final String value;
}

class RewindFrozen extends RewindEvent {
  const RewindFrozen({required this.frames, required this.still});

  final List<RewindFrame> frames;

  /// Null when the still failed or was cancelled.
  final RewindStill? still;
}

/// The frames around a shot of the main camera, about a second after it.
class RewindBurst extends RewindEvent {
  const RewindBurst({required this.shotId, required this.frames});

  final String shotId;
  final List<RewindFrame> frames;
}

class RewindError extends RewindEvent {
  const RewindError(this.code, this.message);

  final String code;
  final String? message;
}

/// The camera behind the rewind screen. The real one talks to Kotlin; tests
/// put a fake in its place.
abstract class RewindBackend {
  /// Starts the camera. Throws a [PlatformException] (code `cameraBusy`) when
  /// it cannot.
  Future<RewindStart> start({
    required bool front,
    bool continuous = false,
    bool askPermission = false,
  });
  Future<void> shutter();

  /// Main camera: takes the picture. Its frames follow as a [RewindBurst].
  Future<RewindShot> shoot();

  /// One of `off`, `auto`, `on`.
  Future<void> setFlash(String mode);
  Future<void> setZoom(double ratio);

  /// Omni POV: reads QR codes out of the main camera's frames while on.
  Future<void> setScanning(bool on);

  /// Starts a clip (no sound) and later hands back the MP4's path.
  Future<void> startVideo();
  Future<String> stopVideo();

  /// The shot's frames and still are not needed any more.
  Future<void> releaseShot(String shotId);

  /// Drops the held frames and watches again.
  Future<void> rearm();

  /// A frame turned upright and encoded as a square JPEG.
  Future<Uint8List> finalizeFrame(String path, int rotation);

  /// Numbers for the debug overlay.
  Future<Map<String, Object?>> stats();
  Future<void> stop();

  /// Lock screen only: asks the user to unlock. True once unlocked.
  Future<bool> dismissKeyguard();

  /// Lock screen only: saves [bytes], opens the main app on them and closes.
  Future<void> handoff(Uint8List bytes);
  Stream<RewindEvent> get events;
}

class MethodChannelRewindBackend implements RewindBackend {
  static const _methods = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/rewind',
  );
  static const _eventChannel = EventChannel(
    'com.neobrutalism.neo_brutalism_locket/rewind_events',
  );

  @override
  Future<RewindStart> start({
    required bool front,
    bool continuous = false,
    bool askPermission = false,
  }) async {
    final map = await _methods.invokeMapMethod<Object?, Object?>('start', {
      'lens': front ? 'front' : 'back',
      'continuous': continuous,
      'askPermission': askPermission,
    });
    return RewindStart.fromMap(map!);
  }

  @override
  Future<RewindShot> shoot() async => RewindShot.fromMap(
    (await _methods.invokeMapMethod<Object?, Object?>('shoot'))!,
  );

  @override
  Future<void> setFlash(String mode) =>
      _methods.invokeMethod<void>('setFlash', {'mode': mode});

  @override
  Future<void> setScanning(bool on) =>
      _methods.invokeMethod<void>('setScanning', {'on': on});

  @override
  Future<void> setZoom(double ratio) =>
      _methods.invokeMethod<void>('setZoom', {'ratio': ratio});

  @override
  Future<void> startVideo() => _methods.invokeMethod<void>('startVideo');

  @override
  Future<String> stopVideo() async =>
      (await _methods.invokeMethod<String>('stopVideo'))!;

  @override
  Future<void> releaseShot(String shotId) =>
      _methods.invokeMethod<void>('releaseShot', {'shotId': shotId});

  @override
  Future<void> shutter() => _methods.invokeMethod<void>('shutter');

  @override
  Future<void> rearm() => _methods.invokeMethod<void>('rearm');

  @override
  Future<Uint8List> finalizeFrame(String path, int rotation) async {
    final bytes = await _methods.invokeMethod<Uint8List>('finalizeFrame', {
      'path': path,
      'rotation': rotation,
    });
    return bytes!;
  }

  @override
  Future<Map<String, Object?>> stats() async =>
      await _methods.invokeMapMethod<String, Object?>('stats') ?? const {};

  @override
  Future<void> stop() => _methods.invokeMethod<void>('stop');

  @override
  Future<bool> dismissKeyguard() async =>
      await _methods.invokeMethod<bool>('dismissKeyguard') ?? false;

  @override
  Future<void> handoff(Uint8List bytes) =>
      _methods.invokeMethod<void>('handoff', {'bytes': bytes});

  @override
  Stream<RewindEvent> get events =>
      _eventChannel.receiveBroadcastStream().map(_decode);

  static RewindEvent _decode(Object? raw) {
    final map = raw! as Map<Object?, Object?>;
    switch (map['type']) {
      case 'holding':
        return const RewindHolding();
      case 'code':
        return RewindCode(map['value']! as String);
      case 'frozen':
        final still = map['hq'];
        return RewindFrozen(
          frames: [
            for (final f in map['frames']! as List<Object?>)
              RewindFrame.fromMap(f! as Map<Object?, Object?>),
          ],
          still: still == null
              ? null
              : RewindStill.fromMap(still as Map<Object?, Object?>),
        );
      case 'burst':
        return RewindBurst(
          shotId: map['shotId']! as String,
          frames: [
            for (final f in map['frames']! as List<Object?>)
              RewindFrame.fromMap(f! as Map<Object?, Object?>),
          ],
        );
      default:
        return RewindError(
          (map['code'] as String?) ?? 'unknown',
          map['message'] as String?,
        );
    }
  }
}
