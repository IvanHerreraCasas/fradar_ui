// lib/presentation/features/timeseries/bloc/timeseries_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/domain/models/timeseries_datapoint.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'timeseries_event.dart';
import 'timeseries_state.dart';
// Import TimeseriesDataPoint if parsing JSON
// import 'package:fradar_ui/domain/models/timeseries_datapoint.dart';

class TimeseriesBloc extends Bloc<TimeseriesEvent, TimeseriesState> {
  final RadprocRepository _radprocRepository;
  StreamSubscription<Job>? _jobUpdateSubscription;

  TimeseriesBloc({required RadprocRepository radprocRepository})
    : _radprocRepository = radprocRepository,
      super(TimeseriesState()) {
    // Initial state

    on<LoadPoints>(_onLoadPoints);
    on<PointSelectionChanged>(_onPointSelectionChanged);
    on<VariableSelected>(_onVariableSelected);
    on<IntervalSelected>(_onIntervalSelected);
    on<DateTimeRangeChanged>(_onDateTimeRangeChanged);
    on<DisplayModeToggled>(_onDisplayModeToggled);
    on<FetchDataForSelectedPoints>(_onFetchDataForSelectedPoints);
    on<ExportPointDataClicked>(_onExportPointDataClicked);
    on<JobUpdateReceived>(_onJobUpdateReceived, transformer: sequential());
    on<ErrorOccurredInternal>(_onErrorOccurredInternal);

    _subscribeToJobUpdates();
  }

  void _subscribeToJobUpdates() {
    _jobUpdateSubscription?.cancel();
    _jobUpdateSubscription = _radprocRepository.jobUpdates.listen(
      (job) {
        // Only react to relevant job types
        if (job.jobType == JobType.timeseries ||
            job.jobType == JobType.accumulation) {
          print(
            'TimeseriesBloc received relevant job update: ${job.taskId} Status: ${job.status.name}',
          );
          add(JobUpdateReceived(job));
        }
      },
      onError:
          (error) =>
              add(ErrorOccurredInternal('Job update stream error: $error')),
    );
  }

  Future<void> _onLoadPoints(
    LoadPoints event,
    Emitter<TimeseriesState> emit,
  ) async {
    emit(
      state.copyWith(status: TimeseriesStatus.loadingPoints, clearError: true),
    );
    try {
      final points = await _radprocRepository.fetchPoints();
      // Determine a sensible default variable if needed
      final defaultVariable =
          points.isNotEmpty ? points.first.variable : 'RATE';
      emit(
        state.copyWith(
          status: TimeseriesStatus.idle, // Ready for interaction
          availablePoints: points,
          selectedVariable:
              state.selectedVariable == 'RATE'
                  ? defaultVariable
                  : state.selectedVariable, // Update default if still RATE
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TimeseriesStatus.pointsLoadError,
          errorMessage: 'Failed to load points: $e',
        ),
      );
    }
  }

  void _onPointSelectionChanged(
    PointSelectionChanged event,
    Emitter<TimeseriesState> emit,
  ) {
    final currentSelection = Set<String>.from(state.selectedPointNames);
    if (event.isSelected) {
      currentSelection.add(event.pointName);
    } else {
      currentSelection.remove(event.pointName);
      // Also remove any loaded data/status for the deselected point
      final newPointData = Map<String, List<TimeseriesDataPoint>>.from(
        state.pointData,
      )..remove(event.pointName);
      final newLoadingStatus = Map<String, bool>.from(state.pointLoadingStatus)
        ..remove(event.pointName);
      final newErrorStatus = Map<String, String?>.from(state.pointErrorStatus)
        ..remove(event.pointName);
      emit(
        state.copyWith(
          selectedPointNames: currentSelection,
          pointData: newPointData,
          pointLoadingStatus: newLoadingStatus,
          pointErrorStatus: newErrorStatus,
          status: _determineIdleStatus(
            currentSelection,
            newLoadingStatus,
            newErrorStatus,
          ),
        ),
      );
      return; // Exit early after removing data
    }
    emit(
      state.copyWith(
        selectedPointNames: currentSelection,
        status: _determineIdleStatus(
          currentSelection,
          state.pointLoadingStatus,
          state.pointErrorStatus,
        ), // Re-evaluate status
      ),
    );
    // Optional: Automatically trigger fetch if in Graph mode and points selected?
    // if (!state.isMapMode && currentSelection.isNotEmpty) {
    //    add(FetchDataForSelectedPoints());
    // }
  }

