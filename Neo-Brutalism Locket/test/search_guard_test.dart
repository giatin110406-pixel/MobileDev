import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/search/search_guard.dart';

void main() {
  test('what a person is cannot be searched in photos', () {
    for (final text in [
      'gay',
      'Gays at the beach',
      'người đồng tính',
      'bê đê',
      'người chuyển giới',
      'LGBT',
      'LGBTQ+ parade',
      'muslim woman',
      'black people',
      'người da đen',
    ]) {
      expect(asksAboutPeople(text), isTrue, reason: text);
    }
  });

  test('things, places and everyday words are searched as usual', () {
    for (final text in [
      'gaylord hotel',
      'transport',
      'trans',
      'black cat',
      'áo đen',
      'man in black',
      'white shirt',
      'indian restaurant',
      'mosque',
      'chùa',
      'con chó',
      'ăn cơm tấm',
    ]) {
      expect(asksAboutPeople(text), isFalse, reason: text);
    }
  });
}
