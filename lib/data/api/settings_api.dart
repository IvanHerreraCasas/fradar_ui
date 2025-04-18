// lib/data/api/settings_api.dart
abstract class SettingsApi {
  /// Retrieves the saved API base URL.
  /// Returns null if no URL is saved.
  Future<String?> getApiBaseUrl();

  /// Saves the API base URL.
  Future<void> saveApiBaseUrl(String url);
}
