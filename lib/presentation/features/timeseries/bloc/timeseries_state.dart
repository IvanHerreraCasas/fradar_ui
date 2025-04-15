// lib/presentation/features/timeseries/bloc/timeseries_state.dart
import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/point.dart';
import 'package:fradar_ui/domain/models/timeseries_datapoint.dart'; // Import if parsing JSON

enum TimeseriesStatus {
  initial,
  loadingPoints, // Loading the list of available points
  pointsLoadError,
  idle, // Points loaded, ready for selection/action
  loadingData, // Submitting job or fetching data after job success
  partialDataLoad, // Some points loaded, others pending/error
  allDataLoaded, // Data loaded successfully for all selected points
  dataLoadError, // Error loading data for one or more points
  error,
}

// Special variable name to represent accumulation
const String accumulationVariable = 'PRECIPITATION';
// Default accumulation interval
const String defaultInterval = '1H';

class TimeseriesState extends Equatable {
  TimeseriesState({
    this.status = TimeseriesStatus.initial,
    this.availablePoints = const [],
    this.selectedPointNames = const {}, // Use a Set for efficient lookup
    this.selectedVariable = 'RATE', // Default variable
    this.selectedInterval = defaultInterval,
    DateTime? startDt,
    DateTime? endDt,
    this.isMapMode = true, // Start in Map mode by default
    this.pointData = const {}, // Map point name to its timeseries data list
    this.pointLoadingStatus =
        const {}, // Map point name to bool (true if loading)
    this.pointErrorStatus = const {}, // Map point name to error message
    this.errorMessage, // General error (e.g., loading points)
  }) : startDt =
           startDt ??
           DateTime.now().subtract(
             const Duration(hours: 6),
           ), // Default: last 6 hours
       endDt = endDt ?? DateTime.now();

  final TimeseriesStatus status;
  // Selections
  final List<Point> availablePoints;
  final Set<String> selectedPointNames;
  final String selectedVariable;
  final String
  selectedInterval; // Only used when variable is accumulationVariable
  final DateTime startDt; // Range for graph display / data fetch
  final DateTime endDt;
  final bool isMapMode; // True for Map view, false for Graph view
  // Data & Status per Point (for Graph mode)
  final Map<String, List<TimeseriesDataPoint>> pointData;
  final Map<String, bool> pointLoadingStatus; // pointName -> isLoading
  final Map<String, String?>
  pointErrorStatus; // pointName -> errorMessage / null
  // General Error
  final String? errorMessage;

  // Convenience Getters
  bool get isAccumulationSelected => selectedVariable == accumulationVariable;

  // Default intervals for accumulation
  static const List<String> defaultIntervals = [
    '10min',
    '15min',
    '30min',
    '1H',
    '3H',
    '6H',
  ];

  TimeseriesState copyWith({
    TimeseriesStatus? status,
    List<Point>? availablePoints,
    Set<String>? selectedPointNames,
    String? selectedVariable,
    String? selectedInterval,
    DateTime? startDt,
    DateTime? endDt,
    bool? isMapMode,
    Map<String, List<TimeseriesDataPoint>>? pointData,
    Map<String, bool>? pointLoadingStatus,
    Map<String, String?>? pointErrorStatus,
    String? errorMessage,
    bool clearError = false,
    bool clearPointData = false,
    bool clearPointStatus = false,
  }) {
    return TimeseriesState(
      status: status ?? this.status,
      availablePoints: availablePoints ?? this.availablePoints,
      selectedPointNames: selectedPointNames ?? this.selectedPointNames,
      selectedVariable: selectedVariable ?? this.selectedVariable,
      selectedInterval: selectedInterval ?? this.selectedInterval,
      startDt: startDt ?? this.startDt,
      endDt: endDt ?? this.endDt,
      isMapMode: isMapMode ?? this.isMapMode,
      pointData: clearPointData ? {} : pointData ?? this.pointData,
      pointLoadingStatus:
          clearPointStatus ? {} : pointLoadingStatus ?? this.pointLoadingStatus,
      pointErrorStatus:
          clearPointStatus ? {} : pointErrorStatus ?? this.pointErrorStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    availablePoints,
    selectedPointNames,
    selectedVariable,
    selectedInterval,
    startDt,
    endDt,
    isMapMode,
    pointData,
    pointLoadingStatus,
    pointErrorStatus,
    errorMessage,
  ];
}
