import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neo_brutalism_locket/core/backend/media_urls.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/albums/albums_repository.dart';
import 'package:neo_brutalism_locket/features/albums/albums_screen.dart';
import 'package:neo_brutalism_locket/features/albums/albums_store.dart';
import 'package:neo_brutalism_locket/features/export/media_export.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/posts/media_actions.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

const trip = 'a0000000-0000-4000-8000-000000000001';
const old = 'a0000000-0000-4000-8000-000000000002';

Album album(
  String id, {
  String group = 'g1',
  String name = 'Dalat',
  DateTime? start,
  DateTime? end,
  String? createdBy = 'me',
  int count = 0,
}) => Album(
  id: id,
  groupId: group,
  name: name,
  startsAt: start ?? DateTime(2026, 10, 20),
  endsAt: end ?? DateTime(2026, 10, 24),
  createdAt: DateTime(2026, 10, 19),
  createdBy: createdBy,
  itemCount: count,
);

AlbumItem item(String post, {String author = 'me', String? original}) =>
    AlbumItem(
      albumId: trip,
      postId: post,
      authorId: author,
      mediaPath: '$author/$post.jpg',
      thumbPath: '$author/${post}_thumb.jpg',
      originalPath: original,
      caption: 'cap $post',
      createdAt: DateTime(2026, 10, 21, 9),
    );

class FakeAlbums implements AlbumsRepository {
  FakeAlbums({List<Album>? albums}) : albums = albums ?? [];

  final List<Album> albums;
  final items = <AlbumItem>[];
  final calls = <String>[];
  final mine = <RemotePost>[];
  AlbumFailure? failNext;
  final refused = <String>{};

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<List<Album>> loadAlbums() async {
    _maybeFail();
    return List.of(albums);
  }

  @override
  Future<List<AlbumItem>> loadItems(String albumId) async {
    _maybeFail();
    return [
      for (final i in items)
        if (i.albumId == albumId) i,
    ];
  }

  @override
  Future<String> create({
    required String groupId,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    _maybeFail();
    calls.add('create $name');
    albums.add(
      album(
        'new${albums.length}',
        group: groupId,
        name: name,
        start: startsAt,
        end: endsAt,
      ),
    );
    return albums.last.id;
  }

  @override
  Future<void> delete(String albumId) async {
    _maybeFail();
    calls.add('delete $albumId');
    albums.removeWhere((a) => a.id == albumId);
  }

  @override
  Future<bool> add(String albumId, String postId) async {
    _maybeFail();
    calls.add('add $postId');
    return !refused.contains(postId);
  }

  @override
  Future<void> remove(String albumId, String postId) async {
    _maybeFail();
    calls.add('remove $postId');
    items.removeWhere((i) => i.postId == postId);
  }

  @override
  Future<List<RemotePost>> myPostsBetween(DateTime from, DateTime to) async =>
      List.of(mine);
}

class StubUrls implements MediaUrls {
  StubUrls({this.missing = const {}});

  final Set<String> missing;

