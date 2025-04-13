// lib/domain/models/api_status.dart
import 'package:equatable/equatable.dart';

class ApiStatus extends Equatable {
  const ApiStatus({
    required this.status,
    required this.message,
  });

  final String status;
  final String message;

  /// Factory constructor to create ApiStatus from a JSON map (Map<String, dynamic>)
  /// returned by the RadprocApi.
  factory ApiStatus.fromJson(Map<String, dynamic> json) {
    // Perform basic validation
    if (json case {'status': String status, 'message': String message}) {
       return ApiStatus(
         status: status,
         message: message,
       );
    } else {
       // Handle cases where the JSON structure is unexpected
       throw const FormatException('Invalid JSON format for ApiStatus');
       // Alternatively, return a default/error status:
       // return const ApiStatus(status: 'error', message: 'Invalid format received');
    }
  }

  /// Convenience method to create a default/initial status
  factory ApiStatus.initial() => const ApiStatus(status: 'unknown', message: '');


  @override
  List<Object?> get props => [status, message]; // Used by equatable for comparison
}