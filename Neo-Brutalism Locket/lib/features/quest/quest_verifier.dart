import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_client.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';

/// The photo could not be checked at all (no laptop, offline, ...). This never
/// costs the user one of their tries.
class QuestCheckUnavailable implements Exception {
  const QuestCheckUnavailable(this.kind, [this.detail = '']);

  final QuestCheckError kind;

  /// For [QuestCheckError.laptopFailed]: the laptop error code.
  final String detail;

  /// For logs only.
  String get message => kind.name;

  @override
  String toString() => 'QuestCheckUnavailable(${kind.name})';
}

/// Why a quest photo could not be checked.
enum QuestCheckError {
  needsLaptop,
  laptopFailed,
  questUnknown,
  unreadablePhoto,
  deviceFailed,
}

/// What a quest check decided. Both refusals cost a try, but the player is
/// told apart why.
enum QuestVerdict {
  /// The photo shows the subject.
  match,

  /// A real photo of something else.
  wrongSubject,

  /// A photo of a screen or a print: someone is cheating.
  screenRecapture,
}

/// Decides whether a photo shows the quest subject.
abstract interface class QuestVerifier {
  /// What [jpeg] shows with respect to [quest]. Throws [QuestCheckUnavailable]
  /// when there is no answer.
  Future<QuestVerdict> check(Uint8List jpeg, Quest quest);
}

/// A verifier that can say what it saw in the last photo. Only debug builds
/// show this (the player must never be told what was detected).
abstract interface class QuestDiagnostics {
  /// E.g. "a dog 31%": the most likely label and the share of the probability
  /// the quest's accepted descriptions got. When the check could not run, the
  /// reason instead (so a broken model is visible). Null before any check.
  String? get lastDiagnosis;
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
  Future<QuestVerdict> check(Uint8List jpeg, Quest quest) async {
    final config = await store.load();
    if (!config.isConfigured) {
      throw const QuestCheckUnavailable(QuestCheckError.needsLaptop);
    }
    final client = StylizeClient(config, client: httpClient);
    try {
      final result = await client.verifySubject(
        jpeg,
        positives: quest.positives,
        negatives: quest.negatives,
      );
      return result.match ? QuestVerdict.match : QuestVerdict.wrongSubject;
    } on StylizeException catch (error) {
      throw QuestCheckUnavailable(QuestCheckError.laptopFailed, error.message);
    } finally {
      if (httpClient == null) client.close();
    }
  }
}
