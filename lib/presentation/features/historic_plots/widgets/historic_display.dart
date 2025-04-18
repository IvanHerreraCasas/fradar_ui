// lib/presentation/features/historic_plots/widgets/historic_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_state.dart';
import 'package:fradar_ui/presentation/features/historic_plots/widgets/image_carousel.dart';
import 'package:fradar_ui/presentation/features/historic_plots/widgets/video_display.dart';

class HistoricDisplay extends StatelessWidget {
  const HistoricDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoricPlotsBloc, HistoricPlotsState>(
      // Build only when relevant parts of state change
      buildWhen:
          (prev, current) =>
              prev.status != current.status ||
              prev.currentFrameImage !=
                  current.currentFrameImage || // For carousel update
              prev.frames != current.frames || // For carousel data
              prev.currentFrameIndex !=
                  current.currentFrameIndex || // For carousel index
              prev.isPlaying != current.isPlaying || // For carousel controls
              prev.fps != current.fps, // For carousel controls
      builder: (context, state) {
        // --- Loading / Submitting / Monitoring ---
        if (state.status == HistoricPlotsStatus.loadingFrames ||
            state.status == HistoricPlotsStatus.submittingJob ||
            state.status == HistoricPlotsStatus.monitoringJob ||
            state.status == HistoricPlotsStatus.loadingVideo) {
          String message = switch (state.status) {
            HistoricPlotsStatus.loadingFrames => 'Loading Frames...',
            HistoricPlotsStatus.submittingJob => 'Submitting Job...',
            HistoricPlotsStatus.monitoringJob => 'Loading...',
            HistoricPlotsStatus.loadingVideo => 'Loading Video Data...',
            _ => 'Loading...', // Default case
          };
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          );
        }

        // --- Error States ---
        if (state.status == HistoricPlotsStatus.error ||
            state.status == HistoricPlotsStatus.framesLoadError) {
          return Center(
            child: Text(
              'Error: ${state.errorMessage ?? 'An unknown error occurred.'}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          );
        }

        // --- Frames Loaded (Show Carousel) ---
        // Also handles playbackActive implicitly via isPlaying prop
        if (state.status == HistoricPlotsStatus.framesLoadSuccess ||
            state.status == HistoricPlotsStatus.playbackActive ||
            state.status == HistoricPlotsStatus.animationReadyToDownload) {
          // Check if frames are actually loaded (might be success with 0 frames)
          if (state.frames.isEmpty &&
              state.status != HistoricPlotsStatus.animationReadyToDownload) {
            return const Center(
              child: Text('No frames found for the selected parameters.'),
            );
          }
          // Show carousel (which includes download button if animationReadyToDownload)
          return ImageCarousel(
            frames: state.frames,
            currentFrameIndex: state.currentFrameIndex,
            currentFrameImage: state.currentFrameImage,
            isPlaying: state.isPlaying,
            fps: state.fps,
            status: state.status, // Pass status for download button visibility
            canGenerateOrExport:
                state.canGenerateOrExport, // Pass for enabling export button
          );
        }

        // --- Video Ready (Show Video Player) ---
        if (state.status == HistoricPlotsStatus.videoFileReady) {
          return VideoDisplay(
            tempVideoFilePath:
                state.tempVideoFilePath!, 
          );
        }

        // --- Initial / Parameters Changed ---
        // Default state before any action or after param changes
        return const Center(
          child: Text(
            'Select parameters and Fetch Frames (for RATE) or Generate Animation.',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
