import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/auth_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// Sign in or create an account with email + password.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
    _signUp = !_signUp;
    _error = null;
    _info = null;
  });

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = l10n.errInvalidEmail);
      return;
    }
    if (_signUp && password.length < 8) {
      setState(() => _error = l10n.errPasswordShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_signUp) {
        final signedIn = await widget.auth.signUp(
          email: email,
          password: password,
        );
        if (!signedIn && mounted) {
          setState(() {
            _signUp = false;
            _info = l10n.confirmEmailSent;
          });
        }
      } else {
        await widget.auth.signIn(email: email, password: password);
      }
      // On success the auth gate moves on by itself.
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = authFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = l10n.resetNeedsEmail;
        _info = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.auth.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _info = l10n.resetSent;
          _error = null;
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = authFailureText(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: NeoTheme.panel(
                          color: NeoColors.pink,
                          radius: 12,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: NeoColors.ink,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _signUp ? l10n.signUpTitle : l10n.signInTitle,
                      style: const TextStyle(
                        fontFamily: NeoFont.display,
                        color: NeoColors.ink,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authTagline,
                      style: const TextStyle(
                        color: NeoColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 26),
                    NeoField(
                      label: l10n.emailLabel,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    NeoField(
                      label: l10n.passwordLabel,
                      controller: _password,
                      obscure: true,
                      autofillHints: [
                        _signUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      autocorrect: false,
                      enabled: !_busy,
                    ),
                    if (_error != null) FieldMessage(_error!),
                    if (_info != null) FieldMessage(_info!, good: true),
                    const SizedBox(height: 22),
                    NeoButton(
                      expand: true,
                      label: _signUp ? l10n.signUpButton : l10n.signInButton,
                      icon: _busy ? Icons.hourglass_top : Icons.arrow_forward,
                      variant: NeoButtonVariant.primary,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: Haptics.tap(_busy ? null : _toggle),
                          child: Text(
                            _signUp ? l10n.switchToSignIn : l10n.switchToSignUp,
                            style: const TextStyle(
                              color: NeoColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!_signUp)
                          TextButton(
                            onPressed: Haptics.tap(_busy ? null : _forgot),
                            child: Text(
                              l10n.forgotPassword,
                              style: const TextStyle(
                                color: NeoColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
