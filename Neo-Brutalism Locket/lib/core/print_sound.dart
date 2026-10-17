import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The two sounds of the post animation: the printer's needle chatter and the
/// stamp's thud. Both are short, synthesised files (see `tools/`).
///
/// Sound is decoration: a phone that cannot play it must never fail a post, so
/// every call swallows its errors.
abstract final class PrintSound {
  static bool enabled = true;

  static const printerAsset = 'sfx/printer.wav';
  static const stampAsset = 'sfx/stamp.wav';

  static AudioPlayer? _printer;
  static AudioPlayer? _stamp;

  /// Tests set this to see what would play instead of touching the platform.
  @visibleForTesting
  static void Function(String asset)? onPlay;

  /// Loads both files ahead so the first one starts without a delay.
  static Future<void> warmUp() async {
    if (!enabled || onPlay != null) return;
    try {
      await _player(stamp: false).setSource(AssetSource(printerAsset));
      await _player(stamp: true).setSource(AssetSource(stampAsset));
    } catch (_) {}
  }

  static Future<void> printOut() => _play(printerAsset, stamp: false);

  static Future<void> stampDown() => _play(stampAsset, stamp: true);

  /// Cuts whatever is playing (the animation was skipped).
  static Future<void> stop() async {
    try {
      await _printer?.stop();
      await _stamp?.stop();
    } catch (_) {}
  }

  static AudioPlayer _player({required bool stamp}) {
    if (stamp) {
      return _stamp ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    }
    return _printer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  }

  static Future<void> _play(String asset, {required bool stamp}) async {
    if (!enabled) return;
    final hook = onPlay;
    if (hook != null) return hook(asset);
    try {
      final player = _player(stamp: stamp);
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (_) {}
  }
}
