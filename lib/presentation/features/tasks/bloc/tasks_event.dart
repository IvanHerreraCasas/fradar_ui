import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/job.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();
  @override List<Object> get props => [];
}

/// Load initial tasks from storage.
class LoadTasks extends TasksEvent {}

/// Delete a specific task record.
class DeleteTask extends TasksEvent {
  const DeleteTask(this.taskId);
  final String taskId;
  @override List<Object> get props => [taskId];
}

 /// Clear all completed/failed task records.
class ClearTerminatedTasks extends TasksEvent {}

/// Internal event when the repository broadcasts a job update.
class JobUpdatedInternal extends TasksEvent {
   const JobUpdatedInternal(this.job);
   final Job job;
   @override List<Object> get props => [job];
}