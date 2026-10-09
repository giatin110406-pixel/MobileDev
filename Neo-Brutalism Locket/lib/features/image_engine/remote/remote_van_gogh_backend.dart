import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/features/image_engine/magenta_van_gogh_backend.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/remote_stylize.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';

/// Van Gogh via the laptop diffusion server. Falls back to [fallback]
/// (Magenta, then mock) whenever the laptop is unset, offline or fails, and
/// reports the real source plus the reason.
class RemoteVanGoghBackend implements VanGoghBackend {
  RemoteVanGoghBackend({
    this.store = const StylizeServerConfigStore(),
    this.httpClient,
    this.fallback = const MagentaVanGoghBackend(),
    this.pollInterval = const Duration(seconds: 1),
  });

  final StylizeServerConfigStore store;
  final http.Client? httpClient;
  final VanGoghBackend fallback;
  final Duration pollInterval;

  @override
  Future<StyleResult> process(
    Uint8List originalBytes, {
    StyleProgress? onProgress,
  }) async {
    final attempt = await tryRemoteStylize(
      originalBytes,
      style: 'van_gogh',
      store: store,
      httpClient: httpClient,
      pollInterval: pollInterval,
      onProgress: onProgress,
    );
    final png = attempt.png;
    if (png != null) return StyleResult(png, StyleSource.laptopDiffusion);

    onProgress?.call('using fallback', 0);
    final result = await fallback.process(
      originalBytes,
      onProgress: onProgress,
    );
    return StyleResult(
      result.png,
      result.source,
      note: result.note == null
          ? attempt.reason
          : '${attempt.reason}; ${result.note}',
    );
  }
}
