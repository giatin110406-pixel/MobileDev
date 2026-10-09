import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_gate.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/auth/reset_password_screen.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/safety/safety_widgets.dart';
import 'package:neo_brutalism_locket/features/settings/legal_text.dart';
import 'package:neo_brutalism_locket/features/settings/settings_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test.dart' show FakeAuth, FakeProfiles;

class FakeSafety implements SafetyRepository {
  final blocked = <Person>[];
  final calls = <String>[];
  SafetyFailure? fail;
  ({String? user, String? post, ReportReason reason, String? details})?
  lastReport;

  void _check() {
    final failure = fail;
    if (failure != null) {
      fail = null;
      throw failure;
    }
  }

  @override
  Future<void> block(String personId) async {
    _check();
    calls.add('block $personId');
  }

  @override
  Future<void> unblock(String personId) async {
    _check();
    calls.add('unblock $personId');
    blocked.removeWhere((p) => p.id == personId);
  }

  @override
  Future<List<Person>> loadBlocked() async => List.of(blocked);

  @override
  Future<void> report({
    String? userId,
    String? postId,
    required ReportReason reason,
    String? details,
  }) async {
    _check();
    lastReport = (user: userId, post: postId, reason: reason, details: details);
  }
}

Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: NeoTheme.data,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  home: home,
);

