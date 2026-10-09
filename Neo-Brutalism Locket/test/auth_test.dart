import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_gate.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/auth_screen.dart';
import 'package:neo_brutalism_locket/features/auth/onboarding_screen.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  AuthFailure? failNext;
  bool needsConfirmation = false;
  final calls = <String>[];

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get changes => _controller.stream;

  void _emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email');
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    _emit(AuthUser(id: 'u1', email: email));
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    calls.add('signUp $email');
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    if (needsConfirmation) return false;
    _emit(AuthUser(id: 'u1', email: email));
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset $email');

  final _recovery = StreamController<void>.broadcast();

  /// The person opened the reset-password link from their email.
  void openRecoveryLink() => _recovery.add(null);

  @override
  Stream<void> get passwordRecovery => _recovery.stream;

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('updatePassword');
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _emit(null);
  }
}

class FakeProfiles implements ProfileRepository {
  FakeProfiles({this.profile = const Profile(id: 'u1')});

  Profile profile;
  final taken = <String>{'taken.name'};
  Object? loadError;
  Uint8List? uploaded;

  @override
  Future<Profile> loadMine(String userId) async {
    final error = loadError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !taken.contains(username);

  @override
  Future<Profile> saveIdentity({
    required String userId,
    required String username,
    required String displayName,
  }) async {
    if (taken.contains(username)) throw const UsernameTaken();
    return profile = Profile(
      id: userId,
      username: username,
      displayName: displayName,
    );
  }

  @override
  Future<Profile> uploadAvatar(String userId, Uint8List jpeg) async {
    uploaded = jpeg;
    return profile = profile.copyWith(avatarPath: '$userId/avatar.jpg');
  }

  bool deleted = false;
  String? savedLocale;

  @override
  Future<Profile> setAllowRequests(String userId, bool allow) async =>
      profile = profile.copyWith(allowRequests: allow);

  @override
  Future<void> setLocale(String userId, String code) async =>
      savedLocale = code;

  @override
  Future<void> deleteAccount(String userId) async => deleted = true;
}

Widget app(Widget home) => MaterialApp(
  theme: NeoTheme.data,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

/// A valid 1x1 PNG.
const _tinyPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

Widget _screen(FakeAuth auth) => AuthScreen(auth: auth);

Widget _onboarding(
  FakeProfiles profiles,
  ValueChanged<Profile> onDone, {
  Future<Uint8List?> Function()? pick,
}) => OnboardingScreen(
  userId: 'u1',
  profiles: profiles,
  onDone: onDone,
  pickPhoto: pick,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('username rules', () {
    test('normalising lower-cases and drops a leading @', () {
      expect(normalizeUsername('  @Ava.Chen '), 'ava.chen');
    });

    test('valid and invalid names', () {
      expect(checkUsername('ava_chen.9'), isNull);
      expect(checkUsername('ab'), UsernameProblem.tooShort);
      expect(checkUsername('a' * 21), UsernameProblem.tooLong);
      expect(checkUsername('ava chen'), UsernameProblem.badCharacters);
      expect(checkUsername('AVA'), UsernameProblem.badCharacters);
      expect(checkUsername('ava-chen'), UsernameProblem.badCharacters);
    });
  });

  group('auth gate', () {
    late FakeAuth auth;
    late FakeProfiles profiles;

    Future<void> pumpGate(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          AuthGate(
            auth: auth,
            profiles: profiles,
            builder: (context, session) =>
                Scaffold(body: Text('APP ${session.profile.username}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      auth = FakeAuth();
      profiles = FakeProfiles();
    });

    testWidgets('signed out: shows the sign-in screen', (tester) async {
      await pumpGate(tester);
      expect(find.text('SIGN IN'), findsWidgets);
      expect(find.textContaining('APP'), findsNothing);
    });

    testWidgets('signing in with a new account goes through onboarding', (
      tester,
    ) async {
      await pumpGate(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'password1');
      await tester.tap(find.text('SIGN IN').last);
      await tester.pumpAndSettle();
      expect(auth.calls, ['signIn a@b.co']);
      expect(find.text('WELCOME!'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Ava Chen');
      await tester.enterText(find.byType(TextField).at(1), 'Ava.Chen');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Available!'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.text('APP ava.chen'), findsOneWidget);
    });

    testWidgets('a returning account with a profile skips onboarding', (
      tester,
    ) async {
      profiles.profile = const Profile(
        id: 'u1',
        username: 'ava',
        displayName: 'Ava',
      );
      auth._current = const AuthUser(id: 'u1');
      await pumpGate(tester);
      expect(find.text('APP ava'), findsOneWidget);
    });

    testWidgets('signing out returns to the sign-in screen', (tester) async {
      profiles.profile = const Profile(
        id: 'u1',
        username: 'ava',
        displayName: 'Ava',
      );
      auth._current = const AuthUser(id: 'u1');
      await pumpGate(tester);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('SIGN IN'), findsWidgets);
      expect(find.textContaining('APP'), findsNothing);
    });

    testWidgets('a profile that cannot load offers retry and sign out', (
      tester,
    ) async {
      auth._current = const AuthUser(id: 'u1');
      profiles.loadError = Exception('offline');
      await pumpGate(tester);
      expect(find.text('Could not load your account.'), findsOneWidget);
      profiles.loadError = null;
      profiles.profile = const Profile(
        id: 'u1',
        username: 'ava',
        displayName: 'Ava',
      );
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pumpAndSettle();
      expect(find.text('APP ava'), findsOneWidget);
    });
  });

  group('sign-in screen', () {
    late FakeAuth auth;

    setUp(() => auth = FakeAuth());

    Future<void> fill(
      WidgetTester tester,
      String email,
      String password,
    ) async {
      await tester.pumpWidget(app(Material(child: _screen(auth))));
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
    }

    testWidgets('wrong password shows the message', (tester) async {
      await fill(tester, 'a@b.co', 'password1');
      auth.failNext = const AuthFailure(AuthFailureKind.invalidCredentials);
      await tester.tap(find.text('SIGN IN').last);
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password.'), findsOneWidget);
    });

    testWidgets('a bad email never reaches the server', (tester) async {
      await fill(tester, 'nope', 'password1');
      await tester.tap(find.text('SIGN IN').last);
      await tester.pumpAndSettle();
      expect(auth.calls, isEmpty);
      expect(find.text('That email does not look right.'), findsOneWidget);
    });

    testWidgets('sign-up needs 8 characters', (tester) async {
      await fill(tester, 'a@b.co', 'short');
      await tester.tap(find.text('No account yet? Sign up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIGN UP'));
      await tester.pumpAndSettle();
      expect(auth.calls, isEmpty);
      expect(
        find.text('Password needs at least 8 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('when email confirmation is required, says so', (tester) async {
      auth.needsConfirmation = true;
      await fill(tester, 'a@b.co', 'password1');
      await tester.tap(find.text('No account yet? Sign up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIGN UP'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['signUp a@b.co']);
      expect(find.textContaining('Almost done'), findsOneWidget);
      expect(find.text('SIGN IN'), findsWidgets);
    });

    testWidgets('forgot password asks for the email first', (tester) async {
      await tester.pumpWidget(app(Material(child: _screen(auth))));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email above first.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['reset a@b.co']);
      expect(find.textContaining('reset email sent'), findsOneWidget);
    });
  });

  group('onboarding', () {
    testWidgets('a taken username blocks saving and says so', (tester) async {
      final profiles = FakeProfiles();
      Profile? done;
      await tester.pumpWidget(
        app(_onboarding(profiles, (profile) => done = profile)),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Ava');
      await tester.enterText(find.byType(TextField).at(1), 'taken.name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('That username is taken.'), findsOneWidget);
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(done, isNull);
    });

    testWidgets('invalid names show the rule, not "available"', (tester) async {
      final profiles = FakeProfiles();
      await tester.pumpWidget(app(_onboarding(profiles, (_) {})));
      await tester.enterText(find.byType(TextField).at(1), 'ab');
      await tester.pump();
      expect(find.text('At least 3 characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'has space');
      await tester.pump();
      expect(
        find.text('Use lower-case letters, digits, dot and underscore only.'),
        findsOneWidget,
      );
    });

    testWidgets('an optional photo is uploaded after saving', (tester) async {
      final profiles = FakeProfiles();
      Profile? done;
      final bytes = Uint8List.fromList(_tinyPng);
      await tester.pumpWidget(
        app(
          _onboarding(
            profiles,
            (profile) => done = profile,
            pick: () async => bytes,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('avatar-picker')));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'Ava');
      await tester.enterText(find.byType(TextField).at(1), 'ava');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('CONTINUE'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(profiles.uploaded, bytes);
      expect(done?.avatarPath, 'u1/avatar.jpg');
    });
  });

  test('the session reports the uploaded avatar to listeners', () async {
    final profiles = FakeProfiles(
      profile: const Profile(id: 'u1', username: 'ava', displayName: 'Ava'),
    );
    final session = AccountSession(
      user: const AuthUser(id: 'u1'),
      profile: profiles.profile,
      auth: FakeAuth(),
      profiles: profiles,
    );
    var notified = 0;
    session.addListener(() => notified++);
    await session.uploadAvatar(Uint8List.fromList([9]));
    expect(session.profile.avatarPath, 'u1/avatar.jpg');
    expect(notified, 1);
  });
}
