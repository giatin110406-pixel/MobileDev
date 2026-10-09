import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';

/// What the next change of the contest is, for the countdown.
class ContestMilestone {
  const ContestMilestone(this.phase, this.at);

  /// The phase that starts at [at].
  final ContestPhase phase;
  final DateTime at;
}

/// This week's contest, for the UI.
///
/// Time comes from the server: the store remembers how far the phone's clock
/// is from the server's, so a wrong phone clock cannot show a contest as open
/// when it is not (and the server refuses anyway).
class ContestStore extends ChangeNotifier {
  ContestStore(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _subscription = repository.changes.listen((_) => refresh());
  }

  final ContestRepository repository;
  final DateTime Function() _clock;
  StreamSubscription<void>? _subscription;
  Timer? _timer;
  ContestOverview? _overview;
  Duration _offset = Duration.zero;
  bool _loaded = false;
  bool _loading = false;
  bool _again = false;
  ContestFailure? _error;

  ContestOverview? get overview => _overview;
  ContestInfo? get contest => _overview?.contest;
  ContestTheme? get theme => _overview?.theme;
  bool get isLoaded => _loaded;
  bool get isLoading => _loading;

  /// Set when the last refresh failed (the old data stays).
  ContestFailure? get error => _error;

  /// The server's idea of now.
  DateTime get now => _clock().add(_offset);

  /// The phase right now by the server's clock, so the screen moves on by
  /// itself without asking the server (the server is the one that enforces it).
  ContestPhase get phase {
    final info = contest;
    if (info == null) return ContestPhase.upcoming;
    if (info.phase == ContestPhase.finalized) return ContestPhase.finalized;
    final at = now;
    if (!at.isBefore(info.endsAt)) return ContestPhase.closed;
    if (!at.isBefore(info.submitClosesAt) ||
        (!at.isBefore(info.opensAt) && info.isFull)) {
      return ContestPhase.judging;
    }
    if (!at.isBefore(info.opensAt)) return ContestPhase.open;
    return ContestPhase.upcoming;
  }

  /// The next time the phase changes, or null once nothing more will.
  ContestMilestone? get nextMilestone {
    final info = contest;
    if (info == null) return null;
    return switch (phase) {
      ContestPhase.upcoming => ContestMilestone(
        ContestPhase.open,
        info.opensAt,
      ),
      ContestPhase.open => ContestMilestone(
        ContestPhase.judging,
        info.submitClosesAt,
      ),
      ContestPhase.judging => ContestMilestone(
        ContestPhase.closed,
        info.endsAt,
      ),
      ContestPhase.closed || ContestPhase.finalized => null,
    };
  }

  Duration? get timeLeft {
    final milestone = nextMilestone;
    if (milestone == null) return null;
    final left = milestone.at.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Groups I own that can still enter (the contest must be open).
  List<OwnedGroup> get submittableGroups => phase == ContestPhase.open
      ? [
          for (final group in _overview?.ownerGroups ?? const <OwnedGroup>[])
            if (!group.submitted) group,
        ]
      : const [];

  Future<void> refresh() async {
    if (_loading) {
      _again = true; // a change arrived while loading: load once more after
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      do {
        _again = false;
        try {
          final fresh = await repository.overview();
          _overview = fresh;
          if (fresh != null) _offset = fresh.serverNow.difference(_clock());
          _loaded = true;
          _error = null;
        } on ContestFailure catch (failure) {
          _error = failure;
        }
      } while (_again);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Keep the screen's countdown and phase fresh while it is open: the
  /// countdown ticks each second and the server is asked again now and then.
  void startTicking({Duration every = const Duration(seconds: 1)}) {
    _timer?.cancel();
    var seconds = 0;
    _timer = Timer.periodic(every, (_) {
      seconds++;
      // The phase may have just moved on: ask the server after a milestone.
      final left = timeLeft;
      if (seconds % 60 == 0 || (left != null && left == Duration.zero)) {
        refresh();
      }
      notifyListeners();
    });
  }

  void stopTicking() {
    _timer?.cancel();
    _timer = null;
  }

  /// Enters [group]'s canvas. Throws [ContestFailure]; reloads on success.
  /// Returns the place the entry got (1 to 100).
  Future<int> submit(OwnedGroup group) async {
    final contestId = contest?.id;
    try {
      final seq = await repository.submit(group.id, contestId: contestId);
      return seq;
    } finally {
      // Also after a refusal: someone else may have taken the last place.
      await refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    repository.dispose();
    super.dispose();
  }
}
