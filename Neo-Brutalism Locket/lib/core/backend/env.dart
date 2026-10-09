/// Build-time configuration, passed with
/// `flutter run --dart-define-from-file=env/dev.json` (see env/dev.json.example).
/// Nothing secret lives here: the publishable key is public by design; access is
/// enforced by row-level security on the server.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Google Sign-In "Web client ID" (used as the server client id on Android).
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
