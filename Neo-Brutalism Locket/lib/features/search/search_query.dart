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

  final rules = <RegExp, void Function(RegExpMatch)>{
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
  );
}
