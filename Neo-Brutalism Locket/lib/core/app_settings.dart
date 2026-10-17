import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:neo_brutalism_locket/core/print_sound.dart';
import 'package:neo_brutalism_locket/features/camera/print_post_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choices that belong to the phone, not the account: the language and
/// whether buttons buzz.
class AppSettings extends ChangeNotifier {
  AppSettings();

  static const _localeKey = 'app_locale';
  static const _hapticsKey = 'haptics_enabled';
  static const _directKey = 'haptics_direct';
  static const _printEffectKey = 'print_effect';
  static const _printSoundKey = 'print_sound';

  /// The languages the app speaks.
  static const supported = [Locale('vi'), Locale('en')];

  Locale? _locale;
  bool _haptics = true;
  bool _direct = false;
  bool _printEffect = true;
  bool _printSound = true;

  /// The chosen language, or null to follow the phone.
  Locale? get locale => _locale;

  /// Whether buttons, tabs and the shutter give a little buzz.
  bool get hapticsEnabled => _haptics;

  /// Drive the vibration motor directly, whatever the phone's own
  /// "touch vibration" setting says.
  bool get hapticsDirect => _direct;

  /// Whether posting plays the stamp-and-print animation.
  bool get printEffectEnabled => _printEffect;

  /// Whether the print animation makes its printer and stamp sounds.
  bool get printSoundEnabled => _printSound;

  /// Reads what was saved last time.
  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _locale = parseLocale(preferences.getString(_localeKey));
      _haptics = preferences.getBool(_hapticsKey) ?? true;
      _direct = preferences.getBool(_directKey) ?? false;
      _printEffect = preferences.getBool(_printEffectKey) ?? true;
      _printSound = preferences.getBool(_printSoundKey) ?? true;
    } catch (_) {
      _locale = null;
      _haptics = true;
      _direct = false;
      _printEffect = true;
      _printSound = true;
    }
    PrintEffect.enabled = _printEffect;
    PrintSound.enabled = _printSound;
    Haptics.enabled = _haptics;
    Haptics.direct = _direct;
    notifyListeners();
  }

  /// null = follow the phone.
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (locale == null) {
        await preferences.remove(_localeKey);
      } else {
        await preferences.setString(_localeKey, locale.languageCode);
      }
    } catch (_) {
      // The choice still applies until the app closes.
    }
  }

  Future<void> setHaptics(bool enabled) async {
    _haptics = enabled;
    Haptics.enabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_hapticsKey, enabled);
    } catch (_) {
      // The choice still applies until the app closes.
    }
  }

  Future<void> setPrintEffect(bool enabled) async {
    _printEffect = enabled;
    PrintEffect.enabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_printEffectKey, enabled);
    } catch (_) {
      // The choice still applies until the app closes.
    }
  }

  Future<void> setPrintSound(bool enabled) async {
    _printSound = enabled;
    PrintSound.enabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_printSoundKey, enabled);
    } catch (_) {
      // The choice still applies until the app closes.
    }
  }

  Future<void> setHapticsDirect(bool direct) async {
    _direct = direct;
    Haptics.direct = direct;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_directKey, direct);
    } catch (_) {
      // The choice still applies until the app closes.
    }
  }

  /// `vi` / `en` → a [Locale]; anything else → null (follow the phone).
  static Locale? parseLocale(String? code) {
    for (final locale in supported) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }
}
