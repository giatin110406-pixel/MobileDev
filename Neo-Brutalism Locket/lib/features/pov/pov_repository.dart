import 'dart:async';
import 'dart:convert';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Omni POV: a friend (the viewer, A) watches what my camera (the host, B) sees, live,
/// to fix their pose; only B takes the photos. A shows a QR code, B scans it with the
/// camera of the app and confirms. The picture goes straight from phone to phone; this
/// file is the server side of it: the codes, who joined whom, and the set-up messages.
/// See omni-pov-plan.md and supabase/migrations/20261030000001_pov_qr.sql.
///
/// `pending` is a code on A's screen that nobody has scanned yet.
enum PovStatus { pending, accepted, cancelled, expired, ended }

PovStatus povStatusOf(Object? value) => switch (value) {
  'pending' => PovStatus.pending,
  'accepted' => PovStatus.accepted,
  'cancelled' => PovStatus.cancelled,
  'expired' => PovStatus.expired,
  // 'ended', and anything a newer server might say: over.
  _ => PovStatus.ended,
};

/// The link in the QR code, and what reads it. `neolocket://pov/<code>`: the phone's
/// own camera app can open it too (the app has an intent filter for it).
const povLinkHost = 'pov';

String povLinkFor(String code) => 'neolocket://pov/$code';

final _povCode = RegExp(r'^[0-9a-zA-Z]{32}$');

/// The code in [uri], or null when it is not an Omni POV link.
String? povCodeFromLink(Uri uri) {
  if (uri.scheme != 'neolocket' || uri.host != povLinkHost) return null;
  if (uri.pathSegments.length != 1) return null;
  final code = uri.pathSegments.single;
  return _povCode.hasMatch(code) ? code : null;
}

/// The code in the text a QR code held, or null when it is something else.
String? povCodeFromText(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri == null ? null : povCodeFromLink(uri);
}

/// One request to watch someone's camera, and what became of it.
class PovSession {
  const PovSession({
    required this.id,
    required this.viewerId,
    this.hostId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.shots = 0,
  });

  final String id;

  /// A: the person being photographed, who watches.
  final String viewerId;

  /// B: the person taking the photos, whose camera is watched. Null until B scans.
  final String? hostId;
  final PovStatus status;
  final DateTime createdAt;

  /// When a code nobody scanned runs out.
  final DateTime expiresAt;

  /// Photos B has taken in this session.
  final int shots;

  bool get isOver =>
      status != PovStatus.pending && status != PovStatus.accepted;

  /// A code still waiting to be scanned at [now].
  bool isWaiting(DateTime now) =>
      status == PovStatus.pending && expiresAt.isAfter(now);

  PovSession copyWith({PovStatus? status, int? shots}) => PovSession(
    id: id,
    viewerId: viewerId,
    hostId: hostId,
    status: status ?? this.status,
    createdAt: createdAt,
    expiresAt: expiresAt,
    shots: shots ?? this.shots,
  );

  factory PovSession.fromRow(Map<String, dynamic> row) => PovSession(
    id: row['id'] as String,
    viewerId: row['viewer_id'] as String,
    hostId: row['host_id'] as String?,
    status: povStatusOf(row['status']),
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    shots: (row['shots'] as num?)?.toInt() ?? 0,
  );
}

enum PovFailureKind {
  /// The code is a stranger's (or someone who blocked me, or I blocked).
  notFriends,

  /// Me or them is in a session already.
  busy,

  /// 30 codes an hour.
  tooMany,

  /// No such code (any more): used, closed or never made.
  notFound,

  /// The code ran out.
  expired,

  /// It is my own code.
  self,
  network,
  unknown,
}

class PovFailure implements Exception {
  const PovFailure(this.kind);

  final PovFailureKind kind;

  @override
  String toString() => 'PovFailure($kind)';
}

/// A code A has just opened: shown as a QR code until [expiresAt].
class PovCode {
  const PovCode({
    required this.sessionId,
    required this.code,
    required this.expiresAt,
  });

