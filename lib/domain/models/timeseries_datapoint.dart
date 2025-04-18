// lib/domain/models/timeseries_datapoint.dart
import 'package:equatable/equatable.dart';

class TimeseriesDataPoint extends Equatable {
  const TimeseriesDataPoint({required this.timestamp, required this.value});

  final DateTime
  timestamp; // Assume API returns timestamps parsable to DateTime
  final double value;

  factory TimeseriesDataPoint.fromJson(
    Map<String, dynamic> json,
    String variableName,
  ) {
    try {
      // Check if the expected variable key exists
      if (!json.containsKey(variableName)) {
        throw FormatException(
          "JSON object does not contain key '$variableName'",
        );
      }
      // Check if timestamp key exists
      if (!json.containsKey('timestamp')) {
        throw FormatException("JSON object does not contain key 'timestamp'");
      }

      return TimeseriesDataPoint(
        timestamp: DateTime.parse(
          json['timestamp'] as String? ?? '',
        ), // Handle potential null/parse error
        value:
            (json[variableName] as num? ?? double.nan)
                .toDouble(), // Use variableName key, handle null/non-num
      );
    } catch (e) {
      throw FormatException(
        'Invalid JSON for TimeseriesDataPoint ($variableName): $e',
      );
    }
  }

  @override
  List<Object?> get props => [timestamp, value];
}
