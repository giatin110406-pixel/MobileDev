import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/core/backend/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase connection. Without a configured backend the app keeps
/// working on this device only (everything before accounts existed).
abstract final class Backend {
  static bool _ready = false;

  /// True once Supabase is initialised for this run.
  static bool get isReady => _ready;

  static SupabaseClient get client {
    assert(_ready, 'Backend.init() did not run or no backend is configured');
    return Supabase.instance.client;
  }

  /// Call once before runApp. Safe to call without configuration.
  static Future<void> init() async {
    if (_ready || !Env.hasBackend) return;
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
      );
      _ready = true;
    } catch (error) {
      // A bad URL or no network must not stop the camera from opening.
      debugPrint('Supabase init failed: $error');
    }
  }
}
