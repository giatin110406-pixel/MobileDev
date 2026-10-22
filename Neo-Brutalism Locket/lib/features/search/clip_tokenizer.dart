import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// The BPE merges open_clip uses, exported by
/// server/eval/export_search_tokenizer.py.
const clipMergesAsset = 'assets/search_model/clip_merges.txt.gz';

/// open_clip's `SimpleTokenizer` (the CLIP tokenizer) in Dart: text -> the
/// token ids the search text model takes. Checked against open_clip by
/// test/clip_tokenizer_test.dart.
///
/// Not ported: open_clip's `ftfy.fix_text` and `html.unescape`. Typed or
/// translated text has no broken encodings or HTML entities.
class ClipTokenizer {
  ClipTokenizer._(this._encoder, this._ranks);

  /// [merges]: one merge per line, two symbols separated by a space.
  factory ClipTokenizer.fromMerges(List<String> merges) {
    final bytes = _bytes.order;
    final vocab = <String>[
      ...bytes,
      for (final b in bytes) '$b</w>',
      for (final m in merges) m.replaceFirst(' ', ''),
      '<start_of_text>',
      '<end_of_text>',
    ];
    return ClipTokenizer._(
      {for (var i = 0; i < vocab.length; i++) vocab[i]: i},
      {for (var i = 0; i < merges.length; i++) merges[i]: i},
    );
  }

  static Future<ClipTokenizer> load({AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(clipMergesAsset);
    final text = utf8.decode(
      gzip.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
    return ClipTokenizer.fromMerges(text.split('\n'));
  }

  static const contextLength = 77;
  static const startOfText = 49406;
  static const endOfText = 49407;

  final Map<String, int> _encoder;

  /// "first second" -> priority (lower merges first).
  final Map<String, int> _ranks;
  final Map<String, List<String>> _cache = {};

  static final _pattern = RegExp(
    r"'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+",
    unicode: true,
    caseSensitive: false,
  );

  /// [contextLength] ids: start, the text, end, then zeros. Text that is too
  /// long is cut and still ends with [endOfText], as open_clip does.
  Int64List encode(String text) {
    final ids = <int>[startOfText, ..._encodeText(text), endOfText];
    if (ids.length > contextLength) {
      ids.length = contextLength;
      ids[contextLength - 1] = endOfText;
    }
    return Int64List(contextLength)..setAll(0, ids);
  }

  List<int> _encodeText(String text) {
    final clean = text.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();
    final out = <int>[];
    for (final match in _pattern.allMatches(clean)) {
      final word = [
        for (final b in utf8.encode(match.group(0)!)) _bytes.byByte[b],
      ].join();
      for (final piece in _bpe(word)) {
        out.add(_encoder[piece]!);
      }
    }
    return out;
  }

  List<String> _bpe(String token) {
    final cached = _cache[token];
    if (cached != null) return cached;
    final chars = token.runes.map(String.fromCharCode).toList();
    var word = [...chars.sublist(0, chars.length - 1), '${chars.last}</w>'];
    while (word.length > 1) {
      // the adjacent pair merged first by the trained order
      int? best;
      var bestRank = 1 << 30;
      for (var i = 0; i < word.length - 1; i++) {
        final rank = _ranks['${word[i]} ${word[i + 1]}'];
        if (rank != null && rank < bestRank) {
          bestRank = rank;
          best = i;
        }
      }
      if (best == null) break;
      final first = word[best];
      final second = word[best + 1];
      final merged = <String>[];
      for (var i = 0; i < word.length; i++) {
        if (i < word.length - 1 && word[i] == first && word[i + 1] == second) {
          merged.add(first + second);
          i++;
        } else {
          merged.add(word[i]);
        }
      }
      word = merged;
    }
    if (_cache.length < 10000) _cache[token] = word;
    return word;
  }

  /// GPT-2 / CLIP byte -> printable character table (`bytes_to_unicode`):
  /// printable bytes keep their own character, the rest are moved to 256+.
  /// [order] is the vocabulary order, [byByte] is indexed by byte value.
  static final ({List<String> order, List<String> byByte}) _bytes = () {
    final printable = <int>[
      for (var b = 0x21; b <= 0x7e; b++) b,
      for (var b = 0xa1; b <= 0xac; b++) b,
      for (var b = 0xae; b <= 0xff; b++) b,
    ];
    final bytes = [...printable];
    final codes = [...printable];
    var extra = 0;
    for (var b = 0; b < 256; b++) {
      if (!printable.contains(b)) {
        bytes.add(b);
        codes.add(256 + extra++);
      }
    }
    final order = [for (final c in codes) String.fromCharCode(c)];
    final byByte = List<String>.filled(256, '');
    for (var i = 0; i < 256; i++) {
      byByte[bytes[i]] = order[i];
    }
    return (order: order, byByte: byByte);
  }();
}
