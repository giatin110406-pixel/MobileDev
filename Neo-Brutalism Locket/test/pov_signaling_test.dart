import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neo_brutalism_locket/features/pov/pov_connection.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_signaling.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _Signal implements PovSignalChannel {
  final incoming = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get messages => incoming.stream;
  @override
  Future<void> get ready => Future.value();
  @override
  Future<void> send(Map<String, dynamic> message) async => sent.add(message);
  @override
  Future<void> close() => incoming.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in ['offer', 'answer']) {
    test('Supabase broadcast preserves the WebRTC $type description', () async {
      Map<String, dynamic>? delivered;
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final wirePayload = Map<String, dynamic>.from(
          (body['messages'] as List).single['payload'] as Map,
        );
        // The installed SDK reserves and overwrites these outer fields.
        expect(wirePayload['type'], 'broadcast');
        expect(wirePayload['event'], 'signal');
        delivered = decodePovSignal(wirePayload);
        return http.Response('{}', 200);
      });
      final client = sb.RealtimeClient(
        'wss://pov-test.invalid/realtime/v1',
        httpClient: transport,
      );
      final channel = client.channel('pov:test');
      final description = {'t': type, 'type': type, 'sdp': 'v=0\r\n'};
      final result = await channel.sendBroadcastMessage(
        event: 'signal',
        payload: encodePovSignal(description),
      );
      expect(result, sb.ChannelResponse.ok);
      expect(delivered, description);
      expect(description['type'], type);
      transport.close();
    });
  }

  test(
    'decodes both websocket and REST envelopes, ignoring unrelated events',
    () {
      final ice = {
        't': 'ice',
        'c': {'candidate': 'candidate:test'},
      };
      expect(decodePovSignal(ice), ice);
      expect(decodePovSignal({'payload': ice}), ice);
      expect(
        decodePovSignal({
          'payload': {'payload': ice},
        }),
        ice,
      );
      expect(decodePovSignal({'type': 'broadcast', 'event': 'other'}), isNull);
    },
  );

  test(
    'viewer answers a live video offer even from an older broadcast client',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const native = MethodChannel('FlutterWebRTC.Method');
      const events = MethodChannel('FlutterWebRTC/peerConnectionEventpov-test');
      final descriptions = <Map<String, dynamic>>[];
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(native, (call) async {
        switch (call.method) {
          case 'initialize':
          case 'peerConnectionClose':
          case 'setLocalDescription':
            return null;
          case 'createPeerConnection':
            return {'peerConnectionId': 'pov-test'};
          case 'setRemoteDescription':
            descriptions.add(
              Map<String, dynamic>.from(call.arguments['description'] as Map),
            );
            return null;
          case 'createAnswer':
            return {'type': 'answer', 'sdp': 'v=0\r\n'};
          default:
            fail('Unexpected WebRTC call: ${call.method}');
        }
      });
      final signal = _Signal();
      final viewer = PovViewerConnection(signal: signal, ice: PovIce.stunOnly);
      try {
        await viewer.start();
        signal.incoming.add({
          't': 'offer',
          'type': 'broadcast',
          'sdp': 'v=0\r\n',
        });
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(descriptions.single['type'], 'offer');
        expect(signal.sent, contains(containsPair('t', 'answer')));
        // A photo notification is never needed to negotiate the live video.
        expect(signal.sent.any((m) => m['t'] == 'shot'), isFalse);
      } finally {
        await viewer.close(sayBye: false);
        messenger.setMockMethodCallHandler(native, null);
        messenger.setMockMethodCallHandler(events, null);
      }
    },
  );
}
