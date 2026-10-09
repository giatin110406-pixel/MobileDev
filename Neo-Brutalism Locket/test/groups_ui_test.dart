import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_painter.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_store.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_view.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:neo_brutalism_locket/features/friends/friends_store.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_store.dart';
import 'package:neo_brutalism_locket/features/groups/group_chat_view.dart';
import 'package:neo_brutalism_locket/features/groups/groups_repository.dart';
import 'package:neo_brutalism_locket/features/groups/groups_screen.dart';
import 'package:neo_brutalism_locket/features/groups/groups_store.dart';
import 'package:neo_brutalism_locket/features/groups/groups_widgets.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

import 'canvas_store_test.dart' show FakeCanvas;
import 'friends_test.dart' show FakeFriends;
import 'groups_test.dart' show FakeGroups, message, person, summary;

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('groups list', () {
    testWidgets('an empty list explains what groups are for', (tester) async {
      final store = GroupsStore(FakeGroups());
      await store.refresh();
      await tester.pumpWidget(
        app(GroupsScreen(store: store, onOpenGroup: (_) {})),
      );
      expect(find.text('Chưa có nhóm nào'), findsOneWidget);
      expect(find.text('TẠO NHÓM'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('shows groups with their unread count and opens one', (
      tester,
    ) async {
      final store = GroupsStore(
        FakeGroups(groups: [summary('a', unread: 3), summary('b')]),
      );
      await store.refresh();
      GroupSummary? opened;
      await tester.pumpWidget(
        app(GroupsScreen(store: store, onOpenGroup: (g) => opened = g)),
      );
      expect(find.text('Group a'), findsOneWidget);
      expect(find.text('Group b'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Group b'));
      expect(opened?.group.id, 'b');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('an invitation can be accepted', (tester) async {
      final repo = FakeGroups(
        incoming: [
          GroupInvite(
            id: 'i1',
            groupId: 'z',
            groupName: 'Painters',
            person: person('boss'),
            incoming: true,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final store = GroupsStore(repo);
      await store.refresh();
      await tester.pumpWidget(
        app(GroupsScreen(store: store, onOpenGroup: (_) {})),
      );
      expect(find.text('Painters'), findsOneWidget);
      await tester.tap(find.text('THAM GIA'));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, contains('respond:i1:true'));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('a failed load shows a retry, not a blank screen', (
      tester,
    ) async {
      final repo = _Failing();
      final store = GroupsStore(repo);
      await store.refresh();
      await tester.pumpWidget(
        app(GroupsScreen(store: store, onOpenGroup: (_) {})),
      );
      expect(find.text('Không tải được danh sách nhóm.'), findsOneWidget);
      expect(find.text('THỬ LẠI'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('creating a group asks the server and closes the sheet', (
      tester,
    ) async {
      final repo = FakeGroups();
      final store = GroupsStore(repo);
      await store.refresh();
      String? created;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateGroupSheet(
                context,
                store: store,
                onCreated: (id) => created = id,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Team');
      await tester.tap(find.text('TẠO NHÓM').last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['create:Team']);
      expect(created, 'g0');
      expect(find.text('TẠO NHÓM MỚI'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('the server\'s refusal is shown inside the sheet', (
      tester,
    ) async {
      final repo = FakeGroups()
        ..failNext = const GroupFailure(GroupFailureKind.groupLimit);
      final store = GroupsStore(repo);
      await store.refresh();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateGroupSheet(context, store: store),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Team');
      await tester.tap(find.text('TẠO NHÓM').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('tối đa 5 nhóm'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });

  group('group chat', () {
    testWidgets('shows messages, names the others and sends mine', (
      tester,
    ) async {
      final repo = FakeGroups()
        ..messages.addAll([
          message('1', 'a', 'hello all', from: 'id-zed'),
          GroupMessage(
            id: '2',
            groupId: 'a',
            kind: GroupMessageKind.system,
            body: 'joined',
            senderId: 'id-zed',
            createdAt: DateTime(2026, 1, 1, 12, 1),
          ),
        ]);
      final chat = GroupChatStore(repo, groupId: 'a', myId: 'id-me');
      await chat.load();
      await tester.pumpWidget(
        app(
          GroupChatView(
            store: chat,
            members: {'id-zed': person('zed')},
            myId: 'id-me',
            onOpenPerson: (_) {},
          ),
        ),
      );
      expect(find.text('hello all'), findsOneWidget);
      expect(find.text('zed'), findsOneWidget);
      expect(find.text('zed đã tham gia nhóm'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hi team');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(repo.calls, ['send:a:hi team']);
      expect(find.text('hi team'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      chat.dispose();
    });
  });

  group('canvas view', () {
    Future<(FakeCanvas, CanvasStore)> open(
      WidgetTester tester, {
      int ink = 5,
    }) async {
      final repo = FakeCanvas(ink: ink);
      final store = CanvasStore(
        repo,
        groupId: 'g1',
        batchDelay: const Duration(hours: 1),
        retryDelay: Duration.zero,
      );
      await tester.runAsync(store.load);
      await tester.pumpWidget(
        app(CanvasView(store: store, nameOf: (id) => id == 'other' ? 'Zed' : null)),
      );
      return (repo, store);
    }

    final painterFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CanvasPainter,
    );

    testWidgets('tapping a cell paints it and spends Ink', (tester) async {
      final (_, store) = await open(tester);
      expect(find.text('5 MỰC'), findsOneWidget);
      final topLeft = tester.getTopLeft(painterFinder);
      final cell = tester.getSize(painterFinder).width / 4;
      await tester.tapAt(topLeft + Offset(cell * 1.5, cell * 0.5));
      await tester.pump();
      expect(store.colorIndexAt(1, 0), 1);
      expect(store.isPending(1, 0), isTrue);
      expect(find.text('4 MỰC'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('with no Ink it says so and nothing is painted', (
      tester,
    ) async {
      final (_, store) = await open(tester, ink: 0);
      expect(find.textContaining('Hết mực'), findsOneWidget);
      final topLeft = tester.getTopLeft(painterFinder);
      final cell = tester.getSize(painterFinder).width / 4;
      await tester.tapAt(topLeft + Offset(cell * 0.5, cell * 0.5));
      await tester.pump();
      expect(store.colorIndexAt(0, 0), 0);
      expect(find.textContaining('Hết mực'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('choosing another colour changes what a tap paints', (
      tester,
    ) async {
      final (_, store) = await open(tester);
      // The palette swatches are the 34-pixel squares under the canvas.
      final swatches = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 34 &&
            w.constraints?.maxHeight == 34,
      );
      expect(swatches, findsNWidgets(4));
      await tester.tap(swatches.at(3));
      await tester.pump();
      final topLeft = tester.getTopLeft(painterFinder);
      final cell = tester.getSize(painterFinder).width / 4;
      await tester.tapAt(topLeft + Offset(cell * 2.5, cell * 2.5));
      await tester.pump();
      expect(store.colorIndexAt(2, 2), 3);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('a group with no canvas says so', (tester) async {
      final repo = FakeCanvas(hasCanvas: false);
      final store = CanvasStore(repo, groupId: 'g1');
      await tester.runAsync(store.load);
      await tester.pumpWidget(app(CanvasView(store: store, nameOf: (_) => null)));
      expect(find.text('Nhóm này chưa có canvas.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });

  group('stranger card', () {
    Future<(FakeFriends, FriendsStore)> open(
      WidgetTester tester,
      Person stranger, {
      List<Friend> friends = const [],
    }) async {
      final repo = FakeFriends(friends: [...friends]);
      final store = FriendsStore(repo);
      await store.refresh();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPersonCard(context, person: stranger, friends: store),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (repo, store);
    }

    testWidgets('says that sharing a group does not share photos', (
      tester,
    ) async {
      await open(tester, person('zed'));
      expect(find.text('zed'), findsWidgets);
      expect(find.textContaining('chưa phải là bạn bè'), findsOneWidget);
      expect(find.text('KẾT BẠN'), findsOneWidget);
    });

    testWidgets('a friend shows as already a friend', (tester) async {
      final zed = person('zed');
      await open(
        tester,
        zed,
        friends: [Friend(person: zed, since: DateTime(2026, 1, 1))],
      );
      expect(find.text('ĐÃ LÀ BẠN BÈ'), findsOneWidget);
      expect(find.textContaining('chưa phải là bạn bè'), findsNothing);
    });
  });
}

/// A server that cannot be reached.
class _Failing extends FakeGroups {
  @override
  Future<GroupsSnapshot> load() async =>
      throw const GroupFailure(GroupFailureKind.network);
}
