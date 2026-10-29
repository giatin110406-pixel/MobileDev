import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:neo_brutalism_locket/features/camera/square_crop.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';

@immutable
class HoldFrameUpdate {
  const HoldFrameUpdate({
    required this.state,
    this.reason,
    this.dx = 0,
    this.dy = 0,
    this.roll = 0,
    this.scale = 1,
    this.ready = false,
  });

  factory HoldFrameUpdate.fromMap(Map<Object?, Object?> map) => HoldFrameUpdate(
    state: map['state'] as String? ?? 'unsure',
    reason: map['reason'] as String?,
    dx: (map['dx'] as num?)?.toDouble() ?? 0,
    dy: (map['dy'] as num?)?.toDouble() ?? 0,
    roll: (map['roll'] as num?)?.toDouble() ?? 0,
    scale: (map['scale'] as num?)?.toDouble() ?? 1,
    ready: map['ready'] == true,
  );

  final String state;
  final String? reason;
  final double dx, dy, roll, scale;
  final bool ready;
}

abstract class HoldFrameBackend {
  Future<RewindStart> start();
  Future<Uint8List> lock();
  Future<void> unlock();
  Future<void> arm(bool on);
  Future<Uint8List> capture();
  Future<void> stop();
  Stream<HoldFrameUpdate> get updates;
}

class MethodChannelHoldFrameBackend implements HoldFrameBackend {
  static const _methods = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/rewind',
  );
  static const _events = EventChannel(
    'com.neobrutalism.neo_brutalism_locket/rewind_events',
  );
  int? _lockId;

  @override
  Future<RewindStart> start() async => RewindStart.fromMap(
    (await _methods.invokeMapMethod<Object?, Object?>('start', {
      'lens': 'back',
      'continuous': true,
      'keepFrames': false,
      'askPermission': true,
    }))!,
  );

  @override
  Future<Uint8List> lock() async {
    _lockId = null;
    final result = (await _methods.invokeMapMethod<Object?, Object?>(
      'lockFrame',
    ))!;
    _lockId = (result['lockId']! as num).toInt();
    return result['image']! as Uint8List;
  }

  @override
  Future<void> unlock() {
    _lockId = null;
    return _methods.invokeMethod<void>('unlockFrame');
  }

  @override
  Future<void> arm(bool on) =>
      _methods.invokeMethod<void>('armHoldFrame', {'on': on});

  @override
  Future<Uint8List> capture() async {
    final shot = (await _methods.invokeMapMethod<Object?, Object?>('shoot'))!;
    return cropShotToSquare(shot['path']! as String);
  }

  @override
  Future<void> stop() {
    _lockId = null;
    return _methods.invokeMethod<void>('stop');
  }

  @override
  Stream<HoldFrameUpdate> get updates => _events
      .receiveBroadcastStream()
      .where((raw) {
        final map = raw! as Map<Object?, Object?>;
        return map['type'] == 'error' ||
            (map['type'] == 'alignment' &&
                _lockId != null &&
                map['lockId'] == _lockId);
      })
      .map((raw) {
        final map = raw! as Map<Object?, Object?>;
        return map['type'] == 'error'
            ? HoldFrameUpdate(state: 'error', reason: map['code'] as String?)
            : HoldFrameUpdate.fromMap(map);
      });
}
