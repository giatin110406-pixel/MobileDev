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
  });

  factory RewindStart.fromMap(Map<Object?, Object?> map) => RewindStart(
    textureId: (map['textureId']! as num).toInt(),
    previewWidth: (map['previewWidth']! as num).toInt(),
    previewHeight: (map['previewHeight']! as num).toInt(),
    sensorOrientation: (map['sensorOrientation']! as num).toInt(),
    front: map['lensFacing'] == 'front',
    handlesCropAndRotation: map['handlesCropAndRotation'] == true,
  );

  final int textureId;

  /// The preview buffer as the sensor delivers it (wider than tall).
  final int previewWidth;
  final int previewHeight;
  final int sensorOrientation;
  final bool front;

  /// The engine already turns and crops the texture, so Dart must not.
  final bool handlesCropAndRotation;
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

class RewindFrozen extends RewindEvent {
  const RewindFrozen({required this.frames, required this.still});

  final List<RewindFrame> frames;

  /// Null when the still failed or was cancelled.
  final RewindStill? still;
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
  Future<RewindStart> start({required bool front});
  Future<void> shutter();

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
  Future<RewindStart> start({required bool front}) async {
    final map = await _methods.invokeMapMethod<Object?, Object?>('start', {
      'lens': front ? 'front' : 'back',
    });
    return RewindStart.fromMap(map!);
  }

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
      default:
        return RewindError(
          (map['code'] as String?) ?? 'unknown',
          map['message'] as String?,
        );
    }
  }
}
