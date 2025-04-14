import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/job.dart';

enum TasksStatus { initial, loading, success, error }

class TasksState extends Equatable {
  const TasksState({
    this.status = TasksStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  final TasksStatus status;
  final List<Job> tasks; // Displayed list, potentially sorted
  final String? errorMessage;

  TasksState copyWith({
    TasksStatus? status,
    List<Job>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tasks, errorMessage];
}