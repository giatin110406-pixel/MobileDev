import 'dart:math' as math;
import 'dart:ui';

/// What kind of private detail a finding is.
enum SensitiveKind {
  /// A 12-digit citizen ID number (CCCD).
  idNumber,

  /// A Vietnamese mobile or landline number.
  phone,

  /// A Vietnamese licence plate (car, or the two lines of a motorbike plate).
  plate,

  /// A bank card number (16 digits that pass the Luhn check).
  card,

  /// A house address: a house number with a street, alley or ward word.
  address,

  /// An identity document: ID card, driving licence, passport.
  idDocument,

  /// Text on a photographed screen (messages, a chat, an app).
  screenText,
}

/// One line of text read from the photo, with where it is (image pixels).
class TextLine {
  const TextLine(this.text, this.box);
  final String text;
  final Rect box;
}

/// A region of the photo that may show something private.
class SensitiveFinding {
  const SensitiveFinding(this.kind, this.box, this.text);
  final SensitiveKind kind;

  /// The region to cover, in image pixels.
  final Rect box;

  /// What was read there (shown to the person, never sent anywhere).
  final String text;

  @override
  String toString() => 'SensitiveFinding($kind, $text, $box)';
}

/// Finds private details in the text read from a photo.
///
/// Only patterns that can be checked are reported: a number has to have the
/// exact shape of a phone number, an ID number, a plate or a card, so prices,
/// dates and times are not mistaken for them. [screen] says the photo is of
/// a display (from the pixel-grid test); then its text is treated as private
/// as soon as there are a few lines of it.
List<SensitiveFinding> findSensitive(
  List<TextLine> lines, {
  bool screen = false,
}) {
  final out = <SensitiveFinding>[];
  final documentLines = <TextLine>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final digits = _digitText(line.text);
    final plain = foldVietnamese(line.text).toUpperCase();

    if (_documentWords.any(plain.contains) || _mrz.hasMatch(plain)) {
      documentLines.add(line);
    }
    final card = _cardNumber(digits);
    if (card != null) {
      out.add(SensitiveFinding(SensitiveKind.card, line.box, card));
      continue;
    }
    final id = _idNumber.firstMatch(digits);
    if (id != null) {
      out.add(SensitiveFinding(SensitiveKind.idNumber, line.box, id[0]!));
      continue;
    }
    final phone = _phone.firstMatch(digits);
    if (phone != null) {
      out.add(SensitiveFinding(SensitiveKind.phone, line.box, phone[0]!));
      continue;
    }
    final plate = _plate(plain, i, lines);
    if (plate != null) {
      out.add(SensitiveFinding(SensitiveKind.plate, plate.$2, plate.$1));
      continue;
    }
    if (_isAddress(plain)) {
      out.add(SensitiveFinding(SensitiveKind.address, line.box, line.text));
    }
  }

  if (documentLines.isNotEmpty) {
    out.add(
      SensitiveFinding(
        SensitiveKind.idDocument,
        _documentRegion(documentLines, lines),
        documentLines.first.text,
      ),
    );
  }
  if (screen) {
    final words = lines.where((l) => _letters.hasMatch(l.text)).toList();
    if (words.length >= 3) {
      out.add(
        SensitiveFinding(
          SensitiveKind.screenText,
          _union(words.map((l) => l.box)),
          words.first.text,
        ),
      );
    }
  }
  return out;
}

// Numbers ----------------------------------------------------------------------------------

/// The line with the separators people put inside numbers removed and the
/// letters OCR confuses with digits fixed, but only inside digit runs.
String _digitText(String text) {
  final fixed = text.replaceAllMapped(
    RegExp(r'(?<=\d)[OoQDIl|](?=[\d\s.\-])|(?<=[\d\s.\-])[OoQDIl|](?=\d)'),
    (m) => switch (m[0]) {
      'O' || 'o' || 'Q' || 'D' => '0',
      _ => '1',
    },
  );
  // "0912 345 678", "091.234.5678", "0912-345-678", "+84 912 345 678".
  return fixed.replaceAllMapped(RegExp(r'(?<=\d)[\s.\-](?=\d)'), (_) => '');
}

/// 12 digits on their own: the CCCD number.
final _idNumber = RegExp(r'(?<!\d)0\d{11}(?!\d)');

/// Mobile (03, 05, 07, 08, 09 + 8 digits) and landline (02x + 8 digits),
/// with 0 or +84 in front.
final _phone = RegExp(r'(?<![\d])(?:\+?84|0)(?:[35789]\d{8}|2\d{9})(?!\d)');

String? _cardNumber(String digits) {
  for (final m in RegExp(r'(?<!\d)\d{16}(?!\d)').allMatches(digits)) {
    final number = m[0]!;
    if (_luhn(number)) return number;
  }
  return null;
}

