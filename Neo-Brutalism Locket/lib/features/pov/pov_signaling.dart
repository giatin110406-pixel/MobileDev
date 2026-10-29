/// Supabase reserves the outer `type` and `event` keys for its broadcast
/// envelope. Keep all WebRTC fields inside `payload`, including SDP `type`.
Map<String, dynamic> encodePovSignal(Map<String, dynamic> message) => {
  'payload': Map<String, dynamic>.from(message),
};

/// Accept both the broadcast envelope and an already unwrapped message.
/// REST fallback can add another envelope around the same message.
Map<String, dynamic>? decodePovSignal(Map<String, dynamic> envelope) {
  Map<String, dynamic> message = envelope;
  for (var depth = 0; depth < 4; depth++) {
    if (message['t'] is String) return Map<String, dynamic>.from(message);
    final payload = message['payload'];
    if (payload is! Map) return null;
    message = Map<String, dynamic>.from(payload);
  }
  return null;
}
