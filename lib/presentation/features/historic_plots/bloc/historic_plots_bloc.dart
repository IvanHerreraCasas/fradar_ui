// lib/presentation/features/historic_plots/bloc/historic_plots_bloc.dart
import 'dart:async';
import 'dart:io'; // Import dart:io for File operations
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart'; // <--- ADD THIS LINE
import 'package:video_player/video_player.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/domain/models/plot_frame.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'historic_plots_event.dart';
import 'historic_plots_state.dart';

class HistoricPlotsBloc extends Bloc<HistoricPlotsEvent, HistoricPlotsState> {
  final RadprocRepository _radprocRepository;
  StreamSubscription<Job>? _jobMonitorSubscription;
  Timer? _playbackTimer;

  HistoricPlotsBloc({required RadprocRepository radprocRepository})
    : _radprocRepository = radprocRepository,
      super(HistoricPlotsState()) {
    // Initial state

    // Register event handlers
    on<LoadInitialHistoricData>(_onLoadInitial);
    on<ParametersChanged>(_onParametersChanged);
    on<FetchFrames>(_onFetchFrames);
    on<FrameIndexSelected>(_onFrameIndexSelected);
    on<PlaybackToggled>(_onPlaybackToggled);
    on<GenerateOrExportAnimation>(_onGenerateOrExportAnimation);
    on<DownloadAnimationClicked>(_onDownloadAnimationClicked);
    on<JobStatusUpdated>(_onJobStatusUpdated);
    on<PlaybackTimerTick>(_onPlaybackTimerTick);
    on<VideoPlayerInitialized>(_onVideoPlayerInitialized);
    on<ErrorOccurred>(_onErrorOccurred);

    // Add initial event if needed, e.g., pre-load something
    // add(LoadInitialHistoricData());
  }

  // --- Event Handlers ---

  void _onLoadInitial(
    LoadInitialHistoricData event,
    Emitter<HistoricPlotsState> emit,
  ) {
    // Reset to initial state if needed
    emit(HistoricPlotsState());
    _cleanupResources(); // Ensure any previous resources are cleared
  }

  void _onParametersChanged(
    ParametersChanged event,
    Emitter<HistoricPlotsState> emit,
  ) {
    bool variableChanged =
        event.variable != null && event.variable != state.variable;
    emit(
      state.copyWith(
        variable: event.variable,
        elevation: event.elevation,
        startDt: event.startDt,
        endDt: event.endDt,
        region: event.region,
        clearRegion: event.region == null, // Handle explicit clearing if needed
        status:
            HistoricPlotsStatus.parametersChanged, // Indicate params changed
        // Clear dependent data if variable changes or explicitly told to
        clearFrames: variableChanged,
        clearFrameImage: true, // Always clear image on param change
        clearActiveJob: true, // Cancel any ongoing job/video if params change
        clearVideoController: true,
        isVideoControllerInitialized: false,
        isPlaying: false, // Stop playback
        clearError: true,
      ),
    );
    _cleanupResources(keepVideoController: false); // Dispose video/timers/subs
  }

  Future<void> _onFetchFrames(
    FetchFrames event,
    Emitter<HistoricPlotsState> emit,
  ) async {
    // Only fetch frames if variable is RATE (or others we know have plots)
    if (state.variable != 'RATE') {
      emit(
        state.copyWith(
          status: HistoricPlotsStatus.initial,
          clearFrames: true,
          clearFrameImage: true,
        ),
      );
      return; // No frames to fetch for non-RATE vars
    }
    emit(
      state.copyWith(
        status: HistoricPlotsStatus.loadingFrames,
        clearError: true,
      ),
    );
    try {
      final frames = await _radprocRepository.fetchFrames(
        state.variable,
        state.elevation,
        state.startDt,
        state.endDt,
      );
      if (frames.isEmpty) {
        emit(
          state.copyWith(
            status: HistoricPlotsStatus.framesLoadSuccess,
            frames: [],
            currentFrameIndex: -1,
            clearFrameImage: true,
          ),
        );
      } else {
        // Emit success state first, then trigger loading the first frame image
        emit(
          state.copyWith(
            status: HistoricPlotsStatus.framesLoadSuccess,
            frames: frames,
            currentFrameIndex: 0,
            clearFrameImage: true,
          ),
        );
        // Trigger loading the image for the first frame
        add(const FrameIndexSelected(0));
      }
    } catch (e) {
      add(ErrorOccurred('Failed to fetch frames: $e'));
    }
  }

