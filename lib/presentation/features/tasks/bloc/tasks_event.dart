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

/// User requested to download the result of a completed job.
class DownloadJobResultRequested extends TasksEvent {
  const DownloadJobResultRequested(this.job);
  final Job job;
  @override List<Object> get props => [job];
}

/// Internal: A relevant background job was updated via repo stream.
class JobUpdateReceived extends TasksEvent { // Renamed this previously
   const JobUpdateReceived(this.job);
   final Job job;
   @override List<Object> get props => [job];
}

/// Internal: A general error occurred during task processing.
class ErrorOccurredInternal extends TasksEvent { // Renamed this previously
   const ErrorOccurredInternal(this.message);
   final String message;
   @override List<Object> get props => [message];
}
