// lib/data/sources/local_settings_api.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fradar_ui/data/api/settings_api.dart';

class LocalSettingsApi implements SettingsApi {
  LocalSettingsApi({required SharedPreferences plugin}) : _plugin = plugin;

  final SharedPreferences _plugin;

  // Define a key for storing the URL
  static const String _kApiBaseUrlKey = 'api_base_url';

  @override
  Future<String?> getApiBaseUrl() async {
    return _plugin.getString(_kApiBaseUrlKey);
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    await _plugin.setString(_kApiBaseUrlKey, url);
  }
}