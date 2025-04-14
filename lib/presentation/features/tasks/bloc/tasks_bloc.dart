import 'dart:async';
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
        super(const TasksState()) { // Initial state

    on<LoadTasks>(_onLoadTasks);
    on<DeleteTask>(_onDeleteTask);
    on<ClearTerminatedTasks>(_onClearTerminatedTasks);
    on<JobUpdatedInternal>(_onJobUpdatedInternal);

    // Subscribe to the central job update stream from the repository
    _subscribeToJobUpdates();
  }

  void _subscribeToJobUpdates() {
     _jobUpdateSubscription?.cancel(); // Cancel previous if any
     _jobUpdateSubscription = _radprocRepository.jobUpdates.listen(
        (job) {
           print('TasksBloc received job update: ${job.taskId} Status: ${job.status.name}');
           add(JobUpdatedInternal(job)); // Add internal event
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
      // Jobs loaded from storage are already sorted by date in repo helper
      emit(state.copyWith(status: TasksStatus.success, tasks: tasks));
    } catch (e) {
      emit(state.copyWith(status: TasksStatus.error, errorMessage: 'Failed to load tasks: $e'));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TasksState> emit) async {
     // Optimistic UI update: remove immediately
     final optimisticList = List<Job>.from(state.tasks)..removeWhere((j) => j.taskId == event.taskId);
     emit(state.copyWith(tasks: optimisticList));
     try {
        await _radprocRepository.deleteJobRecord(event.taskId);
        // No need to reload state if optimistic update is sufficient
     } catch (e) {
        emit(state.copyWith(status: TasksStatus.error, errorMessage: 'Failed to delete task ${event.taskId}: $e'));
        // Optionally reload tasks to revert optimistic update on error
        add(LoadTasks());
     }
  }

  Future<void> _onClearTerminatedTasks(ClearTerminatedTasks event, Emitter<TasksState> emit) async {
      final List<Job> toKeep = [];
      final List<Future<void>> deleteFutures = [];
      for (final job in state.tasks) {
          if (job.status == JobStatusEnum.pending || job.status == JobStatusEnum.running || job.status == JobStatusEnum.unknown) {
             toKeep.add(job);
          } else {
             // Add deletion future without waiting here
             deleteFutures.add(_radprocRepository.deleteJobRecord(job.taskId));
          }
      }
      // Optimistic UI update
      emit(state.copyWith(tasks: toKeep));
      // Wait for all deletions to complete in background
      try {
         await Future.wait(deleteFutures);
         print('Cleared ${deleteFutures.length} terminated tasks.');
      } catch (e) {
          print('Error during bulk task deletion: $e');
          // Optionally reload state on error
          add(LoadTasks());
      }
  }


  void _onJobUpdatedInternal(JobUpdatedInternal event, Emitter<TasksState> emit) {
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
     emit(state.copyWith(tasks: currentTasks, status: TasksStatus.success)); // Ensure status is success
  }

  @override
  Future<void> close() {
    print('Closing TasksBloc and cancelling job update subscription.');
    _jobUpdateSubscription?.cancel();
    return super.close();
  }
}