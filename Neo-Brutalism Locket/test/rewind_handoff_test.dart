import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_handoff.dart';

void main() {
  group('rewindFileFromLink', () {
    test('accepts the link the lock screen writes', () {
      expect(
        rewindFileFromLink(
          Uri.parse('neolocket://rewind?file=1730000000000.jpg'),
        ),
        '1730000000000.jpg',
      );
    });

    test('refuses anything that could leave the folder or is not a jpg', () {
      for (final link in [
        'neolocket://rewind?file=../x.jpg',
        'neolocket://rewind?file=..%2Fx.jpg',
        'neolocket://rewind?file=%2Fetc%2Fpasswd',
        'neolocket://rewind?file=a.png',
        'neolocket://rewind?file=123.jpg.png',
        'neolocket://rewind?file=abc.jpg',
        'neolocket://rewind?file=.jpg',
        'neolocket://rewind?file=123.jpg%0A',
        'neolocket://rewind?file=',
      ]) {
        expect(rewindFileFromLink(Uri.parse(link)), isNull, reason: link);
      }
    });

    test('refuses a missing file, another host or another scheme', () {
      expect(rewindFileFromLink(Uri.parse('neolocket://rewind')), isNull);
      expect(
        rewindFileFromLink(Uri.parse('neolocket://post?file=123.jpg')),
        isNull,
      );
      expect(
        rewindFileFromLink(Uri.parse('https://rewind/?file=123.jpg')),
        isNull,
      );
      expect(rewindFileFromLink(Uri.parse('neolocket://add/tin')), isNull);
    });
  });

  group('the handed-over files', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('rewind_handoff'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('taking a picture returns it and removes the file', () async {
      File('${dir.path}/111.jpg').writeAsBytesSync([1, 2, 3]);
      expect(await takeRewindHandoff('111.jpg', dir: dir), [1, 2, 3]);
      expect(File('${dir.path}/111.jpg').existsSync(), isFalse);
      // A second time there is nothing.
      expect(await takeRewindHandoff('111.jpg', dir: dir), isNull);
    });

    test('a bad name never touches the disk', () async {
      File('${dir.path}/x.jpg').writeAsBytesSync([9]);
      expect(await takeRewindHandoff('../x.jpg', dir: dir), isNull);
      expect(await takeRewindHandoff('x.jpg', dir: dir), isNull);
      expect(File('${dir.path}/x.jpg').existsSync(), isTrue);
    });

    test('an empty file is dropped and reported as nothing', () async {
      File('${dir.path}/222.jpg').writeAsBytesSync([]);
      expect(await takeRewindHandoff('222.jpg', dir: dir), isNull);
      expect(File('${dir.path}/222.jpg').existsSync(), isFalse);
    });

    test('the sweep deletes files older than an hour only', () async {
      final old = File('${dir.path}/1.jpg')..writeAsBytesSync([1]);
      final fresh = File('${dir.path}/2.jpg')..writeAsBytesSync([2]);
      final now = DateTime.now();
      old.setLastModifiedSync(now.subtract(const Duration(minutes: 61)));
      fresh.setLastModifiedSync(now.subtract(const Duration(minutes: 59)));
      await sweepRewindHandoff(dir: dir, now: now);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('the sweep does nothing when the folder does not exist', () async {
      await sweepRewindHandoff(dir: Directory('${dir.path}/nope'));
    });
  });
}
