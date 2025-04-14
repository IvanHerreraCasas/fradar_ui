// lib/data/api/job_storage_api.dart
import 'package:fradar_ui/domain/models/job.dart';

abstract class JobStorageApi {
  /// Saves or updates a job's persisted details.
  Future<void> saveJob(Job job);

  /// Retrieves all persisted jobs.
  Future<List<Job>> loadJobs();

  /// Deletes a specific job record by its task ID.
  Future<void> deleteJob(String taskId);

  /// Clears all persisted job records.
  Future<void> clearAllJobs();
}