bool _luhn(String number) {
  var sum = 0;
  for (var i = 0; i < number.length; i++) {
    var d = number.codeUnitAt(number.length - 1 - i) - 48;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

// Plates -----------------------------------------------------------------------------------

/// Car: "51F-123.45", "30A 12345", "51LD-123.45". Province codes are 11..99.
final _carPlate = RegExp(
  r'(?<![A-Z0-9])(1[1-9]|[2-9]\d)\s*-?\s*([A-Z]{1,2}\d?)\s*-?\s*(\d{3}\.?\d{2}|\d{4})(?![A-Z0-9])',
);

/// Motorbike plates are two lines: "59-X1" over "123.45".
final _bikeTop = RegExp(r'^\s*(1[1-9]|[2-9]\d)\s*-?\s*([A-Z]{1,2}\d?)\s*$');
final _bikeBottom = RegExp(r'^\s*(\d{3}\.\d{2}|\d{5}|\d{4})\s*$');

(String, Rect)? _plate(String plain, int index, List<TextLine> lines) {
  final car = _carPlate.firstMatch(plain);
  if (car != null && !_looksLikeTime(car[0]!)) {
    return (car[0]!.trim(), lines[index].box);
  }
  final top = _bikeTop.firstMatch(plain);
  if (top == null) return null;
  final box = lines[index].box;
  for (final other in lines) {
    if (identical(other, lines[index])) continue;
    final below =
        other.box.top >= box.top + box.height * .4 &&
        other.box.top <= box.bottom + box.height * 1.2;
    final aligned =
        (other.box.center.dx - box.center.dx).abs() <
        math.max(box.width, other.box.width) * .6;
    if (below && aligned && _bikeBottom.hasMatch(other.text)) {
      return (
        '${top[0]!.trim()} ${other.text.trim()}',
        box.expandToInclude(other.box),
      );
    }
  }
  return null;
}

bool _looksLikeTime(String s) => RegExp(r'\d{1,2}:\d{2}').hasMatch(s);

// Addresses --------------------------------------------------------------------------------

/// "Số 25 Ngõ 12 Phố Huế", "123/4 Đường Nguyễn Trãi", "Số nhà 7", "Hẻm 51".
final _houseNumber = RegExp(
  r'(?<![\d.,:])\d{1,5}[A-Z]?(?:/\d{1,5}[A-Z]?)*(?![\d.,:%])',
);
final _streetWord = RegExp(
  r'\b(?:SO NHA|DUONG|PHO|NGO|NGACH|HEM|KIET|THON|XOM|AP|TO DAN PHO|PHUONG|QUAN|HUYEN|THANH PHO|TP|P|Q)\b',
);

bool _isAddress(String plain) {
  if (plain.contains('SO NHA') && _houseNumber.hasMatch(plain)) return true;
  final words = _streetWord.allMatches(plain).map((m) => m[0]!).toSet();
  if (words.isEmpty || !_houseNumber.hasMatch(plain)) return false;
  // One short word alone ("P", "Q", "TP") is too weak; ask for a real
  // street word or two of them.
  const weak = {'P', 'Q', 'TP'};
  return words.length >= 2 || !weak.contains(words.single);
}

// Documents --------------------------------------------------------------------------------

const _documentWords = [
  'CAN CUOC',
  'CONG HOA XA HOI CHU NGHIA VIET NAM',
  'CHUNG MINH NHAN DAN',
  'SOCIALIST REPUBLIC OF VIET NAM',
  'CITIZEN IDENTITY',
  'IDENTITY CARD',
  'GIAY PHEP LAI XE',
  'DRIVER\'S LICENSE',
  'DRIVING LICENCE',
  'HO CHIEU',
  'PASSPORT',
];

/// The machine-readable lines at the bottom of an ID card or passport.
final _mrz = RegExp(r'[A-Z0-9]{5,}<{2,}');

/// The card around its title: every line from a bit above the title to well
/// below it, within the title's column.
Rect _documentRegion(List<TextLine> titles, List<TextLine> lines) {
  final title = _union(titles.map((l) => l.box));
  final lineHeight = titles.map((l) => l.box.height).reduce(math.max);
  final area = Rect.fromLTRB(
    title.left - title.width * .6,
    title.top - lineHeight * 3,
    title.right + title.width * .6,
    title.bottom + lineHeight * 25,
  );
  final inside = lines.where((l) => area.contains(l.box.center));
  final region = _union([title, ...inside.map((l) => l.box)]);
  return region.inflate(lineHeight);
}

// Helpers ----------------------------------------------------------------------------------

final _letters = RegExp(r'[A-Za-zÀ-ỹ]{2,}');

Rect _union(Iterable<Rect> boxes) =>
    boxes.reduce((a, b) => a.expandToInclude(b));

/// Vietnamese text without its accents, đ as d (so "Căn cước" matches
/// "CAN CUOC" however the OCR read the marks).
String foldVietnamese(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_fold[char] ?? char);
  }
  return buffer.toString();
}

final Map<String, String> _fold = () {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final map = <String, String>{};
  groups.forEach((base, accented) {
    for (final rune in accented.runes) {
      final char = String.fromCharCode(rune);
      map[char] = base;
      map[char.toUpperCase()] = base.toUpperCase();
    }
  });
  return map;
}();
