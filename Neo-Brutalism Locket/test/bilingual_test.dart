import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/quest/quest_catalog.dart';

/// Every word the app shows must exist in Vietnamese and in English. These
/// tests keep it that way: a new screen with a hard-coded sentence, or a
/// message nobody translated, fails here.

/// Letters only Vietnamese uses (đ, ă, ơ, ư and the tone-marked vowels), so
/// "café" or "Saint-Rémy" in an English text does not count as Vietnamese.
final _vietnameseLetters = RegExp(
  r'[ăơưđạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịĩọỏốồổỗộớờởỡợụủũứừửữựỳỵỷỹ]',
  caseSensitive: false,
);

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

void main() {
  group('language files', () {
    final en = _arb('en');
    final vi = _arb('vi');

    test('English messages contain no Vietnamese', () {
      // The name of the Vietnamese option in the language picker is written
      // in Vietnamese on purpose.
      const allowed = {'settingsLanguageVi'};
      for (final key in _messages(en).where((k) => !allowed.contains(k))) {
        expect(
          _vietnameseLetters.hasMatch(en[key] as String),
          isFalse,
          reason: '$key: ${en[key]}',
        );
      }
    });

    test('a Vietnamese message that equals the English one is a real name', () {
      // Proper names, loan words and symbols that read the same in both.
      const sameInBoth = {
        'appTitle',
        'ok',
        'emailLabel',
        'friendsOnline',
        'settingsEmail',
        'settingsLanguageVi',
        'settingsLanguageEn',
        'menuTooltip',
        'rankTop3',
        'kindBanner',
        // The name of the room is the same in both languages.
        'hallOfFameButton',
        'hallOfFameTitle',
      };
      for (final key in _messages(en)) {
        if (sameInBoth.contains(key)) continue;
        expect(
          vi[key],
          isNot(en[key]),
          reason: '$key looks untranslated: ${en[key]}',
        );
      }
    });
  });

  group('daily quests', () {
    for (final quest in questCatalog) {
      test('${quest.id} reads in English and in Vietnamese', () {
        for (final english in [
          quest.subjectEn,
          quest.storyTitleEn,
          quest.storyEn,
          quest.captionEn,
        ]) {
          expect(english, isNotNull, reason: quest.id);
          expect(english!.trim(), isNotEmpty, reason: quest.id);
          expect(
            _vietnameseLetters.hasMatch(english),
            isFalse,
            reason: english,
          );
        }
        // The title may be a game's own name (Pac-Man), the rest is prose.
        expect(quest.subjectEn, isNot(quest.subject), reason: quest.id);
        expect(quest.storyEn, isNot(quest.story), reason: quest.id);
        expect(quest.captionEn, isNot(quest.caption), reason: quest.id);
        expect(quest.storyEn!.length, greaterThan(80), reason: quest.id);
      });
    }

    test('the accessors pick the language', () {
      final quest = questCatalog.first;
      expect(quest.subjectFor(vietnamese: true), quest.subject);
      expect(quest.subjectFor(vietnamese: false), quest.subjectEn);
      expect(quest.storyFor(vietnamese: false), quest.storyEn);
    });
  });

  group('no hard-coded sentences in the screens', () {
    // Text that is allowed to stay as it is: names, loan words, symbols.
    const allowed = {
      'POCKET PORTRAIT',
      'VAN GOGH',
      '8-BIT',
      '8-bit',
      'Van Gogh',
      'CHAT',
      'CANVAS',
      'Gallery',
      'REC',
      'CPU',
      'OK',
    };
    // Where the words come from data, not from screens.
    const skipFiles = {
      'quest_catalog.dart',
      'legal_text.dart',
      'shop_catalog.dart',
      'social_repository.dart',
    };

    // A literal given straight to something the user reads.
    final shown = RegExp(
      r'''(?:Text|NeoLabel|SelectableText)\(\s*(?:const\s+)?['"]([^'"$\n]*[A-Za-zÀ-ỹ]{3}[^'"$\n]*)['"]'''
      r'''|(?:label|tooltip|hintText|labelText|semanticLabel|helperText|errorText|title|subtitle|actionLabel)\s*:\s*(?:const\s+)?['"]([^'"$\n]*[A-Za-zÀ-ỹ]{3}[^'"$\n]*)['"]'''
      r'''|(?:_notify|showNeoSnack)\((?:context,\s*)?['"]([^'"$\n]*[A-Za-zÀ-ỹ]{3}[^'"$\n]*)['"]''',
    );

    test('screens take their words from the language files', () {
      final found = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (path.contains('lib/l10n/')) continue;
        if (skipFiles.any(path.endsWith)) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          for (final match in shown.allMatches(line)) {
            final text = match.group(1) ?? match.group(2) ?? match.group(3)!;
            if (allowed.contains(text)) continue;
            found.add('$path:${i + 1}: "$text"');
          }
        }
      }
      expect(found, isEmpty, reason: found.join('\n'));
    });
  });
}
