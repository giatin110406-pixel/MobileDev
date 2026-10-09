import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';

/// A photo ready to upload: the full picture and a small thumbnail.
class EncodedPhoto {
  const EncodedPhoto({
    required this.media,
    required this.thumb,
    required this.extension,
    required this.mimeType,
  });

  final Uint8List media;
  final Uint8List thumb;

  /// `jpg` or `png`.
  final String extension;
  final String mimeType;
}

/// Longest side of the uploaded picture. Prints are square and already small,
/// so this mostly keeps big gallery photos from eating storage.
const maxUploadSide = 1080;
const thumbSide = 360;

class _Job {
  const _Job(this.bytes, this.lossless);

  final Uint8List bytes;
  final bool lossless;
}

/// Pixel-art prints stay PNG (JPEG would smear the hard edges); everything
/// else becomes a JPEG. Runs in a background isolate.
Future<EncodedPhoto> encodePhotoForUpload(
  Uint8List bytes, {
  required bool lossless,
}) => compute(_encode, _Job(bytes, lossless));

EncodedPhoto _encode(_Job job) => encodePhotoSync(job.bytes, job.lossless);

/// The synchronous work of [encodePhotoForUpload] (also used by tests).
EncodedPhoto encodePhotoSync(Uint8List bytes, bool lossless) {
  final source = decodeOrientedImage(bytes);
  final longest = source.width > source.height ? source.width : source.height;
  final full = longest > maxUploadSide
      ? img.copyResize(
          source,
          width: source.width >= source.height ? maxUploadSide : null,
          height: source.height > source.width ? maxUploadSide : null,
          interpolation: img.Interpolation.average,
        )
      : source;
  final small = img.copyResize(
    full,
    width: full.width >= full.height ? thumbSide : null,
    height: full.height > full.width ? thumbSide : null,
    interpolation: img.Interpolation.average,
  );
  return EncodedPhoto(
    media: Uint8List.fromList(
      lossless ? img.encodePng(full) : img.encodeJpg(full, quality: 90),
    ),
    thumb: Uint8List.fromList(img.encodeJpg(small, quality: 80)),
    extension: lossless ? 'png' : 'jpg',
    mimeType: lossless ? 'image/png' : 'image/jpeg',
  );
}
