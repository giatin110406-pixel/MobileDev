import 'dart:io';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/backend/backend.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/search/query_translator.dart';
import 'package:neo_brutalism_locket/features/search/search_text_encoder.dart';
import 'package:path_provider/path_provider.dart';

/// Debug builds only (archive-ai-search-plan.md, step A6): does the search
/// text model load and run on this phone, how fast, how much memory, and how
/// does ML Kit translate typical Vietnamese searches?
///
/// The model is the one shipped in the app (assets/search_model/).
Future<void> showSearchModelCheck(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SearchModelCheckScreen()));

/// The Settings row and the page title (debug builds only, not translated).
const searchModelCheckTitle = 'SEARCH MODEL CHECK (DEBUG)';

/// The same pairs scored by the PC with each exported file
/// (eval.export_text_model); the phone must agree to about 0.01.
const _pairs = [
  ('a dog', 'a puppy', {'4bit': 0.9020}),
  ('a dog', 'a car', {'4bit': 0.7046}),
  ('a bowl of noodle soup', 'pho', {'4bit': 0.8351}),
  (
    'a red shirt next to a motorbike',
    'a person in red standing by a scooter',
    {'4bit': 0.8679},
  ),
];

/// Typical searches, for the owner to judge the English ML Kit gives.
const _queries = [
  'con chó',
  'mèo ngủ trên ghế',
  'bát phở',
  'bánh mì',
  'trà sữa trân châu',
  'ly cà phê sữa đá',
  'bánh sinh nhật',
  'pizza',
  'cơm tấm',
  'đồ ăn đường phố',
  'bãi biển lúc hoàng hôn',
  'núi và mây',
  'bầu trời đầy sao',
  'mưa trên phố',
  'cánh đồng lúa',
  'hồ nước',
  'công viên',
  'quán cà phê',
  'phòng ngủ',
  'lớp học',
  'xe máy',
  'ô tô màu đỏ',
  'xe đạp',
  'máy bay',
  'thuyền trên sông',
  'nhóm bạn chụp ảnh chung',
  'hai người ôm nhau',
  'em bé cười',
  'người mặc áo dài',
  'ảnh tự sướng',
  'áo đỏ đứng cạnh xe máy',
  'người đang chơi đàn guitar',
  'đá bóng',
  'chạy bộ buổi sáng',
  'buổi hòa nhạc',
  'pháo hoa',
  'đám cưới',
  'cây thông Noel',
  'hoa đào ngày Tết',
  'đèn lồng',
  'hoa hướng dương',
  'chậu cây xanh',
  'sách trên bàn',
  'máy tính xách tay',
  'đôi giày thể thao',
  'mũ bảo hiểm',
  'tranh vẽ trên tường',
  'chợ đêm',
  'cầu vồng',
  'tuyết',
];

class SearchModelCheckScreen extends StatefulWidget {
  const SearchModelCheckScreen({super.key});

  @override
  State<SearchModelCheckScreen> createState() => _SearchModelCheckScreenState();
}

class _SearchModelCheckScreenState extends State<SearchModelCheckScreen> {
  final _lines = <String>[];
  bool _running = false;

  /// Also printed (adb logcat -s flutter) and kept in
  /// search_check.txt in the external files folder, for adb pull.
  void _log(String line) {
    debugPrint('SEARCHCHECK $line');
    _report?.writeAsStringSync('$line\n', mode: FileMode.append);
    if (mounted) setState(() => _lines.add(line));
  }

  File? _report;

  int _rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  Future<void> _run() async {
    setState(() {
      _running = true;
      _lines.clear();
    });
    try {
      final folder = await getExternalStorageDirectory();
      _report = File('${folder?.path}/search_check.txt')..writeAsStringSync('');
      await _checkModel();
      await _checkServerVectors();
      await _checkTranslation();
    } catch (error) {
      _log('FAILED: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _checkModel() async {
    const name = 'model v2 (in the app)';
    final encoder = SearchTextEncoder();
    final before = _rssMb();
    final watch = Stopwatch()..start();
    try {
      await encoder.open();
      _log(
        '$name: loaded in '
        '${watch.elapsedMilliseconds} ms, RAM +${_rssMb() - before} MB',
      );
      for (final (a, b, refs) in _pairs) {
        final pc = refs['4bit']!;
        final va = await encoder.encode(a);
        final vb = await encoder.encode(b);
        var dot = 0.0;
        for (var i = 0; i < va.length; i++) {
          dot += va[i] * vb[i];
        }
        final ok = (dot - pc).abs() < 0.01 ? 'ok' : 'DIFFERENT';
        _log('  "$a" ~ "$b": ${dot.toStringAsFixed(4)} (PC $pc) $ok');
      }
      final times = <int>[];
      for (final q in _queries.take(20)) {
        watch.reset();
        await encoder.encode(q);
        times.add(watch.elapsedMilliseconds);
      }
      times.sort();
      _log(
        '  query time: median ${times[times.length ~/ 2]} ms, '
        'slowest ${times.last} ms; RAM now +${_rssMb() - before} MB',
      );
    } catch (error) {
      _log('$name: FAILED $error');
    } finally {
      await encoder.close();
    }
  }

  /// Phase B on the real database, as the signed-in user.
  Future<void> _checkServerVectors() async {
    if (!Backend.isReady) {
      _log('server vectors: not signed in to a backend');
      return;
    }
    final db = Backend.client;
    final me = db.auth.currentUser?.id;
    try {
      final visible = await db.rpc('visible_embedding_ids') as List<dynamic>;
      final mine = me == null
          ? <dynamic>[]
          : await db
                .from('posts')
                .select('id, created_at, embedding')
                .eq('author_id', me)
                .order('created_at', ascending: false)
                .limit(200);
      final without = mine.where((r) => r['embedding'] == null).length;
      _log(
        'server vectors: ${visible.length} posts I can see have one; '
        'my posts: ${mine.length}, without a vector: $without',
      );
      if (mine.isNotEmpty) {
        final last = mine.first;
        _log(
          '  my newest post (${last['created_at']}): '
          '${last['embedding'] == null ? 'NO vector' : 'has a vector'}',
        );
      }
    } catch (error) {
      _log('server vectors: FAILED $error');
    }
  }

  Future<void> _checkTranslation() async {
    final translator = QueryTranslator();
    try {
      _log(
        'ML Kit Vietnamese pack: '
        '${await translator.isReady ? 'present' : 'downloading...'}',
      );
      if (!await translator.prepare(wifiOnly: false)) {
        _log('ML Kit download failed');
        return;
      }
      final watch = Stopwatch();
      final times = <int>[];
      for (final (i, q) in _queries.indexed) {
        watch
          ..reset()
          ..start();
        final en = await translator.toEnglish(q);
        times.add(watch.elapsedMilliseconds);
        _log('${i + 1}. $q -> $en');
      }
      times.sort();
      _log('translation: median ${times[times.length ~/ 2]} ms');
    } finally {
      await translator.close();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NeoColors.surface,
    appBar: AppBar(title: const Text(searchModelCheckTitle)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _running ? null : _run,
            child: Text(_running ? 'RUNNING...' : 'RUN'),
          ),
        ),
        Expanded(
          // No SelectionArea: selecting while lines are added crashes it. The
          // lines are in logcat and search_check.txt instead.
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final line in _lines)
                Text(line, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}
