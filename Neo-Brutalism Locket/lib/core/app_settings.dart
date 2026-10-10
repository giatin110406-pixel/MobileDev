import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choices that belong to the phone, not the account: the language and
/// whether buttons buzz.
class AppSettings extends ChangeNotifier {
  AppSettings();

  static const _localeKey = 'app_locale';
  static const _hapticsKey = 'haptics_enabled';

  /// The languages the app speaks.
  static const supported = [Locale('vi'), Locale('en')];

  Locale? _locale;
  bool _haptics = true;

  /// The chosen language, or null to follow the phone.
  Locale? get locale => _locale;

  /// Whether buttons, tabs and the shutter give a little buzz.
  bool get hapticsEnabled => _haptics;

  /// Reads what was saved last time.
  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _locale = parseLocale(preferences.getString(_localeKey));
      _haptics = preferences.getBool(_hapticsKey) ?? true;
    } catch (_) {
      _locale = null;
      _haptics = true;
    }
    Haptics.enabled = _haptics;
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

  /// `vi` / `en` → a [Locale]; anything else → null (follow the phone).
  static Locale? parseLocale(String? code) {
    for (final locale in supported) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }
}
