import 'dart:math' as math;

/// What a typed search asks for (archive-ai-search-plan.md, C3): who and when
/// become filters, because a photo model cannot see them; what is left is the
/// picture to look for.
///
/// "áo đỏ cạnh xe máy với Lan năm ngoái" ->
///   content "áo đỏ cạnh xe máy", friend Lan, 2025-01-01 .. 2026-01-01
class SearchQuery {
  const SearchQuery({
    required this.content,
    this.friendId,
    this.mine = false,
    this.from,
    this.until,
    this.friendHints = const [],
  });

  /// What to look for in the photo, in the typed language, with the glossary
  /// already applied. Empty when the search is only about who / when.
  final String content;

  /// Posts this friend sent me or I sent them.
  final String? friendId;

  /// Only my own posts ("của tôi", "mine").
  final bool mine;

  /// Inclusive start / exclusive end, local time.
  final DateTime? from;
  final DateTime? until;

  /// Friends whose name is in the what-to-look-for part of the search without a
  /// "with" in front ("Lan ăn lẩu"). Not applied: the screen offers them as
  /// one-tap filters, since a name can also be an ordinary word.
  final List<SearchFriend> friendHints;

  bool get hasFilters => friendId != null || mine || from != null;
}

/// A friend as the parser needs them.
typedef SearchFriend = ({String id, String name});

/// Lower case without Vietnamese accents, for matching what people type with
/// or without them. Accents typed as separate combining marks are dropped too.
String foldAccents(String text) => _fold(text).text;

/// [text] folded, and for each folded character the index it came from, so a
/// match in the folded text can be cut out of the typed one.
({String text, List<int> origin}) _fold(String text) {
  final out = StringBuffer();
  final origin = <int>[];
  final lower = text.toLowerCase();
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    if (unit >= 0x300 && unit <= 0x36f) continue; // combining accent
    out.write(_plain[lower[i]] ?? lower[i]);
    origin.add(i);
  }
  origin.add(lower.length);
  return (text: out.toString(), origin: origin);
}

final Map<String, String> _plain = () {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  return <String, String>{
    for (final e in groups.entries)
      for (final c in e.value.split('')) c: e.key,
  };
}();

/// Words ML Kit gets wrong or that the photo model knows under another name
/// (measured on the owner's phone, plan A6). Keys are accent-folded.
const searchGlossary = {
  'ao dai': 'ao dai Vietnamese long dress',
  'banh mi': 'banh mi sandwich',
  'om nhau': 'hugging',
  'chup anh chung': 'group photo',
  'anh chung': 'group photo',
  'lop hoc': 'classroom',
  'non la': 'conical hat',
  'xe om': 'motorbike taxi',
};

final _space = RegExp(r'\s+');