  @override
  Future<String?> resolve(String bucket, String path) async =>
      missing.contains(path) ? null : 'https://files.test/$bucket/$path';
}

/// A few frames: the pictures' spinners never stop, so pumpAndSettle would not.
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

void main() {
  group('albums', () {
    test('an album is open from its first moment to just before its end', () {
      final a = album(trip);
      expect(a.isOpenAt(DateTime(2026, 10, 20)), isTrue);
      expect(a.isOpenAt(DateTime(2026, 10, 23, 23, 59)), isTrue);
      expect(a.isOpenAt(DateTime(2026, 10, 24)), isFalse);
      expect(a.isOpenAt(DateTime(2026, 10, 19, 23, 59)), isFalse);
    });

    test('a server row becomes an album with its photo count', () {
      final a = Album.fromRow({
        'id': trip,
        'group_id': 'g1',
        'name': 'Dalat',
        'starts_at': '2026-10-20T00:00:00Z',
        'ends_at': '2026-10-24T00:00:00Z',
        'created_by': 'me',
        'created_at': '2026-10-19T00:00:00Z',
        'album_items': [
          {'count': 7},
        ],
      });
      expect(a.itemCount, 7);
      expect(a.name, 'Dalat');
      expect(
        Album.fromRow({
          'id': trip,
          'group_id': 'g1',
          'name': 'x',
          'starts_at': '2026-10-20T00:00:00Z',
          'ends_at': '2026-10-24T00:00:00Z',
          'created_at': '2026-10-19T00:00:00Z',
          'album_items': <Object>[],
        }).itemCount,
        0,
      );
    });

    test('the server\'s error codes are told apart', () {
      expect(
        SupabaseAlbumsRepository.kindOfMessage('bad_window'),
        AlbumFailureKind.badWindow,
      );
      expect(
        SupabaseAlbumsRepository.kindOfMessage('album_limit'),
        AlbumFailureKind.albumLimit,
      );
      expect(
        SupabaseAlbumsRepository.kindOfMessage('whatever'),
        AlbumFailureKind.unknown,
      );
    });
  });

  group('albums store', () {
    test('lists albums per group and the ones open now', () async {
      final repo = FakeAlbums(
        albums: [
          album(trip),
          album(old, start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 3)),
          album('other', group: 'g2'),
        ],
      );
      final store = AlbumsStore(repo, clock: () => DateTime(2026, 10, 21));
      await store.refresh();
      expect(store.forGroup('g1').map((a) => a.id), [trip, old]);
      expect(store.open.map((a) => a.id), [trip, 'other']);
      expect(store.byId(old)?.groupId, 'g1');
      expect(store.byId('nope'), isNull);
    });

    test('a failed refresh keeps what was there and says so', () async {
      final repo = FakeAlbums(albums: [album(trip)]);
      final store = AlbumsStore(repo);
      await store.refresh();
      repo.failNext = const AlbumFailure(AlbumFailureKind.network);
      await store.refresh();
      expect(store.albums, hasLength(1));
      expect(store.loadError?.kind, AlbumFailureKind.network);
      await store.refresh();
      expect(store.loadError, isNull);
    });

    test('creating reloads and returns the new id', () async {
      final repo = FakeAlbums();
      final store = AlbumsStore(repo);
      final id = await store.create(
        groupId: 'g1',
        name: 'Hue',
        startsAt: DateTime(2026, 10, 1),
        endsAt: DateTime(2026, 10, 3),
      );
      expect(store.byId(id)?.name, 'Hue');
    });

    test('adding counts only the posts the server accepted', () async {
      final repo = FakeAlbums(albums: [album(trip)])..refused.add('late');
      final store = AlbumsStore(repo);
      await store.refresh();
      final added = await store.addPosts(album(trip), ['p1', 'late', 'p2']);
      expect(added, 2);
      expect(repo.calls, ['add p1', 'add late', 'add p2']);
    });

    test('deleting takes the album out', () async {
      final repo = FakeAlbums(albums: [album(trip)]);
      final store = AlbumsStore(repo);
      await store.refresh();
      await store.delete(store.byId(trip)!);
      expect(store.albums, isEmpty);
    });
  });

  group('choosing albums when posting', () {
    test('no album is ticked to start with, and ticks go in the result', () {
      final composer = ComposerController(
        friends: const [],
        albums: [album(trip), album(old)],
      );
      expect(composer.selectedAlbums, isEmpty);
      expect(composer.result().albumIds, isEmpty);
      composer.toggleAlbum(trip);
      expect(composer.result().albumIds, [trip]);
      composer.toggleAlbum(trip);
      expect(composer.result().albumIds, isEmpty);
      composer.dispose();
    });

    testWidgets('the form offers each open album and sends the ticked ones', (
      tester,
    ) async {
      ComposerResult? sent;
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: PostComposerForm(
              friends: const [],
              albums: [album(trip, name: 'Dalat')],
              previewBuilder: (context, overlay) => const SizedBox(height: 40),
              onSubmit: (result) => sent = result,
            ),
          ),
        ),
      );
      expect(find.text('ALBUM: Dalat'), findsOneWidget);
      await tester.tap(find.text('ALBUM: Dalat'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent?.albumIds, [trip]);
    });

