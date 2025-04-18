// lib/presentation/features/timeseries/widgets/timeseries_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_event.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_state.dart';
import 'package:fradar_ui/presentation/features/timeseries/widgets/map_display.dart';
import 'package:fradar_ui/presentation/features/timeseries/widgets/graph_display.dart';

class TimeseriesDisplay extends StatelessWidget {
  const TimeseriesDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimeseriesBloc, TimeseriesState>(
      // Build only when map/graph mode changes or status dictates display change
      buildWhen:
          (prev, current) =>
              prev.isMapMode != current.isMapMode ||
              prev.status != current.status,
      builder: (context, state) {
        return Column(
          children: [
            // --- Mode Toggle ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              // Use SegmentedButton for a modern look
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Map'),
                    icon: Icon(Icons.map_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Graph'),
                    icon: Icon(Icons.show_chart),
                  ),
                ],
                selected: {state.isMapMode}, // Selection state requires a Set
                onSelectionChanged: (Set<bool> newSelection) {
                  // Assuming single selection mode, though SegmentedButton supports multi
                  if (newSelection.isNotEmpty) {
                    context.read<TimeseriesBloc>().add(DisplayModeToggled());
                  }
                },
                // Optionally style selected button
                style: SegmentedButton.styleFrom(
                  // backgroundColor: Colors.grey[200],
                  // foregroundColor: Colors.blue,
                  // selectedForegroundColor: Colors.white,
                  // selectedBackgroundColor: Colors.blue,
                ),
              ),
            ),
            const Divider(height: 1),

            // --- Conditional Content using IndexedStack ---
            Expanded(
              // Replace AnimatedSwitcher/Conditional with IndexedStack
              child: IndexedStack(
                // Index 0 for Map, Index 1 for Graph
                index: state.isMapMode ? 0 : 1,
                // Provide *both* widgets as children. They will be kept alive.
                children: const [
                  MapDisplay(key: ValueKey('MapDisplay')), // Index 0
                  GraphDisplay(key: ValueKey('GraphDisplay')), // Index 1
                  // Adding Keys helps Flutter identify the widgets if needed,
                  // though not strictly necessary for IndexedStack state preservation itself.
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