  Future<void> _onFrameIndexSelected(
    FrameIndexSelected event,
    Emitter<HistoricPlotsState> emit,
  ) async {
    // Check if index is valid and frames are loaded
    if (event.index < 0 ||
        event.index >= state.frames.length ||
        state.status == HistoricPlotsStatus.loadingFrames) {
      return; // Invalid index or still loading frames
    }
    // Avoid redundant loading if index hasn't changed (unless forced?)
    // if (event.index == state.currentFrameIndex && state.currentFrameImage != null) return;

    emit(
      state.copyWith(
        status: HistoricPlotsStatus.loadingFrames,
        currentFrameIndex: event.index,
        clearFrameImage: true,
        clearError: true,
      ),
    ); // Show loading briefly
    try {
      final frame = state.frames[event.index];
      final imageData = await _radprocRepository.fetchHistoricalPlot(
        state.variable,
        state.elevation,
        frame.datetimeStr,
      );
      emit(
        state.copyWith(
          status: HistoricPlotsStatus.framesLoadSuccess,
          currentFrameImage: imageData,
        ),
      );
    } catch (e) {
      add(ErrorOccurred('Failed to load frame ${event.index}: $e'));
      // Revert to previous state? Or just show error?
      emit(
        state.copyWith(
          status: HistoricPlotsStatus.framesLoadError,
          errorMessage: 'Failed to load frame ${event.index}: $e',
          clearFrameImage: true,
        ),
      );
    }
  }

  void _onPlaybackToggled(
    PlaybackToggled event,
    Emitter<HistoricPlotsState> emit,
  ) {
    if (state.frames.isEmpty) return; // Can't play without frames

    if (state.isPlaying) {
      // Pause playback
      _playbackTimer?.cancel();
      _playbackTimer = null;
      emit(
        state.copyWith(
          isPlaying: false,
          status: HistoricPlotsStatus.framesLoadSuccess,
        ),
      ); // Back to normal frame view status
    } else {
      // Start playback
      emit(
        state.copyWith(
          isPlaying: true,
          status: HistoricPlotsStatus.playbackActive,
        ),
      );
      // Start timer
      _playbackTimer?.cancel(); // Ensure no duplicate timers
      _playbackTimer = Timer.periodic(
        Duration(milliseconds: 1000 ~/ state.fps),
        (_) {
          add(PlaybackTimerTick());
        },
      );
    }
  }

  void _onPlaybackTimerTick(
    PlaybackTimerTick event,
    Emitter<HistoricPlotsState> emit,
  ) {
    if (!state.isPlaying || state.frames.isEmpty) {
      _playbackTimer?.cancel(); // Should not happen, but safety check
      _playbackTimer = null;
      return;
    }
    // Calculate next frame index
    int nextIndex = (state.currentFrameIndex + 1) % state.frames.length;
    add(FrameIndexSelected(nextIndex)); // Trigger loading the next frame
  }

