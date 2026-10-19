import 'package:flutter/foundation.dart';

/// Where swallowed and uncaught errors go. Today it prints (debug console /
/// `adb logcat`) and keeps the last few lines for a bug report; set [reporter]
/// to forward them to a crash service (e.g. Firebase Crashlytics) later.
class AppLog {
  AppLog._();

  /// Called for every warning and uncaught error. Null by default.
  static void Function(String where, Object error, StackTrace? stack)? reporter;

  static final List<String> _recent = [];

  /// The last [_keep] lines, newest last.
  static List<String> get recent => List.unmodifiable(_recent);
  static const _keep = 50;

  /// For failures the app can live with (best-effort cleanup, optional sync):
  /// the person sees nothing, but it is no longer invisible to the developer.
  static void warn(String where, Object error, [StackTrace? stack]) {
    final line = '[$where] $error';
    _recent.add(line);
    if (_recent.length > _keep) _recent.removeAt(0);
    debugPrint('AppLog: $line');
    reporter?.call(where, error, stack);
  }

  /// Routes Flutter framework errors and uncaught async errors here.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      warn('flutter', details.exception, details.stack);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      warn('uncaught', error, stack);
      return true;
    };
  }
}
