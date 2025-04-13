import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/plot_update.dart'; // Import domain model
import 'dart:typed_data'; // For plot data in state

abstract class RealtimePlotEvent extends Equatable {
  const RealtimePlotEvent();
  @override
  List<Object?> get props => [];
}

/// Event to trigger initial loading or explicit refresh.
class LoadRealtimePlot extends RealtimePlotEvent {
   // Optional: could pass variable/elevation if needed for explicit load
}

/// Event when the selected variable changes.
class VariableSelected extends RealtimePlotEvent {
  const VariableSelected(this.variable);
  final String variable;
  @override List<Object?> get props => [variable];
}

/// Event when the selected elevation changes.
class ElevationSelected extends RealtimePlotEvent {
  const ElevationSelected(this.elevation);
  final double elevation;
  @override List<Object?> get props => [elevation];
}

/// Internal event when an SSE update is received.
class SsePlotUpdateReceived extends RealtimePlotEvent {
  const SsePlotUpdateReceived(this.update);
  final PlotUpdate update;
  @override List<Object?> get props => [update];
}

/// Event when the SSE stream emits an error
class SseErrorOccurred extends RealtimePlotEvent {
    const SseErrorOccurred(this.error);
    final Object error;
    @override List<Object?> get props => [error];
}