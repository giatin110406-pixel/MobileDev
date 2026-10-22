import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/search/clip_tokenizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClipTokenizer tokenizer;
  setUpAll(() async => tokenizer = await ClipTokenizer.load());

  test(
    'gives the same ids as open_clip (server/eval/export_search_tokenizer.py)',
    () {
      final goldens =
          jsonDecode(
                File(
                  'test/fixtures/search/tokenizer_goldens.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cases = goldens['cases'] as List<dynamic>;
      expect(cases.length, greaterThan(500));
      final wrong = <String>[];
      for (final c in cases.cast<Map<String, dynamic>>()) {
        final want = (c['ids'] as List<dynamic>).cast<int>();
        final got = tokenizer.encode(c['text'] as String);
        final padded = [
          ...want,
          ...List.filled(ClipTokenizer.contextLength - want.length, 0),
        ];
        if (got.toList().join(',') != padded.join(',')) wrong.add(c['text']);
      }
      expect(wrong, isEmpty);
    },
  );

  test('always 77 ids, starting and ending with the special tokens', () {
    for (final text in ['', 'a dog', List.filled(200, 'word').join(' ')]) {
      final ids = tokenizer.encode(text);
      expect(ids.length, ClipTokenizer.contextLength);
      expect(ids.first, ClipTokenizer.startOfText);
      expect(ids.contains(ClipTokenizer.endOfText), isTrue);
    }
  });
}
