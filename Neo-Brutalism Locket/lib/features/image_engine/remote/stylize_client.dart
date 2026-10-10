import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';

/// Why the laptop server could not be used.
enum StylizeError {
  notSetUp,
  tooLong,
  wrongToken,
  tooLarge,
  busy,
  noAnswer,
  unreachable,
  failed,
  status,
}

class StylizeException implements Exception {
  const StylizeException(this.kind, [this.detail = '']);

  final StylizeError kind;

  /// The server's own words (a status code, a failure text), if it gave any.
  final String detail;

  /// A short code the screens turn into a sentence (stylizeCodeText).
  String get message =>
      detail.isEmpty ? 'laptop:${kind.name}' : 'laptop:${kind.name}|$detail';

  @override
  String toString() => message;
}

class ServerHealth {
  const ServerHealth({
    required this.gpu,
    required this.modelsReady,
    required this.vramFreeMb,
  });

  final String? gpu;
  final bool modelsReady;
  final int? vramFreeMb;
}

/// The laptop's answer to "is this the quest subject?".
class SubjectCheck {
  const SubjectCheck({
    required this.match,
    required this.score,
    required this.top,
  });

  final bool match;
  final double score;

  /// What the photo looked most like (English, for debugging only).
  final String top;
}

/// Talks to the laptop stylize server (see server/locket_server/api.py).
class StylizeClient {
  StylizeClient(
    this.config, {
    http.Client? client,
    this.pollInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 180),
  }) : _client = client ?? http.Client();

  final StylizeServerConfig config;
  final Duration pollInterval;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path) => config.baseUri.replace(path: path);

  Map<String, String> get _headers => {'X-Locket-Token': config.token.trim()};

  Future<ServerHealth> health() async {
    final response = await _guard(
      () => _client.get(_uri('/v1/health')).timeout(const Duration(seconds: 5)),
    );
    if (response.statusCode != 200) {
      throw StylizeException(StylizeError.status, '${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ServerHealth(
      gpu: body['gpu'] as String?,
      modelsReady: body['models_ready'] == true,
      vramFreeMb: body['vram_free_mb'] as int?,
    );
  }

  /// Uploads [bytes], waits for the job and returns the PNG.
  Future<Uint8List> stylize(
    Uint8List bytes, {
    String style = 'van_gogh',
    StyleProgress? onProgress,
  }) async {
    final deadline = DateTime.now().add(timeout);
    final request = http.MultipartRequest('POST', _uri('/v1/jobs'))
      ..headers.addAll(_headers)
      ..fields['style'] = style
      ..files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: 'photo.jpg'),
      );
    final submitted = await _guard(() async {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    });
    _checkStatus(submitted, expected: 202);
    final jobId =
        (jsonDecode(submitted.body) as Map<String, dynamic>)['job_id']
            as String;

    var failures = 0;
    while (true) {
      if (DateTime.now().isAfter(deadline)) {
        throw const StylizeException(StylizeError.tooLong);
      }
      await Future<void>.delayed(pollInterval);
      final http.Response status;
      try {
        status = await _guard(
          () => _client
              .get(_uri('/v1/jobs/$jobId'), headers: _headers)
              .timeout(const Duration(seconds: 10)),
        );
      } on StylizeException {
        // The laptop keeps painting even if one poll is lost (flaky Wi-Fi/USB).
        if (++failures > _maxTransientFailures) rethrow;
        continue;
      }
      failures = 0;
      _checkStatus(status);
      final body = jsonDecode(status.body) as Map<String, dynamic>;
      onProgress?.call(
        body['stage'] as String? ?? '',
        (body['progress'] as num? ?? 0).toDouble(),
      );
      final state = body['state'];
      if (state == 'failed') {
        throw StylizeException(StylizeError.failed, '${body['error'] ?? ''}');
      }
      if (state == 'done') break;
    }

    http.Response? result;
    for (var attempt = 0; attempt < 3 && result == null; attempt++) {
      try {
        result = await _guard(
          () => _client
              .get(_uri('/v1/jobs/$jobId/result'), headers: _headers)
              .timeout(const Duration(seconds: 60)),
        );
      } on StylizeException {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(pollInterval);
      }
    }
    _checkStatus(result!);
    // Free the laptop's copy; failure to do so is harmless (it expires anyway).
    unawaited(
      _client
          .delete(_uri('/v1/jobs/$jobId'), headers: _headers)
          .timeout(const Duration(seconds: 5))
          .then<void>((_) {}, onError: (Object _) {}),
    );
    return result.bodyBytes;
  }

  /// Daily quest check: does the photo show one of [positives] (short English
  /// descriptions) rather than an everyday distractor or one of [negatives]?
  Future<SubjectCheck> verifySubject(
    Uint8List bytes, {
    required List<String> positives,
    List<String> negatives = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri('/v1/verify'))
      ..headers.addAll(_headers)
      ..fields['positives'] = jsonEncode(positives)
      ..fields['negatives'] = jsonEncode(negatives)
      ..files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: 'photo.jpg'),
      );
    final response = await _guard(() async {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      return http.Response.fromStream(streamed);
    });
    _checkStatus(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return SubjectCheck(
      match: body['match'] == true,
      score: (body['score'] as num? ?? 0).toDouble(),
      top: body['top'] as String? ?? '',
    );
  }

  static const _maxTransientFailures = 8;

  void _checkStatus(http.Response response, {int expected = 200}) {
    if (response.statusCode == expected) return;
    throw switch (response.statusCode) {
      401 => const StylizeException(StylizeError.wrongToken),
      413 => const StylizeException(StylizeError.tooLarge),
      429 => const StylizeException(StylizeError.busy),
      final code => StylizeException(StylizeError.status, '$code'),
    };
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on TimeoutException {
      throw const StylizeException(StylizeError.noAnswer);
    } on SocketException {
      throw const StylizeException(StylizeError.unreachable);
    } on http.ClientException {
      throw const StylizeException(StylizeError.unreachable);
    }
  }

  void close() => _client.close();
}
