import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 12:00 in Vietnam on 2026-10-[day].
DateTime noonVn(int day) => DateTime.utc(2026, 10, day, 5);

void main() {
  group('Vietnam day', () {
    test('a new day starts at 00:00 in Vietnam (17:00 UTC)', () {
      final before = QuestRules.vietnamDay(DateTime.utc(2026, 10, 7, 16, 59));
      final after = QuestRules.vietnamDay(DateTime.utc(2026, 10, 7, 17, 0));
      expect(after, before + 1);
      // Same instant, any phone time zone: only UTC matters.
      expect(
        QuestRules.vietnamDay(DateTime.utc(2026, 10, 7, 16, 59).toLocal()),
        before,
      );
    });
  });

  group('quest catalog', () {
    test('ids are unique and every quest is complete', () {
      expect(
        questCatalog.map((q) => q.id).toSet(),
        hasLength(questCatalog.length),
      );
      for (final quest in questCatalog) {
        expect(quest.positives, isNotEmpty, reason: quest.id);
        expect(quest.style, isNot(StyleType.none), reason: quest.id);
        expect(quest.story.length, greaterThan(80), reason: quest.id);
        expect(
          quest.caption.characters.length,
          lessThanOrEqualTo(QuestRules.maxCaptionLength),
          reason: quest.id,
        );
      }
      expect(
        questCatalog.where((q) => q.style == StyleType.vanGogh),
        isNotEmpty,
      );
      expect(
        questCatalog.where((q) => q.style == StyleType.pixel8bit),
        isNotEmpty,
      );
    });

    test('one quest per day, the same all day, different per user', () {
      expect(questForDay(42, 20000).id, questForDay(42, 20000).id);
      final a = [for (var d = 0; d < 30; d++) questForDay(1, 20000 + d).id];
      final b = [for (var d = 0; d < 30; d++) questForDay(2, 20000 + d).id];
      expect(a, isNot(b));
    });

    test('never the same quest two days in a row; all seen before repeats', () {
      for (final seed in [0, 1, 7, 123456, 0x7FFFFFFE]) {
        String? previous;
        for (var day = 19990; day < 19990 + questCatalog.length * 6; day++) {
          final id = questForDay(seed, day).id;
          expect(id, isNot(previous), reason: 'seed $seed day $day');
          previous = id;
        }
        final n = questCatalog.length;
        final cycleStart = (20000 ~/ n) * n;
        final cycle = {
          for (var d = cycleStart; d < cycleStart + n; d++)
            questForDay(seed, d).id,
        };
        expect(cycle, hasLength(n), reason: 'seed $seed');
      }
    });
  });

  group('quest, streak and Sunbit', () {
    late DateTime now;
    late PlayerRepository repository;
    final quest = questCatalog.first;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = noonVn(1);
      repository = PlayerRepository(clock: () => now);
    });

    Future<QuestReward> complete({int? questDay}) => repository.completeQuest(
      quest: quest,
      questDay: questDay ?? repository.today,
      photoId: 'p${now.day}',
      imagePath: '/x.png',
      caption: quest.caption,
    );

    test('completing pays 25 Sunbit and starts a streak of 1', () async {
      final reward = await complete();
      expect(reward.total, 25);
      expect(reward.state.balance, 25);
      expect(reward.state.streak, 1);
      expect(reward.state.questPosts.single.caption, quest.caption);
      expect(reward.state.ledger.single.amount, 25);
    });

    test('only one reward per day', () async {
      await complete();
      await expectLater(complete(), throwsA(isA<PlayerException>()));
      final state = await repository.load();
      expect(state.balance, 25);
      expect(state.questPosts, hasLength(1));
    });

    test('streak grows on consecutive days and resets after a miss', () async {
      await complete();
      now = noonVn(2);
      expect((await complete()).streak, 2);
      now = noonVn(4); // missed the 3rd
      expect((await repository.load()).visibleStreak(repository.today), 0);
      expect((await complete()).streak, 1);
    });

    test('every 7th day in a row pays a 50 Sunbit bonus', () async {
      var balance = 0;
      for (var day = 1; day <= 14; day++) {
        now = noonVn(day);
        final reward = await complete();
        expect(reward.bonus, day % 7 == 0 ? 50 : 0, reason: 'day $day');
        balance += reward.total;
      }
      expect(balance, 14 * 25 + 2 * 50);
      expect((await repository.load()).balance, balance);
    });

    test('three misses a day, then no more tries until tomorrow', () async {
      for (var i = 0; i < QuestRules.attemptsPerDay; i++) {
        await repository.recordFailedAttempt();
      }
      final state = await repository.load();
      expect(state.attemptsLeft(repository.today), 0);
      await expectLater(
        repository.recordFailedAttempt(),
        throwsA(isA<PlayerException>()),
      );
      await expectLater(
        repository.recordPassed('late'),
        throwsA(isA<PlayerException>()),
      );
      now = noonVn(2);
      expect(
        (await repository.load()).attemptsLeft(repository.today),
        QuestRules.attemptsPerDay,
      );
      await repository.recordFailedAttempt();
      expect(
        (await repository.load()).attemptsLeft(repository.today),
        QuestRules.attemptsPerDay - 1,
      );
    });

    test('a passed photo waits until midnight, then expires', () async {
      await repository.recordPassed('photo-1');
      final day = repository.today;
      expect((await repository.load()).passedPhotoOn(day), 'photo-1');
      // 23:59 -> 00:01 Vietnam time: the old quest cannot be posted.
      now = DateTime.utc(2026, 10, 1, 17, 1);
      expect((await repository.load()).passedPhotoOn(repository.today), isNull);
      await expectLater(
        complete(questDay: day),
        throwsA(isA<PlayerException>()),
      );
      expect((await repository.load()).balance, 0);
    });

    test('captions longer than 80 characters are refused', () async {
      await expectLater(
        repository.completeQuest(
          quest: quest,
          questDay: repository.today,
          photoId: 'p',
          imagePath: '/x.png',
          caption: 'a' * 81,
        ),
        throwsA(isA<PlayerException>()),
      );
    });
  });

  group('shop', () {
    late PlayerRepository repository;
    final cheap = shopItemById('frame_pixel')!; // 50
    final pricey = shopItemById('banner_starry_night')!; // 500
    final otherFrame = shopItemById('frame_brush')!; // 60

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = PlayerRepository(clock: () => noonVn(1));
    });

    Future<void> earn(int quests) async {
      for (var i = 0; i < quests; i++) {
        final now = noonVn(1 + i);
        final dayRepository = PlayerRepository(clock: () => now);
        await dayRepository.completeQuest(
          quest: questCatalog.first,
          questDay: dayRepository.today,
          photoId: 'p$i',
          imagePath: '/x.png',
          caption: '',
        );
      }
    }

    test('prices follow rarity, 50 to 500', () {
      for (final item in shopCatalog) {
        final range = switch (item.rarity) {
          Rarity.common => (50, 100),
          Rarity.rare => (150, 250),
          Rarity.legendary => (400, 500),
        };
        expect(
          item.price,
          inInclusiveRange(range.$1, range.$2),
          reason: item.id,
        );
      }
      expect(shopCatalog, hasLength(10));
    });

    test(
      'not enough Sunbit: locked, shows what is missing, nothing spent',
      () async {
        await earn(1); // 25
        final state = await repository.load();
        expect(shopActionFor(state, cheap), ShopAction.locked);
        await expectLater(
          repository.buy(cheap.id),
          throwsA(
            isA<NotEnoughSunbit>().having((e) => e.missing, 'missing', 25),
          ),
        );
        expect((await repository.load()).balance, 25);
      },
    );

    test('buy, own forever, never buy twice; balance never negative', () async {
      await earn(3); // 75
      var state = await repository.buy(cheap.id);
      expect(state.balance, 25);
      expect(state.owns(cheap.id), isTrue);
      expect(shopActionFor(state, cheap), ShopAction.equip);
      await expectLater(
        repository.buy(cheap.id),
        throwsA(isA<PlayerException>()),
      );
      await expectLater(
        repository.buy(pricey.id),
        throwsA(isA<NotEnoughSunbit>()),
      );
      state = await repository.load();
      expect(state.balance, 25);
    });

    test('one frame at a time; swapping and taking off are free', () async {
      await earn(5); // 125
      await repository.buy(cheap.id);
      await repository.buy(otherFrame.id); // 125 - 50 - 60 = 15
      await expectLater(
        repository.equip(pricey.id),
        throwsA(isA<PlayerException>()),
      );
      var state = await repository.equip(cheap.id);
      expect(state.equippedFrame, cheap.id);
      expect(shopActionFor(state, cheap), ShopAction.unequip);
      state = await repository.equip(otherFrame.id);
      expect(state.equippedFrame, otherFrame.id);
      expect(shopActionFor(state, cheap), ShopAction.equip);
      state = await repository.unequip(CosmeticKind.frame);
      expect(state.equippedFrame, isNull);
      expect(state.balance, 15);
    });

    test('two quick buys cannot spend the same Sunbit twice', () async {
      await earn(3); // 75: enough for one 50 or one 60, not both
      final results = await Future.wait([
        repository.buy(cheap.id).then((_) => true, onError: (_) => false),
        repository.buy(otherFrame.id).then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((ok) => ok), hasLength(1));
      expect((await repository.load()).balance, greaterThanOrEqualTo(0));
    });
  });
}
