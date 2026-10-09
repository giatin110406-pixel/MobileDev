import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/on_device_quest_verifier.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/ort_image_encoder.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_preprocess.dart';
import 'package:neo_brutalism_locket/features/quest/on_device/quest_scoring.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/quest/quest_verifier.dart';

QuestLabels loadBank() => QuestLabels.parse(
  File(questLabelsAsset).readAsStringSync(),
  File(questVectorsAsset).readAsBytesSync(),
);

Float32List vectorOf(List<dynamic> numbers) =>
    Float32List.fromList([for (final n in numbers) (n as num).toDouble()]);

/// Answers with a fixed embedding and remembers what it was asked.
class FakeEncoder implements QuestImageEncoder {
  FakeEncoder(this.embedding);

  final Float32List embedding;
  int? lastSize;
  int? lastLength;

  @override
  Future<Float32List> encode(Float32List planes, int size) async {
    lastSize = size;
    lastLength = planes.length;
    return embedding;
  }
}

class FailingEncoder implements QuestImageEncoder {
  @override
  Future<Float32List> encode(Float32List planes, int size) =>
      Future.error(StateError('model missing'));
}

void main() {
  final bank = loadBank();
  final goldens =
      (jsonDecode(File('test/fixtures/quest/goldens.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();
  Uint8List photo(Map<String, dynamic> golden) =>
      File('test/fixtures/quest/${golden['file']}').readAsBytesSync();

  group('exported labels match the quest catalog', () {
    test('every quest is in the model, with its own positives first', () {
      for (final quest in questCatalog) {
        final set = bank.quests[quest.id];
        expect(set, isNotNull, reason: '${quest.id} is missing: re-export');
        final names = [for (final id in set!.labelIds) bank.labels[id]];
        expect(
          names.take(set.positives).toList(),
          quest.positives,
          reason: '${quest.id} positives changed: re-export',
        );
        expect(
          names.skip(set.positives).toList(),
          containsAll(quest.negatives),
          reason: '${quest.id} negatives changed: re-export',
        );
      }
      expect(bank.quests.length, questCatalog.length);
    });

    test('vectors are unit length', () {
      for (final id in [0, 10, bank.labels.length - 1]) {
        var sum = 0.0;
        for (var d = 0; d < bank.dimension; d++) {
          final v = bank.vectors[id * bank.dimension + d];
          sum += v * v;
        }
        expect(sum, closeTo(1, 1e-3));
      }
    });

    test('rejects vectors that do not fit the labels', () {
      expect(
        () => QuestLabels.parse(
          File(questLabelsAsset).readAsStringSync(),
          Uint8List(8),
        ),
        throwsFormatException,
      );
    });
  });

  group('scoring agrees with the server rules (python reference)', () {
    for (final golden in goldens) {
      test('${golden['file']}', () {
        final score = scoreQuestPhoto(
          vectorOf(golden['embedding'] as List<dynamic>),
          bank,
          golden['quest'] as String,
        );
        expect(score.match, golden['match']);
        expect(score.top, golden['top']);
        expect(score.score, closeTo((golden['score'] as num).toDouble(), 2e-3));
      });
    }

    test('unknown quest is refused', () {
      expect(
        () => scoreQuestPhoto(Float32List(bank.dimension), bank, 'nope'),
        throwsArgumentError,
      );
    });

    test('a vector of the wrong size is refused', () {
      expect(
        () => scoreQuestPhoto(Float32List(3), bank, questCatalog.first.id),
        throwsArgumentError,
      );
    });

    test('the quest subject itself wins', () {
      for (final quest in questCatalog) {
        final id = bank.quests[quest.id]!.labelIds.first;
        final vector = Float32List.sublistView(
          bank.vectors,
          id * bank.dimension,
          (id + 1) * bank.dimension,
        );
        expect(
          scoreQuestPhoto(vector, bank, quest.id).match,
          isTrue,
          reason: quest.id,
        );
      }
    });
  });

  group('preprocessing matches python', () {
    for (final golden in goldens) {
      test('${golden['file']}', () {
        final size = bank.inputSize;
        final plane = size * size;
        final planes = preprocessQuestPhoto(photo(golden), size);
        expect(planes.length, 3 * plane);
        for (var c = 0; c < 3; c++) {
          var sum = 0.0;
          for (var i = 0; i < plane; i++) {
            sum += planes[c * plane + i];
          }
          expect(
            sum / plane,
            closeTo(
              ((golden['channelMeans'] as List<dynamic>)[c] as num).toDouble(),
              0.02,
            ),
          );
        }
        final grid = golden['grid'] as List<dynamic>;
        var worst = 0.0;
        var total = 0.0;
        for (var c = 0; c < 3; c++) {
          for (var gy = 0; gy < 8; gy++) {
            for (var gx = 0; gx < 8; gx++) {
              final expected = (grid[c * 64 + gy * 8 + gx] as num).toDouble();
              final got =
                  planes[c * plane + (16 + gy * 32) * size + 16 + gx * 32];
              final diff = (got - expected).abs();
              total += diff;
              if (diff > worst) worst = diff;
            }
          }
        }
        // Different JPEG decoders and resizers: a few grey levels on average,
        // more only on sharp edges (measured 0.01-0.025 mean, 0.17 worst).
        expect(total / 192, lessThan(0.04));
        expect(worst, lessThan(0.25));
        expect(planes.every((v) => v >= 0 && v <= 1), isTrue);
      });
    }

    test('any size is produced', () {
      expect(preprocessQuestPhoto(photo(goldens.first), 64).length, 3 * 64 * 64);
    });

    test('something that is not an image is refused', () {
      expect(
        () => preprocessQuestPhoto(Uint8List.fromList([1, 2, 3]), 256),
        throwsFormatException,
      );
    });
  });

  group('OnDeviceQuestVerifier', () {
    Quest quest(String id) => questCatalog.firstWhere((q) => q.id == id);
    final dog = goldens.firstWhere((g) => g['quest'] == 'px_dog');

    OnDeviceQuestVerifier verifier(QuestImageEncoder encoder) =>
        OnDeviceQuestVerifier(encoder: encoder, loadLabels: () async => bank);

    test('passes a photo whose embedding shows the subject', () async {
      final encoder = FakeEncoder(vectorOf(dog['embedding'] as List<dynamic>));
      expect(await verifier(encoder).check(photo(dog), quest('px_dog')), isTrue);
      expect(encoder.lastSize, bank.inputSize);
      expect(encoder.lastLength, 3 * bank.inputSize * bank.inputSize);
    });

    test('refuses a photo that shows something else', () async {
      final wrong = goldens.firstWhere((g) => g['match'] == false);
      final encoder = FakeEncoder(vectorOf(wrong['embedding'] as List<dynamic>));
      expect(
        await verifier(encoder).check(photo(wrong), quest(wrong['quest'] as String)),
        isFalse,
      );
    });

    test('loads the labels once', () async {
      var loads = 0;
      final once = OnDeviceQuestVerifier(
        encoder: FakeEncoder(vectorOf(dog['embedding'] as List<dynamic>)),
        loadLabels: () async {
          loads++;
          return bank;
        },
      );
      await once.check(photo(dog), quest('px_dog'));
      await once.check(photo(dog), quest('px_dog'));
      expect(loads, 1);
    });

    test('a broken model never costs a try', () {
      expect(
        verifier(FailingEncoder()).check(photo(dog), quest('px_dog')),
        throwsA(isA<QuestCheckUnavailable>()),
      );
    });

    test('an unreadable photo never costs a try', () {
      expect(
        verifier(
          FakeEncoder(Float32List(bank.dimension)),
        ).check(Uint8List.fromList([1, 2, 3]), quest('px_dog')),
        throwsA(isA<QuestCheckUnavailable>()),
      );
    });

    test('a quest missing from the model is unavailable, not wrong', () {
      const stranger = Quest(
        id: 'not_exported',
        subject: 'x',
        positives: ['a thing'],
        style: StyleType.pixel8bit,
        storyTitle: '',
        story: '',
        caption: '',
        emoji: '',
      );
      expect(
        verifier(
          FakeEncoder(Float32List(bank.dimension)),
        ).check(photo(dog), stranger),
        throwsA(isA<QuestCheckUnavailable>()),
      );
    });
  });
}
