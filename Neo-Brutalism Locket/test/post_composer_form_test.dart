import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_brutalism_locket/features/posts/post_composer.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('the popup form shows its extras and holds POST until ready', (
    tester,
  ) async {
    ComposerResult? sent;
    Widget form({required bool canPost}) => _app(
      PostComposerForm(
        friends: const [],
        canPost: canPost,
        previewBuilder: (context, overlay) =>
            const SizedBox(height: 40, child: Text('PREVIEW')),
        afterPreview: const Text('STYLES'),
        onSubmit: (result) => sent = result,
      ),
    );

    await tester.pumpWidget(form(canPost: false));
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('STYLES'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded), warnIfMissed: false);
    expect(sent, isNull);

    await tester.pumpWidget(form(canPost: true));
    await tester.enterText(find.byType(TextField), '  hello ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    expect(sent?.caption, 'hello');
    expect(sent?.recipients, isNull);
  });
}
