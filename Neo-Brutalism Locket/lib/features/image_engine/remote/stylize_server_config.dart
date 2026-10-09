import 'package:shared_preferences/shared_preferences.dart';

class StylizeServerConfig {
  const StylizeServerConfig({this.address = '', this.token = ''});

  /// `host:port` or a full `http://host:port` URL of the laptop server.
  final String address;
  final String token;

  bool get isConfigured => address.trim().isNotEmpty && token.trim().isNotEmpty;

  Uri get baseUri {
    final trimmed = address.trim();
    return Uri.parse(trimmed.startsWith('http') ? trimmed : 'http://$trimmed');
  }
}

class StylizeServerConfigStore {
  const StylizeServerConfigStore();

  static const _addressKey = 'stylize_server_address';
  static const _tokenKey = 'stylize_server_token';

  Future<StylizeServerConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StylizeServerConfig(
      address: prefs.getString(_addressKey) ?? '',
      token: prefs.getString(_tokenKey) ?? '',
    );
  }

  Future<void> save(StylizeServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_addressKey, config.address.trim());
    await prefs.setString(_tokenKey, config.token.trim());
  }
}
