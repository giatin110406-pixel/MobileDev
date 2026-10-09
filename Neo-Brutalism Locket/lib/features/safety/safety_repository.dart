import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/features/friends/friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum ReportReason { spam, inappropriate, harassment, other }

enum SafetyFailureKind { notFound, tooMany, network, unknown }

class SafetyFailure implements Exception {
  const SafetyFailure(this.kind);

  final SafetyFailureKind kind;

  @override
  String toString() => 'SafetyFailure($kind)';
}

abstract interface class SafetyRepository {
  /// Ends the friendship, hides each other's posts. They are not told.
  Future<void> block(String personId);

  Future<void> unblock(String personId);

  Future<List<Person>> loadBlocked();

  /// Reports a person ([userId]) or a post I received ([postId]).
  Future<void> report({
    String? userId,
    String? postId,
    required ReportReason reason,
    String? details,
  });
}

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository({required this.myId});

  final String myId;

  sb.SupabaseClient get _db => Backend.client;

  @override
  Future<void> block(String personId) =>
      _guard(() => _db.rpc('block_user', params: {'p_user': personId}));

  @override
  Future<void> unblock(String personId) =>
      _guard(() => _db.rpc('unblock_user', params: {'p_user': personId}));

  @override
  Future<List<Person>> loadBlocked() => _guard(() async {
    final rows = await _db
        .from('blocks')
        .select(
          'created_at, '
          'person:profiles!blocks_blocked_id_fkey(${Person.columns})',
        )
        .eq('blocker_id', myId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        Person.fromRow(row['person'] as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> report({
    String? userId,
    String? postId,
    required ReportReason reason,
    String? details,
  }) => _guard(
    () => _db.rpc(
      'report_content',
      params: {
        'p_user': userId,
        'p_post': postId,
        'p_reason': reason.name,
        'p_details': details,
      },
    ),
  );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.PostgrestException catch (error) {
      throw SafetyFailure(switch (error.message) {
        'not_found' => SafetyFailureKind.notFound,
        'too_many' => SafetyFailureKind.tooMany,
        _ => SafetyFailureKind.unknown,
      });
    } catch (_) {
      throw const SafetyFailure(SafetyFailureKind.network);
    }
  }
}