  void _onVariableSelected(
    VariableSelected event,
    Emitter<TimeseriesState> emit,
  ) {
    if (event.variable == state.selectedVariable) return; // No change

    emit(
      state.copyWith(
        selectedVariable: event.variable,
        status: TimeseriesStatus.idle, // Back to idle, clear data
        clearPointData: true,
        clearPointStatus: true,
        clearError: true,
        // Reset interval only if changing *away* from accumulation? Keep user's choice otherwise.
        // selectedInterval: event.variable == accumulationVariable ? state.selectedInterval : defaultInterval,
      ),
    );
  }

  void _onIntervalSelected(
    IntervalSelected event,
    Emitter<TimeseriesState> emit,
  ) {
    if (!state.isAccumulationSelected ||
        event.interval == state.selectedInterval)
      return; // Only applicable for accumulation

    emit(
      state.copyWith(
        selectedInterval: event.interval,
        status: TimeseriesStatus.idle, // Back to idle, clear data
        clearPointData: true,
        clearPointStatus: true,
        clearError: true,
      ),
    );
  }

  void _onDateTimeRangeChanged(
    DateTimeRangeChanged event,
    Emitter<TimeseriesState> emit,
  ) {
    if (event.start == state.startDt && event.end == state.endDt)
      return; // No change

    emit(
      state.copyWith(
        startDt: event.start,
        endDt: event.end,
        status: TimeseriesStatus.idle, // Back to idle, clear data
        clearPointData: true,
        clearPointStatus: true,
        clearError: true,
      ),
    );
  }

  void _onDisplayModeToggled(
    DisplayModeToggled event,
    Emitter<TimeseriesState> emit,
  ) {
    final newIsMapMode = !state.isMapMode;
    emit(
      state.copyWith(
        isMapMode: newIsMapMode,
        // Determine status based on new mode and existing data/selections
        status:
            newIsMapMode
                ? TimeseriesStatus.idle
                : _determineIdleStatus(
                  state.selectedPointNames,
                  state.pointLoadingStatus,
                  state.pointErrorStatus,
                ),
      ),
    );
    // Optionally trigger fetch if switching to graph mode with selections
    // if (!newIsMapMode && state.selectedPointNames.isNotEmpty) {
    //    add(FetchDataForSelectedPoints());
    // }
  }

