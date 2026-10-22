import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Center(child: SizedBox.square(dimension: 300, child: child)),
);

Widget _view({String? styled = 'styled.png'}) => BeforeAfterView(
  originalPath: 'original.jpg',
  styledPath: styled,
  styleLabel: '8-BIT',
);

void main() {
  testWidgets('opens on the finished print, with no hint on it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_view()));
    expect(find.text('8-BIT'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(find.text('DRAG TO COMPARE'), findsNothing);
  });

  testWidgets('the finger decides how much of each side shows', (tester) async {
    await tester.pumpWidget(_host(_view()));
    final left = tester.getTopLeft(find.byType(BeforeAfterView));

    // Halfway: both sides are on screen.
    final drag = await tester.startGesture(left + const Offset(150, 150));
    await tester.pump();
    await drag.moveTo(left + const Offset(150, 160));
    await tester.pump();
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('8-BIT'), findsOneWidget);

    // Far right: almost all original, the style's name steps aside.
    await drag.moveTo(left + const Offset(285, 160));
    await tester.pump();
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('8-BIT'), findsNothing);

    // Back to the left edge: all styled again.
    await drag.moveTo(left + const Offset(2, 160));
    await tester.pump();
    expect(find.text('ORIGINAL'), findsNothing);
    expect(find.text('8-BIT'), findsOneWidget);
    await drag.up();
  });

  testWidgets('the divider stays where the finger left it', (tester) async {
    await tester.pumpWidget(_host(_view()));
    final left = tester.getTopLeft(find.byType(BeforeAfterView));
    final drag = await tester.startGesture(left + const Offset(20, 150));
    await drag.moveTo(left + const Offset(60, 150));
    await drag.moveTo(left + const Offset(280, 150));
    await drag.up();
    await tester.pump();
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('8-BIT'), findsNothing);
  });

  testWidgets('while the style runs only the original shows', (tester) async {
    await tester.pumpWidget(_host(_view(styled: null)));
    expect(find.byType(RevealCompare), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('with no before picture there is nothing to drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const RevealCompare(after: ColoredBox(color: Colors.green))),
    );
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });

  testWidgets('the line and grip fade out after the finger lifts', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_view()));
    double opacityOfGrip() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byIcon(Icons.swap_horiz_rounded),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    final left = tester.getTopLeft(find.byType(BeforeAfterView));
    final drag = await tester.startGesture(left + const Offset(100, 150));
    await drag.moveTo(left + const Offset(140, 150));
    await drag.moveTo(left + const Offset(200, 150));
    await tester.pump();
    expect(opacityOfGrip(), greaterThan(0));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOfGrip(), 0, reason: 'nothing left sitting on the picture');
  });

  testWidgets('the before picture waits its turn when asked to', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RevealCompare(
          beforeDelay: Duration(seconds: 1),
          before: Text('BEFORE-PIC'),
          after: Text('AFTER-PIC'),
        ),
      ),
    );
    expect(find.text('BEFORE-PIC'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('BEFORE-PIC'), findsOneWidget);
  });
}
