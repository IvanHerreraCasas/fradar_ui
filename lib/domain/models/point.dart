// lib/domain/models/point.dart
import 'package:equatable/equatable.dart';

class Point extends Equatable {
  const Point({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.description,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double elevation; // The default elevation associated with the point
  final String description;

  factory Point.fromJson(Map<String, dynamic> json) {
     // Add type checking and default values or throw error for robustness
     try {
        return Point(
          name: json['point_name'] as String? ?? 'Unknown Name',
          latitude: (json['latitude'] as num? ?? 0.0).toDouble(),
          longitude: (json['longitude'] as num? ?? 0.0).toDouble(),
          elevation: (json['target_elevation'] as num? ?? 0.0).toDouble(),
          description: json['description'] as String? ?? '',
        );
     } catch (e) {
         throw FormatException('Invalid JSON format for Point: $e');
     }
  }

  @override
  List<Object?> get props => [
        name,
        latitude,
        longitude,
        elevation,
        description,
      ];
}