import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/pov/pov_repository.dart';

/// Why a session is over, for the person who has to be told.
enum PovEnd {
  /// The code ran out before anybody scanned it.
  expired,

  /// The other person (or I) stopped it.
  ended,

  /// The phones could not stay connected.
  lostConnection,
}

/// Where I stand in Omni POV: showing a code, watching a friend's camera (A), or
/// showing mine to a friend (B). At most one session at a time (the server sees to it).
///
///  * A opens a code ([openCode]): [code] is on the screen and [isWaiting] until a
///    friend scans it, then [isWatching].
///  * B scans a code, is shown whose it is ([peek]) and says yes ([join]): [isHosting].
class PovStore extends ChangeNotifier {
  PovStore(this.repository, {required this.myId, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PovRepository repository;
  final String myId;
  final DateTime Function() _clock;

  PovSession? _session;
  PovCode? _code;
  PovEnd? _lastEnd;
  PovFailure? _error;
  bool _busy = false;
  Timer? _expiry;
  Timer? _waitingPoll;
  bool _polling = false;
  StreamSubscription<PovSession>? _changes;

  /// My session, if it is not over.
  PovSession? get session => _session;

  /// The code on my screen, while nobody has scanned it.
  PovCode? get code => isWaiting ? _code : null;

  /// Why the last session ended, until [clearNotice].
  PovEnd? get lastEnd => _lastEnd;

  /// What went wrong with the last thing I tried, until [clearNotice].
  PovFailure? get error => _error;

  /// Something is being sent to the server.
  bool get busy => _busy;

  bool get isViewer => _session?.viewerId == myId;
  bool get isHost => _session?.hostId == myId;

  /// My code is on the screen and nobody has scanned it yet.
  bool get isWaiting => isViewer && (_session?.isWaiting(_clock()) ?? false);

  /// I am watching a friend's camera.
  bool get isWatching => isViewer && _session?.status == PovStatus.accepted;

  /// A friend is watching mine.
  bool get isHosting => isHost && _session?.status == PovStatus.accepted;

  /// Starts listening for changes and loads what is going on now.
  Future<void> start() async {
    _changes ??= repository.changes.listen(_apply);
    await refresh();
  }

  /// Loads my live sessions (after the app was away).
  Future<void> refresh() async {
    try {
      final live = await repository.loadLive();
      for (final session in live.reversed) {
        _apply(session);
      }
    } on PovFailure {
      // Nothing to show; the next change will say more.
    }
  }

  // Showing a code (A) -----------------------------------------------------------------

  /// A opens a code. Returns false (and sets [error]) when it did not go through.
  Future<bool> openCode() async {
    if (_busy) return false;
    if (isWatching) return false;
    _lastEnd = null;
    return _run(() async {
      final code = await repository.createCode();
      _code = code;
      _setSession(
        PovSession(
          id: code.sessionId,
          viewerId: myId,
          status: PovStatus.pending,
          createdAt: _clock(),
          expiresAt: code.expiresAt,
        ),
      );
    });
  }

  /// A closes the code.
  Future<void> closeCode() async {
    final session = _session;
    if (session == null || !isWaiting) return;
    _code = null;
    _setSession(null);
    await _run(() => repository.cancel(session.id));
  }

  // Scanning a code (B) -----------------------------------------------------------------

  /// Whose is this code? Null (and [error] set) when it cannot be used.
  Future<PovPeek?> peek(String code) async {
    PovPeek? found;
    await _run(() async => found = await repository.peek(code));
    return found;
  }

  /// B said yes: A watches B's camera from now on.
  Future<bool> join(String code) async {
    if (_busy) return false;
    return _run(() async {
      final joined = await repository.join(code);
      _setSession(joined.copyWith(status: PovStatus.accepted));
    });
  }

  // During a session ------------------------------------------------------------------

  /// B reports a photo (A's screen counts them).
  Future<void> reportShot() async {
    final session = _session;
    if (session == null || !isHost) return;
    _session = session.copyWith(shots: session.shots + 1);
    notifyListeners();
    try {
      await repository.reportShot(session.id);
    } on PovFailure {
      // The photo is saved anyway; only the other screen's count is off.
    }
  }

  /// Either of them stops the session.
  Future<void> end({PovEnd? reason}) async {
    final session = _session;
    if (session == null) return;
    final waiting = isWaiting;
    _code = null;
    _setSession(null);
    if (reason != null) _lastEnd = reason;
    notifyListeners();
    try {
      if (session.status == PovStatus.accepted) {
        await repository.end(session.id);
      } else if (waiting) {
        await repository.cancel(session.id);
      }
    } on PovFailure {
      // It ends by itself (30 minutes at the latest).
    }
  }

  /// The screen has shown [lastEnd] or [error].
  void clearNotice() {
    if (_lastEnd == null && _error == null) return;
    _lastEnd = null;
    _error = null;
    notifyListeners();
  }

  // Changes from the server ---------------------------------------------------------------

  void _apply(PovSession update) {
    final now = _clock();
    final mine = _session;
    if (mine != null && mine.id == update.id) {
      // A delayed read must not put an accepted session back into pending.
      if (mine.status == PovStatus.accepted &&
          update.status == PovStatus.pending) {
        return;
      }
      if (update.isOver) {
        _lastEnd = _endOf(update.status);
        _code = null;
        _setSession(null);
      } else {
        // The code was scanned (a host appeared), or the count went up. Keep the
        // larger count: B's own report may be ahead of the server's.
        _setSession(
          update.copyWith(
            shots: update.shots > mine.shots ? update.shots : mine.shots,
          ),
        );
      }
      return;
    }
    if (mine != null) return;
    // Picked up after the app was away: a code on screen or a session running.
    final isMine = update.viewerId == myId || update.hostId == myId;
    if (isMine &&
        (update.status == PovStatus.accepted || update.isWaiting(now))) {
      _setSession(update);
    }
  }

  PovEnd _endOf(PovStatus status) =>
      status == PovStatus.expired ? PovEnd.expired : PovEnd.ended;

  void _setSession(PovSession? session) {
    _session = session;
    _syncExpiry();
    notifyListeners();
  }

  /// A code nobody scans runs out here too, without asking the server.
  void _syncExpiry() {
    _expiry?.cancel();
    _expiry = null;
    _waitingPoll?.cancel();
    _waitingPoll = null;
    final session = _session;
    if (session == null || session.status != PovStatus.pending) return;
    final wait = session.expiresAt.difference(_clock());
    _expiry = Timer(wait.isNegative ? Duration.zero : wait, _expire);
    // Realtime can miss an update while its subscription is reconnecting.
    // While the QR is visible, reconcile with the server as a fallback.
    _waitingPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_polling) return;
      _polling = true;
      try {
        final live = await repository.loadLive();
        if (_session?.id != session.id || !isWaiting) return;
        for (final update in live) {
          if (update.id == session.id) {
            _apply(update);
            break;
          }
        }
      } on PovFailure {
        // Realtime or the next poll can still deliver the update.
      } finally {
        _polling = false;
      }
    });
  }

  void _expire() {
    final session = _session;
    if (session == null || session.status != PovStatus.pending) return;
    if (session.isWaiting(_clock())) {
      // The timer went off a moment before the clock says the code has run out.
      _syncExpiry();
      return;
    }
    _code = null;
    _session = null;
    _waitingPoll?.cancel();
    _waitingPoll = null;
    _lastEnd = PovEnd.expired;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() call) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await call();
      return true;
    } on PovFailure catch (failure) {
      _error = failure;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _waitingPoll?.cancel();
    _changes?.cancel();
    repository.dispose();
    super.dispose();
  }
}
