import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/app/app_shell.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/camera/capture_options.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/history/history_screen.dart';
import 'package:neo_brutalism_locket/features/posts/media_encoding.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_outbox.dart';
import 'package:neo_brutalism_locket/features/posts/post_overlay.dart';
import 'package:neo_brutalism_locket/features/posts/posts_repository.dart';
import 'package:neo_brutalism_locket/features/posts/video_views.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/social/feed_view.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingPosts implements PostsRepository {
  final sent = <PendingPost>[];

  @override
  Future<List<RemotePost>> loadFeed({DateTime? before, int limit = 30}) async =>
      const [];

  @override
  Future<void> send(PendingPost post) async => sent.add(post);

  @override
  Stream<void> get incoming => const Stream<void>.empty();

  @override
  void dispose() {}
}

class FakePlace implements PlaceLookup {
  FakePlace(this.answer);

  /// A name, or a [PlaceProblem] to fail with.
  final Object answer;
  var calls = 0;

  @override
  Future<String> currentPlace() async {
    calls++;
    final value = answer;
    if (value is PlaceProblem) throw PlaceUnavailable(value);
    return value as String;
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

  group('zoom and timer', () {
    test('zoom buttons only for levels the lens can reach', () {
      expect(zoomPresets(1, 8), [1.0, 2.0]);
      expect(zoomPresets(0.5, 10), [0.5, 1.0, 2.0]);
      expect(zoomPresets(1, 1), [1.0]);
      expect(zoomPresets(0.6, 1.5), [1.0]);
    });

    test('zoom stays inside the lens limits', () {
      expect(clampZoom(0.2, 1, 8), 1);
      expect(clampZoom(12, 1, 8), 8);
      expect(clampZoom(2.5, 1, 8), 2.5);
    });

    test('zoom labels', () {
      expect(zoomLabel(1), '1×');
      expect(zoomLabel(0.5), '0.5×');
      expect(zoomLabel(2.04), '2×');
      expect(zoomLabel(1.36), '1.4×');
    });

    test('the timer button goes off → 3s → 10s → off', () {
      expect(ShotTimer.off.next, ShotTimer.three);
      expect(ShotTimer.three.next, ShotTimer.ten);
      expect(ShotTimer.ten.next, ShotTimer.off);
      expect(ShotTimer.ten.seconds, 10);
      expect(maxVideoLength, const Duration(seconds: 3));
    });
  });

  group('time and place labels', () {
    test('only what is set is stored', () {
      expect(const PostOverlay().toJson(), isNull);
      expect(const PostOverlay(time: '09:05').toJson(), {'time': '09:05'});
      expect(const PostOverlay(time: '09:05', place: 'Huế').toJson(), {
        'time': '09:05',
        'place': 'Huế',
      });
    });

    test('reading the server copy ignores junk', () {
      final overlay = PostOverlay.fromJson({
        'time': ' 14:30 ',
        'place': 42,
        'extra': 'x',
      });
      expect(overlay.time, '14:30');
      expect(overlay.place, isNull);
      expect(PostOverlay.fromJson(null).isEmpty, isTrue);
      expect(PostOverlay.fromJson({'place': 'x' * 100}).place, hasLength(40));
    });

    test('time is shown as HH:mm', () {
      expect(formatOverlayTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(formatOverlayTime(DateTime(2026, 1, 1, 23, 59)), '23:59');
    });
  });

  group('videos in the outbox', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('video_outbox'));
    tearDown(() => dir.deleteSync(recursive: true));

    PostOutbox outbox(
      RecordingPosts posts, {
      Future<Uint8List?> Function(String)? thumb,
    }) => PostOutbox(
      repository: posts,
      userId: 'me',
      folder: dir,
      encode: (bytes, {required lossless}) => throw UnimplementedError(),
      videoThumbnail: thumb ?? (_) async => Uint8List.fromList([1, 2]),
    );

    test('a clip is copied, gets a still, and is sent as a video', () async {
      final posts = RecordingPosts();
      final clip = File('${dir.path}/clip.mp4')..writeAsBytesSync([7, 7, 7]);
      final box = outbox(posts);
      await box.enqueueVideo(
        video: clip,
        caption: ' look ',
        overlay: const {'time': '10:00'},
      );
      final pending = (await box.pending()).single;
      expect(pending.kind, 'video');
      expect(pending.extension, 'mp4');
      expect(pending.contentType, 'video/mp4');
      expect(pending.thumbFile, isNotNull);
      expect(File(pending.mediaFile).readAsBytesSync(), [7, 7, 7]);

      expect(await box.flush(), 1);
      expect(posts.sent.single.kind, 'video');
      expect(posts.sent.single.caption, 'look');
      expect(posts.sent.single.overlay, {'time': '10:00'});
      expect(File(pending.mediaFile).existsSync(), isFalse);
    });

    test('no still is fine: the video is still sent', () async {
      final posts = RecordingPosts();
      final clip = File('${dir.path}/clip.mp4')..writeAsBytesSync([1]);
      final box = outbox(posts, thumb: (_) async => throw Exception('codec'));
      await box.enqueueVideo(video: clip, caption: '');
      expect((await box.pending()).single.thumbFile, isNull);
      expect(await box.flush(), 1);
    });

    test('a queued video survives a restart', () async {
      final posts = RecordingPosts();
      final clip = File('${dir.path}/clip.mp4')..writeAsBytesSync([1]);
      await outbox(posts).enqueueVideo(video: clip, caption: 'later');
      final again = (await outbox(posts).pending()).single;
      expect(again.kind, 'video');
      expect(again.caption, 'later');
    });

    test('photos still go out as photos', () async {
      final posts = RecordingPosts();
      final source = File('${dir.path}/p.jpg')..writeAsBytesSync([1]);
      final box = PostOutbox(
        repository: posts,
        userId: 'me',
        folder: dir,
        encode: (bytes, {required lossless}) async => EncodedPhoto(
          media: Uint8List.fromList([1]),
          thumb: Uint8List.fromList([2]),
          extension: 'jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await box.enqueue(
        source: source,
        caption: '',
        overlay: const {'place': 'Huế'},
      );
      await box.flush();
      expect(posts.sent.single.kind, 'photo');
      expect(posts.sent.single.overlay, {'place': 'Huế'});
    });
  });

  group('composer labels', () {
    Future<ComposerResult?> run(
      WidgetTester tester,
      PlaceLookup place,
      Future<void> Function() interact,
    ) async {
      tester.view.physicalSize = const Size(400, 1000);
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
                          friends: [
                            Friend(
                              person: const Person(
                                id: 'f',
                                username: 'ava',
                                displayName: 'Ava',
                              ),
                              since: DateTime(2026),
                            ),
                          ],
                          placeLookup: place,
                          clock: () => DateTime(2026, 1, 1, 8, 7),
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

    testWidgets('no labels unless asked for', (tester) async {
      final result = await run(tester, FakePlace('Huế'), () async {
        await tester.tap(find.byIcon(Icons.send_rounded));
      });
      expect(result?.overlay, isNull);
    });

    testWidgets('time and place go on the post and show in the preview', (
      tester,
    ) async {
      final place = FakePlace('Huế');
      final result = await run(tester, place, () async {
        await tester.tap(find.text('TIME 08:07'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PLACE'));
        await tester.pumpAndSettle();
        expect(find.text('PLACE: Huế'), findsOneWidget);
        expect(find.text('08:07'), findsOneWidget, reason: 'preview label');
        expect(find.text('Huế'), findsOneWidget, reason: 'preview label');
        await tester.tap(find.byIcon(Icons.send_rounded));
      });
      expect(result?.overlay, {'time': '08:07', 'place': 'Huế'});
      expect(place.calls, 1);
    });

    testWidgets('location off: says so and sends without a place', (
      tester,
    ) async {
      final result = await run(
        tester,
        FakePlace(PlaceProblem.denied),
        () async {
          await tester.tap(find.text('PLACE'));
          await tester.pump();
          expect(
            find.text('The app is not allowed to use your location.'),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.send_rounded));
        },
      );
      expect(result?.overlay, isNull);
    });
  });

  group('showing videos and labels', () {
    RemotePost remote(
      String id, {
      String kind = 'photo',
      Map<String, dynamic>? overlay,
      String? thumb,
    }) => RemotePost(
      id: id,
      authorId: 'me',
      kind: kind,
      mediaPath: 'me/$id.${kind == 'video' ? 'mp4' : 'jpg'}',
      thumbPath: thumb,
      overlay: overlay,
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets('the feed shows a post\'s time and place', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FeedScreen(
              entries: [
                FeedEntry.remote(
                  remote('p1', overlay: {'time': '18:20', 'place': 'Đà Lạt'}),
                ),
              ],
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
      expect(find.text('18:20'), findsOneWidget);
      expect(find.text('Đà Lạt'), findsOneWidget);
    });

    testWidgets('a video waits behind its play badge', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FeedScreen(
              entries: [FeedEntry.remote(remote('v1', kind: 'video'))],
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
      expect(find.byType(RemoteVideo), findsOneWidget);
      expect(find.byType(VideoBadge), findsOneWidget);
    });

    testWidgets('videos are marked in the history grid', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: HistoryScreen(
              posts: [
                remote('v1', kind: 'video', thumb: 'me/v1_thumb.jpg'),
                remote('v2', kind: 'video'),
                remote('p1'),
              ],
              friends: const [],
              myId: 'me',
              onOpen: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(VideoBadge), findsNWidgets(2));
    });
  });

  group('self-timer on the camera', () {
    testWidgets('counts down, and a second tap cancels', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final player = PlayerStore(
        repository: PlayerRepository(clock: () => DateTime.utc(2026, 10, 1, 5)),
      );
      await tester.runAsync(player.load);
      await tester.pumpWidget(app(AppShell(playerStore: player)));
      await tester.pump(const Duration(milliseconds: 300));

      final timerButton = find.byIcon(Icons.timer_off_outlined);
      expect(timerButton, findsOneWidget);
      await tester.tap(timerButton);
      await tester.pump();
      expect(find.byIcon(Icons.timer_3), findsOneWidget);

      final shutter = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Take photo',
      );
      await tester.tap(shutter);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);

      await tester.tap(shutter); // cancel
      await tester.pump();
      expect(find.text('2'), findsNothing, reason: 'gone at once');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1'), findsNothing, reason: 'it did not keep going');
    });
  });
}
