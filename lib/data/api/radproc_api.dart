// lib/data/api/radproc_api.dart
import 'dart:typed_data'; // Import for Uint8List

abstract class RadprocApi {
  /// Gets the basic API status.
  /// Returns a Map representing the JSON response (e.g., {"status": "ok"}).
  /// Throws an exception on API or network errors.
  Future<Map<String, dynamic>> getApiStatus();

  /// Gets the list of configured points.
  /// Returns a List of Maps, where each map represents a point's JSON data.
  /// Throws an exception on API or network errors.
  Future<List<Map<String, dynamic>>> getPoints();

  /// Gets the latest plot image for the given variable/elevation.
  /// Returns the raw image bytes.
  /// Throws [RadprocApiException] if the plot is not found (404) or other errors occur.
  Future<Uint8List> getRealtimePlot(String variable, double elevation);
}