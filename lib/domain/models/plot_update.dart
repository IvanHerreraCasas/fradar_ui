// lib/domain/models/plot_update.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';

class PlotUpdate extends Equatable {
  const PlotUpdate({
    required this.updatedImageFilename,
    this.variable, // Parsed variable
    this.elevation, // Parsed elevation
  });

  final String updatedImageFilename; // e.g., realtime_RATE_005.png
  final String? variable;
  final double? elevation;

  /// Parses the filename to extract variable and elevation.
  /// Example format: realtime_{VARIABLE}_{ELEVATION_WITH_3_DECIMALS}.png
  static PlotUpdate fromFilename(String filename) {
     String? parsedVariable;
     double? parsedElevation;
     final parts = filename.replaceFirst('realtime_', '').replaceFirst('.png', '').split('_');

     if (parts.length >= 2) {
        parsedVariable = parts[0];
        // Attempt to parse elevation (e.g., "005" -> 0.5, "100" -> 10.0)
        if (double.tryParse(parts[1]) != null) {
           parsedElevation = double.parse(parts[1]) / 100.0; // Assuming format like 005 -> 0.5
        }
        // Add more robust parsing if elevation format varies
     }

     return PlotUpdate(
       updatedImageFilename: filename,
       variable: parsedVariable,
       elevation: parsedElevation,
     );
  }

  /// Factory to parse the raw JSON string data from the SSE event.
  factory PlotUpdate.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final filename = json['updated_image'] as String?;
      if (filename != null) {
         return PlotUpdate.fromFilename(filename);
      }
    } catch (e) {
      print('Error parsing PlotUpdate JSON string: $e');
    }
    // Return a default/invalid state if parsing fails
    return const PlotUpdate(updatedImageFilename: '', variable: null, elevation: null);
  }


  @override
  List<Object?> get props => [updatedImageFilename, variable, elevation];
}