  final String sessionId;
  final String code;
  final DateTime expiresAt;

  factory PovCode.fromJson(Map<String, dynamic> json) => PovCode(
    sessionId: json['session_id'] as String,
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
  );
}

/// Whose code B has scanned, before B says yes.
class PovPeek {
  const PovPeek({
    required this.sessionId,
    required this.viewerId,
    required this.displayName,
    this.avatarPath,
  });

  final String sessionId;
  final String viewerId;
  final String displayName;
  final String? avatarPath;

  factory PovPeek.fromJson(Map<String, dynamic> json) => PovPeek(
    sessionId: json['session_id'] as String,
    viewerId: json['viewer_id'] as String,
    displayName: (json['display_name'] as String?) ?? '',
    avatarPath: json['avatar_path'] as String?,
  );
}

/// The STUN and relay servers the two phones use to find each other.
class PovIce {
  const PovIce({required this.servers, required this.hasRelay});

  /// In the shape `RTCConfiguration.iceServers` takes.
  final List<Map<String, dynamic>> servers;

  /// Whether a relay (TURN) is among them: without one, two phones on mobile data
  /// may not be able to connect.
  final bool hasRelay;

  /// Google's STUN alone: what is used when the function cannot be reached.
  static const stunOnly = PovIce(
    servers: [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    hasRelay: false,
  );

  factory PovIce.fromJson(Map<String, dynamic> json) {
    final raw = json['ice_servers'];
    final servers = [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
    if (servers.isEmpty) return stunOnly;
    return PovIce(servers: servers, hasRelay: json['turn'] == true);
  }
}

/// The private channel of one session, for the messages that set up the connection
/// (offer, answer, candidates). Only the two people of an accepted session can use it.
abstract interface class PovSignalChannel {
  /// Messages from the other phone.
  Stream<Map<String, dynamic>> get messages;

  /// Completes once the channel is joined; throws when it cannot be.
  Future<void> get ready;

  Future<void> send(Map<String, dynamic> message);

  Future<void> close();
}

abstract interface class PovRepository {
  /// A opens a code (any code A had open is closed).
  Future<PovCode> createCode();

  /// B scanned [code]: whose is it? Joins nothing.
  Future<PovPeek> peek(String code);

  /// B said yes: A watches B's camera from now on. Returns the session.
  Future<PovSession> join(String code);

  /// A closes the code.
  Future<void> cancel(String sessionId);

  /// Either of them stops the session.
  Future<void> end(String sessionId);

  /// B has taken a photo.
  Future<void> reportShot(String sessionId);

  /// My sessions that are not over, newest first.
  Future<List<PovSession>> loadLive();

  /// Every change to one of my sessions (a request for me, an answer, the end).
  Stream<PovSession> get changes;

  /// The servers for the connection (never throws: falls back to STUN).
  Future<PovIce> iceServers();

  PovSignalChannel openSignal(String sessionId);

  void dispose();
}

class SupabasePovRepository implements PovRepository {
  SupabasePovRepository({required this.myId});

  final String myId;
  final _changes = StreamController<PovSession>.broadcast();
  sb.RealtimeChannel? _channel;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Stream<PovSession> get changes {
    if (_channel == null) {
      var channel = _db.channel('pov-$myId');
      // One listener cannot filter on two columns: one for each role, for new
      // requests and for changes.
      for (final column in const ['viewer_id', 'host_id']) {
        for (final event in const [
          sb.PostgresChangeEvent.insert,
          sb.PostgresChangeEvent.update,
        ]) {
          channel = channel.onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'pov_sessions',
            filter: sb.PostgresChangeFilter(
              type: sb.PostgresChangeFilterType.eq,
              column: column,
              value: myId,
            ),
            callback: (payload) {
              try {
                _changes.add(PovSession.fromRow(payload.newRecord));
              } catch (_) {
                // A row this version does not understand: ignore it.
              }
            },
          );
        }
      }
      _channel = channel.subscribe();
    }
    return _changes.stream;
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _changes.close();
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const PovFailure(PovFailureKind.unknown);
  }

  @override
  Future<PovCode> createCode() => _guard(() async {
    final data = await _db.rpc('create_pov_code');
    return PovCode.fromJson(_asMap(data));
  });

  @override
  Future<PovPeek> peek(String code) => _guard(() async {
    final data = await _db.rpc('peek_pov_code', params: {'p_code': code});
    return PovPeek.fromJson(_asMap(data));
  });

  @override
  Future<PovSession> join(String code) => _guard(() async {
    final data = _asMap(await _db.rpc('join_pov', params: {'p_code': code}));
    final now = DateTime.now();
    return PovSession(
      id: data['session_id'] as String,
      viewerId: data['viewer_id'] as String,
      hostId: _db.auth.currentUser?.id,
      status: PovStatus.accepted,
      createdAt: now,
      expiresAt: now,
    );
  });

  @override
  Future<void> cancel(String sessionId) =>
      _guard(() => _db.rpc('cancel_pov', params: {'p_session': sessionId}));

  @override
  Future<void> end(String sessionId) =>
      _guard(() => _db.rpc('end_pov', params: {'p_session': sessionId}));

  @override
  Future<void> reportShot(String sessionId) =>
      _guard(() => _db.rpc('pov_shot', params: {'p_session': sessionId}));

  @override
  Future<List<PovSession>> loadLive() => _guard(() async {
    final rows = await _db
        .from('pov_sessions')
        .select()
        .inFilter('status', ['pending', 'accepted'])
        .order('created_at', ascending: false);
    return [for (final row in rows) PovSession.fromRow(row)];
  });

  @override
  Future<PovIce> iceServers() async {
    try {
      final response = await _db.functions.invoke('pov-ice', body: const {});
      final data = response.data;
      if (data is Map<String, dynamic>) return PovIce.fromJson(data);
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return PovIce.fromJson(decoded);
      }
    } catch (_) {
      // No relay then: two phones on the same Wi-Fi still connect.
    }
    return PovIce.stunOnly;
  }

