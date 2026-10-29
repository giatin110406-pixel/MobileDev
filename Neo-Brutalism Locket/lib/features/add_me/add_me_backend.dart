import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the merge of two shots gave.
@immutable
class AddMeOutcome {
  const AddMeOutcome.merged(Uint8List this.image) : reason = null;
  const AddMeOutcome.refused(String this.reason) : image = null;

  /// The group photo with the photographer in it (square JPEG).
  final Uint8List? image;

  /// Why it could not be merged (AddMeMerger.REASON_* codes).
  final String? reason;

  bool get ok => image != null;
}

/// Puts the person who is only in [second] into [first]. Both are JPEGs of
/// the same frame (the second one taken with the first one's frame locked).
abstract class AddMeBackend {
  Future<AddMeOutcome> merge(Uint8List first, Uint8List second);
}

class MethodChannelAddMeBackend implements AddMeBackend {
  static const _channel = MethodChannel(
    'com.neobrutalism.neo_brutalism_locket/add_me',
  );

  @override
  Future<AddMeOutcome> merge(Uint8List first, Uint8List second) async {
    final result = (await _channel.invokeMapMethod<Object?, Object?>('merge', {
      'first': first,
      'second': second,
    }))!;
    final image = result['image'] as Uint8List?;
    if (result['ok'] == true && image != null) {
      return AddMeOutcome.merged(image);
    }
    return AddMeOutcome.refused(result['reason'] as String? ?? 'unknown');
  }
}