AccountSession session(FakeAuth auth, FakeProfiles profiles) => AccountSession(
  user: const AuthUser(id: 'u1', email: 'me@test.dev'),
  profile: profiles.profile,
  auth: auth,
  profiles: profiles,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const me = Profile(id: 'u1', username: 'quinn', displayName: 'Quinn');

  group('language', () {
    test('follows the phone until one is picked, and remembers it', () async {
      final settings = AppSettings();
      await settings.load();
      expect(settings.locale, isNull);
      await settings.setLocale(const Locale('vi'));
      final again = AppSettings();
      await again.load();
      expect(again.locale, const Locale('vi'));
      await again.setLocale(null);
      final third = AppSettings();
      await third.load();
      expect(third.locale, isNull);
    });

    test('unknown saved languages are ignored', () {
      expect(AppSettings.parseLocale('fr'), isNull);
      expect(AppSettings.parseLocale(null), isNull);
      expect(AppSettings.parseLocale('en'), const Locale('en'));
    });
  });

  group('account session', () {
    test('editing the profile, privacy and deleting', () async {
      final auth = FakeAuth();
      final profiles = FakeProfiles(profile: me);
      final s = session(auth, profiles);
      var notified = 0;
      s.addListener(() => notified++);

      await s.updateIdentity(displayName: 'Quinn Lee', username: 'quinn.lee');
      expect(s.profile.displayName, 'Quinn Lee');
      expect(s.profile.username, 'quinn.lee');

      await s.setAllowRequests(false);
      expect(s.profile.allowRequests, isFalse);
      expect(notified, 2);

      await s.rememberLocale('vi');
      expect(profiles.savedLocale, 'vi');

      await s.deleteAccount();
      expect(profiles.deleted, isTrue);
      expect(auth.calls, contains('signOut'));
    });

    test('taking a username that exists is refused', () async {
      final s = session(FakeAuth(), FakeProfiles(profile: me));
      await expectLater(
        s.updateIdentity(displayName: 'Q', username: 'taken.name'),
        throwsA(isA<UsernameTaken>()),
      );
      expect(s.profile.username, 'quinn');
    });

    test('a new password goes to the auth service', () async {
      final auth = FakeAuth();
      await session(
        auth,
        FakeProfiles(profile: me),
      ).changePassword('longenough');
      expect(auth.calls, ['updatePassword']);
    });
  });

  group('reset password', () {
    Future<FakeAuth> pump(WidgetTester tester, {VoidCallback? onDone}) async {
      final auth = FakeAuth();
      await tester.pumpWidget(
        app(ResetPasswordScreen(auth: auth, onDone: onDone ?? () {})),
      );
      return auth;
    }

    testWidgets('needs 8 characters and two matching entries', (tester) async {
      var done = false;
      final auth = await pump(tester, onDone: () => done = true);
      await tester.enterText(find.byType(TextField).at(0), 'short');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('SAVE PASSWORD'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password needs at least 8 characters.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'longenough1');
      await tester.enterText(find.byType(TextField).at(1), 'different11');
      await tester.tap(find.text('SAVE PASSWORD'));
      await tester.pumpAndSettle();
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(auth.calls, isEmpty);
      expect(done, isFalse);
    });

    testWidgets('saves and finishes', (tester) async {
      var done = false;
      final auth = await pump(tester, onDone: () => done = true);
      await tester.enterText(find.byType(TextField).at(0), 'longenough1');
      await tester.enterText(find.byType(TextField).at(1), 'longenough1');
      await tester.tap(find.text('SAVE PASSWORD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(auth.calls, ['updatePassword']);
      expect(done, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the server refusing the same password is explained', (
      tester,
    ) async {
      final auth = await pump(tester);
      auth.failNext = const AuthFailure(AuthFailureKind.samePassword);
      await tester.enterText(find.byType(TextField).at(0), 'longenough1');
      await tester.enterText(find.byType(TextField).at(1), 'longenough1');
      await tester.tap(find.text('SAVE PASSWORD'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pick a password different from the current one.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'opening the email link makes the gate ask for a new password',
      (tester) async {
        final auth = FakeAuth();
        final profiles = FakeProfiles(profile: me);
        await tester.pumpWidget(
          app(
            AuthGate(
              auth: auth,
              profiles: profiles,
              builder: (context, session) =>
                  const Scaffold(body: Text('THE APP')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('SIGN IN'), findsWidgets);

        auth.openRecoveryLink();
        await tester.pumpAndSettle();
        expect(find.text('NEW PASSWORD'), findsWidgets);
        expect(find.text('SIGN IN'), findsNothing);
      },
    );
  });

  group('reporting and blocking', () {
    testWidgets('a reason is required, details are optional', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ReportDraft? draft;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => draft = await showReportSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEND REPORT'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(draft, isNull, reason: 'no reason chosen yet');

      await tester.tap(find.text('Harassment or bullying'));
      await tester.enterText(find.byType(TextField), '  keeps messaging me  ');
      await tester.pump();
      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();
      expect(draft?.reason, ReportReason.harassment);
      expect(draft?.details, 'keeps messaging me');
    });

    testWidgets('the blocked list shows people and unblocks them', (
      tester,
    ) async {
      final safety = FakeSafety()
        ..blocked.add(
          const Person(id: 'x1', username: 'pest', displayName: 'Pest'),
        );
      var changed = 0;
      await tester.pumpWidget(
        app(BlockedScreen(safety: safety, onChanged: () => changed++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pest'), findsOneWidget);
      await tester.tap(find.text('UNBLOCK'));
      await tester.pumpAndSettle();
      expect(safety.calls, ['unblock x1']);
      expect(find.text('Pest'), findsNothing);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
      expect(changed, 1);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an empty list says so', (tester) async {
      await tester.pumpWidget(app(BlockedScreen(safety: FakeSafety())));
      await tester.pumpAndSettle();
      expect(find.text('You have not blocked anyone.'), findsOneWidget);
    });

    testWidgets('block asks first', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    answer = await confirmBlock(context, 'Ava'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('BLOCK Ava?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });
  });

  group('settings screen', () {
    Future<(FakeAuth, FakeProfiles, AppSettings, FakeSafety)> pump(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = FakeAuth();
      final profiles = FakeProfiles(profile: me);
      final settings = AppSettings();
      final safety = FakeSafety();
      await tester.pumpWidget(
        app(
          SettingsScreen(
            session: session(auth, profiles),
            settings: settings,
            auth: auth,
            safety: safety,
            onBlocksChanged: () {},
            openServerSettings: (_) async {},
          ),
        ),
      );
      await tester.pump();
      return (auth, profiles, settings, safety);
    }

    testWidgets('shows who I am and the language choices', (tester) async {
      await pump(tester);
      expect(find.text('Email: me@test.dev'), findsOneWidget);
      expect(find.text('Quinn · @quinn'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('picking a language applies and is remembered', (tester) async {
      final (_, profiles, settings, _) = await pump(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Tiếng Việt'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(settings.locale, const Locale('vi'));
      expect(profiles.savedLocale, 'vi');
    });

    testWidgets('the friend-request switch saves', (tester) async {
      final (_, profiles, _, _) = await pump(tester);
      await tester.runAsync(() async {
        await tester.tap(find.byType(Switch));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(profiles.profile.allowRequests, isFalse);
    });

    testWidgets('edit profile checks the username before saving', (
      tester,
    ) async {
      final (_, profiles, _, _) = await pump(tester);
      await tester.tap(find.text('Edit name and username'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'ab');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('At least 3 characters.'), findsOneWidget);
      expect(profiles.profile.username, 'quinn');

      await tester.enterText(find.byType(TextField).at(1), 'taken.name');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('That username is taken.'), findsOneWidget);
    });

    testWidgets('deleting needs the username typed first', (tester) async {
      final (auth, profiles, _, _) = await pump(tester);
      await tester.scrollUntilVisible(
        find.text('DELETE ACCOUNT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      expect(find.text('DELETE ACCOUNT?'), findsOneWidget);

      // Not typed: the confirm button does nothing.
      await tester.tap(find.text('DELETE FOR GOOD'));
      await tester.pumpAndSettle();
      expect(profiles.deleted, isFalse);

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(find.text('DELETE FOR GOOD'));
      await tester.pumpAndSettle();
      expect(profiles.deleted, isFalse);

      await tester.enterText(find.byType(TextField), 'Quinn');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('DELETE FOR GOOD'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(profiles.deleted, isTrue);
      expect(auth.calls, contains('signOut'));
    });
  });

  group('policy text', () {
    test('both languages cover the same sections and have no blanks', () {
      for (final getter in [privacyPolicy, termsOfUse]) {
        final vi = getter('vi');
        final en = getter('en');
        expect(vi.length, en.length);
        for (final section in [...vi, ...en]) {
          expect(section.heading, isNotEmpty);
          expect(section.body, isNotEmpty);
        }
      }
    });
  });
}
