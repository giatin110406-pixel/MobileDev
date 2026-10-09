import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choices that belong to the phone, not the account: for now the language.
class AppSettings extends ChangeNotifier {
  AppSettings();

  static const _localeKey = 'app_locale';

  /// The languages the app speaks.
  static const supported = [Locale('vi'), Locale('en')];

  Locale? _locale;

  /// The chosen language, or null to follow the phone.
  Locale? get locale => _locale;

  /// Reads what was saved last time.
  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _locale = parseLocale(preferences.getString(_localeKey));
    } catch (_) {
      _locale = null;
    }
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

  /// `vi` / `en` → a [Locale]; anything else → null (follow the phone).
  static Locale? parseLocale(String? code) {
    for (final locale in supported) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }
}
