import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/job.dart';

enum TasksStatus { initial, loading, success, error }

class TasksState extends Equatable {
  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.processingTaskId, // ID of task being downloaded/retried/cancelled
    this.errorMessage,
  });

  final TasksStatus status;
  final List<Job> tasks;
  final String? processingTaskId; // ID of task with ongoing action
  final String? errorMessage;

  TasksState copyWith({
    TasksStatus? status,
    List<Job>? tasks,
    String? processingTaskId,
    bool clearProcessingTask = false, // Helper to clear the ID
    String? errorMessage,
    bool clearError = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      // Clear ID if requested, otherwise update or keep existing
      processingTaskId: clearProcessingTask ? null : processingTaskId ?? this.processingTaskId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tasks, processingTaskId, errorMessage];
}