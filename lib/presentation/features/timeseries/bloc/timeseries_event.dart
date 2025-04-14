// lib/presentation/features/timeseries/bloc/timeseries_event.dart
import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/job.dart';

abstract class TimeseriesEvent extends Equatable {
  const TimeseriesEvent();
  @override List<Object?> get props => [];
}

/// Load the list of available points.
class LoadPoints extends TimeseriesEvent {}

/// Toggle selection state for a specific point.
class PointSelectionChanged extends TimeseriesEvent {
  const PointSelectionChanged(this.pointName, this.isSelected);
  final String pointName;
  final bool isSelected;
  @override List<Object?> get props => [pointName, isSelected];
}

/// User selected a different variable (or accumulation).
class VariableSelected extends TimeseriesEvent {
  const VariableSelected(this.variable);
  final String variable; // Includes 'PRECIPITATION'
  @override List<Object?> get props => [variable];
}

/// User selected an interval for accumulation.
class IntervalSelected extends TimeseriesEvent {
  const IntervalSelected(this.interval);
  final String interval;
  @override List<Object?> get props => [interval];
}

/// User changed the date/time range for graph display.
class DateTimeRangeChanged extends TimeseriesEvent {
  const DateTimeRangeChanged({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
  @override List<Object?> get props => [start, end];
}

/// User toggled between Map and Graph display modes.
class DisplayModeToggled extends TimeseriesEvent {}

/// Trigger fetching data for all currently selected points (in Graph mode).
class FetchDataForSelectedPoints extends TimeseriesEvent {}

/// Trigger export for a specific point's loaded data.
class ExportPointDataClicked extends TimeseriesEvent {
   const ExportPointDataClicked(this.pointName);
   final String pointName;
   @override List<Object?> get props => [pointName];
}

// --- Internal Events ---

/// Internal: A relevant background job (Timeseries/Accumulation) was updated.
class JobUpdateReceived extends TimeseriesEvent {
   const JobUpdateReceived(this.job);
   final Job job;
   @override List<Object?> get props => [job];
}

/// Internal: A general error occurred.
class ErrorOccurredInternal extends TimeseriesEvent {
   const ErrorOccurredInternal(this.message);
   final String message;
   @override List<Object?> get props => [message];
}