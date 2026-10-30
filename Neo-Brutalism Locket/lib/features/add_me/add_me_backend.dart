import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the merge of two shots gave.
@immutable
class AddMeOutcome {
  const AddMeOutcome.merged(
    Uint8List this.image, {
    this.alternative,
    this.inFront = false,
  }) : reason = null;
  const AddMeOutcome.refused(String this.reason)
      : image = null,
        alternative = null,
        inFront = false;

  /// The group photo with the photographer in it (square JPEG).
  final Uint8List? image;

  /// The same merge with the newcomer in front of someone of photo 1 who is
  /// not in photo 2, when it is a question which of them is in front ([image]
  /// has the newcomer behind them). Null when there was nothing to choose.
  final Uint8List? alternative;

  /// Whether [image] has the newcomer in front of the person of photo 1 they
  /// overlap ([alternative] has the opposite).
  final bool inFront;

  /// Why it could not be merged (AddMeMerger.REASON_* codes).
  final String? reason;

  bool get ok => image != null;
}

/// Puts the person who is only in [second] into [first]. Both are JPEGs of
/// the same frame (the second one taken with the first one's frame locked).
abstract class AddMeBackend {
  /// Loads the models ahead of the first merge, so that one is not slow.
  Future<void> warmUp();

  Future<AddMeOutcome> merge(Uint8List first, Uint8List second);
}

class MethodChannelAddMeBackend implements AddMeBackend {
  static const _channel = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/add_me',
  );

  @override
  Future<void> warmUp() async {
    try {
      await _channel.invokeMethod<void>('warmUp');
    } on PlatformException {
      // The merge itself reports what is wrong.
    }
  }

  @override
  Future<AddMeOutcome> merge(Uint8List first, Uint8List second) async {
    final result = (await _channel.invokeMapMethod<Object?, Object?>('merge', {
      'first': first,
      'second': second,
    }))!;
    final image = result['image'] as Uint8List?;
    if (result['ok'] == true && image != null) {
      return AddMeOutcome.merged(
        image,
        alternative: result['alternative'] as Uint8List?,
        inFront: result['inFront'] == true,
      );
    }
    return AddMeOutcome.refused(result['reason'] as String? ?? 'unknown');
  }
}
