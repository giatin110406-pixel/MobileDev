import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> load(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> keysOf(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

/// The `{name}` parts of a message, ignoring plural bodies' inner text.
Set<String> placeholders(String text) =>
    RegExp(r'\{(\w+)\s*[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final vi = load('vi');
  final en = load('en');

  test('both languages have exactly the same messages', () {
    expect(keysOf(vi).toSet().difference(keysOf(en).toSet()), isEmpty);
    expect(keysOf(en).toSet().difference(keysOf(vi).toSet()), isEmpty);
  });

  test('no message is empty', () {
    for (final arb in [vi, en]) {
      for (final key in keysOf(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('a message takes the same values in both languages', () {
    for (final key in keysOf(en)) {
      expect(
        placeholders(vi[key] as String),
        placeholders(en[key] as String),
        reason: key,
      );
    }
  });
}
