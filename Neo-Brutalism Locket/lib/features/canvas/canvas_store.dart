import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neo_brutalism_locket/features/canvas/canvas_repository.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';

enum CanvasStatus { loading, ready, empty, error }

/// The shared canvas of one group.
///
/// - What I paint shows at once (optimistic) and is sent in batches of up to
///   10 pixels; if the server refuses, my pixels go back to what they were.
/// - Other people's pixels arrive by themselves. Every change has a version
///   number; when one is missing the store asks the server for what it missed.
/// - A dropped connection retries the SAME batch (the server never charges a
///   batch twice). If it stays down, the canvas becomes view-only.
class CanvasStore extends ChangeNotifier {
  CanvasStore(
    this.repository, {
    required this.groupId,
    this.batchDelay = const Duration(milliseconds: 300),
    this.retryDelay = const Duration(seconds: 3),
    this.maxAttempts = 3,
    String Function()? newBatchId,
  }) : _newBatchId = newBatchId ?? newUuid;

  final CanvasRepository repository;
  final String groupId;
  final Duration batchDelay;
  final Duration retryDelay;
  final int maxAttempts;
  final String Function() _newBatchId;

  static const maxBatch = 10;

  CanvasStatus _status = CanvasStatus.loading;
  CanvasData? _data;
  Uint8List _pixels = Uint8List(0);
  int _version = 0;
  int _ink = 0;
  bool _offline = false;
  CanvasFailureKind? _lastFailure;
  StreamSubscription<PixelEvent>? _subscription;
  Timer? _flushTimer;
  bool _sending = false;
  bool _catchingUp = false;
  bool _disposed = false;

  /// My unsent pixels, by cell index: what is shown instead of the server's.
  final Map<int, int> _pending = {};

  /// Cells in the order they were painted, waiting for the next batch.
  final List<int> _queue = [];

  /// The last person known to have painted each cell (this session).
  final Map<int, String> _painters = {};

  CanvasStatus get status => _status;
  CanvasData? get data => _data;
  int get width => _data?.width ?? 0;
  int get height => _data?.height ?? 0;
  List<int> get palette => _data?.palette ?? const [];
  int get version => _version;

  /// My Ink, minus what my unsent pixels will cost.
  int get ink => _ink - _pending.length;

  /// True when the connection stayed down: you can look but not paint.
  bool get offline => _offline;

  /// Why the last action was refused (cleared by the next paint).
  CanvasFailureKind? get lastFailure => _lastFailure;

  bool get canPaint =>
      _status == CanvasStatus.ready && !_offline && (_data?.active ?? false);

  int indexOf(int x, int y) => y * width + x;

  /// The palette index shown at a cell (mine first, while it is unsent).
  int colorIndexAt(int x, int y) {
    final index = indexOf(x, y);
    return _pending[index] ?? _pixels[index];
  }

  /// Who painted a cell last, if known.
  String? painterAt(int x, int y) => _painters[indexOf(x, y)];

  bool isPending(int x, int y) => _pending.containsKey(indexOf(x, y));

  Future<void> load() async {
    _status = CanvasStatus.loading;
    notifyListeners();
    try {
      final id = await repository.activeCanvasId(groupId);
      if (id == null) {
        _status = CanvasStatus.empty;
        notifyListeners();
        return;
      }
      final data = await repository.load(id);
      _data = data;
      _pixels = Uint8List.fromList(data.pixels);
      _version = data.version;
      _ink = data.inkBalance;
      _offline = false;
      _status = CanvasStatus.ready;
      await _subscription?.cancel();
      _subscription = repository.watch(id).listen(_onEvent);
      notifyListeners();
      unawaited(_loadAuthors(id));
    } on CanvasFailure catch (failure) {
      _lastFailure = failure.kind;
      _status = CanvasStatus.error;
      notifyListeners();
    }
  }

  /// Fills "who painted this" from the event log. Best effort.
  Future<void> _loadAuthors(String id) async {
    try {
      var since = 0;
      for (var page = 0; page < 5; page++) {
        final events = await repository.eventsSince(id, since, limit: 1000);
        for (final event in events) {
          final userId = event.userId;
          if (userId != null) _painters[event.y * width + event.x] = userId;
          since = event.version;
        }
        if (events.length < 1000) break;
      }
      if (!_disposed) notifyListeners();
    } on CanvasFailure {
      // Authors are a nicety: the canvas works without them.
    }
  }

  /// Retry after a failed load or after coming back online.
  Future<void> reload() async {
    _flushTimer?.cancel();
    _queue.clear();
    _pending.clear();
    await load();
  }

  // Events from the server -----------------------------------------------------

  void _onEvent(PixelEvent event) {
    if (_disposed) return;
    if (event.version <= _version) return; // already applied
    if (event.version > _version + 1) {
      // One or more were missed: ask for them instead of guessing.
      unawaited(_catchUp());
      return;
    }
    _apply(event);
    notifyListeners();
  }

