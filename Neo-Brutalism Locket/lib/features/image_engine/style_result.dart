import 'dart:io';
import 'dart:typed_data';

/// Which path actually produced an image. Shown in the UI so a fallback is never
/// mistaken for the real thing.
enum StyleSource { laptopDiffusion, onDevice, magenta, mock, original }

extension StyleSourceLabel on StyleSource {
  String get label => switch (this) {
    StyleSource.laptopDiffusion => 'LAPTOP · DIFFUSION',
    StyleSource.onDevice => 'ON DEVICE',
    StyleSource.magenta => 'FALLBACK · MAGENTA',
    StyleSource.mock => 'FALLBACK · MOCK',
    StyleSource.original => 'ORIGINAL',
  };

  bool get isFallback =>
      this == StyleSource.magenta || this == StyleSource.mock;
}

typedef StyleProgress = void Function(String stage, double fraction);

class StyleResult {
  const StyleResult(this.png, this.source, {this.note});

  final Uint8List png;
  final StyleSource source;

  /// Why a fallback was used, when one was.
  final String? note;
}

class StyleOutput {
  const StyleOutput(this.file, this.source, {this.note});

  final File file;
  final StyleSource source;
  final String? note;
}
