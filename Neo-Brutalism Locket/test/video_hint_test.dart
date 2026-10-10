import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/camera/video_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a new person sees the hold-to-film hint', () async {
    expect(await VideoHint.shouldShow(), isTrue);
  });

  test('it goes away after a few shutter taps', () async {
    expect(await VideoHint.countTap(), isTrue);
    expect(await VideoHint.countTap(), isTrue);
    expect(await VideoHint.countTap(), isFalse, reason: 'the third tap');
    expect(await VideoHint.shouldShow(), isFalse);
  });

  test('filming once ends it for good', () async {
    await VideoHint.markFilmed();
    expect(await VideoHint.shouldShow(), isFalse);
    expect(await VideoHint.countTap(), isFalse);
  });
}
