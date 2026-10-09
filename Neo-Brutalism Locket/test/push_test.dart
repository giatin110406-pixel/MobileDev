import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/notifications/push_service.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/settings/settings_screen.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test.dart' show FakeAuth, FakeProfiles;
import 'fakes_backend.dart';
import 'friends_test.dart' show FakeFriends, FakePostsRepository;
import 'safety_test.dart' show FakeSafety;

class FakePush implements PushGateway {
  final _taps = StreamController<PushTap>.broadcast();
  var started = 0;
  var stopped = 0;

  void tap(PushTap tap) => _taps.add(tap);

  @override
  Future<void> start() async => started++;

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Future<void> stop() async => stopped++;
}

class FakePrefs implements NotificationPrefsRepository {
  FakePrefs([this.stored = const NotificationPrefs()]);

  NotificationPrefs stored;
  var saves = 0;
  bool failSave = false;

  @override
  Future<NotificationPrefs> load() async => stored;

  @override
  Future<void> save(NotificationPrefs prefs) async {
    if (failSave) throw Exception('offline');
    saves++;
    stored = prefs;
  }
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('notification data', () {
    test('the app reads what the server function sends', () {
      final tap = parsePushTap({
        'type': 'message',
        'from_id': 'user-1',
        'post_id': 'post-1',
      });
      expect(tap?.type, 'message');
      expect(tap?.fromId, 'user-1');
      expect(tap?.postId, 'post-1');
    });

    test('all five kinds are understood', () {
      for (final type in [
        'new_post',
        'message',
        'reaction',
        'friend_request',
        'friend_accepted',
      ]) {
        expect(parsePushTap({'type': type})?.type, type);
      }
    });

    test('anything else is ignored', () {
      expect(parsePushTap(null), isNull);
      expect(parsePushTap({}), isNull);
      expect(parsePushTap({'type': 'ad'}), isNull);
      expect(parsePushTap({'type': 5}), isNull);
      expect(parsePushTap({'type': 'message', 'from': ''})?.fromId, isNull);
    });
  });

  group('notification settings model', () {
    test('everything is on by default', () {
      const prefs = NotificationPrefs();
      expect([
        prefs.newPost,
        prefs.messages,
        prefs.reactions,
        prefs.friendRequests,
      ], everyElement(isTrue));
    });

    test('rows round-trip and missing columns count as on', () {
      final prefs = const NotificationPrefs().copyWith(messages: false);
      final row = prefs.toRow('u1');
      expect(row['user_id'], 'u1');
      expect(row['messages'], false);
      final back = NotificationPrefs.fromRow(Map<String, dynamic>.from(row));
      expect(back.messages, isFalse);
      expect(back.newPost, isTrue);
      expect(NotificationPrefs.fromRow({}).reactions, isTrue);
    });
  });

  group('signing out', () {
    test(
      'stops pushes first, while the account can still be reached',
      () async {
        final auth = FakeAuth();
        final order = <String>[];
        final session = AccountSession(
          user: const AuthUser(id: 'u1'),
          profile: const Profile(id: 'u1', username: 'q', displayName: 'Q'),
          auth: auth,
          profiles: FakeProfiles(),
        )..beforeSignOut = () async => order.add('push stopped');
        await session.signOut();
        expect(order, ['push stopped']);
        expect(auth.calls, ['signOut']);
      },
    );

    test('a failing cleanup never stops the sign-out', () async {
      final auth = FakeAuth();
      final session = AccountSession(
        user: const AuthUser(id: 'u1'),
        profile: const Profile(id: 'u1', username: 'q', displayName: 'Q'),
        auth: auth,
        profiles: FakeProfiles(),
      )..beforeSignOut = () async => throw Exception('offline');
      await session.signOut();
      expect(auth.calls, ['signOut']);
    });
  });

