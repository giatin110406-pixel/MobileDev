import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// A group's canvas: one palette index per cell, row by row.
class CanvasData {
  const CanvasData({
    required this.id,
    required this.groupId,
    required this.width,
    required this.height,
    required this.palette,
    required this.pixels,
    required this.version,
    required this.inkBalance,
    this.active = true,
  });

  final String id;
  final String groupId;
  final int width;
  final int height;

  /// ARGB colours; index 0 is the empty canvas colour.
  final List<int> palette;
  final Uint8List pixels;

  /// Counts every change ever made to this canvas.
  final int version;
  final int inkBalance;
  final bool active;

  factory CanvasData.fromJson(Map<String, dynamic> json) => CanvasData(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
    palette: [
      for (final hex in json['palette'] as List<dynamic>) parseHexColor('$hex'),
    ],
    // Postgres wraps base64 every 76 characters; Dart refuses the line breaks.
    pixels: base64Decode(
      (json['pixels'] as String).replaceAll(RegExp(r'\s'), ''),
    ),
    version: (json['version'] as num).toInt(),
    inkBalance: json['ink_balance'] as int? ?? 0,
    active: json['status'] == null || json['status'] == 'active',
  );
}

/// "#RRGGBB" as an opaque ARGB int.
int parseHexColor(String hex) =>
    0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16);

/// One pixel painted by someone.
class PixelEvent {
  const PixelEvent({
    required this.x,
    required this.y,
    required this.color,
    required this.version,
    this.userId,
    this.at,
  });

  final int x;
  final int y;
  final int color;
  final int version;
  final String? userId;
  final DateTime? at;

  /// Reads both the RPC's shape (`at`) and a realtime row (`created_at`).
  factory PixelEvent.fromJson(Map<String, dynamic> json) {
    final at = (json['at'] ?? json['created_at']) as String?;
    return PixelEvent(
      x: json['x'] as int,
      y: json['y'] as int,
      color: json['color'] as int,
      version: (json['version'] as num).toInt(),
      userId: json['user_id'] as String?,
      at: at == null ? null : DateTime.parse(at).toLocal(),
    );
  }
}

/// A pixel to paint.
class PixelPatch {
  const PixelPatch(this.x, this.y, this.color);

  final int x;
  final int y;
  final int color;

  Map<String, int> toJson() => {'x': x, 'y': y, 'c': color};
}

class PaintResult {
  const PaintResult({
    required this.version,
    required this.inkBalance,
    required this.painted,
    this.repeat = false,
  });

  final int version;
  final int inkBalance;

  /// How many pixels actually changed (and cost 1 Ink each).
  final int painted;

  /// The server had already done this batch.
  final bool repeat;

  factory PaintResult.fromJson(Map<String, dynamic> json) => PaintResult(
    version: (json['version'] as num).toInt(),
    inkBalance: json['ink_balance'] as int? ?? 0,
    painted: json['painted'] as int? ?? 0,
    repeat: json['repeat'] as bool? ?? false,
  );
}

enum CanvasFailureKind {
  notFound,
  notOwner,
  canvasLocked,
  badPixel,
  tooManyPixels,
  insufficientInk,
  rateLimited,
  badSize,
  network,
  unknown,
}

class CanvasFailure implements Exception {
  const CanvasFailure(this.kind);

  final CanvasFailureKind kind;

  @override
  String toString() => 'CanvasFailure($kind)';
}

abstract interface class CanvasRepository {
  /// The group's active canvas, or null if it has none.
  Future<String?> activeCanvasId(String groupId);

  Future<CanvasData> load(String canvasId);

  /// Events after [version], oldest first (at most [limit]).
  Future<List<PixelEvent>> eventsSince(
    String canvasId,
    int version, {
    int limit = 500,
  });

  /// Paints up to 10 pixels. Sending the same [batchId] again never charges
  /// twice, so a retry after a dropped connection is safe.
  Future<PaintResult> paint(
    String canvasId,
    String batchId,
    List<PixelPatch> pixels,
  );

  /// Owner only: archives the current canvas and starts an empty one.
  Future<String> newCanvas(
    String groupId, {
    required int size,
    required String paletteId,
  });

