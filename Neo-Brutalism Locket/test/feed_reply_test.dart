import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/features/social/reply_bar.dart';
import 'package:neo_brutalism_locket/features/social/social_repository.dart';
import 'package:neo_brutalism_locket/features/social/social_views.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

void main() {
  group('replies to posts (local)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fresh install has a sample post for each sample friend', () async {
      final snapshot = await SocialRepository().load();
      // 3 everyday posts + 2 daily-quest posts (with music).
      expect(snapshot.posts, hasLength(5));
      expect(snapshot.posts.where((p) => p.questId != null), hasLength(2));
      final friendIds = snapshot.friends.map((friend) => friend.id).toSet();
      expect(
        snapshot.posts.every((p) => friendIds.contains(p.friendId)),
        isTrue,
      );
    });

    test('sample quest posts are added only once', () async {
      await SocialRepository().load();
      final again = await SocialRepository().load();
      expect(again.posts.where((p) => p.questId != null), hasLength(2));
    });

    test(
      'a text reply lands in the thread with the person who posted',
      () async {
        final repository = SocialRepository();
        final post = (await repository.load()).posts.first;
        final snapshot = await repository.replyToPost(
          postId: post.id,
          text: '  so pretty  ',
        );
        final reply = snapshot.messages.last;
        expect(reply.friendId, post.friendId);
        expect(reply.text, 'so pretty');
        expect(reply.isMine, isTrue);
        expect(reply.replyToPostId, post.id);
        expect(reply.replyPreview, post.caption);
        expect(reply.reaction, isNull);
      },
    );

    test('an emoji reaction is stored as a reaction', () async {
      final repository = SocialRepository();
      final post = (await repository.load()).posts.first;
      final snapshot = await repository.replyToPost(
        postId: post.id,
        reaction: '🔥',
      );
      expect(snapshot.messages.last.reaction, '🔥');
      expect(snapshot.messages.last.text, isEmpty);
    });

    test('empty replies and unknown posts are rejected', () async {
      final repository = SocialRepository();
      final post = (await repository.load()).posts.first;
      expect(
        () => repository.replyToPost(postId: post.id, text: '   '),
        throwsFormatException,
      );
      expect(
        () => repository.replyToPost(postId: 'nope', text: 'hi'),
        throwsFormatException,
      );
    });

    test('marking a thread read keeps the reply details', () async {
      final repository = SocialRepository();
      final post = (await repository.load()).posts.first;
      await repository.replyToPost(postId: post.id, reaction: '💛');
      final snapshot = await repository.markThreadRead(post.friendId);
      expect(snapshot.messages.last.reaction, '💛');
      expect(snapshot.messages.last.replyToPostId, post.id);
      expect(snapshot.posts, hasLength(5));
    });

    test('removing a friend removes their posts', () async {
      final repository = SocialRepository();
      final post = (await repository.load()).posts.first;
      final snapshot = await repository.removeFriend(post.friendId);
      expect(snapshot.posts.any((p) => p.friendId == post.friendId), isFalse);
    });

    test(
      'installs from before the feed get sample posts; old messages load',
      () async {
        SharedPreferences.setMockInitialValues({
          'pocket_friends_v1': jsonEncode([
            {
              'id': 'sample-ava',
              'name': 'Ava Chen',
              'handle': '@ava.chen',
              'avatarColor': 0xFFFF6B6B,
              'isSample': true,
              'addedAt': DateTime(2026).toIso8601String(),
            },
          ]),
          'pocket_messages_v1': jsonEncode([
            {
              'id': 'm1',
              'friendId': 'sample-ava',
              'text': 'old message',
              'createdAt': DateTime(2026).toIso8601String(),
              'isMine': false,
            },
          ]),
        });
        final snapshot = await SocialRepository().load();
        // Ava's everyday sample post and her sample quest post.
        expect(snapshot.posts.map((p) => p.friendId), [
          'sample-ava',
          'sample-ava',
        ]);
        expect(snapshot.messages.single.text, 'old message');
        expect(snapshot.messages.single.isPostReply, isFalse);
      },
    );
  });

  group('replies in the chat', () {
    final friend = PocketFriend(
      id: 'f1',
      name: 'Ava Chen',
      handle: '@ava',
      avatarColor: 0xFFFF6B6B,
      isSample: true,
      addedAt: DateTime(2026),
    );
    final post = FriendPost(
      id: 'p1',
      friendId: 'f1',
      caption: 'Morning light',
      emoji: '☀️',
      color: 0xFFFFE66D,
      createdAt: DateTime(2026, 1, 2),
    );
    PocketMessage reply({String text = 'so pretty', String? reaction}) =>
        PocketMessage(
          id: 'm1',
          friendId: 'f1',
          text: text,
          createdAt: DateTime(2026, 1, 3),
          isMine: true,
          isRead: true,
          replyToPostId: 'p1',
          replyPreview: 'Morning light',
          reaction: reaction,
        );

    Future<void> pumpThread(
      WidgetTester tester,
      PocketMessage message, {
      List<FriendPost> posts = const [],
    }) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ConversationScreen(
            friend: friend,
            messages: [message],
            posts: posts,
            onBack: () {},
            onSend: (_, _) async {},
            onSendLatestPhoto: () {},
            onRemoveFriend: () {},
          ),
        ),
      ),
    );

    testWidgets('a reply shows the post picture it answers', (tester) async {
      await pumpThread(tester, reply(), posts: [post]);
      expect(find.byType(PostThumbnail), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PostThumbnail),
          matching: find.text('☀️'),
        ),
        findsOneWidget,
      );
      expect(find.text("REPLIED TO AVA'S POST"), findsOneWidget);
      expect(find.text('so pretty'), findsOneWidget);
    });

    testWidgets('a reaction shows the post and the emoji', (tester) async {
      await pumpThread(
        tester,
        reply(text: '', reaction: '🔥'),
        posts: [post],
      );
      expect(find.byType(PostThumbnail), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text("REACTED TO AVA'S POST"), findsOneWidget);
    });

    testWidgets('if the post is gone the saved caption is shown', (
      tester,
    ) async {
      await pumpThread(tester, reply());
      expect(find.byType(PostThumbnail), findsOneWidget);
      expect(find.text('Morning light'), findsWidgets);
    });
  });

  group('reply bar', () {
    Future<(List<String>, List<String>)> pumpBar(WidgetTester tester) async {
      final texts = <String>[];
      final reactions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Center(
              child: ReplyBar(
                onSendText: (text) async => texts.add(text),
                onReact: (emoji) async => reactions.add(emoji),
              ),
            ),
          ),
        ),
      );
      return (texts, reactions);
    }

    testWidgets('quick emoji sends a reaction', (tester) async {
      final (texts, reactions) = await pumpBar(tester);
      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(reactions, ['🔥']);
      expect(texts, isEmpty);
    });

    testWidgets('typing swaps emojis for send, sends and clears', (
      tester,
    ) async {
      final (texts, _) = await pumpBar(tester);
      await tester.enterText(find.byType(TextField), 'love this');
      await tester.pump();
      expect(find.text('💛'), findsNothing);
      await tester.tap(find.byTooltip('Send reply'));
      await tester.pumpAndSettle();
      expect(texts, ['love this']);
      expect(find.text('love this'), findsNothing);
      expect(find.text('💛'), findsOneWidget);
    });

    testWidgets('the picker sends the chosen emoji', (tester) async {
      final (_, reactions) = await pumpBar(tester);
      await tester.tap(find.byTooltip('More emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();
      expect(reactions, ['🎉']);
    });
  });

  group('feed', () {
    final friend = PocketFriend(
      id: 'f1',
      name: 'Ava Chen',
      handle: '@ava',
      avatarColor: 0xFFFF6B6B,
      isSample: true,
      addedAt: DateTime(2026),
    );
    final post = FriendPost(
      id: 'p1',
      friendId: 'f1',
      caption: 'Morning light',
      emoji: '☀️',
      color: 0xFFFFE66D,
      createdAt: DateTime(2026, 1, 2),
    );
    final print = NeoPhoto(
      id: '1',
      originalPath: 'missing.jpg',
      createdAt: DateTime(2026, 1, 1),
      status: ProcessingStatus.done,
    );

    test('newest first, posts and own prints together', () {
      final feed = buildFeed([post], [print]);
      expect(feed.first.post, post);
      expect(feed.last.print, print);
    });

    test('time ago', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(timeAgo(now, now: now), 'now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d');
    });

    Future<List<String>> pumpFeed(
      WidgetTester tester,
      List<FeedEntry> entries,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: FeedScreen(
              entries: entries,
              friends: [friend],
              onClose: () {},
              onReplyText: (p, text) async => sent.add('${p.id}:$text'),
              onReact: (p, emoji) async => sent.add('${p.id}:$emoji'),
              onOpenPrint: (_) {},
            ),
          ),
        ),
      );
      return sent;
    }

    testWidgets('a friend post has the reply bar and sends to that post', (
      tester,
    ) async {
      final sent = await pumpFeed(tester, [FeedEntry.post(post)]);
      expect(find.byType(ReplyBar), findsOneWidget);
      expect(find.text('Morning light'), findsOneWidget);
      await tester.tap(find.text('😍'));
      await tester.pumpAndSettle();
      expect(sent, ['p1:😍']);
    });

    testWidgets('name sits right under the photo, reply bar right under it', (
      tester,
    ) async {
      await pumpFeed(tester, [FeedEntry.post(post)]);
      final photo = tester.getRect(find.text('☀️').first.hitTestable());
      final card = tester.getRect(
        find
            .ancestor(of: find.text('☀️'), matching: find.byType(Container))
            .first,
      );
      final name = tester.getRect(find.text('Ava Chen'));
      final bar = tester.getRect(find.byType(ReplyBar));
      expect(photo.center.dx, closeTo(card.center.dx, 1));
      expect(name.top - card.bottom, inInclusiveRange(0, 16));
      expect(bar.top - name.bottom, inInclusiveRange(0, 18));
      expect(tester.widget<Text>(find.text('Ava Chen')).style!.fontSize, 16);
    });

    testWidgets('fits a small phone screen without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpFeed(tester, [FeedEntry.post(post)]);
      expect(tester.takeException(), isNull);
      expect(find.byType(ReplyBar), findsOneWidget);
    });

    testWidgets('your own print has no reply bar', (tester) async {
      await pumpFeed(tester, [FeedEntry.print(print)]);
      expect(find.byType(ReplyBar), findsNothing);
      expect(find.text('OPEN PRINT'), findsOneWidget);
    });
  });
}
