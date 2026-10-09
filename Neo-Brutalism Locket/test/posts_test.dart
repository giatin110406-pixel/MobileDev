import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/posts/media_encoding.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_outbox.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/posts/posts_store.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePosts implements PostsRepository {
  FakePosts({List<RemotePost>? feed}) : feed = feed ?? [];

  List<RemotePost> feed;
  final sent = <PendingPost>[];
  final _incoming = StreamController<void>.broadcast();
  PostsFailure? failSend;
  PostsFailure? failLoad;
  var loads = 0;

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) async {
    loads++;
    final failure = failLoad;
    if (failure != null) throw failure;
    return List.of(feed);
  }

  @override
  Future<void> send(PendingPost post) async {
    final failure = failSend;
    if (failure != null) throw failure;
    sent.add(post);
  }

  void friendPosted() => _incoming.add(null);

  @override
  Stream<void> get incoming => _incoming.stream;

  @override
  void dispose() => _incoming.close();
}

RemotePost remote(
  String id,
  String author, {
  String caption = '',
  String? quest,
}) => RemotePost(
  id: id,
  authorId: author,
  mediaPath: '$author/$id.jpg',
  thumbPath: '$author/${id}_thumb.jpg',
  caption: caption,
  questId: quest,
  createdAt: DateTime(2026, 1, 1).add(Duration(minutes: id.length)),
);