  Future<void> _onFetchDataForSelectedPoints(
    FetchDataForSelectedPoints event,
    Emitter<TimeseriesState> emit,
  ) async {
    if (state.selectedPointNames.isEmpty) {
      emit(
        state.copyWith(
          status: TimeseriesStatus.idle,
          clearPointData: true,
          clearPointStatus: true,
        ),
      );
      return;
    }

    // Set overall status and prepare per-point status maps
    final currentLoading = Map<String, bool>.from(state.pointLoadingStatus);
    final currentErrors = Map<String, String?>.from(state.pointErrorStatus);
    final currentData = Map<String, List<TimeseriesDataPoint>>.from(
      state.pointData,
    );

    // Mark all selected points as loading, clearing previous errors/data for them
    for (final pointName in state.selectedPointNames) {
      currentLoading[pointName] = true;
      currentErrors.remove(pointName);
      currentData.remove(pointName); // Remove old data before fetching new
    }

    emit(
      state.copyWith(
        status: TimeseriesStatus.loadingData,
        pointLoadingStatus: currentLoading,
        pointErrorStatus: currentErrors,
        pointData:
            currentData, // Emit with cleared data for points being reloaded
        clearError: true, // Clear general error message
      ),
    );

    // --- Submit jobs ---
    final List<Future<void>> submissionFutures = []; // Changed to Future<void>

    for (final pointName in state.selectedPointNames) {
      submissionFutures.add(
        Future<void>(() async {
          // Wrap submission in its own async closure
          try {
            Job submittedJob; // Store submitted job info if needed later
            if (state.isAccumulationSelected) {
              submittedJob = await _radprocRepository
                  .startAccumulationCalculation(
                    pointName: pointName,
                    startDt: state.startDt,
                    endDt: state.endDt,
                    interval: state.selectedInterval,
                    // rateVariable: // Optional
                  );
            } else {
              submittedJob = await _radprocRepository.startTimeseriesGeneration(
                pointName: pointName,
                startDt: state.startDt,
                endDt: state.endDt,
                variable: state.selectedVariable,
              );
            }
            print('Submitted job ${submittedJob.taskId} for point $pointName');
            _radprocRepository.monitorJob(submittedJob);
          } catch (e) {
            print('Failed to submit job for point $pointName: $e');
            // Update state immediately to show error for this specific point
            final errorUpdateLoading = Map<String, bool>.from(
              state.pointLoadingStatus,
            )..remove(pointName);
            final errorUpdateErrors = Map<String, String?>.from(
              state.pointErrorStatus,
            )..[pointName] = 'Job submission failed: $e';
            emit(
              state.copyWith(
                pointLoadingStatus: errorUpdateLoading,
                pointErrorStatus: errorUpdateErrors,
                // Re-evaluate overall status after marking this point as error
                status: _determineOverallStatus(
                  state.selectedPointNames,
                  errorUpdateLoading,
                  errorUpdateErrors,
                ),
              ),
            );
          }
        }), // End of async closure
      ); // End of add Future
    } // End of loop

    // Wait for all submissions to finish (or fail individually)
    await Future.wait(submissionFutures);
    print(
      'Finished attempting submissions for ${submissionFutures.length} points.',
    );
    // Final status will be updated progressively by JobCompletedInternal events
  }

  // --- Renamed and Refactored Handler ---
  Future<void> _onJobUpdateReceived(
    JobUpdateReceived event,
    Emitter<TimeseriesState> emit,
  ) async {
    // Renamed handler
    final job = event.job;
    final pointName = job.parameters['pointName'] as String?;

    // Verify relevance (same checks as before)
    if (pointName == null || !state.selectedPointNames.contains(pointName)) {
      return;
    }
    bool paramsMatch = _jobParametersMatchCurrentState(job.parameters, state);
    if (!paramsMatch) {
      return;
    }

    // --- Process Relevant Job Update ---
    final currentLoading = Map<String, bool>.from(state.pointLoadingStatus);
    final currentErrors = Map<String, String?>.from(state.pointErrorStatus);
    final currentData = Map<String, List<TimeseriesDataPoint>>.from(
      state.pointData,
    );

    // Update status based on the received job state
    switch (job.status) {
      case JobStatusEnum.pending:
      case JobStatusEnum.running: // Treat running same as pending for UI
      case JobStatusEnum.unknown: // Treat unknown as potentially loading
        currentLoading[pointName] = true; // Ensure loading is true
        currentErrors.remove(pointName); // Clear any previous error
        // Don't clear existing data yet, keep showing old data while loading if desired
        break;

      case JobStatusEnum.success:
        currentLoading.remove(pointName); // Stop loading indication
        currentErrors.remove(pointName); // Clear previous error
        try {
          // Fetch and parse data ONLY on success
          List<TimeseriesDataPoint> parsedData = [];
          print(
            'Fetching data for successful job ${job.taskId} (${job.jobType.name}) for point $pointName',
          );

          if (job.jobType == JobType.timeseries) {
            final variableName = job.parameters['variable'] as String?;
            if (variableName == null) throw Exception('Variable name missing');
            parsedData = await _radprocRepository.fetchTimeseriesData(
              job.taskId,
              variableName: variableName,
              startDt: state.startDt,
              endDt: state.endDt,
            );
          } else if (job.jobType == JobType.accumulation) {
            parsedData = await _radprocRepository.fetchAccumulationData(
              job.taskId,
            );
          }
          print(
            'Received ${parsedData.length} processed data points for $pointName.',
          );
          print(parsedData);
          currentData[pointName] = parsedData; // Store fresh data
        } catch (e) {
          print(
            'Error fetching/parsing data for $pointName (${job.taskId}): $e',
          );
          currentErrors[pointName] = 'Data processing failed.'; // Set error
          currentData.remove(
            pointName,
          ); // Clear potentially stale data on error
        }
        break; // End of success case

      case JobStatusEnum.failure:
      case JobStatusEnum.revoked:
        currentLoading.remove(pointName); // Stop loading indication
        currentErrors[pointName] =
            job.errorMessage ?? 'Job failed/revoked.'; // Set error
        currentData.remove(pointName); // Clear potentially stale data
        break;
    }

    // Emit the final state reflecting the update for this point
    emit(
      state.copyWith(
        pointData: currentData,
        pointLoadingStatus: currentLoading,
        pointErrorStatus: currentErrors,
        status: _determineOverallStatus(
          state.selectedPointNames,
          currentLoading,
          currentErrors,
          currentData,
        ), // Recalculate overall status
      ),
    );
  }

