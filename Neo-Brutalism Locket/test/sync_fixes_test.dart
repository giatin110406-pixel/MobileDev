import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/features/chat/chat_repository.dart';
import 'package:neo_brutalism_locket/features/chat/chat_store.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/posts_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes_backend.dart';
import 'friends_test.dart' show FakePostsRepository;
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// A chat server that answers only when told to.
class SlowChat extends FakeChat {
  SlowChat() : super(myId: 'me');

  final gates = <Completer<void>>[];
  var loads = 0;

  @override
  Future<List<ChatMessage>> loadRecent({int limit = 500}) async {
    loads++;
    final gate = Completer<void>();
    gates.add(gate);
    final snapshot = List.of(messages);
    await gate.future;
    return snapshot;
  }
}

class SlowPosts extends FakePostsRepository {
  SlowPosts() : super([]);

  final posts = <RemotePost>[];
  final gates = <Completer<void>>[];

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) async {
    final gate = Completer<void>();
    gates.add(gate);
    final snapshot = List.of(posts);
    await gate.future;
    return snapshot;
  }
}

ChatMessage incoming(String id, String body) => ChatMessage(
  id: id,
  senderId: 'ava',
  recipientId: 'me',
  body: body,
  createdAt: DateTime(2026, 1, 1, 12),
);

class CountingUrls implements MediaUrls {
  CountingUrls(this.answer);

  String? answer;
  var calls = 0;
  final gate = Completer<void>();
  bool wait = false;

  @override
  Future<String?> resolve(String bucket, String path) async {
    calls++;
    if (wait) await gate.future;
    return answer;
  }
}

void main() {
  group('messages are not missed', () {
    test(
      'a message that arrives during a load is fetched right after',
      () async {
        final chat = SlowChat();
        final store = ChatStore(chat, myId: 'me');
        final first = store.refresh();
        // While the first load runs, a friend sends something.
        chat.messages.insert(0, incoming('m1', 'are you there?'));
        final second = store.refresh();
        chat.gates.first.complete();
        await Future<void>.delayed(Duration.zero);
        expect(chat.loads, 2, reason: 'loads again for the new message');
        chat.gates.last.complete();
        await first;
        await second;
        expect(store.messages.map((m) => m.body), ['are you there?']);
        store.dispose();
      },
    );

    test('several calls during one load cause only one more load', () async {
      final chat = SlowChat();
      final store = ChatStore(chat, myId: 'me');
      final first = store.refresh();
      store.refresh();
      store.refresh();
      chat.gates.first.complete();
      await Future<void>.delayed(Duration.zero);
      chat.gates.last.complete();
      await first;
      expect(chat.loads, 2);
      store.dispose();
    });

    test('the feed does the same for a post that arrives mid-load', () async {
      final repo = SlowPosts();
      final store = PostsStore(repo);
      final first = store.refresh();
      repo.posts.add(
        RemotePost(
          id: 'p1',
          authorId: 'ava',
          mediaPath: 'ava/p1.jpg',
          createdAt: DateTime(2026),
        ),
      );
      store.refresh();
      repo.gates.first.complete();
      await Future<void>.delayed(Duration.zero);
      repo.gates.last.complete();
      await first;
      expect(store.posts.map((p) => p.id), ['p1']);
      store.dispose();
    });
  });

  group('pictures that are slow or fail', () {
    Widget host(MediaUrls urls, {double size = 300}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: MediaUrlsScope(
        urls: urls,
        child: Center(
          child: SizedBox.square(
            dimension: size,
            child: const RemoteImage(path: 'a/p.jpg'),
          ),
        ),
      ),
    );

    testWidgets('while the link is fetched a spinner shows, not a blank', (
      tester,
    ) async {
      final urls = CountingUrls(null)..wait = true;
      await tester.pumpWidget(host(urls));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      urls.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a big picture that failed can be tried again', (tester) async {
      final urls = CountingUrls(null);
      await tester.pumpWidget(host(urls));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(urls.calls, 1);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(urls.calls, 2);
    });

    testWidgets('a small tile that failed leaves taps to the tile', (
      tester,
    ) async {
      await tester.pumpWidget(host(CountingUrls(null), size: 100));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });

  group('shots on this phone', () {
    late Directory dir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('shots');
    });

    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    NeoPhoto shot(String id) {
      final original = File('${dir.path}/${id}_original.jpg')
        ..writeAsBytesSync([1]);
      final processed = File('${dir.path}/${id}_print.png')
        ..writeAsBytesSync([2]);
      return NeoPhoto(
        id: id,
        originalPath: original.path,
        processedPath: processed.path,
        createdAt: DateTime(2026),
        status: ProcessingStatus.done,
        styleType: StyleType.pixel8bit,
      );
    }

    test('a thrown-away shot is forgotten and its files are deleted', () async {
      final repository = PhotoRepository();
      final keep = shot('1');
      final drop = shot('2');
      await repository.upsert(keep);
      await repository.upsert(drop);
      await repository.delete(drop);
      expect((await repository.loadPhotos()).map((p) => p.id), ['1']);
      expect(File(drop.originalPath).existsSync(), isFalse);
      expect(File(drop.processedPath!).existsSync(), isFalse);
      expect(File(keep.originalPath).existsSync(), isTrue);
    });
  });
}
