import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/social/emoji_rain.dart';

void main() {
  testWidgets('a burst floats emojis up, then clears itself', (tester) async {
    final key = GlobalKey<EmojiRainLayerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: EmojiRainLayer(key: key),
        ),
      ),
    );
    expect(find.text('🔥'), findsNothing);

    key.currentState!.burst('🔥');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('🔥'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('it lets touches through to the page below', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned.fill(child: EmojiRainLayer()),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });
}
