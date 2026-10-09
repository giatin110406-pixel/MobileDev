import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/widget/widget_updater.dart';

/// Runs when a push arrives while the app is closed or in the background.
/// Notifications are shown by the system by themselves; this only picks up the
/// silent "a friend posted" message and refreshes the home-screen widget.
@pragma('vm:entry-point')
Future<void> widgetBackgroundHandler(RemoteMessage message) async {
  try {
    await WidgetUpdater().applyData(message.data);
  } catch (error) {
    debugPrint('Widget update failed: $error');
  }
}

/// Call once at start-up. Safe without Firebase set up (then nothing happens).
Future<void> registerWidgetBackgroundUpdates() async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(widgetBackgroundHandler);
  } catch (error) {
    debugPrint('Background widget updates are off: $error');
  }
}
