import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/safety/safety_repository.dart';
import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'canvas_store_test.dart' show FakeCanvas;
import 'fakes_backend.dart';
import 'groups_test.dart' show FakeGroups, summary;
import 'safety_test.dart' show FakeSafety;
import 'package:neo_brutalism_locket/core/app_settings.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_outbox.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/auth/account_session.dart';
import 'package:neo_brutalism_locket/features/auth/auth_repository.dart';
import 'package:neo_brutalism_locket/features/auth/profile_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_widgets.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Person person(String name, {String? display}) =>
    Person(id: 'id-$name', username: name, displayName: display ?? name);

class FakeFriends implements FriendsRepository {
  FakeFriends({
    List<Friend>? friends,
    List<FriendRequest>? incoming,
    List<FriendRequest>? outgoing,
    this.directory = const [],
  }) : friends = friends ?? [],
       incoming = incoming ?? [],
       outgoing = outgoing ?? [];

  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  final List<Person> directory;
  FriendsFailure? failNext;
  final calls = <String>[];

  @override
  Future<FriendsSnapshot> load() async => FriendsSnapshot(
    friends: List.of(friends),
    incoming: List.of(incoming),
    outgoing: List.of(outgoing),
  );

  @override
  Future<List<Person>> search(String query) async => [
    for (final p in directory)
      if (p.username.startsWith(query.toLowerCase())) p,
  ];

  void _check() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<SendResult> sendRequest(String username) async {
    calls.add('send $username');
    _check();
    final target = directory.firstWhere((p) => p.username == username);
    final theirs = incoming.where((r) => r.person.username == username);
    if (theirs.isNotEmpty) {
      incoming.remove(theirs.first);
      friends.add(Friend(person: target, since: DateTime(2026)));
      return SendResult.accepted;
    }
    outgoing.add(
      FriendRequest(
        id: 'req-$username',
        person: target,
        incoming: false,
        createdAt: DateTime(2026),
      ),
    );
    return SendResult.sent;
  }

  @override
  Future<void> respond(String requestId, {required bool accept}) async {
    calls.add('${accept ? 'accept' : 'decline'} $requestId');
    _check();
    final request = incoming.firstWhere((r) => r.id == requestId);
    incoming.remove(request);
    if (accept) {
      friends.add(Friend(person: request.person, since: DateTime(2026)));
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    calls.add('cancel $requestId');
    outgoing.removeWhere((r) => r.id == requestId);
  }

  @override
  Future<void> removeFriend(String personId) async {
    calls.add('remove $personId');
    friends.removeWhere((f) => f.person.id == personId);
  }
}

FriendRequest incomingFrom(Person who) => FriendRequest(
  id: 'in-${who.username}',
  person: who,
  incoming: true,
  createdAt: DateTime(2026),
);

class FakePostsRepository implements PostsRepository {
  FakePostsRepository([this.feed = const []]);

  final List<RemotePost> feed;

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) async =>
      feed;

  @override
  Future<void> send(PendingPost post) async {}

  @override
  Stream<void> get incoming => const Stream<void>.empty();

  @override
  void dispose() {}
}

class _NoMedia implements MediaUrls {
  const _NoMedia();