  Future<void> _onExportPointDataClicked(
    ExportPointDataClicked event,
    Emitter<TimeseriesState> emit,
  ) async {
    final pointName = event.pointName;
    print('Export requested for point $pointName');
    // Check if data is actually loaded for this point without error
    if (state.pointData[pointName]?.isNotEmpty != true ||
        state.pointErrorStatus[pointName] != null) {
      add(
        ErrorOccurredInternal(
          'No successful data loaded for $pointName to export.',
        ),
      );
      return;
    }

    // Find the latest completed job for this point that matches current params
    final completedJob = await _findCompletedJobForPoint(pointName, state);

    if (completedJob != null) {
      emit(
        state.copyWith(status: TimeseriesStatus.loadingData),
      ); // Indicate activity
      try {
        if (completedJob.jobType == JobType.timeseries) {
          await _radprocRepository.downloadTimeseriesData(completedJob);
        } else if (completedJob.jobType == JobType.accumulation) {
          await _radprocRepository.downloadAccumulationData(completedJob);
        }
        emit(
          state.copyWith(
            status: _determineOverallStatus(
              state.selectedPointNames,
              state.pointLoadingStatus,
              state.pointErrorStatus,
              state.pointData,
            ),
          ),
        ); // Return to previous state
      } catch (e) {
        add(ErrorOccurredInternal('Export failed for $pointName: $e'));
      }
    } else {
      add(
        ErrorOccurredInternal(
          'Could not find completed data job for $pointName with current parameters to export.',
        ),
      );
    }
  }

  // Placeholder for finding the relevant job (needs proper implementation)
  Future<Job?> _findCompletedJobForPoint(
    String pointName,
    TimeseriesState state,
  ) async {
    // Option 1: Look in repository's persisted jobs (best)
    final jobs = await _radprocRepository.getPersistedJobs();
    // Use firstWhereOrNull from package:collection
    return jobs.firstWhereOrNull(
      (job) =>
          job.parameters['pointName'] == pointName &&
          (job.jobType == JobType.timeseries ||
              job.jobType == JobType.accumulation) &&
          job.status == JobStatusEnum.success &&
          // Add checks for matching variable/interval/dates if needed
          // This check might be too strict if params changed since job ran
          _jobParametersMatchCurrentState(job.parameters, state), // Use helper
    );
    // Option 2: If BLoC stored completed jobs (less likely)
    // return state.completedJobs[pointName];
  }

