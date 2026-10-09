import 'package:audioplayers/audioplayers.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';

/// Background music for quest posts: orchestral for Van Gogh, chiptune for
/// 8-bit (see assets/music/CREDITS.md).
abstract final class QuestMusic {
  static const vanGoghTracks = [
    'music/van_gogh_morning_mood.m4a',
    'music/van_gogh_new_world_largo.m4a',
    'music/van_gogh_vltava.m4a',
  ];

  static const chiptuneTracks = [
    'music/chiptune_stage_1.m4a',
    'music/chiptune_stage_2.m4a',
    'music/chiptune_stage_select.m4a',
  ];

  static List<String> tracksFor(StyleType style) =>
      style == StyleType.vanGogh ? vanGoghTracks : chiptuneTracks;

  /// The track for one post: always the same for that post, and posts of the
  /// same style get different tracks.
  static String trackFor(StyleType style, String postId) {
    final tracks = tracksFor(style);
    var hash = 0;
    for (final unit in postId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return tracks[hash % tracks.length];
  }
}

/// Plays one looping track at a time.
abstract interface class MusicPlayer {
  /// Starts [asset] (relative to assets/) on loop; no-op if it is playing.
  Future<void> play(String asset);
  Future<void> stop();
  Future<void> dispose();
}

class AudioMusicPlayer implements MusicPlayer {
  AudioPlayer? _player;
  String? _current;

  // Created on first use, so screens without quest posts never touch audio.
  AudioPlayer get _audio =>
      _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  @override
  Future<void> play(String asset) async {
    if (_current == asset) return;
    _current = asset;
    try {
      await _audio.stop();
      await _audio.play(AssetSource(asset));
    } catch (_) {
      // Music is decoration: a missing codec must never break the feed.
      _current = null;
    }
  }

  @override
  Future<void> stop() async {
    _current = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _current = null;
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (_) {}
  }
}
