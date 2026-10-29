// Measures the "check before posting" (session E) on a labelled photo set,
// with the real ML Kit text reader on a device. The set is served from the
// laptop (server/eval/make_sensitive_set.py makes it):
//
//   python -m http.server 8799 --directory D:/clip_eval_tmp/sensitive_set
//   flutter test integration_test/sensitive_eval_test.dart -d emulator-5554
//
// Each photo prints one SENSITIVE_ROW line (expected kinds, found kinds,
// text read, milliseconds); server/eval/sensitive_report.py sums them up.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:neo_brutalism_locket/features/privacy/sensitive_check.dart';
import 'package:path_provider/path_provider.dart';

const _host = String.fromEnvironment(
  'EVAL_HOST',
  defaultValue: 'http://10.0.2.2:8799',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sensitive check on the labelled set', (t) async {
    final manifest =
        jsonDecode((await http.get(Uri.parse('$_host/manifest.json'))).body)
            as Map<String, dynamic>;
    final dir = await getTemporaryDirectory();
    final scanner = OnDeviceSensitiveScanner();
    for (final entry in manifest.entries) {
      final photo = File('${dir.path}/${entry.key}.jpg');
      await photo.writeAsBytes(
        (await http.get(Uri.parse('$_host/${entry.key}.jpg'))).bodyBytes,
      );
      final clock = Stopwatch()..start();
      final scan = await scanner.scan(photo);
      debugPrint(
        'SENSITIVE_ROW ${jsonEncode({
          'name': entry.key,
          'expected': entry.value,
          'found': [for (final f in scan.findings) f.kind.name],
          'texts': [for (final f in scan.findings) f.text],
          'read': [for (final l in scan.lines) l.text],
          'ms': clock.elapsedMilliseconds,
        })}',
      );
      await photo.delete();
    }
    scanner.close();
  }, timeout: const Timeout(Duration(minutes: 30)));
}
