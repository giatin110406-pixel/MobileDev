import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_screen.dart';
import 'package:neo_brutalism_locket/main.dart' show NeoLocketApp;

/// The Dart entry point of RewindLockscreenActivity (the quick-settings tile).
/// It shows the rewind screen and nothing else: no Supabase, no sign-in, no
/// friends or feed, so nobody holding a locked phone can see any of them. Only
/// the language setting is read, so the words match the app.
@pragma('vm:entry-point')
Future<void> rewindLockscreenMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(
    NeoLocketApp(
      settings: settings,
      home: const RewindScreen(lockscreen: true),
    ),
  );
}
