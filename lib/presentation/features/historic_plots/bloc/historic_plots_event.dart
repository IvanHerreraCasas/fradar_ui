// lib/presentation/features/historic_plots/bloc/historic_plots_event.dart
import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/job.dart'; // Import Job model
import 'dart:typed_data'; // For potential image data if needed directly in event

abstract class HistoricPlotsEvent extends Equatable {
  const HistoricPlotsEvent();
  @override
  List<Object?> get props => [];
}

/// Triggered to load initial state or reset.
class LoadInitialHistoricData extends HistoricPlotsEvent {}

/// Triggered when any parameter controlling the data query changes.
class ParametersChanged extends HistoricPlotsEvent {
  const ParametersChanged({
    this.variable,
    this.elevation,
    this.startDt,
    this.endDt,
    this.region, // List<double>? [minLon, maxLon, minLat, maxLat]
  });

  final String? variable;
  final double? elevation;
  final DateTime? startDt;
  final DateTime? endDt;
  final List<double>? region;

  @override
  List<Object?> get props => [variable, elevation, startDt, endDt, region];
}

/// Explicitly trigger fetching frame list (e.g., after params change for RATE).
class FetchFrames extends HistoricPlotsEvent {}

/// Triggered when user clicks "Generate Animation" or "Export Animation".
class GenerateOrExportAnimation extends HistoricPlotsEvent {}

/// User manually selects a specific frame index (e.g., via slider).
class FrameIndexSelected extends HistoricPlotsEvent {
  const FrameIndexSelected(this.index);
  final int index;
  @override List<Object?> get props => [index];
}

/// User presses the Play/Pause button for the image carousel animation.
class PlaybackToggled extends HistoricPlotsEvent {}

/// User clicks the button to download the successfully generated animation.
class DownloadAnimationClicked extends HistoricPlotsEvent {}

// --- Internal Events ---

/// Internal event when job status polling yields an update.
class JobStatusUpdated extends HistoricPlotsEvent {
  const JobStatusUpdated(this.job);
  final Job job;
  @override List<Object?> get props => [job];
}

/// Internal event for automatic frame advance during playback.
class PlaybackTimerTick extends HistoricPlotsEvent {}

class VideoFileReadyToClean extends HistoricPlotsEvent {
   const VideoFileReadyToClean(this.filePath);
   final String filePath;
   @override List<Object?> get props => [filePath];
}

/// Internal event to signal a generic error to update state.
class ErrorOccurred extends HistoricPlotsEvent {
  const ErrorOccurred(this.message);
  final String message;
  @override List<Object?> get props => [message];
}