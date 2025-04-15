import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final RadprocRepository _radprocRepository;
  StreamSubscription<Job>? _jobUpdateSubscription;

  TasksBloc({required RadprocRepository radprocRepository})
    : _radprocRepository = radprocRepository,
      super(const TasksState()) {
    // Initial state

    on<LoadTasks>(_onLoadTasks);
    on<DeleteTask>(_onDeleteTask);
    on<ClearTerminatedTasks>(_onClearTerminatedTasks);
    on<DownloadJobResultRequested>(
      _onDownloadJobResultRequested,
    ); // Register new handler
    on<JobUpdateReceived>(_onJobUpdateReceived); // Renamed handler
    on<ErrorOccurredInternal>(_onErrorOccurredInternal); // Renamed handler

    // Subscribe to the central job update stream from the repository
    _subscribeToJobUpdates();
  }

  void _subscribeToJobUpdates() {
    _jobUpdateSubscription?.cancel(); // Cancel previous if any
    _jobUpdateSubscription = _radprocRepository.jobUpdates.listen(
      (job) {
        print(
          'TasksBloc received job update: ${job.taskId} Status: ${job.status.name}',
        );
        add(JobUpdateReceived(job)); // Add internal event
      },
      onError: (error) {
        print('TasksBloc: Error on job update stream: $error');
        // Optionally update state with stream error message
      },
    );
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TasksState> emit) async {
    emit(state.copyWith(status: TasksStatus.loading, clearError: true));
    try {
      final tasks = await _radprocRepository.getPersistedJobs();
      emit(state.copyWith(status: TasksStatus.success, tasks: tasks));

      // ***** START MONITORING PERSISTED PENDING JOBS *****
      for (final job in tasks) {
        // Check if job is in a state that requires monitoring
        if (job.status == JobStatusEnum.pending ||
            job.status ==
                JobStatusEnum.running || // If backend distinguishes running
            job.status == JobStatusEnum.unknown) // Monitor unknown just in case
        {
          print(
            'TasksBloc: Restarting monitoring for pending/unknown job ${job.taskId}',
          );
          // Call monitorJob to kick off polling. Updates will come via the
          // central jobUpdates stream which this bloc is already listening to.
          _radprocRepository.monitorJob(job);
        }
      }
      // ****************************************************
    } catch (e) {
      emit(
        state.copyWith(
          status: TasksStatus.error,
          errorMessage: 'Failed to load tasks: $e',
        ),
      );
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TasksState> emit) async {
    // Optimistic UI update: remove immediately
    final optimisticList = List<Job>.from(state.tasks)
      ..removeWhere((j) => j.taskId == event.taskId);
    emit(state.copyWith(tasks: optimisticList));
    try {
      await _radprocRepository.deleteJobRecord(event.taskId);
      // No need to reload state if optimistic update is sufficient
    } catch (e) {
      emit(
        state.copyWith(
          status: TasksStatus.error,
          errorMessage: 'Failed to delete task ${event.taskId}: $e',
        ),
      );
      // Optionally reload tasks to revert optimistic update on error
      add(LoadTasks());
    }
  }

  Future<void> _onClearTerminatedTasks(
    ClearTerminatedTasks event,
    Emitter<TasksState> emit,
  ) async {
    final List<Job> toKeep = [];
    final List<String> toDelete = [];
    for (final job in state.tasks) {
      if (job.status == JobStatusEnum.pending ||
          job.status == JobStatusEnum.running ||
          job.status == JobStatusEnum.unknown) {
        toKeep.add(job);
      } else {
        // Add deletion future without waiting here
        toDelete.add(job.taskId);
      }
    }
    // Wait for all deletions to complete in background
    try {
      await _radprocRepository.deleteJobRecords(toDelete);
      emit(state.copyWith(tasks: toKeep));
    } catch (e) {
      print('Error during bulk task deletion: $e');
      // Optionally reload state on error
      add(LoadTasks());
    }
  }

  void _onJobUpdateReceived(JobUpdateReceived event, Emitter<TasksState> emit) {
    // Update the specific job in the list or add if new
    final currentTasks = List<Job>.from(state.tasks);
    final index = currentTasks.indexWhere((j) => j.taskId == event.job.taskId);
    if (index >= 0) {
      currentTasks[index] = event.job; // Update existing
    } else {
      currentTasks.insert(0, event.job); // Add new job to the top
    }
    // Re-sort? The repo sorts on save, maybe rely on LoadTasks for order?
    // For now, just update/add.
    emit(
      state.copyWith(tasks: currentTasks, status: TasksStatus.success),
    ); // Ensure status is success
  }

  // --- Download Handler ---
  Future<void> _onDownloadJobResultRequested(
    DownloadJobResultRequested event,
    Emitter<TasksState> emit,
  ) async {
    final job = event.job;

    // Prevent download if job isn't successful or already processing
    if (job.status != JobStatusEnum.success || state.processingTaskId != null) {
      print(
        'Download requested for non-successful or already processing job: ${job.taskId}',
      );
      return;
    }

    // Indicate processing started for this task
    emit(state.copyWith(processingTaskId: job.taskId, clearError: true));

    try {
      // Call appropriate repository download method based on type
      switch (job.jobType) {
        case JobType.animation:
          await _radprocRepository.downloadAnimationResult(job);
          break;
        case JobType.timeseries:
          await _radprocRepository.downloadTimeseriesData(job);
          break;
        case JobType.accumulation:
          await _radprocRepository.downloadAccumulationData(job);
          break;
        case JobType.unknown:
          throw Exception('Cannot download result for unknown job type.');
      }
      // If download call completes without error (user might still cancel dialog)
      print('Repository download method completed for ${job.taskId}');
      // Optionally emit a success state or message here if needed
      // For now, just clear processing state
    } catch (e) {
      print('Download failed in Bloc for ${job.taskId}: $e');
      // Dispatch internal error to potentially show snackbar via listener
      add(
        ErrorOccurredInternal(
          'Download failed for ${job.taskId.substring(0, 8)}: $e',
        ),
      );
    } finally {
      // Always clear processing state, regardless of success/failure/cancel
      emit(state.copyWith(clearProcessingTask: true));
    }
  }

  void _onErrorOccurredInternal(
    ErrorOccurredInternal event,
    Emitter<TasksState> emit,
  ) {
    // Set general error status and message, clear processing state
    emit(
      state.copyWith(
        status: TasksStatus.error,
        errorMessage: event.message,
        clearProcessingTask: true, // Clear any task-specific loading indicator
      ),
    );
  }

  @override
  Future<void> close() {
    print('Closing TasksBloc and cancelling job update subscription.');
    _jobUpdateSubscription?.cancel();
    return super.close();
  }
}
