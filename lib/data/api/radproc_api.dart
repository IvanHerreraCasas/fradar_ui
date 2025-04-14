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

  /// Gets the list of available frame identifiers (timestamps) for a given period.
  /// Returns a List of Maps, like [{"datetime_str": "YYYYMMDD_HHMM"}, ...].
  Future<List<Map<String, dynamic>>> getFrames(
    String variable,
    double elevation,
    DateTime startDt,
    DateTime endDt,
  );

  /// Gets a specific historical plot image by its timestamp string.
  /// Returns raw image bytes. Throws if not found (404).
  Future<Uint8List> getHistoricalPlot(
    String variable,
    double elevation,
    String datetimeStr,
  );

  /// Submits a job to generate an animation file.
  /// [extent] is optional: [lonMin, lonMax, latMin, latMax].
  /// Returns the task_id (String) assigned by the backend.
  Future<String> submitAnimationJob(
    String variable,
    double elevation,
    DateTime startDt,
    DateTime endDt,
    String outputFormat,
    bool? noWatermark,
    int? fps,
    List<double>? extent,
  );

  /// Gets the status details of a submitted background job.
  /// Returns a Map representing the job status JSON.
  Future<Map<String, dynamic>> getJobStatus(String taskId);

  /// Gets the result data (animation file bytes) for a completed animation job.
  /// Throws if job failed, pending, or not found. Returns bytes on success.
  Future<Uint8List> getAnimationJobResult(String taskId);

  /// Submits a job to generate timeseries data for a point.
  Future<String> submitTimeseriesJob(
    String pointName,
    DateTime startDt,
    DateTime endDt,
    String? variable,
  );

  /// Submits a job to calculate accumulation for a point.
  Future<String> submitAccumulationJob(
    String pointName,
    DateTime startDt,
    DateTime endDt,
    String interval,
    String? rateVariable,
  );

  /// Gets the result data (JSON or CSV) for a completed timeseries job.
  /// Returns dynamic for now, repository will handle parsing based on format.
  Future<dynamic> getTimeseriesJobResult(String taskId, String format);

  /// Gets the result data (CSV) for a completed accumulation job.
  /// Returns raw CSV content as String (or bytes if preferred).
  Future<String> getAccumulationJobResult(String taskId);
}
