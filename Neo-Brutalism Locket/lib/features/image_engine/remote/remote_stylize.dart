import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_client.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';

/// Outcome of one attempt to use the laptop server: either an image or a
/// human-readable reason why it could not be used.
class RemoteAttempt {
  const RemoteAttempt.success(Uint8List this.png) : reason = null;
  const RemoteAttempt.failure(String this.reason) : png = null;

  final Uint8List? png;
  final String? reason;
}

Future<RemoteAttempt> tryRemoteStylize(
  Uint8List bytes, {
  required String style,
  StylizeServerConfigStore store = const StylizeServerConfigStore(),
  http.Client? httpClient,
  Duration pollInterval = const Duration(seconds: 1),
  StyleProgress? onProgress,
}) async {
  try {
    final config = await store.load();
    if (!config.isConfigured) {
      return const RemoteAttempt.failure('laptop:notSetUp');
    }
    final client = StylizeClient(
      config,
      client: httpClient,
      pollInterval: pollInterval,
    );
    try {
      // Fail fast (3 s) when the laptop is unreachable instead of waiting out the
      // much longer upload timeout.
      await client.health();
      final png = await client.stylize(
        bytes,
        style: style,
        onProgress: onProgress,
      );
      return RemoteAttempt.success(png);
    } finally {
      if (httpClient == null) client.close();
    }
  } on StylizeException catch (error) {
    return RemoteAttempt.failure(error.message);
  } catch (error) {
    return RemoteAttempt.failure('laptop:error');
  }
}
