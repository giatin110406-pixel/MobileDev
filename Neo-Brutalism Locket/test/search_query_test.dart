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
