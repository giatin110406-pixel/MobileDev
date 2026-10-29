import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/pov/pov_qr_sheet.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_scan.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'pov_store_test.dart' show FakePov, code32, friend, me, session;

PocketFriend person(String id, String name) => PocketFriend(
  id: id,
  name: name,
  handle: '@$id',
  avatarColor: 0xFFFF6B6B,
  isSample: false,
  addedAt: DateTime(2026),
);

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Moves on by a little time. `pumpAndSettle` would never end while a code is shown: its
/// countdown redraws every second.
Future<void> later(WidgetTester tester, [int milliseconds = 400]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.pump(Duration(milliseconds: milliseconds));
}

void main() {
  late FakePov repo;
  late PovStore store;

  setUp(() async {
    repo = FakePov();
    store = PovStore(repo, myId: me);
    await store.start();
  });

  tearDown(() => store.dispose());

  /// The end of a test: the screen goes, and so does what the store waits for.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await store.end();
  }

  group('the code sheet (A)', () {
    Future<void> open(WidgetTester tester, [PovStore? shown]) async {
      final target = shown ?? store;
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPovQrSheet(context, store: target),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await later(tester);
    }

    testWidgets('opens a code and shows it as a QR code', (tester) async {
      await open(tester);
      expect(repo.calls, ['create']);
      expect(
        find.text("SEE YOURSELF THROUGH A FRIEND'S CAMERA"),
        findsOneWidget,
      );
      // The code carries the app's own link.
      expect(
        find.byKey(const ValueKey('neolocket://pov/$code32')),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('scans this code'), findsOneWidget);
      expect(find.textContaining('Valid for'), findsOneWidget);
      await done(tester);
    });

    testWidgets('the code is black on white, for the best scan', (
      tester,
    ) async {
      await open(tester);
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, Colors.white);
      expect(qr.eyeStyle.color, Colors.black);
      expect(qr.dataModuleStyle.color, Colors.black);
      await done(tester);
    });

    testWidgets('closing it takes the code back', (tester) async {
      await open(tester);
      await tester.tap(find.text('CLOSE'));
      await later(tester);
      expect(repo.calls, contains('cancel:s1'));
      expect(store.session, isNull);
      expect(find.byType(QrImageView), findsNothing);
      await done(tester);
    });

    testWidgets('dismissing it by tapping outside takes the code back', (
      tester,
    ) async {
      await open(tester);
      await tester.tapAt(const Offset(200, 40));
      await later(tester);
      expect(repo.calls, contains('cancel:s1'));
      expect(store.session, isNull);
      await done(tester);
    });

    testWidgets('it closes by itself when a friend scans it', (tester) async {
      await open(tester);
      repo.updates.add(
        session(id: 's1', host: friend, status: PovStatus.accepted),
      );
      await later(tester);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(store.isWatching, isTrue);
      await done(tester);
    });

    testWidgets('a refusal from the server is said in words, with a way on', (
      tester,
    ) async {
      repo.failNext = const PovFailure(PovFailureKind.busy);
      await open(tester);
      expect(
        find.text('Omni POV is in use already. Finish that first.'),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      await tester.tap(find.text('NEW CODE'));
      await later(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      await done(tester);
    });

    testWidgets('a code that ran out says so and can be renewed', (
      tester,
    ) async {
      // The test's timers are not the clock: this store's clock is moved by hand.
      var now = DateTime.now();
      final clocked = PovStore(repo, myId: me, clock: () => now);
      await clocked.start();
      repo.codeLasts = const Duration(milliseconds: 100);
      await open(tester, clocked);
      now = now.add(const Duration(seconds: 1));
      await later(tester, 300);
      expect(find.text('This code ran out.'), findsOneWidget);
      repo.codeLasts = const Duration(minutes: 2);
      await tester.tap(find.text('NEW CODE'));
      await later(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(repo.calls.where((c) => c == 'create').length, 2);
      await tester.pumpWidget(const SizedBox());
      await clocked.end();
      clocked.dispose();
    });
  });

  group('scanning (B)', () {
    final lan = person(friend, 'Lan Chi');

    /// A button that runs the join flow for the code in [code32].
    Future<void> pump(WidgetTester tester, {List<PocketFriend>? friends}) {
      bigScreen(tester);
      return tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => joinPovWithCode(
                  context,
                  store: store,
                  code: code32,
                  friends: friends ?? [lan],
                ),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows whose code it is before anything is shared', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      expect(
        find.text('LAN CHI WANTS TO SEE THROUGH YOUR CAMERA'),
        findsOneWidget,
      );
      expect(find.textContaining('You take the photos'), findsOneWidget);
      expect(repo.calls, ['peek:$code32']);
      expect(store.isHosting, isFalse);
      await done(tester);
    });

    testWidgets('SHOW joins, and my camera starts to be watched', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      await tester.tap(find.text('SHOW'));
      await later(tester);
      expect(repo.calls.last, 'join:$code32');
      expect(store.isHosting, isTrue);
      await done(tester);
    });

    testWidgets('NOT NOW shares nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      await tester.tap(find.text('NOT NOW'));
      await later(tester);
      expect(repo.calls, ['peek:$code32']);
      expect(store.isHosting, isFalse);
      await done(tester);
    });

    testWidgets('the name comes from the server when the friend is not known', (
      tester,
    ) async {
      await pump(tester, friends: const []);
      await tester.tap(find.text('scan'));
      await later(tester);
      expect(
        find.text('LAN CHI WANTS TO SEE THROUGH YOUR CAMERA'),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('a stranger\'s code is refused in words, nothing is asked', (
      tester,
    ) async {
      repo.failNext = const PovFailure(PovFailureKind.notFriends);
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      expect(
        find.text('You can only share your camera with your friends.'),
        findsOneWidget,
      );
      expect(find.text('SHOW'), findsNothing);
      expect(store.error, isNull);
      await done(tester);
    });

    testWidgets('a code that ran out is said so', (tester) async {
      repo.failNext = const PovFailure(PovFailureKind.expired);
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      expect(
        find.text('That code ran out. Ask for a new one.'),
        findsOneWidget,
      );
      await done(tester);
    });

    testWidgets('a failure while joining is said too', (tester) async {
      await pump(tester);
      await tester.tap(find.text('scan'));
      await later(tester);
      repo.failNext = const PovFailure(PovFailureKind.busy);
      await tester.tap(find.text('SHOW'));
      await later(tester);
      expect(
        find.text('Omni POV is in use already. Finish that first.'),
        findsOneWidget,
      );
      expect(store.isHosting, isFalse);
      await done(tester);
    });
  });

  group('the scan frame', () {
    testWidgets('says what to do, and closes', (tester) async {
      bigScreen(tester);
      var closed = 0;
      await tester.pumpWidget(app(PovScanOverlay(onClose: () => closed++)));
      expect(find.text("Aim at a friend's Omni POV code"), findsOneWidget);
      await tester.tap(find.byTooltip('CLOSE'));
      expect(closed, 1);
    });

    testWidgets('says so when the code in view is not ours', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        app(PovScanOverlay(onClose: () {}, notOurs: true)),
      );
      expect(find.text('That is not an Omni POV code.'), findsOneWidget);
      expect(find.textContaining('Aim at'), findsNothing);
    });
  });
}