  @override
  PovSignalChannel openSignal(String sessionId) =>
      _SupabaseSignal(_db, sessionId);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PovFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw PovFailure(switch (error.message) {
        'not_friends' => PovFailureKind.notFriends,
        'busy' => PovFailureKind.busy,
        'too_many' => PovFailureKind.tooMany,
        'not_found' => PovFailureKind.notFound,
        'expired' => PovFailureKind.expired,
        'self' => PovFailureKind.self,
        _ => PovFailureKind.unknown,
      });
    } catch (_) {
      throw const PovFailure(PovFailureKind.network);
    }
  }
}

class _SupabaseSignal implements PovSignalChannel {
  _SupabaseSignal(sb.SupabaseClient db, String sessionId) : _db = db {
    final channel = db.channel(
      'pov:$sessionId',
      opts: const sb.RealtimeChannelConfig(private: true),
    );
    _channel = channel;
    channel
        .onBroadcast(
          event: 'signal',
          callback: (payload) {
            // The payload sits in `payload` on some versions of the client.
            final inner = payload['payload'];
            _messages.add(
              inner is Map ? Map<String, dynamic>.from(inner) : payload,
            );
          },
        )
        .subscribe((status, error) {
          if (_ready.isCompleted) return;
          if (status == sb.RealtimeSubscribeStatus.subscribed) {
            _ready.complete();
          } else if (status == sb.RealtimeSubscribeStatus.channelError ||
              status == sb.RealtimeSubscribeStatus.timedOut) {
            _ready.completeError(error ?? status);
          }
        });
  }

  final sb.SupabaseClient _db;
  late final sb.RealtimeChannel _channel;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _ready = Completer<void>();

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    await _channel.sendBroadcastMessage(event: 'signal', payload: message);
  }

  @override
  Future<void> close() async {
    await _db.removeChannel(_channel);
    await _messages.close();
  }
}
