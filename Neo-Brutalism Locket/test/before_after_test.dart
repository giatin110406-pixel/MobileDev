import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/camera/before_after_view.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Holds the side shown, like the camera screen does.
class Host extends StatefulWidget {
  const Host({super.key, this.styledPath = 'styled.png'});

  final String? styledPath;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  bool showStyled = true;
  String? styledPath;

  @override
  void initState() {
    super.initState();
    styledPath = widget.styledPath;
  }

  void finishStyle(String path) => setState(() => styledPath = path);

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Center(
      child: SizedBox.square(
        dimension: 300,
        child: BeforeAfterView(
          originalPath: 'original.jpg',
          styledPath: styledPath,
          styleLabel: '8-BIT',
          showStyled: showStyled,
          onChanged: (styled) => setState(() => showStyled = styled),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens on the styled print, swipe right for the original', (
    tester,
  ) async {
    await tester.pumpWidget(const Host());
    final host = tester.state<HostState>(find.byType(Host));
    expect(find.text('8-BIT'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(250, 0), 1000);
    await tester.pumpAndSettle();
    expect(host.showStyled, isFalse);
    expect(find.text('ORIGINAL'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-250, 0), 1000);
    await tester.pumpAndSettle();
    expect(host.showStyled, isTrue);
    expect(find.text('8-BIT'), findsOneWidget);
  });

  testWidgets('a tap switches sides too', (tester) async {
    await tester.pumpWidget(const Host());
    final host = tester.state<HostState>(find.byType(Host));
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(host.showStyled, isFalse);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(host.showStyled, isTrue);
  });

  testWidgets('while the style runs only the original shows', (tester) async {
    await tester.pumpWidget(const Host(styledPath: null));
    final host = tester.state<HostState>(find.byType(Host));
    expect(find.text('ORIGINAL'), findsNothing, reason: 'nothing to compare');
    await tester.fling(find.byType(PageView), const Offset(-250, 0), 1000);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(host.showStyled, isTrue, reason: 'unchanged: no styled side yet');
    expect(
      tester.widget<PageView>(find.byType(PageView)).childrenDelegate,
      isA<SliverChildListDelegate>().having(
        (d) => d.children.length,
        'pages',
        1,
      ),
    );
  });

  testWidgets('when the style is done the view slides to it', (tester) async {
    await tester.pumpWidget(const Host(styledPath: null));
    final host = tester.state<HostState>(find.byType(Host));
    host.finishStyle('styled.png');
    await tester.pumpAndSettle();
    expect(find.text('8-BIT'), findsOneWidget);
    final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pages.page, 1);
  });

  testWidgets('holding shows the other side, letting go brings it back', (
    tester,
  ) async {
    await tester.pumpWidget(const Host());
    final host = tester.state<HostState>(find.byType(Host));
    expect(find.text('8-BIT'), findsOneWidget);

    final hold = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('8-BIT'), findsNothing);
    expect(host.showStyled, isTrue, reason: 'peeking does not switch sides');

    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('8-BIT'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(host.showStyled, isTrue);
  });

  testWidgets('holding on the original peeks at the styled print', (
    tester,
  ) async {
    await tester.pumpWidget(const Host());
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL'), findsOneWidget);

    final hold = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('8-BIT'), findsOneWidget);
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL'), findsOneWidget);
  });

  testWidgets('the hold hint shows until the first hold', (tester) async {
    await tester.pumpWidget(const Host());
    expect(find.text('HOLD TO COMPARE'), findsOneWidget);
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await hold.up();
    await tester.pumpAndSettle();
    expect(find.text('HOLD TO COMPARE'), findsNothing);
  });

  testWidgets('no hint and no peek while only the original exists', (
    tester,
  ) async {
    await tester.pumpWidget(const Host(styledPath: null));
    expect(find.text('HOLD TO COMPARE'), findsNothing);
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('ORIGINAL'), findsNothing);
    await hold.up();
  });
}
