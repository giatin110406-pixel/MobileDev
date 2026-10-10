import 'dart:async';

import 'package:flutter/services.dart';

/// The little buzzes that make a button feel like a mechanical key.
///
/// One switch (`enabled`, kept by `AppSettings`) turns all of them off, so the
/// widgets just call these and never think about the setting.
abstract final class Haptics {
  static bool enabled = true;

  /// A light tick: small icon buttons, opening and closing things.
  static void light() => _fire(HapticFeedback.lightImpact);

  /// A firm press: the buttons that sink into their shadow, the shutter.
  static void press() => _fire(HapticFeedback.mediumImpact);

  /// A heavy thud: the moment a video starts recording.
  static void heavy() => _fire(HapticFeedback.heavyImpact);

  /// A detent click: switches, tabs, and the style and before/after sliders.
  static void select() => _fire(HapticFeedback.selectionClick);

  static void _fire(Future<void> Function() buzz) {
    if (!enabled) return;
    // A phone without a vibration motor must not turn a tap into an error.
    unawaited(buzz().catchError((Object _) {}));
  }
}
