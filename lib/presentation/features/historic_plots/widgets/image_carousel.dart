// lib/presentation/features/historic_plots/widgets/image_carousel.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fradar_ui/domain/models/plot_frame.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_event.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_state.dart';


class ImageCarousel extends StatelessWidget {
  final List<PlotFrame> frames;
  final int currentFrameIndex;
  final Uint8List? currentFrameImage;
  final bool isPlaying;
  final int fps; // TODO: Add FPS control later
  final HistoricPlotsStatus status; // To know when to show download button
  final bool canGenerateOrExport; // To enable/disable export button

  const ImageCarousel({
    super.key,
    required this.frames,
    required this.currentFrameIndex,
    required this.currentFrameImage,
    required this.isPlaying,
    required this.fps,
    required this.status,
    required this.canGenerateOrExport,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HistoricPlotsBloc>();
    final bool hasFrames = frames.isNotEmpty;
    final bool isValidIndex = hasFrames && currentFrameIndex >= 0 && currentFrameIndex < frames.length;
    final String frameTimestamp = isValidIndex
        ? DateFormat.yMd().add_Hms().format(frames[currentFrameIndex].dateTimeUtc.toLocal()) + ' (Local)'
        : 'No frame selected';

    return Column(
      children: [
        // --- Image Display Area ---
        Expanded(
          child: Container(
            color: Colors.grey[200], // Background for image area
            child: Center(
              child: currentFrameImage != null
                  ? InteractiveViewer( // Basic zoom/pan
                      maxScale: 5.0,
                      child: Image.memory(
                         currentFrameImage!,
                         gaplessPlayback: true, // Prevents flicker on change
                         errorBuilder: (ctx, err, st) => const Center(child: Text('Error loading image')),
                      ),
                    )
                  : (isValidIndex // Show loading only if index is valid but image is null
                      ? const CircularProgressIndicator()
                      : const Text('No image loaded')),
            ),
          ),
        ),

        // --- Controls Area ---
        Material( // Provides background and theme defaults
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                 // Timestamp / Frame number
                  Text(isValidIndex ? 'Frame ${currentFrameIndex + 1} / ${frames.length}' : 'No Frames'),
                  Text(frameTimestamp, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 5),
                  // Slider (optional scrubbing)
                  if (hasFrames)
                     Slider(
                        value: currentFrameIndex.toDouble(),
                        min: 0,
                        max: (frames.length - 1).toDouble(),
                        divisions: (frames.length > 1) ? frames.length - 1 : null, // Avoid division by zero
                        label: '${currentFrameIndex + 1}',
                        onChanged: (value) => bloc.add(FrameIndexSelected(value.round())),
                     ),

                 // Buttons Row
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       // Previous Frame
                       IconButton(
                          icon: const Icon(Icons.skip_previous),
                          tooltip: 'Previous Frame',
                          onPressed: (!hasFrames || currentFrameIndex <= 0)
                             ? null
                             : () => bloc.add(FrameIndexSelected(currentFrameIndex - 1)),
                       ),
                       // Play/Pause
                       IconButton(
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                          iconSize: 36,
                          tooltip: isPlaying ? 'Pause' : 'Play Slideshow',
                          onPressed: !hasFrames
                             ? null
                             : () => bloc.add(PlaybackToggled()),
                       ),
                       // Next Frame
                       IconButton(
                          icon: const Icon(Icons.skip_next),
                          tooltip: 'Next Frame',
                          onPressed: (!hasFrames || currentFrameIndex >= frames.length - 1)
                             ? null
                             : () => bloc.add(FrameIndexSelected(currentFrameIndex + 1)),
                       ),
                       // TODO: Add FPS Control Widget later

                       const Spacer(), // Pushes buttons to the right

                       // Export Button (always visible for RATE if params are set)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.movie_creation_outlined, size: 18),
                          label: const Text('Export Anim'),
                          style: ElevatedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                             textStyle: const TextStyle(fontSize: 12)
                          ),
                          onPressed: !canGenerateOrExport
                             ? null
                             : () => bloc.add(GenerateOrExportAnimation()),
                       ),
                       const SizedBox(width: 10),
                       // Download Button (only if ready)
                       if (status == HistoricPlotsStatus.animationReadyToDownload)
                         ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               textStyle: const TextStyle(fontSize: 12)
                            ),
                            onPressed: () => bloc.add(DownloadAnimationClicked()),
                         ),
                    ],
                 ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}