  group('settings switches', () {
    Future<FakePrefs> pump(WidgetTester tester, {FakePrefs? prefs}) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = FakeAuth();
      final profiles = FakeProfiles(
        profile: const Profile(id: 'u1', username: 'q', displayName: 'Q'),
      );
      final store = prefs ?? FakePrefs();
      await tester.pumpWidget(
        app(
          SettingsScreen(
            session: AccountSession(
              user: const AuthUser(id: 'u1', email: 'q@test.dev'),
              profile: profiles.profile,
              auth: auth,
              profiles: profiles,
            ),
            settings: AppSettings(),
            auth: auth,
            safety: FakeSafety(),
            onBlocksChanged: () {},
            notifications: store,
            openServerSettings: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('four switches, all on at first', (tester) async {
      await pump(tester);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(find.text('New photos from friends'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Reactions to my photos'), findsOneWidget);
      expect(find.text('Friend requests'), findsOneWidget);
    });

    testWidgets('switching one off is saved; the others stay on', (
      tester,
    ) async {
      final store = await pump(tester);
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(store.saves, 1);
      expect(store.stored.messages, isFalse);
      expect(store.stored.newPost, isTrue);
    });

    testWidgets('saved choices are shown', (tester) async {
      await pump(
        tester,
        prefs: FakePrefs(const NotificationPrefs(reactions: false)),
      );
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      // [0] is "allow friend requests" (privacy); then the four notification ones.
      expect(switches.skip(1).map((s) => s.value).toList(), [
        true,
        true,
        false,
        true,
      ]);
    });

    testWidgets('if saving fails the switch goes back', (tester) async {
      final store = FakePrefs()..failSave = true;
      await pump(tester, prefs: store);
      await tester.tap(find.text('Messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final tile = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .elementAt(2);
      expect(tile.value, isTrue, reason: 'back to on');
      expect(
        find.text('Could not do that. Check your connection and try again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('tapping a notification', () {
    final bo = Friend(
      person: const Person(id: 'id-bo', username: 'bo', displayName: 'Bo Tran'),
      since: DateTime(2026),
    );

    Future<FakePush> pumpShell(
      WidgetTester tester, {
      List<Friend> friends = const [],
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final push = FakePush();
      final player = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(player.load);
      final auth = FakeAuth();
      final profiles = FakeProfiles(
        profile: const Profile(
          id: 'me',
          username: 'me.user',
          displayName: 'Me',
        ),
      );
      await tester.pumpWidget(
        app(
          AppShell(
            playerStore: player,
            session: AccountSession(
              user: const AuthUser(id: 'me'),
              profile: profiles.profile,
              auth: auth,
              profiles: profiles,
            ),
            friendsRepository: FakeFriends(friends: friends),
            postsRepository: FakePostsRepository(),
            chatRepository: FakeChat(),
            interactionsRepository: FakeInteractions(),
            safetyRepository: FakeSafety(),
            settings: AppSettings(),
            push: push,
            notificationPrefs: FakePrefs(),
            inviteLinks: const Stream<Uri>.empty(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      return push;
    }

    testWidgets('push is started once the shell is up', (tester) async {
      final push = await pumpShell(tester);
      expect(push.started, 1);
    });

    testWidgets('a message opens that friend\'s chat', (tester) async {
      final push = await pumpShell(tester, friends: [bo]);
      push.tap(const PushTap(type: 'message', fromId: 'id-bo'));
      await tester.pumpAndSettle();
      expect(find.text('Bo Tran'), findsWidgets);
      expect(find.byTooltip('Send message'), findsOneWidget);
    });

    testWidgets('a message from someone not loaded yet opens the inbox', (
      tester,
    ) async {
      final push = await pumpShell(tester);
      push.tap(const PushTap(type: 'message', fromId: 'id-unknown'));
      await tester.pumpAndSettle();
      expect(find.text('INBOX'), findsWidgets);
      expect(find.byTooltip('Send message'), findsNothing);
    });

    testWidgets('a friend request opens the friends tab', (tester) async {
      final push = await pumpShell(tester);
      push.tap(const PushTap(type: 'friend_request', fromId: 'id-bo'));
      await tester.pumpAndSettle();
      expect(find.text('ONLINE'), findsOneWidget);
    });

    testWidgets('a new photo opens the feed', (tester) async {
      final push = await pumpShell(tester);
      push.tap(const PushTap(type: 'new_post', postId: 'p1'));
      await tester.pumpAndSettle();
      expect(find.text('FEED'), findsOneWidget);
      expect(find.text('NO POSTS YET'), findsOneWidget);
    });
  });
}
