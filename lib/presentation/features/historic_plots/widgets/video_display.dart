// lib/presentation/features/historic_plots/widgets/video_display.dart
import 'dart:async';
import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_event.dart';

class VideoDisplay extends StatefulWidget {
  // Get the temp file path from BLoC state via parent widget
  final String tempVideoFilePath;
  // Can potentially remove canGenerateOrExport if download button logic changes

  const VideoDisplay({
    super.key,
    required this.tempVideoFilePath,
    // required this.canGenerateOrExport, // Removed if not needed
  });

  @override
  State<VideoDisplay> createState() => _VideoDisplayState();
}

class _VideoDisplayState extends State<VideoDisplay> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _showControls = true; // Control visibility of overlay controls
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    print('VideoDisplay initState: Initializing controller for ${widget.tempVideoFilePath}');
    _initializeController();
  }

  void _initializeController() {
     // Create controller using the file path
     _controller = VideoPlayerController.file(File(widget.tempVideoFilePath));
     // Initialize and store the future for FutureBuilder
     _initializeVideoPlayerFuture = _controller!.initialize()
        ..then((_) {
           // Ensure mounted before calling setState
           if (mounted) setState(() {}); // Trigger rebuild once initialized
            _controller?.play(); // Autoplay?
            _startControlsTimer(); // Show controls initially
        }).catchError((error) {
           print("Error initializing video controller: $error");
           if (mounted) setState(() {}); // Rebuild to show error state maybe
            // Optionally dispatch error event to BLoC?
            // context.read<HistoricPlotsBloc>().add(ErrorOccurredInternal('Video Player Init Error: $error'));
        });
  }

   // Show controls briefly when tapped or playback starts/pauses
  void _showControlsTemporarily() {
     if (!_showControls) {
        setState(() { _showControls = true; });
     }
     _startControlsTimer();
  }

  void _startControlsTimer() {
     _controlsTimer?.cancel(); // Cancel existing timer
     _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller?.value.isPlaying == true) { // Hide only if playing
           setState(() { _showControls = false; });
        }
     });
  }

  @override
  void didUpdateWidget(covariant VideoDisplay oldWidget) {
     super.didUpdateWidget(oldWidget);
     // If the file path changes, re-initialize the controller
     if (widget.tempVideoFilePath != oldWidget.tempVideoFilePath) {
        print('VideoDisplay didUpdateWidget: Path changed, re-initializing controller.');
        // Dispose old controller first
        _controller?.removeListener(_listener); // Remove listener before dispose
        final oldPath = oldWidget.tempVideoFilePath; // Capture old path
        _controller?.dispose().then((_) {
           // Trigger cleanup for the *old* file after disposal
           if (oldPath.isNotEmpty) {
              context.read<HistoricPlotsBloc>().add(VideoFileReadyToClean(oldPath));
           }
        });
        // Initialize new one
        _initializeController();
     }
  }

   // Listener to update local playback state
   void _listener() {
      if (mounted) {
         setState(() {
             // Potentially update _isPlaying state if needed locally
             // Could also just read directly from controller.value.isPlaying in build
         });
      }
   }


  @override
  void dispose() {
    print('VideoDisplay dispose: Disposing controller and requesting cleanup for ${widget.tempVideoFilePath}');
    _controlsTimer?.cancel();
    // Remove listener before dispose
    _controller?.removeListener(_listener);
    // Dispose controller
    _controller?.dispose().then((_) {
       // Trigger cleanup for the current file path *after* disposal completes
       if (widget.tempVideoFilePath.isNotEmpty) {
           context.read<HistoricPlotsBloc>().add(VideoFileReadyToClean(widget.tempVideoFilePath));
       }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<HistoricPlotsBloc>(); // Needed for download action

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: _initializeVideoPlayerFuture == null || _controller == null
                  ? const CircularProgressIndicator() // Show loading if controller creation is pending
                  : FutureBuilder(
                      future: _initializeVideoPlayerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && snapshot.error == null) {
                          // --- Video Player ---
                           return AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            // Use Stack to overlay controls
                            child: Stack(
                               alignment: Alignment.bottomCenter,
                               children: [
                                  GestureDetector( // Tap video to toggle controls
                                     onTap: _showControlsTemporarily,
                                     child: VideoPlayer(_controller!)
                                  ),
                                  // Controls Overlay
                                  AnimatedOpacity(
                                      opacity: _showControls ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 300),
                                      child: _buildControlsOverlay(),
                                  ),
                               ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                           return Text("Error loading video: ${snapshot.error}", style: const TextStyle(color: Colors.white));
                        } else {
                           // Still initializing
                           return const CircularProgressIndicator(color: Colors.white);
                        }
                      },
                    ),
            ),
          ),
        ),
        // Separate Download button area (always visible when video ready)
         if (_controller?.value.isInitialized == true) // Show only when ready
           Material(
             elevation: 4.0,
             child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end, // Align button to right
                 children: [
                   ElevatedButton.icon(
                     icon: const Icon(Icons.download, size: 18),
                     label: const Text('Download'),
                     style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.green, foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         textStyle: const TextStyle(fontSize: 12)),
                     onPressed: () => bloc.add(DownloadAnimationClicked()), // Dispatch BLoC event
                   ),
                 ],
               ),
             ),
           ),
      ],
    );
  }

  // Helper to build controls overlay
  Widget _buildControlsOverlay() {
     if (_controller == null || !_controller!.value.isInitialized) {
        return const SizedBox.shrink();
     }
     return Container(
         decoration: const BoxDecoration(
             gradient: LinearGradient(
                 colors: [Colors.black87, Colors.transparent],
                 begin: Alignment.bottomCenter,
                 end: Alignment.topCenter,
             ),
         ),
         child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [
                 IconButton(
                     icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                     color: Colors.white,
                     iconSize: 32,
                     onPressed: () {
                         setState(() {
                             _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                             _showControlsTemporarily(); // Keep controls visible on pause/play
                         });
                     },
                 ),
                 Expanded(
                     child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.black45,
                        ),
                     ),
                 ),
             ],
         ),
     );
  }
}