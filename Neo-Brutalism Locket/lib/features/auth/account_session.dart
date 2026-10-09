import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';

/// The signed-in person: who they are, and what they can do to the account.
/// Created by the auth gate once sign-in and onboarding are done.
class AccountSession extends ChangeNotifier {
  AccountSession({
    required this.user,
    required Profile profile,
    required AuthRepository auth,
    required ProfileRepository profiles,
  }) : _profile = profile,
       _auth = auth,
       _profiles = profiles;

  final AuthUser user;
  final AuthRepository _auth;
  final ProfileRepository _profiles;
  Profile _profile;

  Profile get profile => _profile;

  /// Runs before signing out, while the account can still be reached (the
  /// app uses it to stop push notifications to this phone).
  Future<void> Function()? beforeSignOut;

  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {
      // Never let this stop the person from signing out.
    }
    await _auth.signOut();
  }

  /// Changes the display name and username (throws [UsernameTaken]).
  Future<void> updateIdentity({
    required String displayName,
    required String username,
  }) async {
    _profile = await _profiles.saveIdentity(
      userId: user.id,
      username: username,
      displayName: displayName,
    );
    notifyListeners();
  }

  Future<void> setAllowRequests(bool allow) async {
    _profile = await _profiles.setAllowRequests(user.id, allow);
    notifyListeners();
  }

  /// Best effort: the language also lives on the phone, so a failure here is
  /// not shown to the person.
  Future<void> rememberLocale(String code) async {
    try {
      await _profiles.setLocale(user.id, code);
    } catch (_) {}
  }

  Future<void> changePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  /// Deletes the account and everything in it, then signs out.
  Future<void> deleteAccount() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
    await _profiles.deleteAccount(user.id);
    try {
      await _auth.signOut();
    } catch (_) {
      // The account is gone, so the server may refuse; the gate still moves
      // to the sign-in screen once the local session is cleared.
    }
  }

  /// Uploads a new avatar. Failure is reported to the caller; the local
  /// avatar keeps working either way.
  Future<void> uploadAvatar(Uint8List jpeg) async {
    _profile = await _profiles.uploadAvatar(user.id, jpeg);
    notifyListeners();
  }
}
