import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A labelled neo-brutalist text field.
class NeoField extends StatelessWidget {
  const NeoField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.prefix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
    this.enabled = true,
    this.autocorrect = true,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final bool enabled;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: NeoColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: NeoTheme.panel(color: NeoColors.surface),
        child: TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: autocorrect,
          textInputAction: textInputAction,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: '',
            prefixText: prefix,
            prefixStyle: const TextStyle(
              color: NeoColors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );
}

/// A small message under a field or button; [good] turns it teal-ish.
class FieldMessage extends StatelessWidget {
  const FieldMessage(this.text, {super.key, this.good = false});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(
        color: good ? const Color(0xFF1B7F79) : const Color(0xFFC0392B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String authFailureText(AppLocalizations l10n, AuthFailure failure) =>
    switch (failure.kind) {
      AuthFailureKind.invalidCredentials => l10n.errInvalidCredentials,
      AuthFailureKind.emailTaken => l10n.errEmailTaken,
      AuthFailureKind.weakPassword => l10n.errWeakPassword,
      AuthFailureKind.samePassword => l10n.errSamePassword,
      AuthFailureKind.invalidEmail => l10n.errInvalidEmail,
      AuthFailureKind.network => l10n.errNetwork,
      AuthFailureKind.unknown => l10n.errUnknown,
    };

String usernameProblemText(AppLocalizations l10n, UsernameProblem problem) =>
    switch (problem) {
      UsernameProblem.tooShort => l10n.usernameTooShort,
      UsernameProblem.tooLong => l10n.usernameTooLong,
      UsernameProblem.badCharacters => l10n.usernameBadCharacters,
    };
