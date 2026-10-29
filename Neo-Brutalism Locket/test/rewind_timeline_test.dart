import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_channel.dart';
import 'package:neo_brutalism_locket/features/rewind/rewind_timeline.dart';

RewindFrame frame(int offsetMs, {int rotation = 90}) =>
    RewindFrame(path: 'f$offsetMs.jpg', offsetMs: offsetMs, rotation: rotation);

void main() {
  group('RewindTimeline', () {
    test('sorts the frames by their offset', () {
      final timeline = RewindTimeline.tryBuild(
        frames: [frame(300), frame(-1200), frame(0), frame(-600)],
      )!;
      expect(timeline.entries.map((e) => e.offsetMs), [-1200, -600, 0, 300]);
      expect(timeline.hasStill, isFalse);
    });

    test('puts the still where it was taken', () {
      final timeline = RewindTimeline.tryBuild(
        frames: [frame(-200), frame(-100), frame(100), frame(200)],
        still: const RewindStill(path: 'hq.jpg', offsetMs: 40),
      )!;
      expect(timeline.entries.map((e) => e.offsetMs), [
        -200,
        -100,
        40,
        100,
        200,
      ]);
      expect(timeline.entries[2].isStill, isTrue);
      expect(timeline.entries[2].rotation, 0);
      expect(timeline.hasStill, isTrue);
    });

    test('a still later than every frame goes last, earlier goes first', () {
      final late = RewindTimeline.tryBuild(
        frames: [frame(-100), frame(0)],
        still: const RewindStill(path: 'hq.jpg', offsetMs: 900),
      )!;
      expect(late.entries.last.isStill, isTrue);
      final early = RewindTimeline.tryBuild(
        frames: [frame(-100), frame(0)],
        still: const RewindStill(path: 'hq.jpg', offsetMs: -900),
      )!;
      expect(early.entries.first.isStill, isTrue);
    });

    test('opens on the still', () {
      final timeline = RewindTimeline.tryBuild(
        frames: [frame(-300), frame(0), frame(300)],
        still: const RewindStill(path: 'hq.jpg', offsetMs: 120),
      )!;
      expect(timeline.entries[timeline.defaultIndex].isStill, isTrue);
    });

    test('without a still, opens on the frame nearest the press', () {
      final timeline = RewindTimeline.tryBuild(
        frames: [frame(-900), frame(-80), frame(50), frame(700)],
      )!;
      expect(timeline.entries[timeline.defaultIndex].offsetMs, 50);
    });

    test('a tie goes to the earlier frame', () {
      final timeline = RewindTimeline.tryBuild(
        frames: [frame(-60), frame(60)],
      )!;
      expect(timeline.entries[timeline.defaultIndex].offsetMs, -60);
    });

    test('a failed still leaves a usable strip of frames', () {
      final timeline = RewindTimeline.tryBuild(frames: [frame(-100)])!;
      expect(timeline.entries, hasLength(1));
      expect(timeline.defaultIndex, 0);
    });

    test('a still alone is a usable strip', () {
      final timeline = RewindTimeline.tryBuild(
        frames: const [],
        still: const RewindStill(path: 'hq.jpg', offsetMs: 0),
      )!;
      expect(timeline.entries.single.isStill, isTrue);
    });

    test('nothing at all is reported as null', () {
      expect(RewindTimeline.tryBuild(frames: const []), isNull);
    });
  });

  group('rewindOffsetLabel', () {
    test('writes seconds with one decimal and a sign', () {
      expect(rewindOffsetLabel(-1200, languageCode: 'en'), '-1.2s');
      expect(rewindOffsetLabel(600, languageCode: 'en'), '+0.6s');
      expect(rewindOffsetLabel(-2000, languageCode: 'en'), '-2.0s');
    });

    test('Vietnamese uses a comma', () {
      expect(rewindOffsetLabel(-1200, languageCode: 'vi'), '-1,2s');
      expect(rewindOffsetLabel(600, languageCode: 'vi'), '+0,6s');
    });

    test('zero, or less than a twentieth of a second, is just 0', () {
      expect(rewindOffsetLabel(0, languageCode: 'vi'), '0');
      expect(rewindOffsetLabel(49, languageCode: 'en'), '0');
      expect(rewindOffsetLabel(-49, languageCode: 'en'), '0');
    });

    test('rounds to the nearest tenth', () {
      expect(rewindOffsetLabel(149, languageCode: 'en'), '+0.1s');
      expect(rewindOffsetLabel(150, languageCode: 'en'), '+0.2s');
      expect(rewindOffsetLabel(-1049, languageCode: 'en'), '-1.0s');
    });
  });
}
