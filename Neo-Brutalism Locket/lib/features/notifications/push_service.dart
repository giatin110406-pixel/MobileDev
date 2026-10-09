import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';

/// The person tapped a notification: where to take them.
class PushTap {
  const PushTap({required this.type, this.postId, this.fromId});

  /// `new_post`, `message`, `reaction`, `friend_request` or `friend_accepted`.
  final String type;
  final String? postId;

  /// The person who caused it (whose chat to open for a message).
  final String? fromId;
}

const _knownTypes = {
  'new_post',
  'message',
  'reaction',
  'friend_request',
  'friend_accepted',
};

/// Reads the data of a notification (see the `notify` Edge Function). Null when
/// it is not one of ours.
PushTap? parsePushTap(Map<String, dynamic>? data) {
  final type = data?['type'];
  if (type is! String || !_knownTypes.contains(type)) return null;
  String? text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
  return PushTap(
    type: type,
    postId: text(data?['post_id']),
    // `from_id`; older servers sent `from`, which FCM rejects.
    fromId: text(data?['from_id']) ?? text(data?['from']),
  );
}

/// Where the phone's push token is kept on the server.
abstract interface class DeviceRepository {
  Future<void> register(String token, String platform);
  Future<void> unregister(String token);
}

class SupabaseDeviceRepository implements DeviceRepository {
  @override
  Future<void> register(String token, String platform) => Backend.client.rpc(
    'register_device',
    params: {'p_token': token, 'p_platform': platform},
  );

  @override
  Future<void> unregister(String token) =>
      Backend.client.rpc('unregister_device', params: {'p_token': token});
}

/// Push notifications: gets this phone a token, keeps the server told about
/// it, and reports taps on notifications.
abstract interface class PushGateway {
  /// Asks for permission and registers the phone. Never throws: push is
  /// optional, so a problem here just means no notifications.
  Future<void> start();

  /// A notification was tapped (also one that opened the app from closed).
  Stream<PushTap> get taps;

  /// Stops pushes to this phone for the current account (call before signing
  /// out, while the account can still be reached).
  Future<void> stop();
}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway({required this.devices, this.onData});

  final DeviceRepository devices;

  /// Receives the data of every message that arrives while the app is open
  /// (the widget updates come this way).
  final void Function(Map<String, dynamic> data)? onData;
  final _taps = StreamController<PushTap>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _token;
  bool _started = false;

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      // Fails when android/app/google-services.json is missing: no pushes.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      _subscriptions
        ..add(messaging.onTokenRefresh.listen(_register))
        ..add(
          FirebaseMessaging.onMessage.listen(
            (message) => onData?.call(message.data),
          ),
        )
        ..add(
          FirebaseMessaging.onMessageOpenedApp.listen(
            (message) => _emit(message.data),
          ),
        );
      final first = await messaging.getInitialMessage();
      if (first != null) _emit(first.data);
    } catch (error) {
      debugPrint('Push notifications are off: $error');
      _started = false;
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await devices.register(token, 'android');
    } catch (error) {
      debugPrint('Could not register this phone for push: $error');
    }
  }

  void _emit(Map<String, dynamic> data) {
    final tap = parsePushTap(data);
    if (tap != null) _taps.add(tap);
  }

  @override
  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final token = _token;
    _token = null;
    _started = false;
    if (token != null) {
      try {
        await devices.unregister(token);
      } catch (_) {
        // Offline at sign-out: the next account to sign in here takes the
        // token over, and a dead token is cleaned up by the server.
      }
    }
  }
}

/// Settings: which kinds of notification to receive.
class NotificationPrefs {
  const NotificationPrefs({
    this.newPost = true,
    this.messages = true,
    this.reactions = true,
    this.friendRequests = true,
  });

  final bool newPost;
  final bool messages;
  final bool reactions;
  final bool friendRequests;

  NotificationPrefs copyWith({
    bool? newPost,
    bool? messages,
    bool? reactions,
    bool? friendRequests,
  }) => NotificationPrefs(
    newPost: newPost ?? this.newPost,
    messages: messages ?? this.messages,
    reactions: reactions ?? this.reactions,
    friendRequests: friendRequests ?? this.friendRequests,
  );

  factory NotificationPrefs.fromRow(Map<String, dynamic> row) =>
      NotificationPrefs(
        newPost: row['new_post'] as bool? ?? true,
        messages: row['messages'] as bool? ?? true,
        reactions: row['reactions'] as bool? ?? true,
        friendRequests: row['friend_requests'] as bool? ?? true,
      );

  Map<String, Object?> toRow(String userId) => {
    'user_id': userId,
    'new_post': newPost,
    'messages': messages,
    'reactions': reactions,
    'friend_requests': friendRequests,
  };
}

abstract interface class NotificationPrefsRepository {
  /// Everything on when nothing was saved yet.
  Future<NotificationPrefs> load();
  Future<void> save(NotificationPrefs prefs);
}

class SupabaseNotificationPrefsRepository
    implements NotificationPrefsRepository {
  SupabaseNotificationPrefsRepository({required this.userId});

  final String userId;

  @override
  Future<NotificationPrefs> load() async {
    final row = await Backend.client
        .from('notification_prefs')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? const NotificationPrefs()
        : NotificationPrefs.fromRow(row);
  }

  @override
  Future<void> save(NotificationPrefs prefs) async {
    await Backend.client.from('notification_prefs').upsert(prefs.toRow(userId));
  }
}