SearchQuery parseSearchQuery(
  String typed, {
  required List<SearchFriend> friends,
  required DateTime now,
  String? pinFriend,
}) {
  var text = ' ${typed.trim().replaceAll(_space, ' ')} ';
  String? friendId;
  var mine = false;
  DateTime? from;
  DateTime? until;

  // Cuts [pattern] (matched on the accent-folded text) out of [text].
  bool take(RegExp pattern, void Function(RegExpMatch m) use) {
    final folded = _fold(text);
    final m = pattern.firstMatch(folded.text);
    if (m == null) return false;
    use(m);
    text =
        '${text.substring(0, folded.origin[m.start])} '
        '${text.substring(folded.origin[m.end])}';
    return true;
  }

  // Who. Full names first, longest first ("Lan Anh" before "Lan"), then
  // first names, so a friend called "Lan" is not taken for "Lan Anh".
  final byLength = [...friends]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  final names = [
    for (final f in byLength) (f.id, foldAccents(f.name.trim())),
    for (final f in byLength)
      (f.id, foldAccents(f.name.trim().split(' ').first)),
  ];
  for (final (id, name) in names) {
    if (take(
      RegExp(
        ' (?:voi|cua|tu|gui|from|with|by) (?:ban )?${RegExp.escape(name)}(?= )',
      ),
      (_) => friendId = id,
    )) {
      break;
    }
  }
  take(
    RegExp(' (?:cua (?:toi|minh|tao|tui)|toi chup|minh chup|mine|my own)(?= )'),
    (_) => mine = true,
  );

  // When.
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = day(now);
  void range(DateTime a, DateTime b) {
    from = a;
    until = b;
  }

  DateTime dayAt(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  // A remembered span is never exact: "6 months ago" means roughly then, so
  // the range is widened by a quarter of the span (at least a few days).
  void ago(double days, int least) {
    final slack = math.max(least, (days * 0.25).round());
    final centre = days.round();
    final end = dayAt(-centre + slack + 1);
    range(dayAt(-centre - slack), end.isAfter(dayAt(1)) ? dayAt(1) : end);
  }

  final rules = <RegExp, void Function(RegExpMatch)>{
    // These come first: "3 nam truoc" must not be read as "nam truoc", nor
    // "half a year ago" as "a year ago".
    RegExp(
      ' $_roughly(?:nua nam|half a year|half year|half-year) '
      '(?:truoc|roi|ago)(?= )',
    ): (_) =>
        ago(182.5, 20),
    RegExp(' $_roughly($_count) ($_unit) (?:truoc|roi|ago)(?= )'): (m) => ago(
      _countOf(m.group(1)!) * _daysIn(m.group(2)!),
      _leastSlack(m.group(2)!),
    ),
    RegExp(
      ' (?:(?:a )?few|several|vai|may) ($_unit) (?:truoc|roi|ago)(?= )',
    ): (m) {
      final unit = _daysIn(m.group(1)!);
      range(dayAt(-(5 * unit).round()), dayAt(-(1.5 * unit).round() + 1));
    },
    RegExp(' (?:hom kia|the day before yesterday)(?= )'): (_) =>
        range(dayAt(-2), dayAt(-1)),
    // "mua he nam ngoai", "last summer", "mua dong 2024"
    RegExp(
      ' (?:mua (he|dong|xuan|thu)|(?:in|last|this) '
      '(summer|winter|spring|autumn|fall))'
      r'(?: (nam ngoai|nam truoc|nam roi|last year|nam nay|this year|'
      r'(?:(?:nam|in) )?(20\d\d)))?(?= )',
    ): (m) {
      final start = switch (m.group(1) ?? m.group(2)) {
        'xuan' || 'spring' => 3,
        'he' || 'summer' => 6,
        'thu' || 'autumn' || 'fall' => 9,
        _ => 12,
      };
      final phrase = m.group(3);
      final int year;
      if (m.group(4) != null) {
        year = int.parse(m.group(4)!);
      } else if (phrase == null) {
        // the latest one that has begun
        year = DateTime(now.year, start).isAfter(today)
            ? now.year - 1
            : now.year;
      } else {
        final past =
            phrase.contains('ngoai') ||
            phrase.contains('truoc') ||
            phrase.contains('roi') ||
            phrase.contains('last');
        year = past ? now.year - 1 : now.year;
      }
      range(DateTime(year, start), DateTime(year, start + 3));
    },
    RegExp(' (?:hom nay|today)(?= )'): (_) =>
        range(today, today.add(const Duration(days: 1))),
    RegExp(' (?:hom qua|yesterday)(?= )'): (_) =>
        range(today.subtract(const Duration(days: 1)), today),
    RegExp(' (?:tuan nay|this week)(?= )'): (_) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      range(monday, monday.add(const Duration(days: 7)));
    },
    RegExp(' (?:tuan truoc|tuan roi|last week)(?= )'): (_) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      range(monday.subtract(const Duration(days: 7)), monday);
    },
    RegExp(' (?:thang nay|this month)(?= )'): (_) =>
        range(DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
    RegExp(' (?:thang truoc|thang roi|last month)(?= )'): (_) =>
        range(DateTime(now.year, now.month - 1), DateTime(now.year, now.month)),
    RegExp(' (?:nam nay|this year)(?= )'): (_) =>
        range(DateTime(now.year), DateTime(now.year + 1)),
    RegExp(' (?:nam ngoai|nam truoc|nam roi|last year)(?= )'): (_) =>
        range(DateTime(now.year - 1), DateTime(now.year)),
    // "tháng 10 năm 2025", "tháng 10" (the last one that has begun)
    RegExp(r' thang (1[0-2]|[1-9])(?: nam (20\d\d))?(?= )'): (m) {
      final month = int.parse(m.group(1)!);
      final year = m.group(2) != null
          ? int.parse(m.group(2)!)
          : (month <= now.month ? now.year : now.year - 1);
      range(DateTime(year, month), DateTime(year, month + 1));
    },
    RegExp(r' (?:nam|in) (20\d\d)(?= )'): (m) {
      final year = int.parse(m.group(1)!);
      range(DateTime(year), DateTime(year + 1));
    },
  };
  for (final rule in rules.entries) {
    if (take(rule.key, rule.value)) break;
  }

  // Filler words in front ("ảnh", "những tấm hình", "photos of"). Matched on
  // the typed text: without accents "anh" is also "brother", so a bare "anh"
  // only counts when "có / chụp / về" follows.
  var content = text.replaceAll(_space, ' ').trim();
  final filler = RegExp(
    r'^(?:(?:tìm|tim) |cho (?:tôi|toi|mình|minh) xem )?(?:(?:những|nhung|các|cac) )?(?:(?:tấm|tam|bức|buc) )?(?:ảnh|hình|hinh|photos?|pictures?|anh(?= (?:có|co|chụp|chup|về|ve)(?: |$)))(?: (?:có|co|chụp|chup|về|ve|of|with))?(?: |$)',
  ).firstMatch(content.toLowerCase());
  if (filler != null) content = content.substring(filler.end).trim();

  // A name with no "with" in front: offered, not applied. When the person
  // already tapped the offer ([pinFriend]) it is applied and the name leaves
  // the picture part of the search.
  var hints = const <SearchFriend>[];
  if (friendId == null) {
    final pinned = friends.where((f) => f.id == pinFriend).firstOrNull;
    if (pinned != null) {
      friendId = pinned.id;
      for (final form in _nameForms(pinned)) {
        final cut = _cutWord(content, form);
        if (cut != null) {
          content = cut;
          break;
        }
      }
    } else {
      hints = _friendHints(content, friends);
    }
  }

  // Glossary, matched without accents, written in English in place.
  for (final entry in searchGlossary.entries) {
    final f = _fold(content);
    final at = f.text.indexOf(entry.key);
    if (at >= 0) {
      content =
          '${content.substring(0, f.origin[at])}${entry.value}'
                  '${content.substring(f.origin[at + entry.key.length])}'
              .trim();
    }
  }

  return SearchQuery(
    content: content,
    friendId: friendId,
    mine: mine,
    from: from,
    until: until,
    friendHints: hints,
  );
}