  Future<void> _onGenerateOrExportAnimation(
    GenerateOrExportAnimation event,
    Emitter<HistoricPlotsState> emit,
  ) async {
    if (!state.canGenerateOrExport) return;

    _cleanupResources();
    emit(
      state.copyWith(
        status: HistoricPlotsStatus.submittingJob,
        clearError: true,
        clearActiveJob: true,
        clearVideoController: true,
      ),
    );

    try {
      // --- Decide on output format ---
      // For now, let's hardcode MP4, but this could come from UI later
      const outputFormat = ".mp4";

      final job = await _radprocRepository.startAnimationGeneration(
        variable: state.variable,
        elevation: state.elevation,
        startDt: state.startDt,
        endDt: state.endDt,
        extent: state.region,
        outputFormat: outputFormat, // Pass the desired format
        // Pass other options like fps, noWatermark if implemented
      );
      emit(
        state.copyWith(
          status: HistoricPlotsStatus.monitoringJob,
          activeJob: job,
        ),
      );
      // Start monitoring... (rest of the logic is the same)
      _jobMonitorSubscription?.cancel();
      _jobMonitorSubscription = _radprocRepository
          .monitorJob(job)
          .listen(
            (updatedJob) => add(JobStatusUpdated(updatedJob)),
            onError:
                (error) => add(ErrorOccurred('Job monitoring failed: $error')),
            onDone:
                () => print('Job monitoring stream closed for ${job.taskId}'),
            cancelOnError: true,
          );
    } catch (e) {
      add(ErrorOccurred('Failed to submit job: $e'));
    }
  }

  void _onJobStatusUpdated(
    JobStatusUpdated event,
    Emitter<HistoricPlotsState> emit,
  ) {
    // Update the job details in the state
    emit(
      state.copyWith(
        activeJob: event.job,
        status: HistoricPlotsStatus.monitoringJob,
      ),
    );

    // Handle final states
    if (event.job.status == JobStatusEnum.success) {
      _jobMonitorSubscription?.cancel();
      _jobMonitorSubscription = null;
      if (state.variable == 'RATE') {
        // For RATE, animation is ready for download/export
        emit(
          state.copyWith(status: HistoricPlotsStatus.animationReadyToDownload),
        );
      } else {
        // For non-RATE, fetch and display the video
        _fetchAndInitializeVideo(event.job.taskId, emit);
      }
    } else if (event.job.status == JobStatusEnum.failure ||
        event.job.status == JobStatusEnum.revoked) {
      _jobMonitorSubscription?.cancel();
      _jobMonitorSubscription = null;
      add(
        ErrorOccurred(
          'Animation job failed: ${event.job.errorMessage ?? 'Unknown reason'}',
        ),
      );
    }
    // If status is still pending/running, do nothing extra, just keep monitoringJob status updated
  }

