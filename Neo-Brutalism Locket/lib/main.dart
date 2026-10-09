import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/auth_gate.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/widget/widget_background.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  // A friend's new photo refreshes the home-screen widget even when the app
  // is closed (needs Firebase; does nothing without it).
  if (Backend.isReady) await registerWidgetBackgroundUpdates();
  final settings = AppSettings();
  await settings.load();
  runApp(
    NeoLocketApp(
      settings: settings,
      // Without a configured backend the app works on this device only.
      home: Backend.isReady
          ? AuthGate(
              auth: SupabaseAuthRepository(),
              profiles: SupabaseProfileRepository(),
              builder: (context, session) =>
                  AppShell(session: session, settings: settings),
            )
          : const AppShell(),
    ),
  );
}

class NeoLocketApp extends StatelessWidget {
  const NeoLocketApp({super.key, required this.settings, required this.home});

  final AppSettings settings;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: NeoTheme.data,
        locale: settings.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }
}
