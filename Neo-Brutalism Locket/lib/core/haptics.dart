import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The four buzzes the app uses.
enum HapticKind {
  /// A light tick: small icon buttons, opening and closing things.
  light,

  /// A firm press: buttons that sink into their shadow, the shutter.
  press,

  /// A heavy thud: the moment a video starts recording.
  heavy,

  /// A detent click: switches, tabs, sliders.
  select,
}

/// What the phone says about vibration (Android only).
class HapticStatus {
  const HapticStatus({
    required this.hasVibrator,
    required this.hasAmplitudeControl,
    required this.touchFeedbackOn,
    required this.sdk,
  });

  /// There is a vibration motor.
  final bool hasVibrator;

  /// The motor can vibrate at different strengths.
  final bool hasAmplitudeControl;

  /// The phone's own "touch vibration / touch feedback" setting. When it is
  /// off, every normal system haptic is silent, whatever the app asks.
  final bool touchFeedbackOn;

  /// The Android API level.
  final int sdk;
}

/// The little buzzes that make a button feel like a mechanical key.
///
/// One switch (`enabled`, kept by `AppSettings`) turns all of them off, so the
/// widgets just call these and never think about the setting.
///
/// Two ways to buzz:
/// - **system** (default): the phone's own haptic feedback. Android only plays
///   it when "touch vibration" is on in the phone's settings, so on some
///   phones (or with that setting off) it stays silent.
/// - **direct** (`direct = true`): the app drives the vibration motor itself,
///   so it works whatever that setting says. Opt-in, see the Settings screen.
abstract final class Haptics {
  static bool enabled = true;

  /// Drive the motor directly (Android), ignoring the touch-vibration setting.
  static bool direct = false;

  static const MethodChannel _channel = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/haptics',
  );

  static void light() => play(HapticKind.light);
  static void press() => play(HapticKind.press);
  static void heavy() => play(HapticKind.heavy);
  static void select() => play(HapticKind.select);

  /// Wraps a tap handler so it buzzes first. A null handler stays null, so a
  /// disabled control keeps looking (and behaving) disabled.
  static VoidCallback? tap(VoidCallback? handler, {HapticKind? kind}) {
    if (handler == null) return null;
    return () {
      play(kind ?? HapticKind.light);
      handler();
    };
  }

  /// [tap] for handlers that take a value (chips, menus, switches).
  static ValueChanged<T>? tapWith<T>(
    ValueChanged<T>? handler, {
    HapticKind? kind,
  }) {
    if (handler == null) return null;
    return (value) {
      play(kind ?? HapticKind.light);
      handler(value);
    };
  }

  static void play(HapticKind kind) {
    if (!enabled) return;
    unawaited(_play(kind, viaMotor: direct));
  }

  /// Plays [kind] the chosen way even when buzzing is switched off: for the
  /// vibration check in Settings.
  static Future<bool> test(HapticKind kind, {required bool viaMotor}) =>
      _play(kind, viaMotor: viaMotor);

  /// What the phone says about vibration, or null where that is unknown
  /// (not Android, or no answer).
  static Future<HapticStatus?> status() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('status');
      if (map == null) return null;
      return HapticStatus(
        hasVibrator: map['hasVibrator'] == true,
        hasAmplitudeControl: map['hasAmplitudeControl'] == true,
        touchFeedbackOn: map['touchFeedbackOn'] != false,
        sdk: (map['sdk'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// How long and how hard the motor runs for each kind (milliseconds, 1-255).
  @visibleForTesting
  static (int, int) motorPattern(HapticKind kind) => switch (kind) {
    HapticKind.select => (8, 70),
    HapticKind.light => (12, 90),
    HapticKind.press => (28, 170),
    HapticKind.heavy => (50, 255),
  };

  static Future<bool> _play(HapticKind kind, {required bool viaMotor}) async {
    if (viaMotor && await _motor(kind)) return true;
    // No motor access (not Android, no vibrator): fall back to the system one.
    return _system(kind);
  }

  static Future<bool> _motor(HapticKind kind) async {
    try {
      final (ms, amplitude) = motorPattern(kind);
      final ok = await _channel.invokeMethod<bool>('buzz', {
        'ms': ms,
        'amplitude': amplitude,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _system(HapticKind kind) async {
    try {
      await switch (kind) {
        HapticKind.light => HapticFeedback.lightImpact(),
        HapticKind.press => HapticFeedback.mediumImpact(),
        HapticKind.heavy => HapticFeedback.heavyImpact(),
        HapticKind.select => HapticFeedback.selectionClick(),
      };
      return true;
    } catch (_) {
      // A phone without a vibration motor must not turn a tap into an error.
      return false;
    }
  }
}