  Future<void> _fetchAndInitializeVideo(
    String taskId,
    Emitter<HistoricPlotsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: HistoricPlotsStatus.loadingVideo,
        clearVideoController: true,
      ),
    ); // Clear previous video stuff
    String? tempFilePath; // Variable to hold the temp path

    try {
      final videoBytes = await _radprocRepository.fetchAnimationResult(taskId);

      // 1. Get temporary directory
      final tempDir = await getTemporaryDirectory();
      // 2. Create unique filename
      tempFilePath =
          '${tempDir.path}/temp_video_${taskId}_${DateTime.now().millisecondsSinceEpoch}.mp4'; // Assuming mp4
      // 3. Write bytes to file
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(videoBytes, flush: true);
      print('Video bytes saved to temporary file: $tempFilePath');

      // Dispose previous controller just in case (should be handled by clearVideoController, but belt-and-suspenders)
      await state.videoPlayerController?.dispose();

      // 4. Initialize new controller using .file()
      final newController = VideoPlayerController.file(tempFile);

      emit(
        state.copyWith(
          status: HistoricPlotsStatus.initializingVideo,
          tempVideoFilePath: tempFilePath, // Store path in state
          videoPlayerController:
              newController, // Store controller (uninitialized)
          isVideoControllerInitialized: false,
        ),
      );

      // 5. Listen for initialization completion
      // Use await here to simplify state management, ensures init completes before next step
      try {
        await newController.initialize();
        // Check if the state context is still valid (i.e., user hasn't changed params etc.)
        if (state.tempVideoFilePath == tempFilePath &&
            state.status == HistoricPlotsStatus.initializingVideo) {
          print('Video player initialized successfully.');
          // Update state to videoReady
          add(const VideoPlayerInitialized(false)); // Use internal event
        } else {
          print(
            'Video initialization completed but state context changed, cleaning up.',
          );
          await newController.dispose();
          await _deleteTempFile(tempFilePath); // Clean up the created file
        }
      } catch (initError) {
        print('Video player initialization failed: $initError');
        add(const VideoPlayerInitialized(true)); // Signal initialization error
        await newController.dispose();
        await _deleteTempFile(tempFilePath); // Clean up the created file
      }
    } catch (e) {
      add(ErrorOccurred('Failed to load video: $e'));
      // Clean up temp file if it was created before error
      if (tempFilePath != null) {
        await _deleteTempFile(tempFilePath);
      }
    }
  }

  void _onVideoPlayerInitialized(
    VideoPlayerInitialized event,
    Emitter<HistoricPlotsState> emit,
  ) {
    if (event.hasError || state.videoPlayerController == null) {
      add(ErrorOccurred('Failed to initialize video player.'));
      // Ensure cleanup if initialization failed
      final controller = state.videoPlayerController;
      final path = state.tempVideoFilePath;
      emit(
        state.copyWith(clearVideoController: true),
      ); // Clear state references
      controller?.dispose();
      _deleteTempFile(path);
    } else {
      // Initialization successful, update state
      emit(
        state.copyWith(
          status: HistoricPlotsStatus.videoReady,
          isVideoControllerInitialized: true, // Mark as ready
        ),
      );
    }
  }

  Future<void> _onDownloadAnimationClicked(
    DownloadAnimationClicked event,
    Emitter<HistoricPlotsState> emit,
  ) async {
    if (state.activeJob != null &&
        state.activeJob!.status == JobStatusEnum.success) {
      try {
        // Show some visual feedback (e.g., snackbar, loading indicator?)
        print('Download started...'); // Placeholder
        await _radprocRepository.downloadAnimationResult(state.activeJob!);
        print('Download prompt finished.'); // Placeholder
        // Show success SnackBar via BlocListener in UI
      } catch (e) {
        print('Download failed: $e');
        // Show error SnackBar via BlocListener in UI
        add(ErrorOccurred('Download failed: $e'));
      }
    } else {
      print('Download requested but no successful job found.');
      add(ErrorOccurred('No completed animation available to download.'));
    }
  }

  void _onErrorOccurred(ErrorOccurred event, Emitter<HistoricPlotsState> emit) {
    // Generic error handler, puts bloc into error state
    _cleanupResources(); // Stop timers/subs on error
    emit(
      state.copyWith(
        status: HistoricPlotsStatus.error,
        errorMessage: event.message,
        isPlaying: false,
        clearActiveJob: true,
        clearVideoController: true,
        isVideoControllerInitialized: false,
      ),
    );
  }

  // Helper to delete temp file safely
  Future<void> _deleteTempFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('Deleted temporary video file: $filePath');
      }
    } catch (e) {
      print('Error deleting temporary file $filePath: $e');
    }
  }

  // Updated cleanup helper
  Future<void> _cleanupResources({bool keepVideoController = true}) async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _jobMonitorSubscription?.cancel();
    _jobMonitorSubscription = null;

    // Get controller and path *before* potentially clearing state
    final controllerToDispose = state.videoPlayerController;
    final pathToDelete = state.tempVideoFilePath;

    if (!keepVideoController) {
      // Dispose controller and delete associated temp file
      await controllerToDispose?.dispose();
      await _deleteTempFile(pathToDelete);
      // Avoid emitting state directly from here if called during close()
    }
  }

  @override
  Future<void> close() async {
    // Make close async
    print('Closing HistoricPlotsBloc');
    // Ensure cleanup happens before super.close()
    final controller = state.videoPlayerController;
    final path = state.tempVideoFilePath;
    await _cleanupResources(
      keepVideoController: false,
    ); // Ensure video controller cleared
    await controller?.dispose(); // Explicitly dispose here too just in case
    await _deleteTempFile(path); // Delete temp file on close
    return super.close();
  }
}
