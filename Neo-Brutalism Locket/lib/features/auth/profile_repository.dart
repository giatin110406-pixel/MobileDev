import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// 3-20 characters: lower-case letters, digits, dot and underscore.
final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

enum UsernameProblem { tooShort, tooLong, badCharacters }

/// Lower-cases and trims [raw], as it will be stored.
String normalizeUsername(String raw) =>
    raw.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

/// Null when [username] (already normalised) is acceptable.
UsernameProblem? checkUsername(String username) {
  if (_usernamePattern.hasMatch(username)) return null;
  if (username.length < 3) return UsernameProblem.tooShort;
  if (username.length > 20) return UsernameProblem.tooLong;
  return UsernameProblem.badCharacters;
}

class Profile {
  const Profile({
    required this.id,
    this.username,
    this.displayName,
    this.avatarPath,
    this.frameId,
    this.bannerId,
    this.allowRequests = true,
  });

  final String id;

  /// Whether other people may send this person friend requests.
  final bool allowRequests;
  final String? username;
  final String? displayName;

  /// Storage path in the `avatars` bucket, e.g. `<uid>/avatar.jpg`.
  final String? avatarPath;
  final String? frameId;
  final String? bannerId;

  /// Onboarding is done once the person picked a username.
  bool get isComplete => username != null && displayName != null;

  Profile copyWith({
    String? avatarPath,
    String? username,
    String? displayName,
    bool? allowRequests,
  }) => Profile(
    id: id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarPath: avatarPath ?? this.avatarPath,
    frameId: frameId,
    bannerId: bannerId,
    allowRequests: allowRequests ?? this.allowRequests,
  );

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    username: row['username'] as String?,
    displayName: row['display_name'] as String?,
    avatarPath: row['avatar_path'] as String?,
    frameId: row['frame_id'] as String?,
    bannerId: row['banner_id'] as String?,
    allowRequests: row['allow_requests'] as bool? ?? true,
  );
}

class UsernameTaken implements Exception {
  const UsernameTaken();
}

abstract interface class ProfileRepository {
  Future<Profile> loadMine(String userId);

  /// True when nobody uses [username] (already normalised and valid).
  Future<bool> isUsernameAvailable(String username);

  /// Throws [UsernameTaken] when someone else got it first.
  Future<Profile> saveIdentity({
    required String userId,
    required String username,
    required String displayName,
  });

  /// Uploads [jpeg] as the avatar and records its path on the profile.
  Future<Profile> uploadAvatar(String userId, Uint8List jpeg);

  Future<Profile> setAllowRequests(String userId, bool allow);

  /// Remembers the chosen language (`vi` or `en`) on the account.
  Future<void> setLocale(String userId, String code);

  /// Removes the account for good: the picture files first, then the account
  /// and everything that belongs to it.
  Future<void> deleteAccount(String userId);
}

class SupabaseProfileRepository implements ProfileRepository {
  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<Profile> loadMine(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).single();
    return Profile.fromRow(row);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final rows = await _db
        .from('profiles')
        .select('id')
        .eq('username', username)
        .limit(1);
    return rows.isEmpty;
  }

  @override
  Future<Profile> saveIdentity({
    required String userId,
    required String username,
    required String displayName,
  }) async {
    try {
      final row = await _db
          .from('profiles')
          .update({'username': username, 'display_name': displayName.trim()})
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromRow(row);
    } on sb.PostgrestException catch (error) {
      if (error.code == '23505') throw const UsernameTaken();
      rethrow;
    }
  }

  @override
  Future<Profile> uploadAvatar(String userId, Uint8List jpeg) async {
    final path = '$userId/avatar.jpg';
    await _db.storage
        .from('avatars')
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const sb.FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final row = await _db
        .from('profiles')
        .update({'avatar_path': path})
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromRow(row);
  }

  @override
  Future<Profile> setAllowRequests(String userId, bool allow) async {
    final row = await _db
        .from('profiles')
        .update({'allow_requests': allow})
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromRow(row);
  }

  @override
  Future<void> setLocale(String userId, String code) async {
    await _db.from('profiles').update({'locale': code}).eq('id', userId);
  }

  @override
  Future<void> deleteAccount(String userId) async {
    // Deleting rows would leave the files behind, so remove them through the
    // storage API first. A leftover file is harmless; a failure here must not
    // stop the account from being deleted.
    for (final bucket in ['media', 'avatars']) {
      try {
        final storage = _db.storage.from(bucket);
        final files = await storage.list(path: userId);
        if (files.isNotEmpty) {
          await storage.remove([for (final f in files) '$userId/${f.name}']);
        }
      } catch (_) {}
    }
    await _db.rpc('delete_my_account');
  }
}