    testWidgets('with no open album there is nothing extra to tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: PostComposerForm(
              friends: const [],
              previewBuilder: (context, overlay) => const SizedBox(height: 40),
              onSubmit: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('ALBUM:'), findsNothing);
    });
  });

  group('the album tab', () {
    final members = {
      'me': const Person(id: 'me', username: 'me', displayName: 'Me'),
      'ava': const Person(id: 'ava', username: 'ava', displayName: 'Ava'),
    };

    Future<AlbumsStore> pumpPanel(
      WidgetTester tester,
      FakeAlbums repo, {
      bool owner = false,
    }) async {
      final store = AlbumsStore(repo, clock: () => DateTime(2026, 10, 21));
      await tester.runAsync(store.refresh);
      await tester.pumpWidget(
        app(
          AlbumsPanel(
            groupId: 'g1',
            store: store,
            members: members,
            myId: 'me',
            iAmOwner: owner,
            mediaUrls: StubUrls(),
            actions: MediaActions(StubUrls()),
          ),
        ),
      );
      return store;
    }

    testWidgets('no albums: explains what they are and offers to start one', (
      tester,
    ) async {
      await pumpPanel(tester, FakeAlbums());
      expect(find.text('NEW ALBUM'), findsOneWidget);
      expect(find.textContaining('No albums yet'), findsOneWidget);
    });

    testWidgets('a failed load says so and TRY AGAIN loads again', (
      tester,
    ) async {
      final repo = FakeAlbums(albums: [album(trip, name: 'Dalat')])
        ..failNext = const AlbumFailure(AlbumFailureKind.network);
      await pumpPanel(tester, repo);
      expect(find.text('The album could not be loaded.'), findsOneWidget);
      expect(find.text('Dalat'), findsNothing);
      await tester.tap(find.text('TRY AGAIN'));
      await frames(tester);
      expect(find.text('Dalat'), findsOneWidget);
      expect(find.text('The album could not be loaded.'), findsNothing);
    });

    testWidgets('lists the group\'s albums, marking the one open now', (
      tester,
    ) async {
      final repo = FakeAlbums(
        albums: [
          album(trip, count: 3),
          album(
            old,
            name: 'Hue',
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 1, 3),
          ),
          album('x', group: 'g2', name: 'Other group'),
        ],
      );
      await pumpPanel(tester, repo);
      expect(find.text('Dalat'), findsOneWidget);
      expect(find.text('Hue'), findsOneWidget);
      expect(find.text('Other group'), findsNothing);
      expect(find.text('OPEN NOW'), findsOneWidget);
      expect(find.textContaining('3 photos'), findsOneWidget);
    });

    testWidgets('opening an album shows its photos; the starter may delete', (
      tester,
    ) async {
      final repo = FakeAlbums(albums: [album(trip, count: 1)])
        ..items.add(item('p1'));
      final store = await pumpPanel(tester, repo);
      await tester.tap(find.text('Dalat'));
      await frames(tester);
      expect(find.text('ADD MY PHOTOS'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await frames(tester);
      await tester.tap(find.text('DELETE ALBUM'));
      await frames(tester);
      expect(repo.calls, contains('delete $trip'));
      expect(store.albums, isEmpty);
      // The screen closed itself: back on the list.
      expect(find.text('ADD MY PHOTOS'), findsNothing);
    });

    testWidgets('someone who did not start it and does not own the group '
        'cannot delete it', (tester) async {
      final repo = FakeAlbums(albums: [album(trip, createdBy: 'ava')])
        ..items.add(item('p1', author: 'ava'));
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Dalat'));
      await frames(tester);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('the group\'s owner can delete any album', (tester) async {
      final repo = FakeAlbums(albums: [album(trip, createdBy: 'ava')]);
      await pumpPanel(tester, repo, owner: true);
      await tester.tap(find.text('Dalat'));
      await frames(tester);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('picking photos for a print: tap order, 2 to 6, no videos', (
      tester,
    ) async {
      // Tall enough that the whole grid is built at once.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeAlbums(albums: [album(trip, count: 8)]);
      for (final id in ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7']) {
        repo.items.add(item(id));
      }
      repo.items.add(
        AlbumItem(
          albumId: trip,
          postId: 'clip',
          authorId: 'me',
          kind: 'video',
          mediaPath: 'me/clip.mp4',
          createdAt: DateTime(2026, 10, 21),
        ),
      );
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Dalat'));
      await frames(tester);
      await tester.tap(find.byIcon(Icons.print_outlined));
      await frames(tester);
      expect(
        find.text('Tap 2–6 photos in the order to print (0/6)'),
        findsOneWidget,
      );
      final next = find.widgetWithText(NeoButton, 'NEXT');
      expect(tester.widget<NeoButton>(next).onPressed, isNull);

      final tiles = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      await tester.tap(tiles.at(2));
      await tester.pump();
      await tester.tap(tiles.at(0));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(tester.widget<NeoButton>(next).onPressed, isNotNull);

      // Tapping again takes it out; at most four.
      await tester.tap(tiles.at(2));
      await tester.pump();
      expect(find.textContaining('(1/6)'), findsOneWidget);
      for (final i in [1, 2, 3, 4, 5]) {
        await tester.tap(tiles.at(i));
        await tester.pump();
      }
      expect(find.textContaining('(6/6)'), findsOneWidget);
      // A seventh does not go in.
      await tester.tap(tiles.at(6));
      await tester.pump();
      expect(find.textContaining('(6/6)'), findsOneWidget);

      // A video is refused with a word why.
      await tester.tap(tiles.at(7));
      await tester.pump();
      expect(find.textContaining('Videos cannot be printed'), findsOneWidget);

      // Closing the picker forgets the picks.
      await tester.tap(find.byIcon(Icons.close));
      await frames(tester);
      expect(find.textContaining('/4)'), findsNothing);
    });

    testWidgets('adding my photos lists only those not in yet', (tester) async {
      RemotePost mine(String id) => RemotePost(
        id: id,
        authorId: 'me',
        mediaPath: 'me/$id.jpg',
        createdAt: DateTime(2026, 10, 21, 10),
      );
      final repo = FakeAlbums(albums: [album(trip, count: 1)])
        ..items.add(item('in'))
        ..mine.addAll([mine('in'), mine('new1'), mine('new2')]);
      await pumpPanel(tester, repo);
      await tester.tap(find.text('Dalat'));
      await frames(tester);
      await tester.tap(find.text('ADD MY PHOTOS'));
      await frames(tester);
      // Two photos to pick from, not three; the button waits for a pick.
      expect(find.text('ADD 0 PHOTOS'), findsOneWidget);
      final tiles = find.descendant(
        of: find.byType(Opacity),
        matching: find.byType(RemoteImage),
      );
      expect(tiles, findsNWidgets(2));
      await tester.tap(tiles.first);
      await tester.pump();
      expect(find.text('ADD 1 PHOTO'), findsOneWidget);
      await tester.tap(find.text('ADD 1 PHOTO'));
      await frames(tester);
      expect(repo.calls.where((c) => c.startsWith('add ')), hasLength(1));
    });
  });

  group('zip export', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('export_test'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    MediaExporter exporter({
      Set<String> missing = const {},
      Set<String> broken = const {},
    }) => MediaExporter(
      StubUrls(missing: missing),
      tempDir: () async => dir,
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst('/media/', '');
        if (broken.contains(path)) return http.Response('no', 500);
        return http.Response.bytes(utf8.encode('bytes of $path'), 200);
      }),
    );

    Archive open(File zip) => ZipDecoder().decodeBytes(zip.readAsBytesSync());

    test('puts each file in the zip under its name, plus extra text', () async {
      final result = await exporter().buildZip(
        zipName: 'album',
        files: const [
          ExportFile(path: 'a/1.jpg', name: 'photos/one.jpg'),
          ExportFile(path: 'a/2.jpg', name: 'originals/two.jpg'),
        ],
        extras: {'posts.json': '{}'},
      );
      expect(result!.added, 2);
      expect(result.missed, 0);
      final zip = open(result.file);
      expect(
        zip.findFile('photos/one.jpg')!.content,
        utf8.encode('bytes of a/1.jpg'),
      );
      expect(zip.findFile('originals/two.jpg'), isNotNull);
      expect(
        utf8.decode(zip.findFile('posts.json')!.content as List<int>),
        '{}',
      );
    });

    test('files that cannot be downloaded are left out and counted', () async {
      final seen = <int>[];
      final result = await exporter(missing: {'a/1.jpg'}, broken: {'a/2.jpg'})
          .buildZip(
            zipName: 'partial',
            files: const [
              ExportFile(path: 'a/1.jpg', name: 'one.jpg'),
              ExportFile(path: 'a/2.jpg', name: 'two.jpg'),
              ExportFile(path: 'a/3.jpg', name: 'three.jpg'),
            ],
            onProgress: (done, total) => seen.add(done),
          );
      expect(result!.added, 1);
      expect(result.missed, 2);
      expect(open(result.file).files.map((f) => f.name), ['three.jpg']);
      expect(seen, [1, 2, 3]);
    });

    test('nothing downloaded: no zip is left behind', () async {
      final result = await exporter(missing: {'a/1.jpg'}).buildZip(
        zipName: 'empty',
        files: const [ExportFile(path: 'a/1.jpg', name: 'one.jpg')],
      );
      expect(result, isNull);
      expect(File('${dir.path}/empty.zip').existsSync(), isFalse);
    });

    test('no files, or no way to reach storage, is null', () async {
      expect(await exporter().buildZip(zipName: 'x', files: const []), isNull);
      expect(
        await MediaExporter(null, tempDir: () async => dir).buildZip(
          zipName: 'x',
          files: const [ExportFile(path: 'a', name: 'a')],
        ),
        isNull,
      );
    });
  });

  group('exporting my account', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('account_export'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    RemotePost post(int n, {bool original = false}) {
      final id = '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';
      return RemotePost(
        id: id,
        authorId: 'me',
        mediaPath: 'me/$id.png',
        originalPath: original ? 'me/${id}_orig.jpg' : null,
        caption: 'post $n',
        createdAt: DateTime(2026, 10, 1).add(Duration(hours: n)),
      );
    }

    test('names files by date, keeps the original apart', () {
      final export = PostExport(post(5, original: true));
      expect(export.mediaName, 'photos/2026-10-01_00000005.png');
      expect(export.originalName, 'originals/2026-10-01_00000005.jpg');
      expect(export.files.map((f) => f.path), hasLength(2));
      expect(PostExport(post(6)).originalName, isNull);
      expect(
        PostExport(
          RemotePost(
            id: 'abcdefgh-0000-4000-8000-000000000000',
            authorId: 'me',
            kind: 'video',
            mediaPath: 'me/x.mp4',
            createdAt: DateTime(2026, 2, 3),
          ),
        ).mediaName,
        'videos/2026-02-03_abcdefgh.mp4',
      );
    });

    test('reads every page and zips the photos with a list', () async {
      // 130 posts: more than one page of 100.
      final all = [for (var n = 130; n >= 1; n--) post(n, original: n.isEven)];
      final source = _PagedPosts(all);
      final export = AccountExport(
        source: source,
        username: 'me',
        clock: () => DateTime(2026, 11, 2),
        exporter: MediaExporter(
          StubUrls(),
          tempDir: () async => dir,
          client: MockClient(
            (request) async => http.Response.bytes([1, 2, 3], 200),
          ),
        ),
      );
      var lastDone = 0;
      final result = await export.run(
        onProgress: (done, total) => lastDone = done,
      );
      expect(source.pages, 2);
      expect(result!.added, 130 + 65);
      expect(lastDone, 195);
      expect(result.file.path, endsWith('pocket_portrait_2026-11-02.zip'));
      final zip = ZipDecoder().decodeBytes(result.file.readAsBytesSync());
      final listing =
          jsonDecode(
                utf8.decode(zip.findFile('posts.json')!.content as List<int>),
              )
              as Map<String, dynamic>;
      expect(listing['username'], 'me');
      expect((listing['posts'] as List), hasLength(130));
      expect(
        (listing['posts'] as List).first,
        containsPair('caption', 'post 130'),
      );
    });

    test('an account with no posts has nothing to export', () async {
      final export = AccountExport(
        source: _PagedPosts(const []),
        username: 'me',
        exporter: MediaExporter(StubUrls(), tempDir: () async => dir),
      );
      expect(await export.run(), isNull);
    });
  });
}

class _PagedPosts implements MyPostsSource {
  _PagedPosts(this.posts);

  /// Newest first.
  final List<RemotePost> posts;
  var pages = 0;

  @override
  Future<List<RemotePost>> page({DateTime? before, int limit = 100}) async {
    pages++;
    return [
      for (final p in posts)
        if (before == null || p.createdAt.isBefore(before)) p,
    ].take(limit).toList();
  }
}
