import 'dart:typed_data' show BytesBuilder;

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

/// Longest side the original is allowed to keep. The camera's square shots are
/// below this, so they are sent untouched.
const maxOriginalSide = 2560;
const _maxOriginalBytes = 8 * 1024 * 1024;

/// The shot before its style, as a JPEG to upload beside the styled one. A
/// shot already within the limits is sent as it is (no second compression, so
/// nothing is lost); a bigger one is shrunk, at high quality.
Future<Uint8List> originalForUpload(Uint8List bytes) =>
    compute(_originalForUpload, bytes);

Uint8List _originalForUpload(Uint8List bytes) {
  if (bytes.length <= _maxOriginalBytes && _isJpeg(bytes)) {
    // Only the header is read to learn the size.
    final info = img.JpegDecoder().startDecode(bytes);
    if (info != null &&
        info.width <= maxOriginalSide &&
        info.height <= maxOriginalSide &&
        !_needsRotation(bytes)) {
      return stripJpegMetadata(bytes);
    }
  }
  final source = decodeOrientedImage(bytes);
  final longest = source.width > source.height ? source.width : source.height;
  final fitted = longest > maxOriginalSide
      ? img.copyResize(
          source,
          width: source.width >= source.height ? maxOriginalSide : null,
          height: source.height > source.width ? maxOriginalSide : null,
          interpolation: img.Interpolation.average,
        )
      : source;
  return Uint8List.fromList(img.encodeJpg(fitted, quality: 95));
}

/// A JPEG that relies on its EXIF orientation must be re-encoded upright, since
/// that tag is about to go.
bool _needsRotation(Uint8List bytes) {
  final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation;
  return orientation != null && orientation != 1;
}

/// The JPEG without its EXIF/XMP (APP1) and IPTC (APP13) segments, byte for
/// byte otherwise, so nothing is recompressed. That is where the GPS position,
/// the time and the device model live. Anything that is not a plain JPEG
/// stream comes back unchanged.
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (!_isJpeg(bytes)) return bytes;
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) return bytes;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    // Start of scan: the entropy-coded data runs to the end, copy it whole.
    if (marker == 0xDA) {
      out.add(Uint8List.sublistView(bytes, i));
      return out.takeBytes();
    }
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > bytes.length) return bytes;
    if (marker != 0xE1 && marker != 0xED) {
      out.add(Uint8List.sublistView(bytes, i, end));
    }
    i = end;
  }
  return bytes;
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
