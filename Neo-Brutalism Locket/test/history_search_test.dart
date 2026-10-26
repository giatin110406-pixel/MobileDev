import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/history/history_screen.dart';
import 'package:neo_brutalism_locket/features/search/photo_search.dart';
import 'package:neo_brutalism_locket/features/search/search_index.dart';

import 'history_test.dart' show app;
import 'photo_search_test.dart' show FakeBackend, axisVector, post, uuid;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('history_search'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  final lan = const Person(
    id: 'lan',
    username: 'lan',
    displayName: 'Lan Nguyen',
  ).toPocketFriend();

  Future<List<(List<String>, int)>> pump(
    WidgetTester tester, {
    bool modelsReady = true,
    bool bank = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      {
        uuid(1): post(1, author: 'lan'),
        uuid(2): post(2),
        uuid(3): post(3, author: 'lan'),
      },
      {uuid(1): axisVector(0), uuid(2): axisVector(0), uuid(3): axisVector(7)},
    );
    final search = PhotoSearch(
      myId: 'me',
      backend: backend,
      index: SearchIndex(
        userId: 'me',
        source: backend,
        folder: () async => dir,
      ),
      clock: () => DateTime(2026, 10, 22),
      // Reading the label bank from the asset bundle works once per test file;
      // a test that needs no bank says so.
      loadBank: bank ? null : () async => throw StateError('no bank'),
      encodeText: modelsReady
          ? (english) async => axisVector(english.contains('dog') ? 0 : 3)
          : null,
    );
    final opened = <(List<String>, int)>[];
    await tester.pumpWidget(
      app(
        Scaffold(
          body: HistoryScreen(
            posts: [
              for (final n in [3, 2, 1]) post(n),
            ],
            friends: [lan],
            myId: 'me',
            search: search,
            onOpen: (shown, index) =>
                opened.add(([for (final p in shown) p.id], index)),
          ),
        ),
      ),
    );
    await tester.pump();
    return opened;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // The search does real file work; give it real time until the spinner
    // is gone (pumpAndSettle would wait on the spinner forever).
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();
  }

  /// Waits until a search has shown its result count (and no spinner).
  Future<void> results(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.textContaining('PHOTOS').evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
  }

  testWidgets('typing a search shows the matching photos and the filters it '
      'understood; clearing brings the history back', (tester) async {
    final opened = await pump(tester);
    expect(find.text('ALL'), findsOneWidget);

    await type(tester, 'dog with Lan');
    expect(find.text('Lan'), findsOneWidget, reason: 'friend chip');
    // Lan's dog photo first; my own dog photo, which does not say Lan is in
    // it, is still there after it.
    expect(find.text('2 PHOTOS'), findsOneWidget);
    expect(find.byType(RemoteImage), findsNWidgets(2));
    await tester.tap(find.byType(RemoteImage).first);
    expect(opened.single.$1, [uuid(1), uuid(2)]);
    expect(opened.single.$2, 0);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('ALL'), findsOneWidget);
    expect(find.byType(RemoteImage), findsNWidgets(3));
  });

  testWidgets('a name typed without "with" is offered as a chip; a tap applies '
      'it', (tester) async {
    await pump(tester, bank: false);
    await type(tester, 'Lan dog');
    await results(tester);
    // nothing applied yet: both dog photos are clear matches
    expect(find.text('WITH LAN?'), findsOneWidget);
    expect(find.text('2 PHOTOS'), findsOneWidget);

    await tester.tap(find.text('WITH LAN?'));
    await results(tester);
    expect(find.text('Lan'), findsOneWidget, reason: 'now a friend filter');
    expect(find.text('WITH LAN?'), findsNothing);
  });

  testWidgets('a search about what a person is says photos cannot tell', (
    tester,
  ) async {
    await pump(tester, bank: false);
    await type(tester, 'gay');
    await results(tester);
    expect(find.textContaining("can't tell"), findsOneWidget);
    expect(find.byType(RemoteImage), findsNothing);
  });

  testWidgets('a Vietnamese search without the language pack offers it', (
    tester,
  ) async {
    await pump(tester, modelsReady: false);
    await type(tester, 'con chó');
    expect(find.text('GET THE VIETNAMESE PACK'), findsOneWidget);
    expect(find.textContaining('about 30 MB'), findsOneWidget);
  });
}
