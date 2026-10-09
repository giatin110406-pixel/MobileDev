import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

// The files in test/fixtures/contest are real answers of the project's server,
// recorded by `E2E_DUMP=test/fixtures/contest python supabase/e2e/e2e_contest.py`.
// Reading them here catches the day the server's JSON and the app's parsing
// stop agreeing (like the base64 line breaks that once stopped the canvas loading).
dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/contest/$name.json').readAsStringSync());

void main() {
  test('the overview of the current contest', () {
    final overview = ContestOverview.fromJson(
      fixture('overview') as Map<String, dynamic>,
    )!;
    expect(overview.contest.weekKey, startsWith('2026-W'));
    expect(overview.contest.maxEntries, 100);
    expect(overview.contest.opensAt.isBefore(overview.contest.submitClosesAt), isTrue);
    expect(overview.contest.submitClosesAt.isBefore(overview.contest.endsAt), isTrue);
    expect(overview.theme.titleVi, isNotEmpty);
    expect(overview.theme.titleEn, isNotEmpty);
    expect(['8bit', 'vangogh'], contains(overview.theme.category));
    expect(overview.ownerGroups.length, 1);
    expect(overview.ownerGroups.single.submitted, isFalse);
    expect(overview.participant, isFalse);
    expect(overview.myEntry, isNull);
  });

  test('a page of the gallery', () {
    final page = GalleryPage.fromJson(fixture('gallery') as Map<String, dynamic>);
    expect(page.phase, ContestPhase.judging);
    expect(page.entries.map((e) => e.seq), [1, 2, 3]);
    expect(page.nextAfter, isNull);
    for (final entry in page.entries) {
      expect(entry.width, 32);
      expect(entry.height, 32);
      expect(entry.palette.length, 16);
      expect(entry.pixels.length, 1024);
      expect(entry.groupName, startsWith('E2E Team'));
      expect(entry.rank, isNull); // scores are hidden until the results
    }
    expect(page.entries.map((e) => e.mine), [true, false, false]);
  });

  test('one entry with its reactions and comment count', () {
    final detail = EntryDetail.fromJson(fixture('entry') as Map<String, dynamic>);
    expect(detail.phase, ContestPhase.judging);
    expect(detail.participant, isTrue);
    expect(detail.reactions, isA<Map<String, int>>());
    expect(detail.commentCount, 1);
    expect(detail.entry.pixels.length, 1024);
  });

  test('comments', () {
    final rows = fixture('comments') as List<dynamic>;
    final comments = [
      for (final row in rows) EntryComment.fromJson(row as Map<String, dynamic>),
    ];
    expect(comments.single.body, 'Love the colours');
    expect(comments.single.mine, isFalse);
    expect(comments.single.authorName, startsWith('E2E'));
  });

  test('the results: three winners, best first, with scores', () {
    final results = ContestResults.fromJson(
      fixture('results') as Map<String, dynamic>,
    );
    expect(results.phase, ContestPhase.finalized);
    expect(results.entryCount, 3);
    expect(results.winners.map((w) => w.rank), [1, 2, 3]);
    expect(
      results.winners.map((w) => w.score!.toStringAsFixed(4)),
      ['3.7222', '3.5000', '3.2778'],
    );
    expect(results.winners.every((w) => w.voteCount == 4), isTrue);
    expect(results.winners.first.pixels.length, 1024);
  });

  test('the Hall of Fame', () {
    final rows = fixture('hall') as List<dynamic>;
    final entries = [
      for (final row in rows) GalleryEntry.fromJson(row as Map<String, dynamic>),
    ];
    expect(entries.length, 3);
    expect(entries.map((e) => e.rank), [1, 2, 3]);
    expect(entries.first.weekKey, startsWith('E2E-'));
    expect(entries.first.titleEn, isNotEmpty);
  });
}
