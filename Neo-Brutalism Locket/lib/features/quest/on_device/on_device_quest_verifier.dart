
import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_preprocess.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';

Float32List _preprocess((Uint8List, int) job) =>
    preprocessQuestPhoto(job.$1, job.$2);

/// Decides whether a photo shows the quest subject, on the phone: no laptop
/// and no network. The image goes through MobileCLIP2-S0 and is compared with
/// the quest's pre-computed descriptions.
class OnDeviceQuestVerifier implements QuestVerifier {
  OnDeviceQuestVerifier({
    QuestImageEncoder? encoder,
    Future<QuestLabels> Function()? loadLabels,
  }) : _encoder = encoder ?? OrtQuestImageEncoder(),
       _loadLabels = loadLabels ?? QuestLabels.load;

  final QuestImageEncoder _encoder;
  final Future<QuestLabels> Function() _loadLabels;
  Future<QuestLabels>? _labels;

  @override
  Future<bool> check(Uint8List jpeg, Quest quest) async {
    try {
      final labels = await (_labels ??= _loadLabels());
      if (!labels.quests.containsKey(quest.id)) {
        throw const QuestCheckUnavailable(
          'Nhiệm vụ này chưa có trong bộ kiểm ảnh. Hãy cập nhật ứng dụng.',
        );
      }
      final planes = await compute(_preprocess, (jpeg, labels.inputSize));
      final embedding = await _encoder.encode(planes, labels.inputSize);
      return scoreQuestPhoto(embedding, labels, quest.id).match;
    } on QuestCheckUnavailable {
      rethrow;
    } on FormatException {
      throw const QuestCheckUnavailable(
        'Không đọc được ảnh. Lượt thử không bị trừ.',
      );
    } catch (_) {
      _labels = null;
      throw const QuestCheckUnavailable(
        'Không kiểm tra được ảnh trên máy. Lượt thử không bị trừ.',
      );
    }
  }
}
