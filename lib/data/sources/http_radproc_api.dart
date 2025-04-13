// lib/data/sources/http_radproc_api.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fradar_ui/data/api/radproc_api.dart';

class HttpRadprocApi implements RadprocApi {
  HttpRadprocApi({required Dio dioClient}) : _dioClient = dioClient;

  final Dio _dioClient; // Dio instance provided externally

  // API Paths (relative to the base URL set in Dio)
  static const String _statusPath = '/status';
  static const String _pointsPath = '/points';
  // Note: Path construction will happen relative to the base URL in _dioClient
  String _realtimePlotPath(String variable, double elevation) => '/plots/realtime/$variable/$elevation';

  @override
  Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await _dioClient.get(_statusPath);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        throw RadprocApiException('Failed to get API status: Invalid response format');
      }
    } on DioException catch (e) {
      // Handle Dio specific errors (network, timeout, status codes)
      throw RadprocApiException('API Error getting status: ${e.message}', e);
    } catch (e) {
      // Handle other potential errors
      throw RadprocApiException('Unexpected error getting status: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPoints() async {
    try {
      final response = await _dioClient.get(_pointsPath);

      if (response.statusCode == 200 && response.data is List) {
        // Ensure all items in the list are maps
        return List<Map<String, dynamic>>.from(
          (response.data as List).cast<Map<String, dynamic>>(),
        );
      } else {
        throw RadprocApiException('Failed to get points: Invalid response format');
      }
    } on DioException catch (e) {
      throw RadprocApiException('API Error getting points: ${e.message}', e);
    } catch (e) {
      throw RadprocApiException('Unexpected error getting points: $e');
    }
  }

  @override
  Future<Uint8List> getRealtimePlot(String variable, double elevation) async {
    final path = _realtimePlotPath(variable, elevation);
    try {
      final response = await _dioClient.get<List<int>>( // Expect list of ints (bytes)
        path,
        options: Options(
          responseType: ResponseType.bytes, // IMPORTANT: Tell Dio to receive bytes
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        // Should be caught by DioException for non-200 codes, but double-check
        throw RadprocApiException('Failed to get realtime plot: Invalid response');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
         throw RadprocApiException('Realtime plot not found for $variable/$elevation', e);
      }
      throw RadprocApiException('API Error getting realtime plot: ${e.message}', e);
    } catch (e) {
      throw RadprocApiException('Unexpected error getting realtime plot: $e');
    }
  }
}

/// Custom exception for API related errors.
class RadprocApiException implements Exception {
  final String message;
  final DioException? dioException; // Optional original Dio exception

  RadprocApiException(this.message, [this.dioException]);

  @override
  String toString() => 'RadprocApiException: $message';
}