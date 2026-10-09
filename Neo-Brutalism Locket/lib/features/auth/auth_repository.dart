import 'dart:async';
import 'dart:io';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}

enum AuthFailureKind {
  invalidCredentials,
  emailTaken,
  weakPassword,
  samePassword,
  invalidEmail,
  network,
  unknown,
}

/// A sign-in or sign-up that did not work. The UI turns [kind] into a message.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, [this.detail]);

  final AuthFailureKind kind;
  final String? detail;

  @override
  String toString() => 'AuthFailure($kind${detail == null ? '' : ': $detail'})';
}

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits on sign-in and sign-out (and once at start with the restored user).
  Stream<AuthUser?> get changes;

  Future<void> signIn({required String email, required String password});

  /// Returns true when the new account is signed in right away, false when the
  /// project requires the email to be confirmed first.
  Future<bool> signUp({required String email, required String password});

  Future<void> sendPasswordReset(String email);

  /// Fires when the person opened a "reset my password" link from their
  /// email. They are signed in by the link; the app must ask for the new
  /// password.
  Stream<void> get passwordRecovery;

  /// Sets a new password for the signed-in person.
  Future<void> updatePassword(String newPassword);

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  sb.GoTrueClient get _auth => Backend.client.auth;

  AuthUser? _user(sb.User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  @override
  AuthUser? get currentUser => _user(_auth.currentUser);

  @override
  Stream<AuthUser?> get changes =>
      _auth.onAuthStateChange.map((state) => _user(state.session?.user));

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _guard(
      () => _auth.signUp(email: email.trim(), password: password),
    );
    return response.session != null;
  }

  /// Where the email's link comes back to (see AndroidManifest). It must also
  /// be listed under Redirect URLs in the Supabase dashboard.
  static const recoveryRedirect = 'neolocket://reset-password';

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () =>
        _auth.resetPasswordForEmail(email.trim(), redirectTo: recoveryRedirect),
  );

  @override
  Stream<void> get passwordRecovery => _auth.onAuthStateChange
      .where((state) => state.event == sb.AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(password: newPassword)));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.AuthException catch (error) {
      throw AuthFailure(_kindOf(error), error.message);
    } on SocketException {
      throw const AuthFailure(AuthFailureKind.network);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  AuthFailureKind _kindOf(sb.AuthException error) {
    if (error is sb.AuthRetryableFetchException) return AuthFailureKind.network;
    return switch (error.code) {
      'invalid_credentials' => AuthFailureKind.invalidCredentials,
      'user_already_exists' || 'email_exists' => AuthFailureKind.emailTaken,
      'weak_password' => AuthFailureKind.weakPassword,
      'same_password' => AuthFailureKind.samePassword,
      'email_address_invalid' ||
      'validation_failed' => AuthFailureKind.invalidEmail,
      _ => AuthFailureKind.unknown,
    };
  }
}