  @override
  Future<String?> resolve(String bucket, String path) async => null;
}

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoProfiles implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AccountSession session() => AccountSession(
  user: const AuthUser(id: 'me'),
  profile: const Profile(id: 'me', username: 'me.user', displayName: 'Me'),
  auth: _NoAuth(),
  profiles: _NoProfiles(),
);

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

  group('invite links', () {
    test('a good link gives the username', () {
      expect(
        usernameFromInviteLink(Uri.parse('neolocket://add/Ava.Chen')),
        'ava.chen',
      );
      expect(inviteLinkFor('ava'), 'neolocket://add/ava');
      expect(
        usernameFromInviteLink(Uri.parse(inviteLinkFor('ava_9'))),
        'ava_9',
      );
    });

    test('anything else is ignored', () {
      for (final bad in [
        'https://example.com/add/ava',
        'neolocket://other/ava',
        'neolocket://add/',
        'neolocket://add/a',
        'neolocket://add/has space',
        'neolocket://add/ava/extra',
      ]) {
        expect(usernameFromInviteLink(Uri.parse(bad)), isNull, reason: bad);
      }
    });
  });

  test('server error codes map to failure kinds', () {
    final kinds = {
      'not_found': FriendsFailureKind.notFound,
      'self': FriendsFailureKind.self,
      'already_friends': FriendsFailureKind.alreadyFriends,
      'already_sent': FriendsFailureKind.alreadySent,
      'not_accepting': FriendsFailureKind.notAccepting,
      'too_many_pending': FriendsFailureKind.tooManyPending,
      'friend_limit': FriendsFailureKind.friendLimit,
      'their_friend_limit': FriendsFailureKind.theirFriendLimit,
      'something else': FriendsFailureKind.unknown,
    };
    kinds.forEach((message, kind) {
      expect(SupabaseFriendsRepository.kindOfMessage(message), kind);
    });
  });

  test('a person keeps the same avatar colour everywhere', () {
    final a = person('ava').toPocketFriend();
    final b = person('ava').toPocketFriend();
    expect(a.avatarColor, b.avatarColor);
    expect(a.handle, '@ava');
    expect(a.isSample, isFalse);
  });

  group('friends store', () {
    test('refresh loads; accepting moves a request into friends', () async {
      final fake = FakeFriends(incoming: [incomingFrom(person('ava'))]);
      final store = FriendsStore(fake);
      expect(store.isLoaded, isFalse);
      await store.refresh();
      expect(store.isLoaded, isTrue);
      expect(store.incoming, hasLength(1));
      expect(store.friends, isEmpty);

      await store.respond(store.incoming.first, accept: true);
      expect(store.incoming, isEmpty);
      expect(store.friends.single.person.username, 'ava');
      expect(store.friendById('id-ava'), isNotNull);
    });

    test('declining just removes the request', () async {
      final fake = FakeFriends(incoming: [incomingFrom(person('ava'))]);
      final store = FriendsStore(fake);
      await store.refresh();
      await store.respond(store.incoming.first, accept: false);
      expect(store.incoming, isEmpty);
      expect(store.friends, isEmpty);
    });

    test('sending when they already asked makes you friends', () async {
      final ava = person('ava');
      final fake = FakeFriends(incoming: [incomingFrom(ava)], directory: [ava]);
      final store = FriendsStore(fake);
      await store.refresh();
      expect(await store.sendRequest('ava'), SendResult.accepted);
      expect(store.friends, hasLength(1));
      expect(store.incoming, isEmpty);
    });

    test('a failed action throws and keeps the list as it was', () async {
      final ava = person('ava');
      final fake = FakeFriends(directory: [ava]);
      final store = FriendsStore(fake);
      await store.refresh();
      fake.failNext = const FriendsFailure(FriendsFailureKind.friendLimit);
      await expectLater(
        store.sendRequest('ava'),
        throwsA(
          isA<FriendsFailure>().having(
            (f) => f.kind,
            'kind',
            FriendsFailureKind.friendLimit,
          ),
        ),
      );
      expect(store.outgoing, isEmpty);
    });

    test('removing a friend and cancelling a request', () async {
      final ava = person('ava');
      final bo = person('bo');
      final fake = FakeFriends(
        friends: [Friend(person: ava, since: DateTime(2026))],
        outgoing: [
          FriendRequest(
            id: 'o1',
            person: bo,
            incoming: false,
            createdAt: DateTime(2026),
          ),
        ],
      );
      final store = FriendsStore(fake);
      await store.refresh();
      await store.removeFriend(ava);
      await store.cancel(store.outgoing.single);
      expect(store.friends, isEmpty);
      expect(store.outgoing, isEmpty);
      expect(fake.calls, ['remove id-ava', 'cancel o1']);
    });
  });

  group('with a real account', () {
    Future<void> pumpShell(
      WidgetTester tester,
      FakeFriends fake, {
      Stream<Uri>? links,
      List<RemotePost> feed = const [],
      FakeChat? chat,
      FakeInteractions? interactions,
      FakeSafety? safety,
      FakeGroups? groups,
      FakeCanvas? canvas,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(player.load);
      await tester.pumpWidget(
        app(
          AppShell(
            playerStore: player,
            session: session(),
            friendsRepository: fake,
            postsRepository: FakePostsRepository(feed),
            chatRepository: chat ?? FakeChat(),
            groupsRepository: groups,
            canvasRepository: canvas,
            safetyRepository: safety ?? FakeSafety(),
            settings: AppSettings(),
            interactionsRepository: interactions ?? FakeInteractions(),
            outbox: PostOutbox(
              repository: FakePostsRepository(),
              userId: 'me',
              encode: (bytes, {required lossless}) =>
                  throw UnimplementedError(),
            ),
            mediaUrls: const _NoMedia(),
            inviteLinks: links ?? const Stream<Uri>.empty(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    Future<void> openFriendsTab(WidgetTester tester) async {
      await tester.tap(find.text('FRIENDS'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'no sample friends; requests and friends come from the server',
      (tester) async {
        final fake = FakeFriends(
          friends: [
            Friend(
              person: person('bo', display: 'Bo Tran'),
              since: DateTime(2026),
            ),
          ],
          incoming: [incomingFrom(person('ava', display: 'Ava Chen'))],
        );
        await pumpShell(tester, fake);
        await openFriendsTab(tester);
        expect(find.text('ONLINE'), findsOneWidget);
        expect(find.text('Bo Tran'), findsOneWidget);
        expect(find.text('Ava Chen'), findsOneWidget);
        expect(find.text('ACCEPT'), findsOneWidget);
        expect(find.text('Jules Kim'), findsNothing); // sample friends are gone
        expect(find.text('SAMPLE'), findsNothing);
      },
    );

    testWidgets('accepting a request makes the person a friend', (
      tester,
    ) async {
      final fake = FakeFriends(
        incoming: [incomingFrom(person('ava', display: 'Ava Chen'))],
      );
      await pumpShell(tester, fake);
      await openFriendsTab(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('ACCEPT'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(fake.calls, ['accept in-ava']);
      expect(find.text('ACCEPT'), findsNothing);
      expect(find.text('Ava Chen'), findsOneWidget); // now in the friend list
    });

    testWidgets('without a groups backend there is no Groups switch', (
      tester,
    ) async {
      await pumpShell(tester, FakeFriends());
      await openFriendsTab(tester);
      expect(find.text('NHÓM'), findsNothing);
    });

    testWidgets('the Groups switch shows my groups and opens one', (
      tester,
    ) async {
      final groups = FakeGroups(groups: [summary('a', unread: 2)]);
      await pumpShell(
        tester,
        FakeFriends(),
        groups: groups,
        canvas: FakeCanvas(),
      );
      await openFriendsTab(tester);
      expect(find.text('NHÓM'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // unread badge on the switch

      await tester.tap(find.text('NHÓM'));
      await tester.pumpAndSettle();
      expect(find.text('Group a'), findsOneWidget);

      await tester.tap(find.text('Group a'));
      await tester.pumpAndSettle();
      expect(find.text('CHAT'), findsOneWidget);
      expect(find.text('CANVAS'), findsOneWidget);

      await tester.tap(find.text('CANVAS'));
      await tester.pumpAndSettle();
      expect(find.text('10 MỰC'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Group a'), findsOneWidget);

      await tester.tap(find.text('BẠN BÈ'));
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsOneWidget);
    });

    testWidgets('an empty list invites you to add friends', (tester) async {
      await pumpShell(tester, FakeFriends());
      await openFriendsTab(tester);
      expect(find.textContaining('NO FRIENDS'), findsOneWidget);
      expect(find.text('ADD FRIEND'), findsWidgets);
    });

    testWidgets('an invite link opens the add sheet and sends a request', (
      tester,
    ) async {
      final ava = person('ava', display: 'Ava Chen');
      final fake = FakeFriends(directory: [ava]);
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await pumpShell(tester, fake, links: links.stream);

      links.add(Uri.parse('neolocket://add/ava'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('ADD FRIEND'), findsWidgets);
      expect(find.text('Ava Chen'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.text('ADD'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(fake.calls, ['send ava']);
      expect(find.text('Request sent to Ava Chen.'), findsOneWidget);
      expect(find.textContaining('· SENT'), findsOneWidget); // under requests
    });

    testWidgets('your own invite link is ignored', (tester) async {
      final fake = FakeFriends(directory: [person('me.user')]);
      final links = StreamController<Uri>();
      addTearDown(links.close);
      await pumpShell(tester, fake, links: links.stream);
      links.add(Uri.parse('neolocket://add/me.user'));
      await tester.pumpAndSettle();
      expect(find.text('ADD'), findsNothing);
    });

    testWidgets('a friend thread opens as a real chat', (tester) async {
      final fake = FakeFriends(
        friends: [
          Friend(
            person: person('bo', display: 'Bo Tran'),
            since: DateTime(2026),
          ),
        ],
      );
      await pumpShell(tester, fake);
      await openFriendsTab(tester);
      await tester.tap(find.text('Bo Tran'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Send latest print'), findsNothing);
    });

    final bo = Friend(
      person: person('bo', display: 'Bo Tran'),
      since: DateTime(2026),
    );

    testWidgets('chatting: messages from the server, sending, unread', (
      tester,
    ) async {
      final chat = FakeChat(
        messages: [
          ChatMessage(
            id: 'm1',
            senderId: 'id-bo',
            recipientId: 'me',
            body: 'hey there',
            createdAt: DateTime(2026, 1, 1, 12),
          ),
        ],
      );
      await pumpShell(tester, FakeFriends(friends: [bo]), chat: chat);
      await openFriendsTab(tester);
      await tester.tap(find.text('Bo Tran'));
      await tester.pumpAndSettle();
      expect(find.text('hey there'), findsOneWidget);
      expect(chat.marked, ['id-bo'], reason: 'opening the thread reads it');

      await tester.enterText(find.byType(TextField), 'hello Bo');
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Send message'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(chat.sent.single.to, 'id-bo');
      expect(chat.sent.single.body, 'hello Bo');
      expect(find.text('hello Bo'), findsOneWidget);
    });

    testWidgets('replying to a friend post on the feed writes in the chat', (
      tester,
    ) async {
      final chat = FakeChat();
      final interactions = FakeInteractions();
      final post = RemotePost(
        id: 'post-1',
        authorId: 'id-bo',
        mediaPath: 'id-bo/post-1.jpg',
        caption: 'Lunch',
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpShell(
        tester,
        FakeFriends(friends: [bo]),
        feed: [post],
        chat: chat,
        interactions: interactions,
      );
      await tester.tap(find.text('FEED'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget);

      // An emoji goes to the author as a private reaction.
      await tester.runAsync(() async {
        await tester.tap(find.text('🔥'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(interactions.reacted, {'post-1': '🔥'});
      await tester.pump(const Duration(seconds: 6)); // snack bar goes away
      await tester.pumpAndSettle();

      // Text becomes a chat message that points at the post.
      await tester.enterText(find.byType(TextField), 'yum');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Send reply'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(chat.sent.single.to, 'id-bo');
      expect(chat.sent.single.body, 'yum');
      expect(chat.sent.single.postId, 'post-1');

      // It was on screen for over a second, so Bo is told it was seen.
      await tester.pump(const Duration(seconds: 2));
      expect(interactions.viewed, ['post-1']);
      // Let the snack bars finish before the test ends.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('I can delete my own post from its menu', (tester) async {
      final interactions = FakeInteractions();
      final mine = RemotePost(
        id: 'mine-1',
        authorId: 'me',
        mediaPath: 'me/mine-1.jpg',
        caption: 'Mine',
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpShell(
        tester,
        FakeFriends(),
        feed: [mine],
        interactions: interactions,
      );
      await tester.tap(find.text('FEED'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('SAVE TO DEVICE'), findsOneWidget);
      await tester.tap(find.text('DELETE POST'));
      await tester.pumpAndSettle();
      expect(find.text('DELETE THIS POST?'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('REMOVE'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(interactions.deleted, ['mine-1']);
    });

    testWidgets('the history tab opens the tapped post in the viewer', (
      tester,
    ) async {
      final newer = RemotePost(
        id: 'h1',
        authorId: 'id-bo',
        mediaPath: 'id-bo/h1.jpg',
        thumbPath: 'id-bo/h1_thumb.jpg',
        caption: 'Sunset',
        createdAt: DateTime(2026, 1, 2),
      );
      final older = RemotePost(
        id: 'h2',
        authorId: 'id-bo',
        mediaPath: 'id-bo/h2.jpg',
        thumbPath: 'id-bo/h2_thumb.jpg',
        caption: 'Lunch',
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpShell(tester, FakeFriends(friends: [bo]), feed: [newer, older]);
      await tester.tap(find.text('HISTORY'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsNWidgets(2));
      expect(find.text('JANUARY 2026'), findsOneWidget);

      await tester.tap(find.byType(RemoteImage).last);
      await tester.pumpAndSettle();
      expect(find.text('Lunch'), findsOneWidget, reason: 'opens on that post');
      expect(find.text('Sunset'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      expect(find.text('JANUARY 2026'), findsOneWidget);

      // The prints kept on this phone are one tap away.
      await tester.tap(find.text('ON DEVICE'));
      await tester.pumpAndSettle();
      expect(find.byType(RemoteImage), findsNothing);
    });

    testWidgets('blocking from a friend profile asks, then blocks', (
      tester,
    ) async {
      final safety = FakeSafety();
      await pumpShell(tester, FakeFriends(friends: [bo]), safety: safety);
      await openFriendsTab(tester);
      await tester.tap(find.text('Bo Tran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@bo').first); // header opens the profile
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLOCK'));
      await tester.pumpAndSettle();
      expect(find.text('BLOCK Bo Tran?'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('BLOCK'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(safety.calls, ['block id-bo']);
      expect(find.text('Blocked Bo Tran.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('reporting a friend post sends the reason', (tester) async {
      final safety = FakeSafety();
      final post = RemotePost(
        id: 'rp1',
        authorId: 'id-bo',
        mediaPath: 'id-bo/rp1.jpg',
        caption: 'Rude',
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpShell(
        tester,
        FakeFriends(friends: [bo]),
        feed: [post],
        safety: safety,
      );
      await tester.tap(find.text('FEED'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Rude'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REPORT THIS POST'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or ads'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('SEND REPORT'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(safety.lastReport?.post, 'rp1');
      expect(safety.lastReport?.reason, ReportReason.spam);
      expect(find.text('Report sent. Thank you.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the profile tab opens the settings', (tester) async {
      await pumpShell(tester, FakeFriends());
      await tester.tap(find.text('TÔI'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Edit name and username'), findsOneWidget);
    });

    testWidgets('a friend post has no delete option', (tester) async {
      final theirs = RemotePost(
        id: 'p9',
        authorId: 'id-bo',
        mediaPath: 'id-bo/p9.jpg',
        caption: 'Theirs',
        createdAt: DateTime(2026, 1, 1),
      );
      await pumpShell(tester, FakeFriends(friends: [bo]), feed: [theirs]);
      await tester.tap(find.text('FEED'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Theirs'));
      await tester.pumpAndSettle();
      expect(find.text('SAVE TO DEVICE'), findsOneWidget);
      expect(find.text('DELETE POST'), findsNothing);
    });
  });
}
