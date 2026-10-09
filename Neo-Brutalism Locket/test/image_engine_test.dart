import 'dart:io';
import 'dart:typed_data';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:neo_brutalism_locket/features/image_engine/pixel_8bit_style_engine.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/remote_van_gogh_backend.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_factory.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_engine_utils.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_result.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_preview.dart';
import 'package:neo_brutalism_locket/features/image_engine/style_type.dart';
import 'package:neo_brutalism_locket/features/image_engine/van_gogh_style_engine.dart';
import 'package:neo_brutalism_locket/features/photos/photo_repository.dart';

img.Image _solidImage(int width, int height, int red, int green, int blue) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, red, green, blue);
    }
  }
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('8-bit output is deterministic and only uses the engine palette', () {
    final source = img.Image(width: 20, height: 12);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x * 12, y * 20, (x + y) * 8);
      }
    }
    final request = {
      'bytes': Uint8List.fromList(img.encodePng(source)),
      'pixelWidth': 96,
    };

    final first = pixel8BitFilterInBackground(request);
    final second = pixel8BitFilterInBackground(request);
    final output = img.decodePng(first)!;
    final allowedColors = endesga32Palette.toSet();

    expect(first, equals(second));
    expect(output.width, 384);
    expect(output.height, 384);
    for (final pixel in output) {
      final color =
          (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
      expect(allowedColors, contains(color));
    }
  });

  Map<int, int> colorHistogram(img.Image image) {
    final counts = <int, int>{};
    for (final pixel in image) {
      final color =
          (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
      counts[color] = (counts[color] ?? 0) + 1;
    }
    return counts;
  }

  Uint8List filter(img.Image source, {int width = 96}) =>
      pixel8BitFilterInBackground({
        'bytes': Uint8List.fromList(img.encodePng(source)),
        'pixelWidth': width,
      });

  test('every 4x4 block of the output is a single colour', () {
    final source = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        source.setPixelRgb(x, y, x * 4, y * 4, (x * y) % 256);
      }
    }
    final output = img.decodePng(filter(source))!;
    for (var y = 0; y < output.height; y += 4) {
      for (var x = 0; x < output.width; x += 4) {
        final reference = output.getPixel(x, y);
        for (var j = 0; j < 4; j++) {
          for (var i = 0; i < 4; i++) {
            expect(output.getPixel(x + i, y + j), equals(reference));
          }
        }
      }
    }
  });

  test('a dark photo is stretched so the palette uses many colours', () {
    final source = img.Image(width: 128, height: 128);
    for (var y = 0; y < 128; y++) {
      for (var x = 0; x < 128; x++) {
        source.setPixelRgb(x, y, x ~/ 3 + 10, y ~/ 3 + 10, (x + y) ~/ 6 + 5);
      }
    }
    final output = img.decodePng(filter(source))!;
    expect(colorHistogram(output).length, greaterThanOrEqualTo(6));
  });

  test('sharp black/white edges do not produce grey in between', () {
    final source = img.Image(width: 128, height: 128);
    for (var y = 0; y < 128; y++) {
      for (var x = 0; x < 128; x++) {
        final white = x >= 61;
        source.setPixelRgb(
          x,
          y,
          white ? 255 : 0,
          white ? 255 : 0,
          white ? 255 : 0,
        );
      }
    }
    final output = img.decodePng(filter(source))!;
    final counts = colorHistogram(output);
    final total = output.width * output.height;
    final extreme = (counts[0x181425] ?? 0) + (counts[0xFFFFFF] ?? 0);
    expect(extreme / total, greaterThan(0.95));
  });

  test('factory creates a distinct engine for each style', () {
    const factory = StyleEngineFactory();

    expect(factory.create(StyleType.pixel8bit), isA<Pixel8BitStyleEngine>());
    expect(factory.create(StyleType.vanGogh), isA<VanGoghStyleEngine>());
  });

  test('Van Gogh mock returns a tinted PNG without changing dimensions', () {
    final source = _solidImage(8, 5, 120, 100, 80);
    final result = mockVanGoghTintInBackground(
      Uint8List.fromList(img.encodePng(source)),
    );
    final output = img.decodePng(result)!;

    expect(output.width, source.width);
    expect(output.height, source.height);
    expect(output.getPixel(0, 0), isNot(source.getPixel(0, 0)));
  });

  group('remote Van Gogh backend', () {
    final photoBytes = Uint8List.fromList(
      img.encodePng(_solidImage(10, 10, 90, 120, 80)),
    );
    final laptopPng = Uint8List.fromList(
      img.encodePng(_solidImage(4, 4, 1, 2, 3)),
    );

    RemoteVanGoghBackend backendWith(http.Client client) =>
        RemoteVanGoghBackend(
          httpClient: client,
          fallback: const MockVanGoghBackend(),
          pollInterval: Duration.zero,
        );

    void configure({bool set = true}) => SharedPreferences.setMockInitialValues(
      set
          ? {
              'stylize_server_address': '192.168.1.5:8765',
              'stylize_server_token': 'secret',
            }
          : {},
    );

    MockClient laptop({int submitStatus = 202, String state = 'done'}) =>
        MockClient((request) async {
          final path = request.url.path;
          if (!path.endsWith('/health')) {
            expect(request.headers['X-Locket-Token'], 'secret');
          }
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'job_id': 'abc'}), submitStatus);
          }
          if (path.endsWith('/result')) {
            return http.Response.bytes(laptopPng, 200);
          }
          return http.Response(
            jsonEncode({
              'state': state,
              'stage': 'painting',
              'progress': 0.5,
              'error': state == 'failed' ? 'gpu on fire' : null,
            }),
            200,
          );
        });

    test('returns the laptop image and reports its source', () async {
      configure();
      final stages = <String>[];
      final result = await backendWith(
        laptop(),
      ).process(photoBytes, onProgress: (stage, fraction) => stages.add(stage));

      expect(result.source, StyleSource.laptopDiffusion);
      expect(result.png, equals(laptopPng));
      expect(result.note, isNull);
      expect(stages, contains('painting'));
    });

    test('survives a few lost polls while the laptop keeps painting', () async {
      configure();
      var statusCalls = 0;
      final flaky = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'job_id': 'abc'}), 202);
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        final path = request.url.path;
        if (path.endsWith('/health')) {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        if (path.endsWith('/result')) {
          return http.Response.bytes(laptopPng, 200);
        }
        statusCalls++;
        if (statusCalls <= 3) throw http.ClientException('dropped');
        return http.Response(
          jsonEncode({'state': 'done', 'stage': 'done', 'progress': 1}),
          200,
        );
      });

      final result = await backendWith(flaky).process(photoBytes);

      expect(result.source, StyleSource.laptopDiffusion);
      expect(result.png, equals(laptopPng));
    });

    test('falls back with a reason when the token is rejected', () async {
      configure();
      final result = await backendWith(
        laptop(submitStatus: 401),
      ).process(photoBytes);

      expect(result.source, StyleSource.mock);
      expect(result.note, contains('token'));
      expect(img.decodePng(result.png)!.width, 10);
    });

    test('falls back when the laptop is unreachable', () async {
      configure();
      final offline = MockClient(
        (_) async => throw http.ClientException('connection refused'),
      );
      final result = await backendWith(offline).process(photoBytes);

      expect(result.source, StyleSource.mock);
      expect(result.note, contains('not reachable'));
    });

    test('falls back when the laptop job fails', () async {
      configure();
      final result = await backendWith(
        laptop(state: 'failed'),
      ).process(photoBytes);

      expect(result.source, StyleSource.mock);
      expect(result.note, contains('gpu on fire'));
    });

    test('falls back when no server is configured', () async {
      configure(set: false);
      final result = await backendWith(laptop()).process(photoBytes);

      expect(result.source, StyleSource.mock);
      expect(result.note, contains('not set up'));
    });
  });

  test('capture crop is a centred square of the shorter side', () {
    final tall = img.Image(width: 90, height: 160);
    for (var y = 0; y < tall.height; y++) {
      for (var x = 0; x < tall.width; x++) {
        // Red marker band exactly in the vertical centre, blue elsewhere.
        final centre = (y - 80).abs() < 10;
        tall.setPixelRgb(x, y, centre ? 255 : 0, 0, centre ? 0 : 255);
      }
    }
    final jpeg = cropToSquareJpeg(Uint8List.fromList(img.encodeJpg(tall)));
    final out = img.decodeJpg(jpeg)!;

    expect(out.width, 90);
    expect(out.height, 90);
    expect(out.getPixel(45, 45).r, greaterThan(200)); // centre kept
    expect(out.getPixel(45, 2).r, lessThan(60)); // edges of the tall frame cut
  });

  test('style previews are generated from a small thumbnail', () {
    final source = _solidImage(320, 180, 120, 100, 80);
    final bytes = Uint8List.fromList(img.encodePng(source));
    final pixelPreview = stylePreviewInBackground({
      'bytes': bytes,
      'styleType': StyleType.pixel8bit.name,
    });
    final vanGoghPreview = stylePreviewInBackground({
      'bytes': bytes,
      'styleType': StyleType.vanGogh.name,
    });

    expect(img.decodePng(pixelPreview)!.width, 128);
    expect(img.decodePng(vanGoghPreview)!.width, 160);
    expect(img.decodePng(vanGoghPreview)!.height, 90);
  });

  test(
    '8-bit engine writes a new PNG and never changes the original',
    () async {
      final directory = await Directory.systemTemp.createTemp('style-engine-');
      addTearDown(() => directory.delete(recursive: true));
      final source = _solidImage(120, 90, 170, 80, 40);
      final originalBytes = Uint8List.fromList(img.encodeJpg(source));
      final originalFile = File(
        '${directory.path}${Platform.pathSeparator}original.jpg',
      );
      await originalFile.writeAsBytes(originalBytes);

      final output = await const Pixel8BitStyleEngine().process(
        originalFile,
        StyleType.pixel8bit,
      );
      final outputFile = output.file;

      expect(output.source, StyleSource.onDevice);
      expect(outputFile.path, isNot(originalFile.path));
      expect(outputFile.path, endsWith('.png'));
      expect(await originalFile.readAsBytes(), equals(originalBytes));
      expect(img.decodePng(await outputFile.readAsBytes())!.width, 512);
    },
  );

  test('legacy photo metadata loads without guessing an old style', () {
    final photo = NeoPhoto.fromJson({
      'id': 'legacy',
      'originalPath': '/tmp/original.jpg',
      'processedPath': '/tmp/old_neo.png',
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'status': 'done',
    });

    expect(photo.styleType, isNull);
    expect(photo.styleSource, isNull);
  });

  test(
    'metadata saved with the removed palette/mode/width keys still loads',
    () {
      final photo = NeoPhoto.fromJson({
        'id': 'older',
        'originalPath': '/tmp/original.jpg',
        'processedPath': '/tmp/older.png',
        'createdAt': DateTime.utc(2026).toIso8601String(),
        'status': 'done',
        'styleType': 'pixel8bit',
        'styleSource': 'onDevice',
        'palette': 'gameBoy',
        'pixelMode': 'enhanced',
        'pixelWidth': 160,
      });

      expect(photo.styleType, StyleType.pixel8bit);
      expect(photo.styleSource, StyleSource.onDevice);
      expect(photo.processedPath, '/tmp/older.png');
    },
  );
}