// Words that only say "about": the range is widened anyway.
const _roughly =
    '(?:(?:tam|khoang|gan|hon|around|about|roughly|approximately|nearly|'
    'cach day) )*';
const _count =
    r'\d{1,3}|mot|hai|ba|bon|nam|sau|bay|tam|chin|muoi|one|two|three|four|'
    'five|six|seven|eight|nine|ten|an?';
const _unit = 'ngay|tuan|thang|nam|days?|weeks?|months?|years?';

const _numberWords = {
  'mot': 1,
  'hai': 2,
  'ba': 3,
  'bon': 4,
  'nam': 5,
  'sau': 6,
  'bay': 7,
  'tam': 8,
  'chin': 9,
  'muoi': 10,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'a': 1,
  'an': 1,
};

double _countOf(String word) =>
    (_numberWords[word] ?? int.tryParse(word) ?? 1).toDouble();

/// Days in one [unit] (a word of [_unit]).
double _daysIn(String unit) {
  if (unit == 'ngay' || unit.startsWith('day')) return 1;
  if (unit == 'tuan' || unit.startsWith('week')) return 7;
  if (unit == 'thang' || unit.startsWith('month')) return 30.44;
  return 365.25; // nam / year
}

/// The least widening, in days, for a span in this unit.
int _leastSlack(String unit) => switch (_daysIn(unit)) {
  <= 1 => 2,
  <= 7 => 5,
  <= 31 => 20,
  _ => 90,
};

/// The folded spellings a friend can be called by: the full name, then the
/// first name.
List<String> _nameForms(SearchFriend friend) {
  final full = foldAccents(friend.name.trim());
  final first = full.split(' ').first;
  return [
    if (full.isNotEmpty) full,
    if (first.isNotEmpty && first != full) first,
  ];
}

RegExp _wholeWord(String folded) => RegExp(
  r'(?<![\p{L}\p{N}])' + RegExp.escape(folded) + r'(?![\p{L}\p{N}])',
  unicode: true,
);

/// [content] without the first whole word [name] (accent-folded); null when
/// it is not there.
String? _cutWord(String content, String name) {
  final folded = _fold(content);
  final m = _wholeWord(name).firstMatch(folded.text);
  if (m == null) return null;
  return '${content.substring(0, folded.origin[m.start])} '
          '${content.substring(folded.origin[m.end])}'
      .replaceAll(_space, ' ')
      .trim();
}

/// Friends named in [content]; "Lan Anh" typed in full is not also "Lan".
List<SearchFriend> _friendHints(String content, List<SearchFriend> friends) {
  final text = _fold(content).text;
  final found = <(SearchFriend, String)>[];
  for (final friend in friends) {
    for (final form in _nameForms(friend)) {
      if (_wholeWord(form).hasMatch(text)) {
        found.add((friend, form));
        break;
      }
    }
  }
  return [
    for (final (friend, form) in found)
      if (!found.any(
        (o) => o.$2.length > form.length && ' ${o.$2} '.contains(' $form '),
      ))
        friend,
  ].take(3).toList();
}
