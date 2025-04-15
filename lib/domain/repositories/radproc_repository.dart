// lib/domain/repositories/radproc_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fradar_ui/data/api/job_storage_api.dart';
import 'package:fradar_ui/data/api/radproc_api.dart';
import 'package:fradar_ui/data/api/settings_api.dart';
import 'package:fradar_ui/data/sources/http_radproc_api.dart';
import 'package:fradar_ui/data/services/sse_service.dart'; // Import SSE Service
import 'package:fradar_ui/domain/models/api_status.dart';
import 'package:fradar_ui/domain/models/point.dart';
import 'package:fradar_ui/domain/models/plot_frame.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/domain/models/plot_update.dart';
import 'package:fradar_ui/domain/models/timeseries_datapoint.dart';
import 'package:path_provider/path_provider.dart';

class RadprocRepository {
  RadprocRepository({
    required RadprocApi radprocApi,
    required SettingsApi settingsApi,
    required JobStorageApi jobStorageApi,
    required Dio dioClient, // Add Dio client
    required SseService sseService, // Add SseService
  }) : _radprocApi = radprocApi,
       _settingsApi = settingsApi,
       _jobStorageApi = jobStorageApi,
       _dioClient = dioClient,
       _sseService = sseService; // Store Dio client

  final RadprocApi _radprocApi;
  final SettingsApi _settingsApi;
  final JobStorageApi _jobStorageApi;
  final Dio _dioClient; // Store Dio client instance
  final SseService _sseService;

  // Central StreamController for broadcasting job updates
  // Use broadcast so multiple BLoCs can listen (e.g., HistoricPlotsBloc and TasksBloc)
  final _jobUpdateController = StreamController<Job>.broadcast();

