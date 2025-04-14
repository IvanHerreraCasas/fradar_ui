// lib/data/sources/http_radproc_api.dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:fradar_ui/data/api/radproc_api.dart';

class HttpRadprocApi implements RadprocApi {
  HttpRadprocApi({required Dio dioClient}) : _dioClient = dioClient;

  final Dio _dioClient; // Dio instance provided externally

  // API Paths (relative to the base URL set in Dio)
  static const String _statusPath = '/status';
  static const String _pointsPath = '/points'; // API Paths
  static const String _framesPath = '/plots/frames';
  String _historicalPlotPath(String variable, double elevation, String dtStr) =>
      '/plots/historical/$variable/$elevation/$dtStr';
  static const String _animationJobPath = '/jobs/animation';
  String _jobStatusPath(String taskId) => '/jobs/$taskId/status';
  String _animationJobResultPath(String taskId) =>
      '/jobs/animation/$taskId/data';

  // Date formatter for API query/body parameters (ISO 8601)
  final _isoFormatter = DateFormat("yyyy-MM-ddTHH:mm:ss'Z'"); // Use UTC 'Z'
  String _realtimePlotPath(String variable, double elevation) =>
      '/plots/realtime/$variable/$elevation';

  @override
  Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final response = await _dioClient.get(_statusPath);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        throw RadprocApiException(
          'Failed to get API status: Invalid response format',
        );
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
        throw RadprocApiException(
          'Failed to get points: Invalid response format',
        );
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
      final response = await _dioClient.get<List<int>>(
        // Expect list of ints (bytes)
        path,
        options: Options(
          responseType:
              ResponseType.bytes, // IMPORTANT: Tell Dio to receive bytes
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        // Should be caught by DioException for non-200 codes, but double-check
        throw RadprocApiException(
          'Failed to get realtime plot: Invalid response',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw RadprocApiException(
          'Realtime plot not found for $variable/$elevation',
          e,
        );
      }
      throw RadprocApiException(
        'API Error getting realtime plot: ${e.message}',
        e,
      );
    } catch (e) {
      throw RadprocApiException('Unexpected error getting realtime plot: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFrames(
    String variable,
    double elevation,
    DateTime startDt,
    DateTime endDt,
  ) async {
    final params = {
      'variable': variable,
      'elevation': elevation,
      'start_dt': _isoFormatter.format(startDt.toUtc()), // Send UTC
      'end_dt': _isoFormatter.format(endDt.toUtc()), // Send UTC
    };
    try {
      final response = await _dioClient.get(
        _framesPath,
        queryParameters: params,
      );
      if (response.statusCode == 200 && response.data?['frames'] is List) {
        // API returns {"frames": [...]}, extract the list
        return List<Map<String, dynamic>>.from(
          (response.data['frames'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        throw RadprocApiException(
          'Failed to get frames: Invalid response format',
        );
      }
    } on DioException catch (e) {
      throw RadprocApiException('API Error getting frames: ${e.message}', e);
    } catch (e) {
      throw RadprocApiException('Unexpected error getting frames: $e');
    }
  }

  @override
  Future<Uint8List> getHistoricalPlot(
    String variable,
    double elevation,
    String datetimeStr,
  ) async {
    final path = _historicalPlotPath(variable, elevation, datetimeStr);
    try {
      final response = await _dioClient.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        throw RadprocApiException(
          'Failed to get historical plot: Invalid response',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw RadprocApiException(
          'Historical plot not found for $variable/$elevation/$datetimeStr',
          e,
        );
      }
      throw RadprocApiException(
        'API Error getting historical plot: ${e.message}',
        e,
      );
    } catch (e) {
      throw RadprocApiException('Unexpected error getting historical plot: $e');
    }
  }

  @override
  Future<String> submitAnimationJob(
    String variable,
    double elevation,
    DateTime startDt,
    DateTime endDt,
    String outputFormat,
    bool? noWatermark,
    int? fps,
    List<double>? extent,
  ) async {
    final body = {
      'variable': variable,
      'elevation': elevation,
      'start_dt': _isoFormatter.format(startDt.toUtc()),
      'end_dt': _isoFormatter.format(endDt.toUtc()),
      'output_format': outputFormat, // Use the new required field
      // Include extent only if provided and valid (4 elements)
      if (extent != null && extent.length == 4) 'extent': extent,
      // API guide implies output_file is handled server-side or optional?
      // If needed: 'output_file': '/path/on/server/...'
      // If API requires *some* path, maybe generate a temporary one? Needs clarification.
      // For now, omitting based on README/API Guide interpretation.
    };
    try {
      final response = await _dioClient.post(_animationJobPath, data: body);
      // Expecting 202 Accepted with {"task_id": "..."}
      if (response.statusCode == 202 && response.data?['task_id'] is String) {
        return response.data['task_id'] as String;
      } else {
        throw RadprocApiException(
          'Failed to submit animation job: Unexpected response status ${response.statusCode} or format',
        );
      }
    } on DioException catch (e) {
      throw RadprocApiException(
        'API Error submitting animation job: ${e.message}',
        e,
      );
    } catch (e) {
      throw RadprocApiException(
        'Unexpected error submitting animation job: $e',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String taskId) async {
    final path = _jobStatusPath(taskId);
    try {
      final response = await _dioClient.get(path);
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        throw RadprocApiException(
          'Failed to get job status: Invalid response format',
        );
      }
    } on DioException catch (e) {
      // Note: API guide says unknown task ID might return PENDING status, not 404 here
      throw RadprocApiException(
        'API Error getting job status: ${e.message}',
        e,
      );
    } catch (e) {
      throw RadprocApiException('Unexpected error getting job status: $e');
    }
  }

  @override
  Future<Uint8List> getAnimationJobResult(String taskId) async {
    final path = _animationJobResultPath(taskId);
    try {
      final response = await _dioClient.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      // API Guide implies 200 OK on success
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        // This case might indicate pending (202) or failed (400) based on API guide,
        // which should ideally be checked *before* calling this via getJobStatus.
        // Throwing a generic error here if not 200.
        throw RadprocApiException(
          'Failed to get animation result: Unexpected status ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      // 404 might mean task ID invalid or file missing
      // 400 might mean job failed/revoked
      // 202 might mean still pending
      // We rely on getJobStatus to prevent calling this endpoint inappropriately.
      throw RadprocApiException(
        'API Error getting animation result: ${e.message}',
        e,
      );
    } catch (e) {
      throw RadprocApiException(
        'Unexpected error getting animation result: $e',
      );
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
