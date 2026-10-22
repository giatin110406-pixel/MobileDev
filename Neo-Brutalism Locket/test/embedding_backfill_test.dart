import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/search/embedding_backfill.dart';

class _FakeSource implements BackfillSource {
  _FakeSource(this.items);

  final List<BackfillItem> items;
  final written = <String, String>{};
  Object? failList;
  int? limitAsked;

  @override
  Future<List<BackfillItem>> postsWithoutVector({required int limit}) async {
    limitAsked = limit;
    if (failList != null) throw failList!;
    return items;
  }

  @override
  Future<Uint8List> download(String path) async =>
      Uint8List.fromList(path.codeUnits);

  @override
  Future<void> setVector(String postId, String embedding) async =>
      written[postId] = embedding;
}

void main() {
  test('each of my posts without a vector gets one from its picture', () async {
    final source = _FakeSource(const [
      BackfillItem('p1', 'me/p1_orig.jpg'),
      BackfillItem('p2', 'me/p2_thumb.jpg'),
    ]);
    final done = await EmbeddingBackfill(
      source,
      embed: (photo) async => 'v:${String.fromCharCodes(photo)}',
    ).run(limit: 5);
    expect(done, 2);
    expect(source.limitAsked, 5);
    expect(source.written, {
      'p1': 'v:me/p1_orig.jpg',
      'p2': 'v:me/p2_thumb.jpg',
    });
  });

  test('a picture the model cannot read is skipped, the rest go on', () async {
    final source = _FakeSource(const [
      BackfillItem('bad', 'me/bad.jpg'),
      BackfillItem('ok', 'me/ok.jpg'),
    ]);
    final done = await EmbeddingBackfill(
      source,
      embed: (photo) async =>
          String.fromCharCodes(photo).contains('bad') ? null : 'v',
    ).run();
    expect(done, 1);
    expect(source.written.keys, ['ok']);
  });

  test('a database without the search columns ends the run quietly', () async {
    final source = _FakeSource(const [])..failList = StateError('no column');
    expect(await EmbeddingBackfill(source, embed: (_) async => 'v').run(), 0);
  });
}
