import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/auth_screen.dart';
import 'package:neo_brutalism_locket/features/auth/onboarding_screen.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/auth/reset_password_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

enum _Stage { loading, signedOut, onboarding, ready, failed }

/// Shows the sign-in screen until there is an account, then onboarding until
/// the profile is complete, and only then the app ([builder]).
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.profiles,
    required this.builder,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final Widget Function(BuildContext context, AccountSession session) builder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthUser?>? _subscription;
  StreamSubscription<void>? _recoverySubscription;

  /// The person opened a reset-password link: ask for a new password first.
  bool _recovering = false;
  _Stage _stage = _Stage.loading;
  AuthUser? _user;
  Profile? _profile;
  AccountSession? _session;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.changes.listen(_onUser);
    _recoverySubscription = widget.auth.passwordRecovery.listen((_) {
      if (mounted) setState(() => _recovering = true);
    });
    // The stream may not replay the restored user, so look at it now too.
    _onUser(widget.auth.currentUser);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recoverySubscription?.cancel();
    _session?.dispose();
    super.dispose();
  }

  Future<void> _onUser(AuthUser? user) async {
    // Token refreshes re-emit the same user: nothing to do then.
    if (user != null && user.id == _user?.id && _stage != _Stage.failed) return;
    final generation = ++_generation;
    _user = user;
    if (user == null) {
      _session?.dispose();
      _session = null;
      _profile = null;
      if (mounted) setState(() => _stage = _Stage.signedOut);
      return;
    }
    if (mounted) setState(() => _stage = _Stage.loading);
    try {
      final profile = await widget.profiles.loadMine(user.id);
      if (!mounted || generation != _generation) return;
      _profile = profile;
      setState(() {
        _stage = profile.isComplete ? _Stage.ready : _Stage.onboarding;
        if (profile.isComplete) _session = _newSession(user, profile);
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _stage = _Stage.failed);
      }
    }
  }

  AccountSession _newSession(AuthUser user, Profile profile) => AccountSession(
    user: user,
    profile: profile,
    auth: widget.auth,
    profiles: widget.profiles,
  );

  void _onboarded(Profile profile) {
    final user = _user;
    if (user == null) return;
    setState(() {
      _profile = profile;
      _session = _newSession(user, profile);
      _stage = _Stage.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) {
      return ResetPasswordScreen(
        auth: widget.auth,
        onDone: () => setState(() => _recovering = false),
      );
    }
    switch (_stage) {
      case _Stage.loading:
        return const _Splash();
      case _Stage.signedOut:
        return AuthScreen(auth: widget.auth);
      case _Stage.onboarding:
        return OnboardingScreen(
          userId: _user!.id,
          profiles: widget.profiles,
          initialName: _profile?.displayName,
          onDone: _onboarded,
        );
      case _Stage.ready:
        return widget.builder(context, _session!);
      case _Stage.failed:
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          backgroundColor: NeoColors.paper,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.accountLoadFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: NeoColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    NeoButton(
                      label: l10n.retry,
                      icon: Icons.refresh,
                      variant: NeoButtonVariant.accent,
                      onPressed: () => _onUser(_user),
                    ),
                    const SizedBox(height: 12),
                    NeoButton(
                      label: l10n.signOut,
                      variant: NeoButtonVariant.outline,
                      onPressed: widget.auth.signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NeoColors.paper,
    body: Center(
      child: Text(
        AppLocalizations.of(context).loadingAccount,
        style: const TextStyle(
          color: NeoColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}
