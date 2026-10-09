import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_client.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';

/// The photo could not be checked at all (no laptop, offline, ...). This never
/// costs the user one of their tries.
class QuestCheckUnavailable implements Exception {
  const QuestCheckUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Decides whether a photo shows the quest subject.
abstract interface class QuestVerifier {
  /// True when [jpeg] shows [quest]'s subject. Throws [QuestCheckUnavailable]
  /// when there is no answer.
  Future<bool> check(Uint8List jpeg, Quest quest);
}

/// Asks the laptop server's CLIP check (POST /v1/verify).
class LaptopQuestVerifier implements QuestVerifier {
  const LaptopQuestVerifier({
    this.store = const StylizeServerConfigStore(),
    this.httpClient,
  });

  final StylizeServerConfigStore store;
  final http.Client? httpClient;

  @override
  Future<bool> check(Uint8List jpeg, Quest quest) async {
    final config = await store.load();
    if (!config.isConfigured) {
      throw const QuestCheckUnavailable(
        'Cần kết nối laptop để kiểm tra ảnh. Bấm nút server (màu xanh) để cài đặt.',
      );
    }
    final client = StylizeClient(config, client: httpClient);
    try {
      final result = await client.verifySubject(
        jpeg,
        positives: quest.positives,
        negatives: quest.negatives,
      );
      return result.match;
    } on StylizeException catch (error) {
      throw QuestCheckUnavailable(
        'Không kiểm tra được ảnh (${error.message}). Lượt thử không bị trừ.',
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
