import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'package:neo_brutalism_locket/features/chat/chat_store.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_repository.dart';
import 'package:neo_brutalism_locket/features/posts/interactions_store.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/reply_bar.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'fakes_backend.dart';

ChatMessage message(
  String id,
  String from,
  String to,
  String body, {
  int minute = 0,
  bool read = false,
  String? postId,
}) => ChatMessage(
  id: id,
  senderId: from,
  recipientId: to,
  body: body,
  postId: postId,
  createdAt: DateTime(2026, 1, 1, 12, minute),
  readAt: read ? DateTime(2026, 1, 1, 13) : null,
);

RemotePost post(String id, String author, {String caption = ''}) => RemotePost(
  id: id,
  authorId: author,
  mediaPath: '$author/$id.jpg',
  caption: caption,
  createdAt: DateTime(2026, 1, 1),
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
  group('chat store', () {
    test('threads are grouped by the other person, oldest first', () async {
      final fake = FakeChat(
        messages: [
          message('3', 'me', 'ava', 'see you', minute: 3),
          message('2', 'ava', 'me', 'hello', minute: 2),
          message('1', 'bo', 'me', 'hey', minute: 1),
        ],
      );
      final store = ChatStore(fake, myId: 'me');
      await store.refresh();
      final all = store.asPocketMessages();
      expect(all.map((m) => m.text), ['hey', 'hello', 'see you']);
      expect(all.map((m) => m.friendId), ['bo', 'ava', 'ava']);
      expect(all.map((m) => m.isMine), [false, false, true]);
      expect(all.last.isRead, isTrue, reason: 'my own messages count as read');
      store.dispose();
    });

    test('unread counts, and reading a thread clears them at once', () async {
      final fake = FakeChat(
        messages: [
          message('2', 'ava', 'me', 'b', minute: 2),
          message('1', 'ava', 'me', 'a', minute: 1),
          message('0', 'bo', 'me', 'c', minute: 0),
        ],
      );
      final store = ChatStore(fake, myId: 'me');
      await store.refresh();
      expect(store.unreadFrom('ava'), 2);
      expect(store.unreadFrom('bo'), 1);
      final future = store.markRead('ava');
      expect(store.unreadFrom('ava'), 0, reason: 'before the server answers');
      await future;
      expect(fake.marked, ['ava']);
      expect(store.unreadFrom('bo'), 1);
      await store.markRead('ava');
      expect(fake.marked, ['ava'], reason: 'nothing unread, nothing to tell');
      store.dispose();
    });

    test('sending reloads; a friend writing arrives by itself', () async {
      final fake = FakeChat();
      final store = ChatStore(fake, myId: 'me');
      await store.refresh();
      await store.send(toId: 'ava', body: 'hi', postId: 'p1');
      expect(fake.sent.single.postId, 'p1');
      expect(store.messages.single.body, 'hi');
      fake.receive('ava', 'hello back');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.messages.first.body, 'hello back');
      expect(store.unreadFrom('ava'), 1);
      store.dispose();
    });

    test('a reply to a post carries the post\'s caption', () async {
      final fake = FakeChat(
        messages: [message('1', 'me', 'ava', 'nice', postId: 'p1')],
      );
      final store = ChatStore(fake, myId: 'me');
      await store.refresh();
      final reply = store.asPocketMessages(captionOf: (id) => 'Sunset').single;
      expect(reply.isPostReply, isTrue);
      expect(reply.replyToPostId, 'p1');
      expect(reply.replyPreview, 'Sunset');
      store.dispose();
    });

    test('a failed send throws and changes nothing', () async {
      final fake = FakeChat()
        ..failSend = const ChatFailure(ChatFailureKind.notFound);
      final store = ChatStore(fake, myId: 'me');
      await expectLater(
        store.send(toId: 'ava', body: 'x'),
        throwsA(isA<ChatFailure>()),
      );
      expect(store.messages, isEmpty);
      store.dispose();
    });
  });

  group('interactions store', () {
    test('loads activity of my posts and my reactions to the others', () async {
      final fake = FakeInteractions(
        activity: {
          'mine': const PostActivity(
            reactions: [Reaction(postId: 'mine', userId: 'ava', emoji: '😍')],
            viewerIds: {'ava', 'bo'},
          ),
        },
        mine: {'theirs': '🔥'},
      );
      final store = InteractionsStore(fake, myId: 'me');
      await store.load([post('mine', 'me'), post('theirs', 'ava')]);
      expect(store.activity['mine']!.viewerIds, hasLength(2));
      expect(store.activity['mine']!.reactions.single.emoji, '😍');
      expect(store.myReaction('theirs'), '🔥');
      expect(store.myReaction('mine'), isNull);
      store.dispose();
    });

    test(
      'a reaction shows at once and is undone if the server refuses',
      () async {
        final fake = FakeInteractions();
        final store = InteractionsStore(fake, myId: 'me');
        await store.load([post('p1', 'ava')]);
        await store.react('p1', '😍');
        expect(store.myReaction('p1'), '😍');
        await store.react('p1', null);
        expect(store.myReaction('p1'), isNull);
        expect(fake.reacted['p1'], isNull);

        fake.failReact = const InteractionFailure(detail: 'not_found');
        await expectLater(
          store.react('p1', '🔥'),
          throwsA(isA<InteractionFailure>()),
        );
        expect(store.myReaction('p1'), isNull, reason: 'rolled back');
        store.dispose();
      },
    );

    test('a post is reported as seen only once', () async {
      final fake = FakeInteractions();
      final store = InteractionsStore(fake, myId: 'me');
      await store.markViewed('p1');
      await store.markViewed('p1');
      await store.markViewed('p2');
      expect(fake.viewed, ['p1', 'p2']);
      store.dispose();
    });

    test('a new reaction on my post shows up by itself', () async {
      final fake = FakeInteractions();
      final store = InteractionsStore(fake, myId: 'me');
      await store.load([post('mine', 'me')]);
      expect(store.activity, isEmpty);
      fake.activity['mine'] = const PostActivity(
        reactions: [Reaction(postId: 'mine', userId: 'ava', emoji: '❤️')],
      );
      fake.someoneReacted();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.activity['mine']!.reactions.single.emoji, '❤️');
      store.dispose();
    });

    test('deleting a post forgets its activity', () async {
      final fake = FakeInteractions(
        activity: {
          'mine': const PostActivity(viewerIds: {'ava'}),
        },
      );
      final store = InteractionsStore(fake, myId: 'me');
      final mine = post('mine', 'me');
      await store.load([mine]);
      await store.deletePost(mine);
      expect(fake.deleted, ['mine']);
      expect(store.activity, isEmpty);
      store.dispose();
    });
  });

  group('feed', () {
    const person = Person(id: 'ava', username: 'ava', displayName: 'Ava Chen');
    final ava = person.toPocketFriend();

    Future<void> pumpFeed(
      WidgetTester tester, {
      required List<FeedEntry> entries,
      Future<void> Function(RemotePost, String)? onReply,
      Future<void> Function(RemotePost, String)? onReact,
      ValueChanged<FeedEntry>? onViewed,
      ValueChanged<RemotePost>? onMenu,
      Map<String, PostActivity> activity = const {},
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FeedScreen(
              entries: entries,
              friends: [ava],
              onClose: () {},
              onReplyText: (p, t) async {},
              onReact: (p, e) async {},
              onOpenPrint: (_) {},
              self: const FeedSelf(userId: 'me'),
              onReplyRemote: onReply,
              onReactRemote: onReact,
              onViewed: onViewed,
              onPostMenu: onMenu,
              activity: activity,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a friend\'s post has the reply bar: emoji and text', (
      tester,
    ) async {
      final replies = <String>[];
      final reactions = <String>[];
      await pumpFeed(
        tester,
        entries: [FeedEntry.remote(post('p1', 'ava'))],
        onReply: (p, t) async => replies.add('${p.id}:$t'),
        onReact: (p, e) async => reactions.add('${p.id}:$e'),
      );
      expect(find.byType(ReplyBar), findsOneWidget);
      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(reactions, ['p1:🔥']);
      await tester.enterText(find.byType(TextField), 'love it');
      await tester.pump();
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pumpAndSettle();
      expect(replies, ['p1:love it']);
    });

    testWidgets('my own post has no reply bar but shows who saw it', (
      tester,
    ) async {
      await pumpFeed(
        tester,
        entries: [FeedEntry.remote(post('mine', 'me'))],
        onReply: (p, t) async {},
        onReact: (p, e) async {},
        activity: {
          'mine': const PostActivity(
            reactions: [Reaction(postId: 'mine', userId: 'ava', emoji: '😍')],
            viewerIds: {'ava', 'bo', 'cy'},
          ),
        },
      );
      expect(find.byType(ReplyBar), findsNothing);
      expect(find.text('👀 3'), findsOneWidget);
      expect(find.text('😍 Ava'), findsOneWidget);
    });

    testWidgets('a post nobody looked at shows nothing extra', (tester) async {
      await pumpFeed(tester, entries: [FeedEntry.remote(post('mine', 'me'))]);
      expect(find.textContaining('👀'), findsNothing);
    });

    testWidgets('a post counts as seen after a second on screen', (
      tester,
    ) async {
      final seen = <String>[];
      await pumpFeed(
        tester,
        entries: [
          FeedEntry.remote(post('p1', 'ava')),
          FeedEntry.remote(post('p2', 'ava')),
        ],
        onViewed: (e) => seen.add(e.id),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(seen, isEmpty);
      await tester.pump(const Duration(milliseconds: 600));
      expect(seen, ['p1']);

      // Swipe to the next post: it counts once it has been there a second.
      await tester.fling(find.byType(PageView), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      expect(seen, ['p1']);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(seen, ['p1', 'p2']);
    });

    testWidgets('long-press opens the post menu', (tester) async {
      RemotePost? opened;
      await pumpFeed(
        tester,
        entries: [FeedEntry.remote(post('p1', 'ava'))],
        onMenu: (p) => opened = p,
      );
      await tester.longPress(find.byType(RemoteImage).first);
      expect(opened?.id, 'p1');
    });
  });
}
