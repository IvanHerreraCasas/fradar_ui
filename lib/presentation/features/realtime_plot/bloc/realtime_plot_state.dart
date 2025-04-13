import 'package:equatable/equatable.dart';
import 'dart:typed_data';

enum RealtimePlotStatus { initial, loading, success, error }

class RealtimePlotState extends Equatable {
  const RealtimePlotState({
    this.status = RealtimePlotStatus.initial,
    this.selectedVariable = 'RATE', // Default variable
    this.selectedElevation = 2.5,  // Default elevation
    this.plotImageData,
    this.errorMessage,
  });

  final RealtimePlotStatus status;
  final String selectedVariable;
  final double selectedElevation;
  final Uint8List? plotImageData;
  final String? errorMessage;

  RealtimePlotState copyWith({
    RealtimePlotStatus? status,
    String? selectedVariable,
    double? selectedElevation,
    Uint8List? plotImageData,
    String? errorMessage,
    bool clearPlotData = false, // Helper to clear image on error/load
    bool clearError = false,
    String? sseStatusMessage,
  }) {
    return RealtimePlotState(
      status: status ?? this.status,
      selectedVariable: selectedVariable ?? this.selectedVariable,
      selectedElevation: selectedElevation ?? this.selectedElevation,
      plotImageData: clearPlotData ? null : plotImageData ?? this.plotImageData,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedVariable,
        selectedElevation,
        plotImageData,
        errorMessage,
      ];
}