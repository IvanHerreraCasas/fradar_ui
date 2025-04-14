// lib/presentation/features/historic_plots/widgets/video_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_event.dart';

class VideoDisplay extends StatefulWidget {
  final VideoPlayerController controller;
  final bool canGenerateOrExport; // To potentially disable download button

  const VideoDisplay({
    super.key,
    required this.controller,
    required this.canGenerateOrExport,
  });

  @override
  State<VideoDisplay> createState() => _VideoDisplayState();
}

class _VideoDisplayState extends State<VideoDisplay> {
   // Local state for playback controls if needed, or rely on controller state
   bool _isPlaying = false;

   @override
   void initState() {
      super.initState();
       // Add listener to update local play state if needed
       _isPlaying = widget.controller.value.isPlaying;
       widget.controller.addListener(_updatePlaybackState);
   }

   @override
   void didUpdateWidget(covariant VideoDisplay oldWidget) {
     super.didUpdateWidget(oldWidget);
     if (oldWidget.controller != widget.controller) {
       // Remove listener from old controller, add to new one
       oldWidget.controller.removeListener(_updatePlaybackState);
       _isPlaying = widget.controller.value.isPlaying;
       widget.controller.addListener(_updatePlaybackState);
     }
   }


   void _updatePlaybackState() {
      if (mounted) {
          setState(() {
             _isPlaying = widget.controller.value.isPlaying;
          });
      }
   }

   @override
   void dispose() {
      widget.controller.removeListener(_updatePlaybackState);
      // NOTE: The controller itself is disposed by the BLoC
      super.dispose();
   }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HistoricPlotsBloc>();

    return Column(
      children: [
        // --- Video Player Area ---
        Expanded(
          child: Container(
            color: Colors.black, // Video background
            child: Center(
              child: widget.controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: widget.controller.value.aspectRatio,
                      child: VideoPlayer(widget.controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white), // Should not show if state is videoReady
            ),
          ),
        ),
        // --- Controls Area ---
         Material(
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                 // Basic Play/Pause Button
                 IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 32,
                    tooltip: _isPlaying ? 'Pause Video' : 'Play Video',
                    onPressed: () {
                       if (_isPlaying) {
                           widget.controller.pause();
                       } else {
                           widget.controller.play();
                       }
                       // Set state is handled by the listener _updatePlaybackState
                    },
                 ),
                 // Video Progress Bar
                 Expanded(
                    child: VideoProgressIndicator(
                       widget.controller,
                       allowScrubbing: true,
                       padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                 ),
                  // TODO: Add Volume control, Seek buttons etc. if needed

                 // Download Button
                 ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                     style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12)
                     ),
                    // Disable button logic might be needed if download is in progress
                    onPressed: () => bloc.add(DownloadAnimationClicked()),
                 ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}