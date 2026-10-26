import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/posts/post_models.dart';
import 'package:neo_brutalism_locket/features/posts/post_tags.dart';

class FakeTags implements PostTagsSource {
  FakeTags(this.tags);

  Map<String, List<String>> tags;
  final removed = <String>[];
  bool offline = false;

  @override
  Future<Map<String, List<String>>> tagsOf(List<String> postIds) async {
    if (offline) throw StateError('offline');
    return {
      for (final id in postIds)
        if (tags[id] != null) id: tags[id]!,
    };
  }

  @override
  Future<void> removeMine(String postId) async {
    if (offline) throw StateError('offline');
    removed.add(postId);
  }
}

RemotePost post(String id) => RemotePost(
  id: id,
  authorId: 'ava',
  mediaPath: 'ava/$id.jpg',
  createdAt: DateTime(2026),
);

void main() {
  test('loads the tags of the posts it is given', () async {
    final store = PostTagsStore(
      FakeTags({
        'p1': ['lan', 'me'],
        'other': ['bo'],
      }),
      myId: 'me',
    );
    await store.load([post('p1'), post('p2')]);
    expect(store.tags, {
      'p1': ['lan', 'me'],
    });
  });

  test('offline keeps what is shown', () async {
    final source = FakeTags({
      'p1': ['lan'],
    });
    final store = PostTagsStore(source, myId: 'me');
    await store.load([post('p1')]);
    source.offline = true;
    await store.load([post('p1')]);
    expect(store.tags['p1'], ['lan']);
  });

  test('taking my name off shows at once and keeps the others', () async {
    final source = FakeTags({
      'p1': ['lan', 'me'],
    });
    final store = PostTagsStore(source, myId: 'me');
    await store.load([post('p1')]);
    await store.removeMine('p1');
    expect(store.tags['p1'], ['lan']);
    expect(source.removed, ['p1']);
  });

  test('if the server refuses, my name comes back', () async {
    final source = FakeTags({
      'p1': ['me'],
    });
    final store = PostTagsStore(source, myId: 'me');
    await store.load([post('p1')]);
    source.offline = true;
    await expectLater(store.removeMine('p1'), throwsStateError);
    expect(store.tags['p1'], ['me']);
  });
}
