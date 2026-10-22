import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neo_brutalism_locket/core/app_log.dart';
import 'package:neo_brutalism_locket/features/search/photo_embedding.dart';
import 'package:path_provider/path_provider.dart';

/// One vector as the server sends it (`post_embeddings`).
typedef EmbeddingRow = ({String id, DateTime embeddedAt, String embedding});

abstract interface class EmbeddingSource {
  /// Vectors set after the cursor (embedded_at, id), oldest first.
  Future<List<EmbeddingRow>> page({
    DateTime? after,
    String? afterId,
    required int limit,
  });

  /// Ids of every post with a vector I may still see.
  Future<Set<String>> visibleIds();
}

/// The vectors of every post I may see, kept on the phone so a search needs
/// no network once synced (archive-ai-search-plan.md, C2). One file per
/// account: 36 bytes of id + 1024 bytes of float16 per post.
class SearchIndex {
  SearchIndex({
    required this.userId,
    required this.source,
    Future<Directory> Function()? folder,
  }) : _folder = folder ?? getApplicationSupportDirectory;

  final String userId;
  final EmbeddingSource source;
  final Future<Directory> Function() _folder;

  static const _pageSize = 500;
  static const _idLength = 36;

  final Map<String, Float32List> vectors = {};
  DateTime? _after;
  String? _afterId;
  bool _loaded = false;

  Future<File> _file(String ext) async {
    final dir = Directory('${(await _folder()).path}/search');
    await dir.create(recursive: true);
    return File('${dir.path}/index_$userId.$ext');
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final cursor = await _file('json');
      final data = await _file('bin');
      if (!cursor.existsSync() || !data.existsSync()) return;
      final c = jsonDecode(await cursor.readAsString()) as Map<String, dynamic>;
      _after = DateTime.parse(c['after'] as String);
      _afterId = c['afterId'] as String;
      final bytes = await data.readAsBytes();
      const record = _idLength + embeddingBytes;
      for (var at = 0; at + record <= bytes.length; at += record) {
        vectors[ascii.decode(bytes.sublist(at, at + _idLength))] =
            float32FromFloat16Bytes(bytes.sublist(at + _idLength, at + record));
      }
    } catch (e, st) {
      // A damaged copy is thrown away and fetched again.
      AppLog.warn('search_index', e, st);
      vectors.clear();
      _after = null;
      _afterId = null;
    }
  }

  /// Fetches what is new and saves. With [prune], also forgets what I may no
  /// longer see (one more request, listing every id). Returns how many vectors
  /// were added or replaced.
  Future<int> sync({bool prune = true}) async {
    await load();
    var added = 0;
    while (true) {
      final rows = await source.page(
        after: _after,
        afterId: _afterId,
        limit: _pageSize,
      );
      for (final row in rows) {
        final raw = base64Decode(row.embedding.replaceAll('\n', ''));
        if (raw.length != embeddingBytes || row.id.length != _idLength) {
          continue;
        }
        vectors[row.id] = float32FromFloat16Bytes(raw);
        _after = row.embeddedAt;
        _afterId = row.id;
        added++;
      }
      if (rows.length < _pageSize) break;
    }
    if (prune) {
      final visible = await source.visibleIds();
      vectors.removeWhere((id, _) => !visible.contains(id));
    }
    if (added > 0 || prune) await _save();
    return added;
  }

  Future<void> _save() async {
    final out = BytesBuilder(copy: false);
    for (final entry in vectors.entries) {
      out
        ..add(ascii.encode(entry.key))
        ..add(float16Bytes(entry.value));
    }
    await (await _file('bin')).writeAsBytes(out.takeBytes(), flush: true);
    if (_after != null) {
      await (await _file('json')).writeAsString(
        jsonEncode({'after': _after!.toIso8601String(), 'afterId': _afterId}),
        flush: true,
      );
    }
  }
}
