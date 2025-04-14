// lib/presentation/features/historic_plots/bloc/historic_plots_state.dart
import 'package:equatable/equatable.dart';
import 'package:fradar_ui/domain/models/plot_frame.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:video_player/video_player.dart'; // Import video player
import 'dart:typed_data';

enum HistoricPlotsStatus {
  initial, // Ready for parameter input
  parametersChanged, // Parameters updated, ready to fetch/generate
  loadingFrames,
  framesLoadSuccess, // Frames loaded, showing carousel
  framesLoadError,
  submittingJob,
  monitoringJob, // Animation job submitted and being polled
  animationReadyToDownload, // Animation (RATE export) job succeeded
  loadingVideo, // Fetching video bytes after non-RATE job succeeded
  initializingVideo, // Video bytes fetched, controller initializing
  videoReady, // Video controller initialized, ready to play
  playbackActive, // Carousel auto-playback is active
  error, // General error state
}

class HistoricPlotsState extends Equatable {
  HistoricPlotsState({
    this.status = HistoricPlotsStatus.initial,
    this.variable = 'RATE', // Default variable
    this.elevation = 2.5, // Default elevation
    DateTime? startDt, // Use factory for defaults
    DateTime? endDt,
    this.region,
    this.frames = const [],
    this.currentFrameIndex = -1, // -1 indicates no frame selected/loaded
    this.currentFrameImage,
    this.isPlaying = false,
    this.fps = 5,
    this.activeJob,
    this.videoPlayerController,
    this.isVideoControllerInitialized = false,
    this.tempVideoFilePath, // Store path for cleanup
    this.errorMessage,
  })  : startDt = startDt ?? DateTime.now().subtract(Duration(hours: 1)),
        endDt = endDt ?? DateTime.now();

  final HistoricPlotsStatus status;
  // Parameters
  final String variable;
  final double elevation;
  final DateTime startDt;
  final DateTime endDt;
  final List<double>? region; // [minLon, maxLon, minLat, maxLat]
  // Frame Carousel Data
  final List<PlotFrame> frames;
  final int currentFrameIndex;
  final Uint8List? currentFrameImage;
  final bool isPlaying;
  final int fps;
  // Job & Video Data
  final Job? activeJob; // Holds the animation job being monitored/processed
  final VideoPlayerController? videoPlayerController;
  final bool isVideoControllerInitialized;
  final String? tempVideoFilePath; // Path to the temporary video file
  // General
  final String? errorMessage;

  // Convenience getter for UI
  bool get canGenerateOrExport =>
      status != HistoricPlotsStatus.submittingJob &&
      status != HistoricPlotsStatus.monitoringJob &&
      status != HistoricPlotsStatus.loadingVideo &&
      status != HistoricPlotsStatus.initializingVideo;

  HistoricPlotsState copyWith({
    HistoricPlotsStatus? status,
    String? variable,
    double? elevation,
    DateTime? startDt,
    DateTime? endDt,
    List<double>? region, // Allow nulling region
    bool clearRegion = false,
    List<PlotFrame>? frames,
    int? currentFrameIndex,
    Uint8List? currentFrameImage,
    bool? isPlaying,
    int? fps,
    Job? activeJob,
    bool clearActiveJob = false,
    VideoPlayerController? videoPlayerController,
    String? tempVideoFilePath,
    bool clearVideoController = false,
    bool? isVideoControllerInitialized,
    String? errorMessage,
    bool clearError = false,
    bool clearFrames = false,
    bool clearFrameImage = false,
  }) {
    return HistoricPlotsState(
      status: status ?? this.status,
      variable: variable ?? this.variable,
      elevation: elevation ?? this.elevation,
      startDt: startDt ?? this.startDt,
      endDt: endDt ?? this.endDt,
      region: clearRegion ? null : region ?? this.region,
      frames: clearFrames ? const [] : frames ?? this.frames,
      currentFrameIndex: clearFrames ? -1 : currentFrameIndex ?? this.currentFrameIndex,
      currentFrameImage: clearFrameImage ? null : currentFrameImage ?? this.currentFrameImage,
      isPlaying: isPlaying ?? this.isPlaying,
      fps: fps ?? this.fps,
      activeJob: clearActiveJob ? null : activeJob ?? this.activeJob,
      videoPlayerController: clearVideoController ? null : videoPlayerController ?? this.videoPlayerController,
      isVideoControllerInitialized: isVideoControllerInitialized ?? this.isVideoControllerInitialized,
      tempVideoFilePath: clearVideoController ? null : tempVideoFilePath ?? this.tempVideoFilePath, // Clear path with controller
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        variable,
        elevation,
        startDt,
        endDt,
        region,
        frames,
        currentFrameIndex,
        currentFrameImage, // Image bytes might impact performance if large/frequent
        isPlaying,
        fps,
        activeJob,
        videoPlayerController, // Controllers generally shouldn't be in Equatable props
        isVideoControllerInitialized,
        errorMessage,
      ];

   // Override toString for better debugging if needed
}