  /// Owner only: puts back what was there before [userId] painted (since
  /// [since]). Returns how many pixels were restored.
  Future<int> rollback(String canvasId, String userId, DateTime since);

  /// New pixels from other people (and my own) while someone listens.
  Stream<PixelEvent> watch(String canvasId);
}

class SupabaseCanvasRepository implements CanvasRepository {
  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<String?> activeCanvasId(String groupId) => _guard(() async {
    final id = await _db.rpc('get_group_canvas', params: {'p_group': groupId});
    return id as String?;
  });

  @override
  Future<CanvasData> load(String canvasId) => _guard(() async {
    final json = await _db.rpc('get_canvas', params: {'p_canvas': canvasId});
    return CanvasData.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<List<PixelEvent>> eventsSince(
    String canvasId,
    int version, {
    int limit = 500,
  }) => _guard(() async {
    final rows = await _db.rpc(
      'get_canvas_events',
      params: {
        'p_canvas': canvasId,
        'p_since_version': version,
        'p_limit': limit,
      },
    );
    return [
      for (final row in rows as List<dynamic>)
        PixelEvent.fromJson(row as Map<String, dynamic>),
    ];
  });

  @override
  Future<PaintResult> paint(
    String canvasId,
    String batchId,
    List<PixelPatch> pixels,
  ) => _guard(() async {
    final json = await _db.rpc(
      'paint_pixels',
      params: {
        'p_canvas': canvasId,
        'p_batch': batchId,
        'p_pixels': [for (final pixel in pixels) pixel.toJson()],
      },
    );
    return PaintResult.fromJson(json as Map<String, dynamic>);
  });

  @override
  Future<String> newCanvas(
    String groupId, {
    required int size,
    required String paletteId,
  }) => _guard(() async {
    final id = await _db.rpc(
      'new_canvas',
      params: {'p_group': groupId, 'p_size': size, 'p_palette': paletteId},
    );
    return id as String;
  });

  @override
  Future<int> rollback(String canvasId, String userId, DateTime since) =>
      _guard(() async {
        final count = await _db.rpc(
          'rollback_user_events',
          params: {
            'p_canvas': canvasId,
            'p_user': userId,
            'p_since': since.toUtc().toIso8601String(),
          },
        );
        return count as int;
      });

  @override
  Stream<PixelEvent> watch(String canvasId) {
    late final StreamController<PixelEvent> controller;
    sb.RealtimeChannel? channel;
    controller = StreamController<PixelEvent>.broadcast(
      onListen: () {
        channel = _db
            .channel('canvas-$canvasId')
            .onPostgresChanges(
              event: sb.PostgresChangeEvent.insert,
              schema: 'public',
              table: 'canvas_events',
              filter: sb.PostgresChangeFilter(
                type: sb.PostgresChangeFilterType.eq,
                column: 'canvas_id',
                value: canvasId,
              ),
              callback: (payload) {
                try {
                  controller.add(PixelEvent.fromJson(payload.newRecord));
                } catch (_) {
                  // A malformed row must not break the stream; the version
                  // gap check in the store fetches what was missed.
                }
              },
            )
            .subscribe();
      },
      onCancel: () {
        final open = channel;
        if (open != null) _db.removeChannel(open);
      },
    );
    return controller.stream;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw CanvasFailure(kindOfMessage(error.message));
    } on sb.AuthException {
      throw const CanvasFailure(CanvasFailureKind.unknown);
    } catch (error) {
      if (error is CanvasFailure) rethrow;
      throw const CanvasFailure(CanvasFailureKind.network);
    }
  }

  /// The RPCs raise short codes (see the canvas migration) as the message.
  static CanvasFailureKind kindOfMessage(String message) => switch (message) {
    'not_found' || 'not_member' => CanvasFailureKind.notFound,
    'not_owner' => CanvasFailureKind.notOwner,
    'canvas_locked' => CanvasFailureKind.canvasLocked,
    'bad_pixel' => CanvasFailureKind.badPixel,
    'too_many_pixels' => CanvasFailureKind.tooManyPixels,
    'insufficient_ink' => CanvasFailureKind.insufficientInk,
    'rate_limited' => CanvasFailureKind.rateLimited,
    'bad_size' || 'bad_palette' => CanvasFailureKind.badSize,
    _ => CanvasFailureKind.unknown,
  };
}
