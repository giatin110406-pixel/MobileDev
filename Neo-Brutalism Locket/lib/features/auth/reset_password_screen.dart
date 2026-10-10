import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/auth_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Choose a new password: after the "reset my password" email link, or from
/// the settings. Calls [onDone] once it is saved.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.auth,
    required this.onDone,
    this.onCancel,
  });

  final AuthRepository auth;
  final VoidCallback onDone;

  /// Shows a back button when set (opened from the settings).
  final VoidCallback? onCancel;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    if (_password.text.length < 8) {
      setState(() => _error = l10n.errPasswordShort);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.passwordsDiffer);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.updatePassword(_password.text);
      if (!mounted) return;
      showNeoSnack(context, l10n.passwordChanged);
      widget.onDone();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onCancel != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: NeoIconButton(
                        icon: Icons.arrow_back,
                        tooltip: l10n.cancel,
                        fill: NeoColors.yellow,
                        onPressed: widget.onCancel,
                      ),
                    ),
                  if (widget.onCancel != null) const SizedBox(height: 20),
                  Text(
                    l10n.resetPasswordTitle,
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
                    l10n.resetPasswordSubtitle,
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),
                  NeoField(
                    label: l10n.newPasswordLabel,
                    controller: _password,
                    obscure: true,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  NeoField(
                    label: l10n.confirmPasswordLabel,
                    controller: _confirm,
                    obscure: true,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    enabled: !_busy,
                  ),
                  if (_error != null) FieldMessage(_error!),
                  const SizedBox(height: 22),
                  NeoButton(
                    expand: true,
                    label: l10n.savePassword,
                    icon: _busy ? Icons.hourglass_top : Icons.check,
                    variant: NeoButtonVariant.primary,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
