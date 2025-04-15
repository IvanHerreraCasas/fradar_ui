// lib/data/sources/local_job_storage_api.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fradar_ui/data/api/job_storage_api.dart';
import 'package:fradar_ui/domain/models/job.dart';

class LocalJobStorageApi implements JobStorageApi {
  LocalJobStorageApi({required SharedPreferences plugin}) : _plugin = plugin;

  final SharedPreferences _plugin;
  static const String _kJobListKey = 'job_list_storage_key';

  @override
  Future<List<Job>> loadJobs() async {
    final List<String>? jobListJson = _plugin.getStringList(_kJobListKey);
    if (jobListJson == null) {
      return []; // No jobs saved yet
    }
    try {
      return jobListJson
          .map((jsonString) => Job.fromJson(jsonDecode(jsonString)))
          .toList();
    } catch (e) {
      print('Error loading jobs from storage: $e');
      // If loading fails, maybe clear corrupted data? Or return empty.
      await clearAllJobs(); // Clear potentially corrupted data
      return [];
    }
  }

  @override
  Future<void> saveJob(Job job) async {
    final currentJobs = await loadJobs();
    // Find existing job by ID to update or add new
    final index = currentJobs.indexWhere((j) => j.taskId == job.taskId);
    if (index >= 0) {
      currentJobs[index] = job; // Update existing
    } else {
      currentJobs.add(job); // Add new
       // Optional: Limit the number of stored jobs?
       // e.g., currentJobs.sort(...); if (currentJobs.length > 50) currentJobs.removeRange(50, currentJobs.length);
    }
    await _saveJobList(currentJobs);
  }

  @override
  Future<void> deleteJob(String taskId) async {
    final currentJobs = await loadJobs();
    currentJobs.removeWhere((job) => job.taskId == taskId);
    await _saveJobList(currentJobs);
  }

  @override
  Future<void> deleteJobs(List<String> taskIds) async {
    final currentJobs = await loadJobs();
    currentJobs.removeWhere((job) => taskIds.contains(job.taskId));
    await _saveJobList(currentJobs);
  }

   @override
  Future<void> clearAllJobs() async {
     await _plugin.remove(_kJobListKey);
  }

  // Helper to save the list back to shared_preferences
  Future<void> _saveJobList(List<Job> jobs) async {
     // Sort jobs? e.g., by submission date descending
     jobs.sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
     final List<String> jobListJson = jobs
         .map((job) => jsonEncode(job.toJson())) // Convert each job to JSON string
         .toList();
     await _plugin.setStringList(_kJobListKey, jobListJson);
  }
}