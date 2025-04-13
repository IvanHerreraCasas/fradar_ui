// lib/domain/repositories/radproc_repository.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fradar_ui/data/api/radproc_api.dart';
import 'package:fradar_ui/data/api/settings_api.dart';
import 'package:fradar_ui/data/sources/http_radproc_api.dart';
import 'package:fradar_ui/data/services/sse_service.dart'; // Import SSE Service
import 'package:fradar_ui/domain/models/api_status.dart';
import 'package:fradar_ui/domain/models/point.dart';
import 'package:fradar_ui/domain/models/plot_update.dart'; // Import PlotUpdate

class RadprocRepository {
  RadprocRepository({
    required RadprocApi radprocApi,
    required SettingsApi settingsApi,
    required Dio dioClient, // Add Dio client
    required SseService sseService, // Add SseService
  })  : _radprocApi = radprocApi,
        _settingsApi = settingsApi,
        _dioClient = dioClient,
        _sseService = sseService; // Store Dio client

  final RadprocApi _radprocApi;
  final SettingsApi _settingsApi;
  final Dio _dioClient; // Store Dio client instance
  final SseService _sseService;

  /// Fetches the currently saved API Base URL from settings.
  Future<String?> getApiBaseUrl() => _settingsApi.getApiBaseUrl();

  /// Saves the API Base URL to settings.
  Future<void> saveApiBaseUrl(String url) async {
    await _settingsApi.saveApiBaseUrl(url);
    // Update the Dio client's base URL immediately after saving
    _dioClient.options.baseUrl = url;
    print('Dio base URL updated to: $url'); // For debugging
  }

  /// Fetches the API status and converts it to an [ApiStatus] domain model.
  Future<ApiStatus> fetchApiStatus() async {
    try {
      final statusMap = await _radprocApi.getApiStatus();
      return ApiStatus.fromJson(statusMap);
    } on RadprocApiException {
      // Re-throw API specific exceptions if needed, or handle them
      rethrow;
    } on FormatException catch (e) {
       // Handle parsing errors from ApiStatus.fromJson
       print('Error parsing ApiStatus: $e');
       // Return a specific error status or rethrow as a domain error
       return const ApiStatus(status: 'error', message: 'Failed to parse API status response.');
    } catch (e) {
       // Catch-all for unexpected errors
       print('Unexpected error fetching API status: $e');
       return const ApiStatus(status: 'error', message: 'An unexpected error occurred.');
    }
  }

  /// Fetches the list of points and converts them to a list of [Point] domain models.
  Future<List<Point>> fetchPoints() async {
    try {
      final pointsListMap = await _radprocApi.getPoints();
      // Transform the list of maps into a list of Point objects
      final points = pointsListMap
          .map((pointMap) => Point.fromJson(pointMap))
          .toList();
      return points;
    } on RadprocApiException {
      rethrow; // Let UI handle API errors
    } on FormatException catch (e) {
       print('Error parsing Points list: $e');
       return []; // Return empty list on parsing error
    } catch (e) {
       print('Unexpected error fetching points: $e');
       return []; // Return empty list on unexpected error
    }
  }

  /// Fetches the latest plot image for the given variable/elevation.
  Future<Uint8List> fetchRealtimePlot(String variable, double elevation) async {
    try {
      final imageData = await _radprocApi.getRealtimePlot(variable, elevation);
      return imageData;
    } on RadprocApiException {
      rethrow; // Propagate API errors
    } catch (e) {
      print('Unexpected error fetching realtime plot in repo: $e');
      throw Exception('Could not fetch realtime plot.'); // Throw generic domain error
    }
  }

  Stream<PlotUpdate> getPlotUpdates() {
     // Listen to the SSEModel stream from SseService
     return _sseService.events
        .where((sseModel) => sseModel.event == 'plot_update' && sseModel.data != null && sseModel.data!.isNotEmpty) // Filter for plot_update events with data
        .map((sseModel) {
           // Parse the data string within the SSEModel using our domain model's factory
           return PlotUpdate.fromJsonString(sseModel.data!);
         })
        .where((update) => update.variable != null && update.elevation != null); // Filter out invalid parses
         // Add error handling if needed (e.g., .handleError(...))
  }

  // Dispose SSE service when repository is disposed (if repository lifecycle is managed)
  // This might happen in main.dart or higher up depending on setup
  void dispose() {
     _sseService.dispose();
  }
}