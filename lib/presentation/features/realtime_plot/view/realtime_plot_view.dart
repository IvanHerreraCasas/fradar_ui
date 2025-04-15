import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/bloc/realtime_plot_bloc.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/bloc/realtime_plot_event.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/bloc/realtime_plot_state.dart';
import 'package:fradar_ui/presentation/shared_widgets/elevation_autocomplete.dart';
import 'package:fradar_ui/presentation/shared_widgets/variable_selector.dart';

class RealtimePlotView extends StatelessWidget {
  const RealtimePlotView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Radar Plot'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Column(
        children: [
          // --- Controls Row ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Variable Selector
                SizedBox(
                  width: 150,
                  child: BlocBuilder<RealtimePlotBloc, RealtimePlotState>(
                    // Build only when variable changes
                    buildWhen:
                        (prev, current) =>
                            prev.selectedVariable != current.selectedVariable,
                    builder: (context, state) {
                      return VariableSelector(
                        selectedVariable: state.selectedVariable,
                        onChanged: (value) {
                          if (value != null) {
                            context.read<RealtimePlotBloc>().add(
                              VariableSelected(value),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 20),

                // Elevation Selector
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: ElevationAutocomplete(
                    onSelected: (value) {
                      final bloc = context.read<RealtimePlotBloc>();

                      bloc.add(ElevationSelected(value));
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // --- Plot Display Area ---
          Expanded(
            child: BlocBuilder<RealtimePlotBloc, RealtimePlotState>(
              builder: (context, state) {
                switch (state.status) {
                  case RealtimePlotStatus.initial:
                    return const Center(
                      child: Text('Select parameters to load plot.'),
                    );
                  case RealtimePlotStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case RealtimePlotStatus.error:
                    return Center(
                      child: Text(
                        'Error: ${state.errorMessage ?? 'Unknown error'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  case RealtimePlotStatus.success:
                    if (state.plotImageData != null) {
                      // Use InteractiveViewer for basic zoom/pan
                      return InteractiveViewer(
                        maxScale: 4.0, // Allow zooming up to 4x
                        child: Center(
                          // Center the image within the viewer
                          child: Image.memory(
                            state.plotImageData!,
                            gaplessPlayback: true, // Smoother updates
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const Text('Error displaying image'),
                          ),
                        ),
                      );
                    } else {
                      // Should not happen in success state ideally, but handle defensively
                      return const Center(
                        child: Text('Plot data unavailable.'),
                      );
                    }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
