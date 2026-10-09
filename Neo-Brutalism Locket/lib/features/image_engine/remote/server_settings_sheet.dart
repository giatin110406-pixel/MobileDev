import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_client.dart';
import 'package:neo_brutalism_locket/features/image_engine/remote/stylize_server_config.dart';

Future<void> showServerSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ServerSettingsSheet(),
    );

class _ServerSettingsSheet extends StatefulWidget {
  const _ServerSettingsSheet();

  @override
  State<_ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends State<_ServerSettingsSheet> {
  static const _store = StylizeServerConfigStore();
  final _address = TextEditingController();
  final _token = TextEditingController();
  String _status = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.load().then((config) {
      if (!mounted) return;
      _address.text = config.address;
      _token.text = config.token;
    });
  }

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  StylizeServerConfig get _config =>
      StylizeServerConfig(address: _address.text, token: _token.text);

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = 'TESTING…';
    });
    String message;
    try {
      final health = await StylizeClient(_config).health();
      message = health.modelsReady
          ? 'CONNECTED · ${health.gpu ?? 'CPU'}'
          : 'CONNECTED · MODELS STILL LOADING';
    } on StylizeException catch (error) {
      message = error.message.toUpperCase();
    } catch (_) {
      message = 'INVALID ADDRESS';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = message;
    });
  }

  Future<void> _save() async {
    await _store.save(_config);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: NeoColors.paper,
          border: Border.all(color: NeoColors.ink, width: 2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'HOME LAPTOP',
                style: TextStyle(
                  color: NeoColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const NeoLabel(
                'VAN GOGH RUNS ON YOUR LAPTOP',
                color: NeoColors.yellow,
              ),
              const SizedBox(height: 20),
              _fieldLabel('ADDRESS (IP:PORT)'),
              const SizedBox(height: 6),
              _input(_address, '192.168.1.10:8765'),
              const SizedBox(height: 14),
              _fieldLabel('TOKEN'),
              const SizedBox(height: 6),
              _input(_token, 'printed when the server starts'),
              const SizedBox(height: 12),
              Text(
                _status,
                style: const TextStyle(
                  color: NeoColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeoButton(
                      label: 'TEST',
                      icon: Icons.wifi_tethering,
                      variant: NeoButtonVariant.outline,
                      expand: true,
                      onPressed: _busy ? null : _test,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoButton(
                      label: 'SAVE',
                      icon: Icons.check,
                      variant: NeoButtonVariant.primary,
                      expand: true,
                      onPressed: _busy ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: NeoColors.ink,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _input(TextEditingController controller, String hint) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: NeoColors.surface,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(color: NeoColors.ink, offset: Offset(3, 3), blurRadius: 0),
      ],
    ),
    child: TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: NeoColors.muted, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    ),
  );
}