Future<EncodedPhoto> fakeEncode(
  Uint8List bytes, {
  required bool lossless,
}) async => EncodedPhoto(
  media: Uint8List.fromList([1, 2, 3]),
  thumb: Uint8List.fromList([4, 5]),
  extension: lossless ? 'png' : 'jpg',
  mimeType: lossless ? 'image/png' : 'image/jpeg',
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

  group('ids and models', () {
    test('uuids look like v4 and do not repeat', () {
      final ids = {for (var i = 0; i < 200; i++) newUuid()};
      expect(ids, hasLength(200));
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(ids.every(pattern.hasMatch), isTrue);
    });

    test('a pending post survives being saved and loaded', () {
      final post = PendingPost(
        id: newUuid(),
        mediaFile: '/a.png',
        thumbFile: '/a_thumb.jpg',
        extension: 'png',
        caption: 'hi',
        style: StyleType.vanGogh,
        questId: 'vg_grapes',
        recipients: const ['x', 'y'],
        overlay: const {'time': '12:00'},
        createdAt: DateTime(2026, 1, 2),
        attempts: 1,
      );
      final back = PendingPost.fromJson(post.toJson());
      expect(back.id, post.id);
      expect(back.style, StyleType.vanGogh);
      expect(back.recipients, ['x', 'y']);
      expect(back.overlay, {'time': '12:00'});
      expect(back.attempts, 1);
      expect(back.contentType, 'image/png');
    });

    test('a server row becomes a post', () {
      final post = RemotePost.fromRow({
        'id': 'p1',
        'author_id': 'u1',
        'kind': 'photo',
        'media_path': 'u1/p1.jpg',
        'thumb_path': 'u1/p1_thumb.jpg',
        'caption': 'hello',
        'style': 'pixel8bit',
        'quest_id': null,
        'overlay': {'place': 'Hue'},
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(post.style, StyleType.pixel8bit);
      expect(post.overlay, {'place': 'Hue'});
      expect(post.caption, 'hello');
    });
  });

  group('encoding for upload', () {
    Uint8List sample(int w, int h) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(200, 80, 40));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('big pictures are shrunk to 1080 and get a 360 thumbnail', () {
      final out = encodePhotoSync(sample(2400, 1200), false);
      final full = img.decodeImage(out.media)!;
      final thumb = img.decodeImage(out.thumb)!;
      expect(full.width, 1080);
      expect(full.height, 540);
      expect(thumb.width, 360);
      expect(out.extension, 'jpg');
      expect(out.mimeType, 'image/jpeg');
    });

    test('small pictures keep their size; pixel art stays PNG', () {
      final out = encodePhotoSync(sample(200, 200), true);
      final full = img.decodeImage(out.media)!;
      expect(full.width, 200);
      expect(out.extension, 'png');
      expect(out.mimeType, 'image/png');
      expect(img.decodePng(out.media), isNotNull);
    });
  });

  group('outbox', () {
    late Directory dir;
    late FakePosts posts;
    late File source;

    PostOutbox outbox({String user = 'u1', int maxAttempts = 3}) => PostOutbox(
      repository: posts,
      userId: user,
      folder: dir,
      maxAttempts: maxAttempts,
      encode: fakeEncode,
    );

    setUp(() {
      dir = Directory.systemTemp.createTempSync('outbox_test');
      posts = FakePosts();
      source = File('${dir.path}/source.jpg')..writeAsBytesSync([9, 9, 9]);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    int filesInOutbox() {
      final folder = Directory('${dir.path}/outbox');
      return folder.existsSync() ? folder.listSync().length : 0;
    }

    test('a queued post is saved to disk and sent on flush', () async {
      final box = outbox();
      final id = await box.enqueue(
        source: source,
        caption: '  hello ',
        style: StyleType.vanGogh,
        recipients: const ['f1'],
      );
      expect(filesInOutbox(), 2);
      expect((await box.pending()).single.id, id);

      expect(await box.flush(), 1);
      expect(posts.sent.single.caption, 'hello');
      expect(posts.sent.single.recipients, ['f1']);
      expect(posts.sent.single.style, StyleType.vanGogh);
      expect(await box.pending(), isEmpty);
      expect(filesInOutbox(), 0, reason: 'files are removed once sent');
    });

    test('pixel-art posts are encoded losslessly', () async {
      final box = outbox();
      await box.enqueue(
        source: source,
        caption: '',
        style: StyleType.pixel8bit,
      );
      expect((await box.pending()).single.extension, 'png');
    });

    test('no connection: the post stays queued for later', () async {
      final box = outbox();
      posts.failSend = const PostsFailure(retryable: true, detail: 'offline');
      await box.enqueue(source: source, caption: 'a');
      await box.enqueue(source: source, caption: 'b');
      expect(await box.flush(), 0);
      expect(await box.pending(), hasLength(2));
      expect(filesInOutbox(), 4);

      posts.failSend = null;
      expect(await box.flush(), 2);
      expect(posts.sent.map((p) => p.caption), ['a', 'b'], reason: 'in order');
    });

    test('a queue left by a closed app is picked up again', () async {
      await outbox().enqueue(source: source, caption: 'left behind');
      final reopened = outbox();
      expect((await reopened.pending()).single.caption, 'left behind');
      expect(await reopened.flush(), 1);
    });

    test('a post the server refuses is dropped after 3 tries', () async {
      final box = outbox();
      posts.failSend = const PostsFailure(retryable: false, detail: 'bad_path');
      await box.enqueue(source: source, caption: 'bad');
      await box.flush();
      expect((await box.pending()).single.attempts, 1);
      await box.flush();
      expect((await box.pending()).single.attempts, 2);
      await box.flush();
      expect(await box.pending(), isEmpty);
      expect(filesInOutbox(), 0);
    });

    test('a refused post does not block the ones behind it', () async {
      final box = outbox(maxAttempts: 1);
      posts.failSend = const PostsFailure(retryable: false);
      await box.enqueue(source: source, caption: 'refused');
      await box.flush();
      posts.failSend = null;
      await box.enqueue(source: source, caption: 'fine');
      expect(await box.flush(), 1);
      expect(posts.sent.single.caption, 'fine');
    });

    test('each account has its own queue', () async {
      await outbox(user: 'u1').enqueue(source: source, caption: 'mine');
      expect(await outbox(user: 'u2').pending(), isEmpty);
    });

    test('two flushes at once do not send twice', () async {
      final box = outbox();
      await box.enqueue(source: source, caption: 'once');
      final results = await Future.wait([box.flush(), box.flush()]);
      expect(results.reduce((a, b) => a + b), 1);
      expect(posts.sent, hasLength(1));
    });
  });

  group('posts store', () {
    test('refresh loads; a failure keeps the old posts', () async {
      final fake = FakePosts(feed: [remote('p1', 'a')]);
      final store = PostsStore(fake);
      await store.refresh();
      expect(store.posts.single.id, 'p1');
      expect(store.isLoaded, isTrue);
      fake.failLoad = const PostsFailure(retryable: true);
      await store.refresh();
      expect(store.failed, isTrue);
      expect(store.posts, hasLength(1));
      fake.failLoad = null;
      await store.refresh();
      expect(store.failed, isFalse);
      store.dispose();
    });

    test('a friend posting reloads the feed by itself', () async {
      final fake = FakePosts();
      final store = PostsStore(fake);
      await store.refresh();
      fake.feed = [remote('p2', 'a')];
      fake.friendPosted();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.posts.single.id, 'p2');
      store.dispose();
    });
  });

  group('feed', () {
    test('shows my posts and friends\' posts, not strangers\'', () {
      final feed = buildRemoteFeed(
        [remote('p1', 'me'), remote('p22', 'friend'), remote('p333', 'gone')],
        myId: 'me',
        friendIds: {'friend'},
      );
      expect(feed.map((e) => e.remote!.id), ['p1', 'p22']);
    });

    test('quest posts from the server play their style\'s music', () {
      final entry = FeedEntry.remote(remote('p1', 'me', quest: 'vg_grapes'));
      expect(entry.musicStyle, StyleType.vanGogh);
      expect(FeedEntry.remote(remote('p2', 'me')).musicStyle, isNull);
    });

    testWidgets('a server post is shown with its caption and author', (
      tester,
    ) async {
      final friend = Person(
        id: 'friend',
        username: 'ava',
        displayName: 'Ava Chen',
      ).toPocketFriend();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FeedScreen(
              entries: [
                FeedEntry.remote(
                  remote('p1', 'friend', caption: 'Hello there'),
                ),
              ],
              friends: [friend],
              onClose: () {},
              onReplyText: (p, t) async {},
              onReact: (p, e) async {},
              onOpenPrint: (_) {},
              self: const FeedSelf(userId: 'me'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Ava Chen'), findsOneWidget);
    });

    testWidgets('my own server post says "You"', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FeedScreen(
              entries: [FeedEntry.remote(remote('p1', 'me'))],
              friends: const [],
              onClose: () {},
              onReplyText: (p, t) async {},
              onReact: (p, e) async {},
              onOpenPrint: (_) {},
              self: const FeedSelf(userId: 'me'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('You'), findsOneWidget);
    });
  });

  group('composer', () {
    final friends = [
      for (final name in ['ava', 'bo', 'cy'])
        Friend(
          person: Person(id: 'id-$name', username: name, displayName: name),
          since: DateTime(2026),
        ),
    ];

    Future<ComposerResult?> run(
      WidgetTester tester,
      Future<void> Function() interact, {
      List<Friend>? list,
    }) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ComposerResult? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await Navigator.of(context).push<ComposerResult>(
                      MaterialPageRoute(
                        builder: (_) => PostComposerScreen(
                          imagePath: 'missing.jpg',
                          friends: list ?? friends,
                        ),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact();
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('everyone is selected by default: sends to all friends', (
      tester,
    ) async {
      final result = await run(tester, () async {
        await tester.enterText(find.byType(TextField), '  Hi all ');
        expect(find.text('POST TO ALL FRIENDS'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.send_rounded));
      });
      expect(result?.caption, 'Hi all');
      expect(result?.recipients, isNull);
    });

    testWidgets('unticking a friend sends only to the others', (tester) async {
      final result = await run(tester, () async {
        await tester.tap(find.text('bo'));
        await tester.pumpAndSettle();
        expect(find.text('SEND TO 2 FRIENDS'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.send_rounded));
      });
      expect(result?.recipients, unorderedEquals(['id-ava', 'id-cy']));
    });

    testWidgets('with nobody picked, send is off and says why', (tester) async {
      final result = await run(tester, () async {
        await tester.tap(find.textContaining('ALL FRIENDS ('));
        await tester.pumpAndSettle();
        expect(find.text('Pick at least one friend.'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.send_rounded), warnIfMissed: false);
      });
      expect(result, isNull);
      expect(find.byType(PostComposerScreen), findsOneWidget);
    });

    testWidgets('with no friends there is nobody to send to', (tester) async {
      final result = await run(tester, () async {
        expect(
          find.text('Add friends first to send them photos.'),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.send_rounded), warnIfMissed: false);
      }, list: const []);
      expect(result, isNull);
    });

    testWidgets('captions stop at 80 characters', (tester) async {
      final result = await run(tester, () async {
        await tester.enterText(find.byType(TextField), 'x' * 120);
        await tester.tap(find.byIcon(Icons.send_rounded));
      });
      expect(result?.caption.length, 80);
    });
  });
}
