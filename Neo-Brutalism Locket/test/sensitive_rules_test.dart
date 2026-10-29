import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_rules.dart';

TextLine line(String text, [double top = 0, double left = 0]) =>
    TextLine(text, Rect.fromLTWH(left, top, 200, 20));

List<SensitiveKind> kinds(List<String> texts, {bool screen = false}) => [
  for (final f in findSensitive([
    for (var i = 0; i < texts.length; i++) line(texts[i], i * 30.0),
  ], screen: screen))
    f.kind,
];

void main() {
  group('phone numbers', () {
    for (final text in [
      '0912345678',
      'SĐT: 0912 345 678',
      'Liên hệ 091.234.5678',
      'Hotline 0912-345-678',
      '+84 912 345 678',
      '+84912345678',
      'ĐT 028 3823 4567',
      'Gọi O912345678', // OCR read 0 as O
    ]) {
      test('finds "$text"', () {
        expect(kinds([text]), [SensitiveKind.phone]);
      });
    }
  });

  group('citizen ID numbers', () {
    test('12 digits starting with 0', () {
      expect(kinds(['Số / No.: 079203001234']), [SensitiveKind.idNumber]);
    });
    test('13 digits is not a CCCD', () {
      expect(kinds(['0792030012345']), isEmpty);
    });
  });

  group('licence plates', () {
    for (final text in [
      '51F-123.45',
      '30A 123.45',
      '29A-12345',
      '51LD-123.45',
    ]) {
      test('car plate "$text"', () {
        expect(kinds([text]), [SensitiveKind.plate]);
      });
    }
    test('motorbike plate on two lines is one finding over both', () {
      final found = findSensitive([
        TextLine('59-X1', const Rect.fromLTWH(100, 100, 80, 30)),
        TextLine('123.45', const Rect.fromLTWH(95, 135, 90, 30)),
      ]);
      expect(found, hasLength(1));
      expect(found.single.kind, SensitiveKind.plate);
      expect(found.single.box, const Rect.fromLTRB(95, 100, 185, 165));
    });
    test('a lone "59-X1" without the number under it is not reported', () {
      expect(kinds(['59-X1']), isEmpty);
    });
  });

  group('bank cards', () {
    test('16 digits that pass Luhn', () {
      expect(kinds(['4111 1111 1111 1111']), [SensitiveKind.card]);
    });
    test('16 digits that fail Luhn are left alone', () {
      expect(kinds(['4111 1111 1111 1112']), isEmpty);
    });
  });

  group('addresses', () {
    for (final text in [
      'Số 25 Ngõ 12 Phố Huế',
      '123/4 Đường Nguyễn Trãi',
      'Số nhà 7',
      'Hẻm 51 Lê Văn Sỹ',
      '45 Lý Thường Kiệt, P. 7, Q. 10',
    ]) {
      test('finds "$text"', () {
        expect(kinds([text]), [SensitiveKind.address]);
      });
    }
    test('a street name without a number is not an address', () {
      expect(kinds(['Đường Nguyễn Trãi']), isEmpty);
    });
  });

  group('identity documents', () {
    test('the CCCD title marks the card around it', () {
      final found = findSensitive([
        TextLine(
          'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
          const Rect.fromLTWH(100, 100, 400, 20),
        ),
        TextLine('CĂN CƯỚC CÔNG DÂN', const Rect.fromLTWH(150, 130, 300, 24)),
        TextLine(
          'Họ và tên: NGUYỄN VĂN A',
          const Rect.fromLTWH(160, 200, 250, 20),
        ),
        // Far away: a caption elsewhere in the photo.
        TextLine('Cafe sáng', const Rect.fromLTWH(1500, 1500, 120, 20)),
      ]);
      final card = found.singleWhere((f) => f.kind == SensitiveKind.idDocument);
      expect(card.box.contains(const Offset(300, 210)), isTrue);
      expect(card.box.contains(const Offset(1550, 1510)), isFalse);
    });
    test('without accents too (OCR often drops them)', () {
      expect(kinds(['CAN CUOC CONG DAN']), [SensitiveKind.idDocument]);
    });
    test('the machine-readable zone of a passport', () {
      expect(kinds(['P<VNMNGUYEN<<VAN<A<<<<<<<<<<']), [
        SensitiveKind.idDocument,
      ]);
    });
  });

  group('screens', () {
    test('a few lines of text on a photographed screen', () {
      expect(kinds(['Lan', 'Tối nay đi ăn không', 'Ok 7h nhé'], screen: true), [
        SensitiveKind.screenText,
      ]);
    });
    test('the same text on paper is not reported', () {
      expect(kinds(['Lan', 'Tối nay đi ăn không', 'Ok 7h nhé']), isEmpty);
    });
    test('a screen with one word is not reported', () {
      expect(kinds(['Netflix'], screen: true), isEmpty);
    });
  });

  group('things that are not private', () {
    for (final text in [
      '35.000đ',
      '1.250.000 VND',
      '29/10/2026',
      '14:05',
      'Mở cửa 7:00 - 22:00',
      'OPEN',
      'Trà sữa size L',
      'Bàn 12',
      '2026',
      'Wifi: cafe12345',
    ]) {
      test('"$text"', () => expect(kinds([text]), isEmpty));
    }
  });

  test('foldVietnamese drops the accents and đ', () {
    expect(foldVietnamese('Căn cước Đường'), 'Can cuoc Duong');
  });
}
