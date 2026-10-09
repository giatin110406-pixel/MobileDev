import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/progress/server_player_repository.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A player document like the server's `player_json`.
Map<String, dynamic> doc({
  int balance = 0,
  int streak = 0,
  int? lastDay,
  int questDay = 20000,
  int failed = 0,
  String? passed,
  List<String> owned = const [],
  String? frame,
  String? banner,
  int today = 20000,
}) => {
  'seed': 12345,
  'balance': balance,
  'streak': streak,
  'last_completed_day': lastDay,
  'quest_day': questDay,
  'failed_attempts': failed,
  'passed_photo_id': passed,
  'music_muted': false,
  'today': today,
  'frame_id': frame,
  'banner_id': banner,
  'owned': owned,
  'ledger': [
    {'amount': 25, 'reason': 'quest:vg_grapes', 'at': '2026-10-07T01:00:00Z'},
  ],
};

class FakeServer {
  final calls = <(String, Map<String, dynamic>?)>[];
  Map<String, dynamic> state = doc();
  Object? failWith;
  Map<String, dynamic>? complete;

  Future<dynamic> call(String name, Map<String, dynamic>? params) async {
    calls.add((name, params));
    final failure = failWith;
    if (failure != null) throw failure;
    if (name == 'complete_quest') return complete;
    return state;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('server document', () {
    test('becomes the state the app shows', () {
      final state = playerStateFromServer(
        doc(
          balance: 120,
          streak: 3,
          lastDay: 19999,
          failed: 2,
          passed: 'photo-1',
          owned: ['frame_pixel'],
          frame: 'frame_pixel',
          banner: 'banner_space',
        ),
        avatarPath: '/a.jpg',
      );
      expect(state.seed, 12345);
      expect(state.balance, 120);
      expect(state.streak, 3);
      expect(state.lastCompletedDay, 19999);
      expect(state.attemptsLeft(20000), 1);
      expect(state.passedPhotoOn(20000), 'photo-1');
      expect(state.owns('frame_pixel'), isTrue);
      expect(state.equippedFrame, 'frame_pixel');
      expect(state.equippedBanner, 'banner_space');
      expect(state.avatarPath, '/a.jpg');
      expect(state.ledger.single.amount, 25);
      expect(state.questPosts, isEmpty, reason: 'posts are on the server');
    });

    test('a negative balance can never be shown', () {
      expect(playerStateFromServer(doc(balance: -5)).balance, 0);
    });

    test('server error codes become messages the app shows', () {
      expect(
        playerFailureFor('already_done').message,
        contains('đã hoàn thành'),
      );
      expect(playerFailureFor('no_attempts').message, contains('Hết lượt'));
      expect(playerFailureFor('expired').message, contains('00:00'));
      expect(playerFailureFor('already_owned').message, contains('sở hữu'));
      expect(playerFailureFor('insufficient_funds'), isA<NotEnoughSunbit>());
      expect(playerFailureFor('???').message, contains('Có lỗi'));
    });
  });

  group('shop catalog matches the server seed', () {
    test('same items, kinds, rarities, themes and prices', () {
      final sql = File(
        'supabase/migrations/20261007000005_player.sql',
      ).readAsStringSync();
      final row = RegExp(
        r"\('(\w+)',\s*'(\w+)',\s*'(\w+)',\s*'(\w+)',\s*(\d+)\)",
      );
      final seeded = {
        for (final m in row.allMatches(
          sql.substring(sql.indexOf('insert into public.shop_items')),
        ))
          m.group(1)!: (
            m.group(2),
            m.group(3),
            m.group(4),
            int.parse(m.group(5)!),
          ),
      };
      expect(seeded.keys.toSet(), {for (final i in shopCatalog) i.id});
      for (final item in shopCatalog) {
        expect(seeded[item.id], (
          item.kind.name,
          item.rarity.name,
          item.theme.name,
          item.price,
        ), reason: item.id);
      }
    });
  });

  group('server player repository', () {
    late FakeServer server;
    late ServerPlayerRepository repository;
    final quest = questCatalog.first;

    setUp(() {
      server = FakeServer();
      repository = ServerPlayerRepository(
        userId: 'u1',
        clock: () => DateTime.utc(2026, 10, 1, 5),
        rpc: server.call,
      );
    });

    test('load asks the server and follows its idea of today', () async {
      final clockDay = QuestRules.vietnamDay(DateTime.utc(2026, 10, 1, 5));
      server.state = doc(today: clockDay + 1, questDay: clockDay + 1);
      await repository.load();
      expect(server.calls.single.$1, 'get_player_state');
      expect(
        repository.today,
        clockDay + 1,
        reason: 'phone clock is a day off',
      );
    });

    test('a missed shot and a passed shot are sent as attempts', () async {
      await repository.recordFailedAttempt();
      await repository.recordPassed('photo-9');
      expect(server.calls[0].$1, 'record_quest_attempt');
      expect(server.calls[0].$2, {'p_passed': false});
      expect(server.calls[1].$1, 'record_quest_attempt');
      expect(server.calls[1].$2, {'p_passed': true, 'p_photo_id': 'photo-9'});
    });

    test('completing a quest returns what the server paid', () async {
      server.complete = {
        'state': doc(balance: 75, streak: 7, lastDay: 20000),
        'streak': 7,
        'base': 25,
        'bonus': 50,
      };
      final reward = await repository.completeQuest(
        quest: quest,
        questDay: 20000,
        photoId: 'p',
        imagePath: '/x.png',
        caption: '  Hi  ',
      );
      expect(server.calls.single.$1, 'complete_quest');
      expect(server.calls.single.$2, {'p_day': 20000, 'p_quest_id': quest.id});
      expect(reward.total, 75);
      expect(reward.streak, 7);
      expect(reward.state.balance, 75);
      expect(reward.post.caption, 'Hi');
      expect(reward.post.style, quest.style);
      expect(reward.post.questId, quest.id);
    });

    test('a caption over 80 characters never reaches the server', () async {
      await expectLater(
        repository.completeQuest(
          quest: quest,
          questDay: 20000,
          photoId: 'p',
          imagePath: '/x.png',
          caption: 'a' * 81,
        ),
        throwsA(isA<PlayerException>()),
      );
      expect(server.calls, isEmpty);
    });

    test(
      'too poor to buy: refused here, and the server is not asked',
      () async {
        server.state = doc(balance: 20);
        await repository.load();
        server.calls.clear();
        await expectLater(
          repository.buy('frame_pixel'),
          throwsA(
            isA<NotEnoughSunbit>().having((e) => e.missing, 'missing', 30),
          ),
        );
        expect(server.calls, isEmpty);
      },
    );

    test('buy, equip and take off go through the server', () async {
      server.state = doc(balance: 100);
      await repository.load();
      server.state = doc(balance: 50, owned: ['frame_pixel']);
      final bought = await repository.buy('frame_pixel');
      expect(bought.balance, 50);
      expect(bought.owns('frame_pixel'), isTrue);
      server.state = doc(
        balance: 50,
        owned: ['frame_pixel'],
        frame: 'frame_pixel',
      );
      expect(
        (await repository.equip('frame_pixel')).equippedFrame,
        'frame_pixel',
      );
      server.state = doc(balance: 50, owned: ['frame_pixel']);
      expect(
        (await repository.unequip(CosmeticKind.frame)).equippedFrame,
        isNull,
      );
      expect(server.calls.map((c) => c.$1), [
        'get_player_state',
        'buy_item',
        'equip_item',
        'unequip_item',
      ]);
      expect(server.calls.last.$2, {'p_kind': 'frame'});
    });

    test('a rule the server enforces shows its message', () async {
      server.failWith = const sb.PostgrestException(message: 'no_attempts');
      await expectLater(
        repository.recordFailedAttempt(),
        throwsA(
          isA<PlayerException>().having(
            (e) => e.message,
            'message',
            contains('Hết lượt'),
          ),
        ),
      );
    });

    test('no connection says so', () async {
      server.failWith = const SocketException('offline');
      await expectLater(
        repository.load(),
        throwsA(
          isA<PlayerException>().having(
            (e) => e.message,
            'message',
            contains('kết nối mạng'),
          ),
        ),
      );
    });
  });

  group('store with the server', () {
    test('remembers the quest post that was just made', () async {
      final server = FakeServer()
        ..complete = {
          'state': doc(balance: 25, streak: 1, lastDay: 20000),
          'streak': 1,
          'base': 25,
          'bonus': 0,
        };
      final store = PlayerStore(
        repository: ServerPlayerRepository(
          userId: 'u1',
          clock: () => DateTime.utc(2026, 10, 1, 5),
          rpc: server.call,
        ),
      );
      await store.load();
      expect(store.lastCompletedPost, isNull);
      await store.completeQuest(
        quest: questCatalog.first,
        questDay: 20000,
        photoId: 'photo-1',
        imagePath: '/styled.png',
        caption: 'done',
      );
      expect(store.balance, 25);
      expect(store.lastCompletedPost?.photoId, 'photo-1');
      expect(store.lastCompletedPost?.imagePath, '/styled.png');
      expect(store.lastCompletedPost?.style, questCatalog.first.style);
    });
  });

  group('what friends wear', () {
    PocketFriend friend({bool sample = false, String? frame, String? banner}) =>
        PocketFriend(
          id: sample ? 'sample-ava' : 'real-1',
          name: 'Ava',
          handle: '@ava',
          avatarColor: 0xFFFF6B6B,
          isSample: sample,
          addedAt: DateTime(2026),
          frameId: frame,
          bannerId: banner,
        );

    test('a real friend wears what their account says', () {
      final loadout = loadoutFor(
        friend(frame: 'frame_hearts', banner: 'banner_space'),
      );
      expect(loadout.frameId, 'frame_hearts');
      expect(loadout.bannerId, 'banner_space');
      expect(loadoutFor(friend()).frameId, isNull);
    });

    test('sample friends keep their built-in look', () {
      expect(loadoutFor(friend(sample: true)).frameId, 'frame_sunflower');
    });

    test('a person\'s frame, banner and photo reach the friend screens', () {
      const person = Person(
        id: 'u2',
        username: 'bo',
        displayName: 'Bo',
        avatarPath: 'u2/avatar.jpg',
        frameId: 'frame_brush',
        bannerId: 'banner_almond',
      );
      final pocket = person.toPocketFriend();
      expect(pocket.avatarPath, 'u2/avatar.jpg');
      expect(loadoutFor(pocket).frameId, 'frame_brush');
      expect(loadoutFor(pocket).bannerId, 'banner_almond');
      // ...and survive being saved on the phone and read back.
      final back = PocketFriend.fromJson(pocket.toJson());
      expect(back.frameId, 'frame_brush');
      expect(back.avatarPath, 'u2/avatar.jpg');
    });

    test('an old saved friend without these fields still loads', () {
      final old = PocketFriend.fromJson({
        'id': 'x',
        'name': 'Old',
        'handle': '@old',
        'avatarColor': 0xFF000000,
        'isSample': false,
        'addedAt': DateTime(2026).toIso8601String(),
      });
      expect(old.frameId, isNull);
      expect(old.avatarPath, isNull);
    });
  });

  test('styles used in quest posts are real styles', () {
    for (final q in questCatalog) {
      expect([StyleType.vanGogh, StyleType.pixel8bit], contains(q.style));
    }
  });
}
