// lib/domain/models/job.dart
import 'package:equatable/equatable.dart';
import 'dart:typed_data';

enum JobType { animation, timeseries, accumulation, unknown }
enum JobStatusEnum { pending, running, success, failure, revoked, unknown }

class Job extends Equatable {
  const Job({
    required this.taskId,
    this.jobType = JobType.unknown,
    this.parameters = const {}, // Params used to start the job
    this.status = JobStatusEnum.unknown,
    this.statusDetails = '', // Raw status string if needed
    this.submittedAt,
    this.lastCheckedAt,
    this.resultData, // Can be Uint8List for animation, String for CSV path, etc.
    this.errorMessage,
  });

  final String taskId;
  final JobType jobType;
  final Map<String, dynamic> parameters;
  final JobStatusEnum status;
  final String statusDetails;
  final DateTime? submittedAt;
  final DateTime? lastCheckedAt;
  final dynamic resultData; // Use specific types or keep dynamic
  final String? errorMessage;

  // Factory to create an initial Job when submitted
  factory Job.submitted({
     required String taskId,
     required JobType jobType,
     required Map<String, dynamic> parameters,
  }) {
     return Job(
        taskId: taskId,
        jobType: jobType,
        parameters: parameters,
        status: JobStatusEnum.pending, // Initial status
        submittedAt: DateTime.now(),
     );
  }


  // Factory or method to update Job from API status response
  Job updateFromApiStatus(Map<String, dynamic> apiStatusJson) {
    final details = apiStatusJson['status_details'] as Map<String, dynamic>? ?? {};
    final statusStr = details['status'] as String? ?? 'UNKNOWN';
    final errorInfo = details['error_info'] as String?;
    // final resultInfo = details['result']; // Might contain filename or data hints

    JobStatusEnum currentStatus;
    switch (statusStr.toUpperCase()) {
      case 'PENDING':
      case 'RUNNING': // Treat RUNNING from backend as PENDING/active for polling
        currentStatus = JobStatusEnum.pending; // Or .running if we distinguish
        break;
      case 'SUCCESS':
        currentStatus = JobStatusEnum.success;
        break;
      case 'FAILURE':
        currentStatus = JobStatusEnum.failure;
        break;
      case 'REVOKED':
         currentStatus = JobStatusEnum.revoked;
         break;
      default:
        currentStatus = JobStatusEnum.unknown;
    }

    return copyWith(
      status: currentStatus,
      statusDetails: statusStr, // Store raw status string too
      errorMessage: errorInfo,
      // resultData: resultInfo, // Update result hint if needed
      lastCheckedAt: DateTime.now(),
    );
  }

  Job copyWith({
    // String? taskId, // Usually taskId doesn't change
    JobType? jobType,
    Map<String, dynamic>? parameters,
    JobStatusEnum? status,
    String? statusDetails,
    DateTime? submittedAt,
    DateTime? lastCheckedAt,
    dynamic resultData, // Allow updating result
    String? errorMessage,
    bool clearResult = false, // Helper
    bool clearError = false,
  }) {
    return Job(
      taskId: taskId,
      jobType: jobType ?? this.jobType,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      statusDetails: statusDetails ?? this.statusDetails,
      submittedAt: submittedAt ?? this.submittedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      resultData: clearResult ? null : resultData ?? this.resultData,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        taskId,
        jobType,
        parameters,
        status,
        statusDetails,
        submittedAt,
        lastCheckedAt,
        resultData, // Note: Equatable might struggle with dynamic/Uint8List comparison
        errorMessage,
      ];
}