  /// A stream that emits [Job] updates whenever a monitored job's status changes.
  Stream<Job> get jobUpdates => _jobUpdateController.stream;

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
      return const ApiStatus(
        status: 'error',
        message: 'Failed to parse API status response.',
      );
    } catch (e) {
      // Catch-all for unexpected errors
      print('Unexpected error fetching API status: $e');
      return const ApiStatus(
        status: 'error',
        message: 'An unexpected error occurred.',
      );
    }
  }

  /// Fetches the list of points and converts them to a list of [Point] domain models.
  Future<List<Point>> fetchPoints() async {
    try {
      final pointsListMap = await _radprocApi.getPoints();
      // Transform the list of maps into a list of Point objects
      final points =
          pointsListMap.map((pointMap) => Point.fromJson(pointMap)).toList();
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
      throw Exception(
        'Could not fetch realtime plot.',
      ); // Throw generic domain error
    }
  }

  // Listen to the SSEModel stream from SseService
  Stream<PlotUpdate> getPlotUpdates() {
    return _sseService.events
        .where(
          (sseModel) =>
              sseModel.event == 'plot_update' &&
              sseModel.data != null &&
              sseModel.data!.isNotEmpty,
        ) // Filter for plot_update events with data
        .map((sseModel) {
          // Parse the data string within the SSEModel using our domain model's factory
          return PlotUpdate.fromJsonString(sseModel.data!);
        })
        .where(
          (update) => update.variable != null && update.elevation != null,
        ); // Filter out invalid parses
    // Add error handling if needed (e.g., .handleError(...))
  }

  /// Fetches list of plot frames for the given parameters.
  Future<List<PlotFrame>> fetchFrames(
    String variable,
    double elevation,
    DateTime startDt,
    DateTime endDt,
  ) async {
    try {
      final framesListMap = await _radprocApi.getFrames(
        variable,
        elevation,
        startDt,
        endDt,
      );
      final frames =
          framesListMap
              .map((frameMap) => PlotFrame.fromJson(frameMap))
              .toList();
      // Optional: Sort frames by dateTimeUtc
      frames.sort((a, b) => a.dateTimeUtc.compareTo(b.dateTimeUtc));
      return frames;
    } on RadprocApiException {
      rethrow;
    } on FormatException catch (e) {
      print('Error parsing Frames list: $e');
      return [];
    } catch (e) {
      print('Unexpected error fetching frames: $e');
      return [];
    }
  }

  /// Fetches the image bytes for a specific historical plot frame.
  Future<Uint8List> fetchHistoricalPlot(
    String variable,
    double elevation,
    String datetimeStr,
  ) async {
    try {
      return await _radprocApi.getHistoricalPlot(
        variable,
        elevation,
        datetimeStr,
      );
    } on RadprocApiException {
      rethrow;
    } catch (e) {
      print('Unexpected error fetching historical plot in repo: $e');
      throw Exception('Could not fetch historical plot.');
    }
  }

  // --- Background Jobs ---

  /// Monitors the status of a job by polling the API.
  /// Emits updated [Job] objects. Completes or errors when job finishes/fails.
  Stream<Job> monitorJob(Job initialJob) {
    final controller = StreamController<Job>();
    Timer? timer;
    Job currentJob = initialJob; // Keep track of the latest known job state

    Future<void> checkStatus() async {
      if (controller.isClosed) return; // Stop if controller is closed
      print('[MonitorJob ${currentJob.taskId}] Polling...'); // Identify job
      try {
        final statusMap = await _radprocApi.getJobStatus(currentJob.taskId);
        print(
          '[MonitorJob ${currentJob.taskId}] Received API Status: $statusMap',
        ); // See raw response

        final previousStatusEnum = currentJob.status; // Store before update
        currentJob = currentJob.updateFromApiStatus(
          statusMap,
        ); // Update local state
        print(
          '[MonitorJob ${currentJob.taskId}] Parsed Status Enum: ${currentJob.status.name}',
        ); // Verify parsing
        print(
          '[MonitorJob ${currentJob.taskId}] Parsed Status Details: ${currentJob.statusDetails}',
        );
        print(
          '[MonitorJob ${currentJob.taskId}] Parsed Error: ${currentJob.errorMessage}',
        );

        // Save and Broadcast
        await _jobStorageApi.saveJob(currentJob);
        print(
          '[MonitorJob ${currentJob.taskId}] Broadcasting Update: ${currentJob.status.name}',
        );
        _jobUpdateController.add(currentJob);
        controller.add(currentJob); // Also emit on local stream

        // Check stop condition
        bool shouldStop =
            currentJob.status == JobStatusEnum.success ||
            currentJob.status == JobStatusEnum.failure ||
            currentJob.status == JobStatusEnum.revoked;
        print(
          '[MonitorJob ${currentJob.taskId}] Should Stop Polling: $shouldStop (Previous: ${previousStatusEnum.name}, Current: ${currentJob.status.name})',
        );

        if (shouldStop && currentJob.status != previousStatusEnum) {
          // Stop only on change to final state
          timer?.cancel();
          controller.close();
          print('[MonitorJob ${currentJob.taskId}] Polling Stopped.');
        }
      } on RadprocApiException catch (e) {
        print('Error polling job ${currentJob.taskId}: $e');
        // Optionally emit an error state or just stop polling
        currentJob = currentJob.copyWith(
          status: JobStatusEnum.unknown,
          errorMessage: e.toString(),
        );
        controller.add(currentJob); // Emit error state
        controller.addError(e);
        timer?.cancel();
        controller.close();
      } catch (e) {
        print('Unexpected error polling job ${currentJob.taskId}: $e');
        currentJob = currentJob.copyWith(
          status: JobStatusEnum.unknown,
          errorMessage: e.toString(),
        );
        await _jobStorageApi.saveJob(currentJob); // Save error state
        _jobUpdateController.add(currentJob); // Broadcast error state
        controller.add(currentJob);
        controller.addError(e); // Propagate error on local stream
        timer?.cancel();
        controller.close();
      }
    }

    // Start polling immediately and then periodically
    checkStatus();
    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkStatus(),
    ); // Poll every 5 seconds

    // Cleanup: Cancel timer when stream subscription is cancelled
    controller.onCancel = () {
      print('Cancelling job monitor for ${currentJob.taskId}');
      timer?.cancel();
    };

    return controller.stream;
  }

  // --- Job Persistence Methods ---
  Future<List<Job>> getPersistedJobs() => _jobStorageApi.loadJobs();
  Future<void> deleteJobRecord(String taskId) =>
      _jobStorageApi.deleteJob(taskId);
  Future<void> clearAllJobRecords() => _jobStorageApi.clearAllJobs();

  /// Submits an animation generation job to the backend.
  Future<Job> startAnimationGeneration({
    required String variable,
    required double elevation,
    required DateTime startDt,
    required DateTime endDt,
    List<double>? extent,
    String outputFormat = ".mp4", // Default format or pass from BLoC
    // int? fps, // Pass other params if needed
    // bool? noWatermark,
  }) async {
    // Store relevant parameters for potential use later (e.g., filename suggestion)
    final params = {
      'variable': variable,
      'elevation': elevation,
      'startDt': startDt.toIso8601String(), // Store as string for simplicity
      'endDt': endDt.toIso8601String(),
      'extent': extent,
      'outputFormat': outputFormat, // Store the requested format
      // 'fps': fps,
      // 'noWatermark': noWatermark,
    };
    try {
      // No longer need to generate server path
      final taskId = await _radprocApi.submitAnimationJob(
        variable,
        elevation,
        startDt,
        endDt,
        outputFormat,
        false,
        5,
        extent,
        // Pass other optional args if implemented
      );
      final initialJob = Job.submitted(
        taskId: taskId,
        jobType: JobType.animation,
        parameters: params,
      );
      await _jobStorageApi.saveJob(initialJob); // Save initial job state
      return initialJob;
    } on RadprocApiException {
      rethrow;
    } catch (e) {
      print('Unexpected error submitting animation job in repo: $e');
      throw Exception('Could not submit animation job.');
    }
  }

  /// Fetches the animation file bytes for a successfully completed animation job.
  Future<Uint8List> fetchAnimationResult(String taskId) async {
    try {
      return await _radprocApi.getAnimationJobResult(taskId);
    } on RadprocApiException {
      rethrow;
    } catch (e) {
      print('Unexpected error fetching animation result in repo: $e');
      throw Exception('Could not fetch animation result.');
    }
  }

  /// Fetches animation bytes, saves to a temp file, returns the file path.
  Future<String> prepareVideoFile(String taskId) async {
      String? tempFilePath;
      try {
        final videoBytes = await fetchAnimationResult(taskId); // Use existing fetcher
        final tempDir = await getTemporaryDirectory();
        tempFilePath = '${tempDir.path}/temp_video_${taskId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(videoBytes, flush: true);
        print('Video bytes saved to temporary file: $tempFilePath');
        return tempFilePath;
      } catch (e) {
          // Clean up partial file if creation failed mid-way
          if (tempFilePath != null) {
            await deleteTempFile(tempFilePath);
          }
          print('Error preparing video file in repo: $e');
          throw Exception('Failed to prepare video file: $e');
      }
  }

  /// Fetches animation bytes and prompts user to save locally using file_picker.
  Future<void> downloadAnimationResult(Job job) async {
    if (job.status != JobStatusEnum.success ||
        job.jobType != JobType.animation) {
      throw Exception('Job not successful or not an animation job.');
    }
    print('Attempting to download result for job ${job.taskId}');
    try {
      final fileBytes = await fetchAnimationResult(job.taskId);
      print(
        'Fetched ${fileBytes.length} bytes for job ${job.taskId}. Prompting user to save via FilePicker...',
      );

      // --- Use file_picker to prompt user for LOCAL save location ---

      // Get format/extension from stored parameters
      final String format =
          job.parameters['outputFormat'] as String? ??
          ".mp4"; // Default if missing
      final String ext =
          format.startsWith('.')
              ? format.substring(1)
              : format; // e.g., mp4, gif

      // Generate suggested filename
      final suggestedFilename =
          'animation_${job.parameters['variable']}_${job.parameters['elevation']}_${job.taskId.substring(0, 6)}.$ext';

      // Call FilePicker.platform.saveFile
      // This returns the path where the file was saved, or null if cancelled.
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Animation As...', // Title for the dialog window
        fileName: suggestedFilename, // Pre-filled filename
        // Pass the bytes directly for non-web platforms
        // bytes: kIsWeb ? null : fileBytes, // file_picker handles bytes differently on web
        bytes: fileBytes, // Pass bytes directly for desktop/mobile
        type: FileType.custom, // Use custom to specify extensions
        allowedExtensions: [ext], // Allow only the generated extension
        lockParentWindow: true,
        // lockParentWindow: true,      // Optional: Modal behavior
      );

      if (outputFile == null) {
        // User cancelled the picker
        print('File save cancelled by user for job ${job.taskId}.');
        // Optionally throw an exception or return a specific status
        return; // Exit the function gracefully
      }

      // On desktop/mobile, saveFile with bytes writes the file automatically.
      // The returned path is the confirmation.
      print('File successfully saved to: $outputFile');
      // Optionally, you could perform actions with the outputFile path here if needed
    } catch (e) {
      // Catch errors from fetchAnimationResult OR FilePicker
      print('Error during animation download/save process: $e');
      // Rethrow a domain-level exception
      throw Exception('Failed to download or save animation result.');
    }
  }

  // --- Timeseries ---
  Future<Job> startTimeseriesGeneration({
    required String pointName,
    required DateTime startDt,
    required DateTime endDt,
    required String?
    variable, // Use point's default if null? API handles optional
  }) async {
    final params = {
      'pointName': pointName,
      'startDt': startDt.toIso8601String(),
      'endDt': endDt.toIso8601String(),
      'variable': variable,
    };
    try {
      final taskId = await _radprocApi.submitTimeseriesJob(
        pointName,
        startDt,
        endDt,
        variable,
      );
      final initialJob = Job.submitted(
        taskId: taskId,
        jobType: JobType.timeseries,
        parameters: params,
      );
      await _jobStorageApi.saveJob(initialJob);
      return initialJob;
    } catch (e) {
      /* ... */
      rethrow;
    } // Rethrow specific or generic
  }

  /// Fetches and parses timeseries JSON data into domain models.
  /// Always requests JSON format from the API.
  Future<List<TimeseriesDataPoint>> fetchTimeseriesData(
    String taskId, {
    required String variableName,
  }) async {
    try {
      // Force format to JSON for internal data use
      final rawData = await _radprocApi.getTimeseriesJobResult(taskId, 'json');

      if (rawData is List) {
        print('Parsing JSON for variable: $variableName');
        // Parsing now happens HERE
        return rawData
            .map(
              (item) => TimeseriesDataPoint.fromJson(
                Map<String, dynamic>.from(item),
                variableName,
              ),
            )
            .toList();
      } else {
        throw Exception(
          'Expected JSON list from timeseries result, got ${rawData.runtimeType}',
        );
      }
    } catch (e) {
      print(
        'Error fetching/parsing timeseries JSON data in repo for $variableName: $e',
      );
      rethrow;
    }
  }

  /// Fetches timeseries CSV and prompts user to save locally.
  Future<void> downloadTimeseriesData(Job job) async {
    if (job.status != JobStatusEnum.success ||
        job.jobType != JobType.timeseries) {
      throw Exception('Job not successful or not a timeseries job.');
    }
    print('Attempting to download timeseries result for job ${job.taskId}');
    try {
      // Fetch as CSV string
      final csvData = await _fetchTimeseriesCsvString(job.taskId);
      print(
        'Fetched ${csvData.length} chars of CSV data for job ${job.taskId}. Prompting user to save...',
      );

      final suggestedFilename =
          'timeseries_${job.parameters['pointName']}_${job.parameters['variable'] ?? 'default'}_${job.taskId.substring(0, 6)}.csv';

      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Timeseries Data As...',
        fileName: suggestedFilename,
        bytes: Uint8List.fromList(
          utf8.encode(csvData),
        ), // Encode string to bytes
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      print('File save dialog prompted for job ${job.taskId}');
    } catch (e) {
      print('Error during timeseries download/save process: $e');
      throw Exception('Failed to download or save timeseries result.');
    }
  }

  // --- Accumulation ---
  Future<Job> startAccumulationCalculation({
    required String pointName,
    required DateTime startDt,
    required DateTime endDt,
    required String interval,
    String? rateVariable, // Defaults to 'RATE' in backend if null
  }) async {
    final params = {
      'pointName': pointName,
      'startDt': startDt.toIso8601String(),
      'endDt': endDt.toIso8601String(),
      'interval': interval,
      'rateVariable': rateVariable,
    };
    try {
      final taskId = await _radprocApi.submitAccumulationJob(
        pointName,
        startDt,
        endDt,
        interval,
        rateVariable,
      );
      final initialJob = Job.submitted(
        taskId: taskId,
        jobType: JobType.accumulation,
        parameters: params,
      );
      await _jobStorageApi.saveJob(initialJob);
      return initialJob;
    } catch (e) {
      /* ... */
      rethrow;
    }
  }

  /// Fetches accumulation CSV data AND parses it into domain models.
  Future<List<TimeseriesDataPoint>> fetchAccumulationData(String taskId) async {
    try {
      // 1. Fetch the raw CSV string (including comments)
      final rawCsvData = await _radprocApi.getAccumulationJobResult(taskId);

      // --- 2. Preprocess: Remove comment lines ---
      final lines = rawCsvData.split('\n');
      final cleanedLines =
          lines
              .where(
                (line) =>
                    line.trim().isNotEmpty && !line.trim().startsWith('#'),
              )
              .toList();

      if (cleanedLines.isEmpty) {
        print(
          'Accumulation CSV for $taskId contains no data after removing comments.',
        );
        return []; // No header or data found
      }

      final cleanedCsvData = cleanedLines.join('\n');
      // -----------------------------------------

      // 3. Parse the CLEANED CSV data
      final List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: true,
      ).convert(cleanedCsvData);

      if (csvTable.length > 1) {
        // Need header + data rows
        final headers =
            csvTable[0].map((h) => h.toString().toLowerCase()).toList();
        final headerIndex = headers.indexOf('timestamp');
        // Adjust value header detection based on actual output in comments
        // Example header from comments: 'precip_acc_1H_mm'
        final valueHeaderPattern = RegExp(r'precip_acc_.*_mm');
        final valueIndex = headers.indexWhere(
          (h) =>
              h == 'value' ||
              h.contains('accum') ||
              valueHeaderPattern.hasMatch(h),
        );

        if (headerIndex != -1 && valueIndex != -1) {
          print('Parsing accumulation CSV with headers: ${csvTable[0]}');
          return csvTable
              .skip(1)
              .map((row) {
                try {
                  // Ensure row has enough columns before accessing index
                  if (row.length > headerIndex && row.length > valueIndex) {
                    return TimeseriesDataPoint(
                      timestamp: DateTime.parse(row[headerIndex].toString()),
                      value: (row[valueIndex] as num? ?? double.nan).toDouble(),
                    );
                  } else {
                    print(
                      "Skipping malformed row (length ${row.length}): $row",
                    );
                    return null;
                  }
                } catch (e) {
                  print("Error parsing row $row: $e");
                  return null; // Skip bad rows
                }
              })
              .whereNotNull()
              .toList();
        } else {
          throw Exception(
            'Could not find expected headers (timestamp, value/accum*/precip_acc_*) in accumulation CSV. Found: ${csvTable[0]}',
          );
        }
      } else {
        print('Accumulation CSV for $taskId has no data rows after header.');
        return []; // Return empty list if only header exists
      }
    } catch (e) {
      print(
        'Error fetching/parsing accumulation data in repo for task $taskId: $e',
      );
      rethrow; // Propagate error
    }
  }

  /// Fetches accumulation CSV and prompts user to save locally.
  Future<void> downloadAccumulationData(Job job) async {
    if (job.status != JobStatusEnum.success ||
        job.jobType != JobType.accumulation) {
      throw Exception('Job not successful or not an accumulation job.');
    }
    print('Attempting to download accumulation result for job ${job.taskId}');
    try {
      final csvData = await _fetchAccumulationCsvString(
        job.taskId,
      ); // Fetch raw CSV
      print(
        'Fetched ${csvData.length} chars of CSV data for job ${job.taskId}. Prompting user to save...',
      );

      final suggestedFilename =
          'accumulation_${job.parameters['pointName']}_${job.parameters['interval']}_${job.taskId.substring(0, 6)}.csv';

      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Accumulation Data As...',
        fileName: suggestedFilename,
        bytes: Uint8List.fromList(utf8.encode(csvData)),
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      print('File save dialog prompted for job ${job.taskId}');
    } catch (e) {
      print('Error during accumulation download/save process: $e');
      throw Exception('Failed to download or save accumulation result.');
    }
  }

  // --- Internal methods for fetching raw CSV for download ---

  Future<String> _fetchTimeseriesCsvString(String taskId) async {
    try {
      final rawData = await _radprocApi.getTimeseriesJobResult(taskId, 'csv');
      if (rawData is String) {
        return rawData;
      } else {
        throw Exception(
          'Expected CSV string for timeseries export, got ${rawData.runtimeType}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _fetchAccumulationCsvString(String taskId) async {
    // This is the same as the original API call for accumulation
    try {
      return await _radprocApi.getAccumulationJobResult(taskId);
    } catch (e) {
      rethrow;
    }
  }


  // Helpers
  // Helper to delete temp file safely
  Future<void> deleteTempFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('Deleted temporary video file: $filePath');
      }
    } catch (e) {
      print('Error deleting temporary file $filePath: $e');
    }
  }

  // Dispose SSE service when repository is disposed (if repository lifecycle is managed)
  // This might happen in main.dart or higher up depending on setup
  void dispose() {
    print('Disposing Repository and closing job update stream.');
    _jobUpdateController.close();
    _sseService.dispose();
  }
}