  // Helper to check if job params broadly match current state (adjust as needed)
  bool _jobParametersMatchCurrentState(
    Map<String, dynamic> jobParams,
    TimeseriesState currentState,
  ) {
    final jobVariable =
        jobParams['variable']
            as String?; // Variable stored during timeseries submission
    final jobInterval =
        jobParams['interval']
            as String?; // Interval stored during accumulation submission

    if (currentState.isAccumulationSelected) {
      // If current selection is accumulation, check interval
      return jobInterval == currentState.selectedInterval;
    } else {
      // If current selection is standard timeseries, check variable
      return jobVariable == currentState.selectedVariable;
    }
    // Could also add date range checks if necessary, but might prevent finding slightly older jobs
  }

  void _onErrorOccurredInternal(
    ErrorOccurredInternal event,
    Emitter<TimeseriesState> emit,
  ) {
    emit(
      state.copyWith(
        status: TimeseriesStatus.error,
        errorMessage: event.message,
      ),
    );
  }

  // Helper to determine overall status when idle/some data loaded
  TimeseriesStatus _determineIdleStatus(
    Set<String> selectedPoints,
    Map<String, bool> loading,
    Map<String, String?> errors,
  ) {
    if (selectedPoints.isEmpty) return TimeseriesStatus.idle;
    bool anyLoading = loading.values.any((isLoading) => isLoading);
    bool anyErrors = errors.values.any((error) => error != null);
    int loadedCount =
        selectedPoints
            .where((p) => !loading.containsKey(p) && !errors.containsKey(p))
            .length; // Simplistic check

    if (anyLoading) return TimeseriesStatus.loadingData; // Or partialDataLoad?
    if (anyErrors && loadedCount < selectedPoints.length)
      return TimeseriesStatus
          .partialDataLoad; // Some errors, maybe some success
    if (anyErrors && loadedCount == 0)
      return TimeseriesStatus.dataLoadError; // All selected have errors
    if (!anyLoading && !anyErrors && loadedCount == selectedPoints.length)
      return TimeseriesStatus.allDataLoaded; // All loaded successfully
    return TimeseriesStatus.idle; // Default idle state
  }

  // Refined helper to determine overall status
  TimeseriesStatus _determineOverallStatus(
    Set<String> selectedPoints,
    Map<String, bool> loading,
    Map<String, String?> errors, [
    Map<String, List<TimeseriesDataPoint>>? data, // Optional data map
  ]) {
    if (selectedPoints.isEmpty) return TimeseriesStatus.idle;

    bool anySelectedLoading = selectedPoints.any((p) => loading[p] == true);
    bool anySelectedWithError = selectedPoints.any((p) => errors[p] != null);
    // Check if ALL selected points have data loaded without error
    bool allSelectedLoaded = selectedPoints.every(
      (p) =>
          (loading[p] != true) &&
          (errors[p] == null) &&
          (data?[p]?.isNotEmpty ?? false),
    );
    // Check if ANY selected point has data loaded without error
    bool anySelectedLoaded = selectedPoints.any(
      (p) =>
          (loading[p] != true) &&
          (errors[p] == null) &&
          (data?[p]?.isNotEmpty ?? false),
    );

    if (anySelectedLoading) return TimeseriesStatus.loadingData;
    if (allSelectedLoaded) return TimeseriesStatus.allDataLoaded;
    if (anySelectedLoaded || anySelectedWithError)
      return TimeseriesStatus.partialDataLoad; // Mix of loaded/error/pending
    if (selectedPoints.every((p) => errors[p] != null))
      return TimeseriesStatus.dataLoadError; // All failed

    return TimeseriesStatus
        .idle; // Default if no points selected or state is indeterminate
  }

  @override
  Future<void> close() {
    _jobUpdateSubscription?.cancel();
    return super.close();
  }
}