  void _apply(PixelEvent event) {
    final index = event.y * width + event.x;
    if (index < 0 || index >= _pixels.length) return;
    _pixels[index] = event.color;
    _version = event.version;
    final userId = event.userId;
    if (userId != null) _painters[index] = userId;
  }

  Future<void> _catchUp() async {
    final id = _data?.id;
    if (id == null || _catchingUp) return;
    _catchingUp = true;
    try {
      while (!_disposed) {
        final events = await repository.eventsSince(id, _version, limit: 500);
        if (events.isEmpty) break;
        // A hole this big is cheaper to fix by loading the whole 1 KB canvas.
        if (events.first.version > _version + 1) {
          final data = await repository.load(id);
          _data = data;
          _pixels = Uint8List.fromList(data.pixels);
          _version = data.version;
          _ink = data.inkBalance;
          break;
        }
        for (final event in events) {
          if (event.version == _version + 1) _apply(event);
        }
        if (events.length < 500) break;
      }
      _offline = false;
    } on CanvasFailure {
      // Still unreachable: the next event or reload tries again.
    } finally {
      _catchingUp = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Painting --------------------------------------------------------------------

  /// Paints a cell. Returns false (and says why in [lastFailure]) when it
  /// cannot: out of Ink, view-only, or outside the canvas.
  bool paint(int x, int y, int color) {
    _lastFailure = null;
    if (!canPaint) {
      notifyListeners();
      return false;
    }
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    if (color < 0 || color >= palette.length) return false;
    final index = indexOf(x, y);
    final already = _pending[index] ?? _pixels[index];
    if (already == color) return true; // nothing changes, nothing costs
    final isNewCell = !_pending.containsKey(index);
    if (isNewCell && ink < 1) {
      _lastFailure = CanvasFailureKind.insufficientInk;
      notifyListeners();
      return false;
    }
    _pending[index] = color;
    if (isNewCell) _queue.add(index);
    _scheduleFlush();
    notifyListeners();
    return true;
  }

  void _scheduleFlush() {
    if (_sending) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(_queue.length >= maxBatch ? Duration.zero : batchDelay,
        () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    final id = _data?.id;
    if (_sending || id == null || _queue.isEmpty) return;
    _sending = true;
    final cells = _queue.take(maxBatch).toList();
    _queue.removeRange(0, cells.length);
    final patches = [
      for (final cell in cells)
        PixelPatch(cell % width, cell ~/ width, _pending[cell]!),
    ];
    final batchId = _newBatchId();
    try {
      PaintResult? result;
      for (var attempt = 1; result == null; attempt++) {
        try {
          result = await repository.paint(id, batchId, patches);
        } on CanvasFailure catch (failure) {
          if (failure.kind != CanvasFailureKind.network) rethrow;
          if (attempt >= maxAttempts || _disposed) rethrow;
          await Future<void>.delayed(retryDelay);
        }
      }
      _ink = result.inkBalance;
      _offline = false;
      for (final cell in cells) {
        _pending.remove(cell);
      }
      // Our own pixels come back as events; fetch them if they are late.
      if (result.version > _version) unawaited(_catchUp());
    } on CanvasFailure catch (failure) {
      _lastFailure = failure.kind;
      // The server did not take them: show the canvas as it really is.
      for (final cell in cells) {
        _pending.remove(cell);
      }
      switch (failure.kind) {
        case CanvasFailureKind.network:
          _offline = true;
        case CanvasFailureKind.insufficientInk:
        case CanvasFailureKind.canvasLocked:
        case CanvasFailureKind.notFound:
          unawaited(_refreshAfterRefusal());
        case _:
          break;
      }
    } finally {
      _sending = false;
      if (!_disposed) {
        if (_queue.isNotEmpty) _scheduleFlush();
        notifyListeners();
      }
    }
  }

  /// After a refusal my Ink or the canvas itself may have changed: reload.
  Future<void> _refreshAfterRefusal() async {
    final id = _data?.id;
    if (id == null) return;
    try {
      final data = await repository.load(id);
      _data = data;
      _pixels = Uint8List.fromList(data.pixels);
      _version = data.version;
      _ink = data.inkBalance;
      if (!_disposed) notifyListeners();
    } on CanvasFailure {
      // Keep what is on screen.
    }
  }

  /// Sends what is waiting right now (for tests and for leaving the screen).
  Future<void> flushNow() async {
    _flushTimer?.cancel();
    while (_queue.isNotEmpty || _sending) {
      if (_sending) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        continue;
      }
      await _flush();
    }
  }

  // Owner tools -------------------------------------------------------------------

  Future<void> startNewCanvas({
    required int size,
    required String paletteId,
  }) async {
    await repository.newCanvas(groupId, size: size, paletteId: paletteId);
    await reload();
  }

  Future<int> rollbackUser(String userId, DateTime since) async {
    final id = _data?.id;
    if (id == null) return 0;
    final restored = await repository.rollback(id, userId, since);
    await _catchUp();
    return restored;
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
