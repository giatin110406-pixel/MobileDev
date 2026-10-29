import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/posts/media_encoding.dart';

/// A JPEG that carries a GPS position, a camera model and, optionally, a
/// rotation, the way a phone camera writes it.
Uint8List _photoWithLocation({
  int width = 200,
  int height = 120,
  int? orientation,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 90, 40));
  image.exif.gpsIfd.setGpsLocation(latitude: 11.9404, longitude: 108.4583);
  image.exif.imageIfd.model = 'Pixel Test';
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// What the EXIF of [bytes] says about where and with what it was taken.
({bool gps, bool model}) _leaks(Uint8List bytes) {
  final exif = img.decodeJpgExif(bytes);
  if (exif == null) return (gps: false, model: false);
  return (
    gps: exif.gpsIfd.gpsLatitude != null || exif.gpsIfd.gpsLongitude != null,
    model: exif.imageIfd.model != null,
  );
}

void main() {
  test('the fixture really carries the position (guards the other tests)', () {
    final leaks = _leaks(_photoWithLocation());
    expect(leaks.gps, isTrue);
    expect(leaks.model, isTrue);
  });

  test('the picture and its thumbnail are uploaded without EXIF', () {
    final encoded = encodePhotoSync(_photoWithLocation(), false);
    expect(_leaks(encoded.media), (gps: false, model: false));
    expect(_leaks(encoded.thumb), (gps: false, model: false));
  });

  test('a photo within the limits keeps its pixels but loses its EXIF', () async {
    final source = _photoWithLocation();
    final sent = await originalForUpload(source);
    expect(_leaks(sent), (gps: false, model: false));
    // Not recompressed: the image data after the headers is byte for byte the same.
    expect(sent.length, lessThan(source.length));
    final tail = source.sublist(source.length - 64);
    expect(sent.sublist(sent.length - 64), tail);
    final a = img.decodeJpg(source)!;
    final b = img.decodeJpg(sent)!;
    expect([b.width, b.height], [a.width, a.height]);
    expect(b.getPixel(10, 10), a.getPixel(10, 10));
  });

  test('a photo bigger than the limit is shrunk and has no EXIF', () async {
    final sent = await originalForUpload(
      _photoWithLocation(width: maxOriginalSide + 400, height: 300),
    );
    expect(_leaks(sent), (gps: false, model: false));
    expect(img.decodeJpg(sent)!.width, maxOriginalSide);
  });

  test('a rotated photo is turned upright, since its tag is dropped', () async {
    // Stored 200x120 with orientation 6 (rotate 90): it displays as 120x200.
    final sent = await originalForUpload(_photoWithLocation(orientation: 6));
    expect(_leaks(sent), (gps: false, model: false));
    final out = img.decodeJpg(sent)!;
    expect([out.width, out.height], [120, 200]);
  });

  test('every crop made on the way keeps no EXIF', () {
    expect(_leaks(cropToSquareJpeg(_photoWithLocation())), (
      gps: false,
      model: false,
    ));
    expect(_leaks(cropToSquareJpegCapped(_photoWithLocation())), (
      gps: false,
      model: false,
    ));
  });

  test('stripJpegMetadata leaves anything that is not a JPEG alone', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
    expect(stripJpegMetadata(png), png);
    final cut = _photoWithLocation().sublist(0, 30);
    expect(stripJpegMetadata(cut), cut);
  });
}
