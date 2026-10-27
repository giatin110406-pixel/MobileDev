import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/search/search_query.dart';

void main() {
  const friends = <SearchFriend>[
    (id: 'lan', name: 'Lan'),
    (id: 'lananh', name: 'Lan Anh'),
    (id: 'minh', name: 'Minh Trần'),
  ];
  final now = DateTime(2026, 10, 22, 15); // a Thursday

  SearchQuery parse(String text) =>
      parseSearchQuery(text, friends: friends, now: now);

  test('who and when become filters, the rest is the picture', () {
    final q = parse('áo đỏ đứng cạnh xe máy với Lan năm ngoái');
    expect(q.content, 'áo đỏ đứng cạnh xe máy');
    expect(q.friendId, 'lan');
    expect(q.from, DateTime(2025));
    expect(q.until, DateTime(2026));
  });

  test('the longest friend name wins; accents are optional', () {
    expect(parse('bien voi lan anh').friendId, 'lananh');
    expect(parse('biển của Minh').friendId, 'minh');
    expect(parse('biển của minh trần').friendId, 'minh');
    expect(parse('biển của minh trần').content, 'biển');
    expect(parse('biển với Hoa').friendId, isNull, reason: 'not a friend');
  });

  test('a part of the day is a rule on the hour, not for the photo model', () {
    var q = parse('đi cà phê với Hiếu lúc chiều');
    expect(q.content, 'đi cà phê với Hiếu');
    expect((q.fromHour, q.untilHour), (12, 19));
    expect(q.hourMatches(15), isTrue);
    expect(q.hourMatches(9), isFalse);
    expect(q.hourMatches(19), isFalse);

    q = parse('coffee in the afternoon');
    expect(q.content, 'coffee');
    expect(q.fromHour, 12);

    q = parse('quán cà phê buổi sáng');
    expect(q.content, 'quán cà phê');
    expect(q.hourMatches(8), isTrue);

    q = parse('đi dạo lúc tối');
    expect(q.content, 'đi dạo');
    expect(q.hourMatches(20), isTrue);

    // past midnight: 21:00 .. 05:00
    q = parse('quán nhậu lúc đêm');
    expect(q.hourMatches(23), isTrue);
    expect(q.hourMatches(2), isTrue);
    expect(q.hourMatches(12), isFalse);
  });

  test('a part of the day needs its marker word, and "tôi" is not "tối"', () {
    // no "lúc / buổi" in front: nothing is cut out
    expect(parse('chiều hôm qua').fromHour, isNull);
    expect(parse('xem chiếu phim').fromHour, isNull);
    // "tôi" (I) is not the evening
    final q = parse('lúc tôi chụp ở biển');
    expect(q.fromHour, isNull);
    // a dark scene is a picture, not a rule
    expect(parse('lanterns at night').fromHour, isNull);
  });

  test('a name inside a word is not a friend', () {
    final q = parse('lanterns at night');
    expect(q.friendId, isNull);
    expect(q.content, 'lanterns at night');
  });

  test('my own posts', () {
    final q = parse('ảnh của tôi ở biển');
    expect(q.mine, isTrue);
    expect(q.content, 'ở biển');
  });

  test('time words, Vietnamese and English', () {
    expect(parse('hôm nay').from, DateTime(2026, 10, 22));
    expect(parse('hôm qua').until, DateTime(2026, 10, 22));
    expect(parse('tuần này').from, DateTime(2026, 10, 19)); // Monday
    expect(parse('tuần trước').from, DateTime(2026, 10, 12));
    expect(parse('tháng trước').from, DateTime(2026, 9));
    expect(parse('last month').until, DateTime(2026, 10));
    expect(parse('năm nay').from, DateTime(2026));
    expect(parse('thang 12').from, DateTime(2025, 12), reason: 'not begun yet');
    expect(parse('tháng 3').from, DateTime(2026, 3));
    expect(parse('tháng 3 năm 2025').until, DateTime(2025, 4));
    expect(parse('pizza in 2025').from, DateTime(2025));
    expect(parse('pizza in 2025').content, 'pizza');
  });

  group('remembered times are ranges, not exact days', () {
    // now = Thursday 2026-10-22
    test('"about half a year ago" is a window around April', () {
      for (final text in [
        'tầm nửa năm trước',
        'khoảng 6 tháng trước',
        'sáu tháng trước',
        'about 6 months ago',
        'half a year ago',
      ]) {
        final q = parse('ăn lẩu $text');
        expect(q.content, 'ăn lẩu', reason: text);
        // 6 months = 183 days; a quarter of it either side
        expect(q.from!.isBefore(DateTime(2026, 4, 1)), isTrue, reason: text);
        expect(q.from!.isAfter(DateTime(2026, 2, 1)), isTrue, reason: text);
        expect(q.until!.isAfter(DateTime(2026, 5, 15)), isTrue, reason: text);
        expect(q.until!.isBefore(DateTime(2026, 7, 15)), isTrue, reason: text);
      }
    });

    test('a few days, weeks or years back, and never into the future', () {
      final days = parse('3 ngày trước');
      expect(days.from, DateTime(2026, 10, 17));
      expect(days.until, DateTime(2026, 10, 22));
      final recent = parse('1 tuần trước');
      expect(recent.until!.isAfter(DateTime(2026, 10, 23)), isFalse);
      final years = parse('2 years ago');
      expect(years.from!.year, 2024);
      expect(years.until!.isAfter(DateTime(2025, 3)), isTrue);
      expect(years.until!.isBefore(DateTime(2025, 6)), isTrue);
    });

    test('"a few months ago" is a wide band', () {
      final q = parse('mấy tháng trước');
      expect(q.from, DateTime(2026, 5, 23));
      expect(q.until, DateTime(2026, 9, 7));
      expect(q.content, isEmpty);
    });

    test('"3 năm trước" is not read as "last year"', () {
      final q = parse('biển 3 năm trước');
      expect(q.content, 'biển');
      expect(q.from!.year, 2023);
    });

    test('seasons, with or without a year', () {
      expect(parse('mùa hè').from, DateTime(2026, 6));
      expect(parse('mùa hè').until, DateTime(2026, 9));
      expect(parse('mùa hè năm ngoái').from, DateTime(2025, 6));
      expect(
        parse('mùa đông').from,
        DateTime(2025, 12),
        reason: 'this winter has not begun',
      );
      expect(parse('mùa thu 2024').from, DateTime(2024, 9));
      expect(parse('pizza last summer').content, 'pizza');
      expect(
        parse('spring roll').content,
        'spring roll',
        reason: 'only "in / last / this spring" is a season',
      );
    });

    test('the day before yesterday', () {
      expect(parse('hôm kia').from, DateTime(2026, 10, 20));
      expect(parse('hôm kia').until, DateTime(2026, 10, 21));
    });
  });

  group('a name without "with" is offered, not applied', () {
    test('"Minh ăn lẩu" offers Minh and keeps the words', () {
      final q = parse('Minh ăn lẩu');
      expect(q.friendId, isNull);
      expect(q.friendHints.map((f) => f.id), ['minh']);
      expect(q.content, 'Minh ăn lẩu');
    });

    test('a name inside another word offers nothing', () {
      expect(parse('lanterns at night').friendHints, isEmpty);
    });

    test('a full name typed in full offers only that friend', () {
      expect(parse('lan anh ăn kem').friendHints.map((f) => f.id), ['lananh']);
    });

    test('a first name shared by two friends offers both', () {
      expect(parse('ảnh lan').friendHints.map((f) => f.id).toSet(), {
        'lan',
        'lananh',
      });
    });

    test('with "with" there is nothing left to offer', () {
      expect(parse('ăn lẩu với Lan').friendHints, isEmpty);
    });

    test('pinning applies the friend and takes the name out of the words', () {
      final q = parseSearchQuery(
        'Lan ăn lẩu',
        friends: friends,
        now: now,
        pinFriend: 'lan',
      );
      expect(q.friendId, 'lan');
      expect(q.content, 'ăn lẩu');
      expect(q.friendHints, isEmpty);
    });

    test('pinning Lan Anh by her first name only', () {
      final q = parseSearchQuery(
        'lan chụp biển',
        friends: friends,
        now: now,
        pinFriend: 'lananh',
      );
      expect(q.friendId, 'lananh');
      expect(q.content, 'chụp biển');
    });
  });

  test('a search can be only filters', () {
    final q = parse('ảnh với Lan tháng trước');
    expect(q.content, isEmpty);
    expect(q.hasFilters, isTrue);
  });

  test('filler words in front go, the subject stays', () {
    expect(parse('những tấm ảnh có con chó').content, 'con chó');
    expect(parse('photos of a dog').content, 'a dog');
    expect(parse('hình mèo').content, 'mèo');
    expect(
      parse('anh trai').content,
      'anh trai',
      reason: '"anh" + more is not filler',
    );
  });

  test('the glossary writes what ML Kit gets wrong in English', () {
    expect(
      parse('người mặc áo dài').content,
      'người mặc ao dai Vietnamese long dress',
    );
    expect(parse('hai người ôm nhau').content, 'hai người hugging');
    expect(parse('banh mi').content, 'banh mi sandwich');
  });

  test('accents typed as combining marks', () {
    // "với Lan" with the accent of "ớ" typed as o + U+031B + U+0301
    final q = parse('biền với Lan');
    expect(q.friendId, 'lan');
    expect(q.content, 'biền');
    expect(foldAccents('Đà Nẵng'), 'da nang');
  });
}
