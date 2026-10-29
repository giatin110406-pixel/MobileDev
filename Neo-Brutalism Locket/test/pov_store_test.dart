import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';
import 'package:neo_brutalism_locket/features/pov/pov_scan.dart';
import 'package:neo_brutalism_locket/features/pov/pov_store.dart';
import 'package:neo_brutalism_locket/features/pov/pov_text.dart';

const me = 'me';
const friend = 'friend';
const code32 = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

class FakePov implements PovRepository {
  final calls = <String>[];
  final updates = StreamController<PovSession>.broadcast();
  List<PovSession> live = [];
  PovFailure? failNext;
  var nextId = 1;
  Duration codeLasts = const Duration(minutes: 2);

  /// Who owns the codes a scan finds.
  PovPeek peeked = const PovPeek(
    sessionId: 's9',
    viewerId: friend,
    displayName: 'Lan Chi',
  );

  Future<T> _maybeFail<T>(T value) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return value;
  }

  @override
  Stream<PovSession> get changes => updates.stream;

  @override
  Future<PovCode> createCode() async {
    calls.add('create');
    final id = 's${nextId++}';
    return _maybeFail(
      PovCode(
        sessionId: id,
        code: code32,
        expiresAt: DateTime.now().add(codeLasts),
      ),
    );
  }

  @override
  Future<PovPeek> peek(String code) async {
    calls.add('peek:$code');
    return _maybeFail(peeked);
  }

  @override
  Future<PovSession> join(String code) async {
    calls.add('join:$code');
    return _maybeFail(
      PovSession(
        id: peeked.sessionId,
        viewerId: peeked.viewerId,
        hostId: me,
        status: PovStatus.accepted,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> cancel(String sessionId) async {
    calls.add('cancel:$sessionId');
  }

  @override
  Future<void> end(String sessionId) async {
    calls.add('end:$sessionId');
  }

  @override
  Future<void> reportShot(String sessionId) async {
    calls.add('shot:$sessionId');
  }

  @override
  Future<List<PovSession>> loadLive() async => live;

  @override
  Future<PovIce> iceServers() async => PovIce.stunOnly;

  @override
  PovSignalChannel openSignal(String sessionId) => throw UnimplementedError();

  @override
  void dispose() => updates.close();
}

/// A session of mine as the server sends it. By default I am the viewer (A), the code
/// is waiting for a scan.
PovSession session({
  String id = 's1',
  String viewer = me,
  String? host,
  PovStatus status = PovStatus.pending,
  Duration expiresIn = const Duration(minutes: 2),
  int shots = 0,
}) => PovSession(
  id: id,
  viewerId: viewer,
  hostId: host,
  status: status,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(expiresIn),
  shots: shots,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakePov repo;
  late PovStore store;

  setUp(() async {
    repo = FakePov();
    store = PovStore(repo, myId: me);
    await store.start();
  });

  tearDown(() => store.dispose());

  group('showing a code (I am the one being photographed)', () {
    test('opening a code puts it on the screen and waits', () async {
      expect(await store.openCode(), isTrue);
      expect(repo.calls, ['create']);
      expect(store.isWaiting, isTrue);
      expect(store.isViewer, isTrue);
      expect(store.code?.code, code32);
      expect(store.session?.hostId, isNull);
      expect(store.isWatching, isFalse);
    });

    test('a refusal from the server is kept and no code shows', () async {
      repo.failNext = const PovFailure(PovFailureKind.busy);
      expect(await store.openCode(), isFalse);
      expect(store.error?.kind, PovFailureKind.busy);
      expect(store.session, isNull);
      expect(store.code, isNull);
      store.clearNotice();
      expect(store.error, isNull);
    });

    test('when a friend scans it I am watching', () async {
      await store.openCode();
      repo.updates.add(
        session(id: 's1', host: friend, status: PovStatus.accepted),
      );
      await settle();
      expect(store.isWatching, isTrue);
      expect(store.isWaiting, isFalse);
      expect(store.code, isNull);
      expect(store.session?.hostId, friend);
    });

    test('I cannot open a code while I am watching', () async {
      await store.openCode();
      repo.updates.add(
        session(id: 's1', host: friend, status: PovStatus.accepted),
      );
      await settle();
      expect(await store.openCode(), isFalse);
      expect(repo.calls, ['create']);
    });

    test('closing the code tells the server', () async {
      await store.openCode();
      await store.closeCode();
      expect(repo.calls.last, 'cancel:s1');
      expect(store.session, isNull);
      expect(store.lastEnd, isNull);
    });

    test(
      'a code nobody scans runs out here, without asking the server',
      () async {
        repo.codeLasts = const Duration(milliseconds: 60);
        await store.openCode();
        expect(store.isWaiting, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(store.session, isNull);
        expect(store.code, isNull);
        expect(store.lastEnd, PovEnd.expired);
      },
    );

    test('the other person ending a session ends it for me', () async {
      await store.openCode();
      final accepted = session(
        id: 's1',
        host: friend,
        status: PovStatus.accepted,
      );
      repo.updates.add(accepted);
      await settle();
      repo.updates.add(accepted.copyWith(status: PovStatus.ended));
      await settle();
      expect(store.session, isNull);
      expect(store.lastEnd, PovEnd.ended);
    });

    test('the viewer sees the count the server sends', () async {
      await store.openCode();
      repo.updates.add(
        session(id: 's1', host: friend, status: PovStatus.accepted),
      );
      await settle();
      repo.updates.add(
        session(id: 's1', host: friend, status: PovStatus.accepted, shots: 3),
      );
      await settle();
      expect(store.session?.shots, 3);
    });
  });

  group('scanning a code (I take the photos)', () {
    test('peeking says whose code it is and joins nothing', () async {
      final peek = await store.peek(code32);
      expect(peek?.displayName, 'Lan Chi');
      expect(repo.calls, ['peek:$code32']);
      expect(store.session, isNull);
      expect(store.isHosting, isFalse);
    });

    test('a code that cannot be used is told, with the reason', () async {
      repo.failNext = const PovFailure(PovFailureKind.notFriends);
      expect(await store.peek(code32), isNull);
      expect(store.error?.kind, PovFailureKind.notFriends);
    });

    test('saying yes starts hosting', () async {
      expect(await store.join(code32), isTrue);
      expect(repo.calls.last, 'join:$code32');
      expect(store.isHosting, isTrue);
      expect(store.isViewer, isFalse);
      expect(store.session?.viewerId, friend);
    });

    test('a code that ran out meanwhile cannot be joined', () async {
      repo.failNext = const PovFailure(PovFailureKind.expired);
      expect(await store.join(code32), isFalse);
      expect(store.error?.kind, PovFailureKind.expired);
      expect(store.isHosting, isFalse);
    });

    test('photos are counted here at once, and reported', () async {
      await store.join(code32);
      await store.reportShot();
      await store.reportShot();
      expect(store.session?.shots, 2);
      expect(repo.calls.where((c) => c.startsWith('shot:')).length, 2);
    });

    test('only the host reports photos', () async {
      await store.openCode();
      await store.reportShot();
      expect(repo.calls.where((c) => c.startsWith('shot:')), isEmpty);
    });

    test('the friend ending the session ends it for me', () async {
      await store.join(code32);
      repo.updates.add(
        session(id: 's9', viewer: friend, host: me, status: PovStatus.ended),
      );
      await settle();
      expect(store.session, isNull);
      expect(store.lastEnd, PovEnd.ended);
    });
  });

  group('during and after', () {
    test('ending an accepted session tells the server and clears it', () async {
      await store.join(code32);
      await store.end();
      expect(repo.calls.last, 'end:s9');
      expect(store.session, isNull);
    });

    test('ending because the phones lost each other says so', () async {
      await store.join(code32);
      await store.end(reason: PovEnd.lostConnection);
      expect(store.lastEnd, PovEnd.lostConnection);
    });

    test('ending while the code waits closes it', () async {
      await store.openCode();
      await store.end();
      expect(repo.calls.last, 'cancel:s1');
      expect(store.session, isNull);
    });

    test('opening the app again picks up a code that is still on', () async {
      repo.live = [session(id: 'now')];
      await store.refresh();
      expect(store.isWaiting, isTrue);
    });

    test('a code that has already run out is not picked up', () async {
      repo.live = [session(id: 'old', expiresIn: const Duration(seconds: -5))];
      await store.refresh();
      expect(store.session, isNull);
    });

    test('a running session is picked up too, as viewer or as host', () async {
      repo.live = [
        session(
          id: 'running',
          viewer: me,
          host: friend,
          status: PovStatus.accepted,
        ),
      ];
      await store.refresh();
      expect(store.isWatching, isTrue);
    });

    test('other people\'s sessions are ignored', () async {
      repo.updates.add(
        session(viewer: 'x', host: 'y', status: PovStatus.accepted),
      );
      await settle();
      expect(store.session, isNull);
    });
  });

  group('the code in a link', () {
    test('the app\'s own link carries it', () {
      expect(povLinkFor(code32), 'neolocket://pov/$code32');
      expect(povCodeFromLink(Uri.parse(povLinkFor(code32))), code32);
      expect(povCodeFromText('  ${povLinkFor(code32)}\n'), code32);
    });

    test('anything else is not a code', () {
      expect(povCodeFromText('https://example.com/pov/$code32'), isNull);
      expect(povCodeFromText('neolocket://add/lan'), isNull);
      expect(povCodeFromText('neolocket://pov/short'), isNull);
      expect(povCodeFromText('neolocket://pov/$code32/extra'), isNull);
      expect(
        povCodeFromText('neolocket://pov/${code32.substring(1)}!'),
        isNull,
      );
      expect(povCodeFromText('hello'), isNull);
      expect(povCodeFromText(''), isNull);
    });
  });

  group('the scan helpers', () {
    test('the frame is turned by the sensor, less how the phone is held', () {
      expect(povScanRotation(90, DeviceOrientation.portraitUp), 90);
      expect(povScanRotation(90, DeviceOrientation.landscapeLeft), 0);
      expect(povScanRotation(90, DeviceOrientation.portraitDown), 270);
      expect(povScanRotation(90, DeviceOrientation.landscapeRight), 180);
    });

    test('the time a code has left reads as m:ss', () {
      expect(povClock(const Duration(minutes: 2)), '2:00');
      expect(povClock(const Duration(seconds: 65)), '1:05');
      expect(povClock(const Duration(seconds: 9)), '0:09');
      expect(povClock(const Duration(seconds: -4)), '0:00');
    });
  });
}
