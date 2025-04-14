import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_state.dart'; // Create this file
import 'package:fradar_ui/presentation/features/timeseries/widgets/timeseries_display.dart';
import 'package:fradar_ui/presentation/features/timeseries/widgets/timeseries_controls.dart';


class TimeseriesView extends StatelessWidget {
  const TimeseriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar needed here as controls/tabs are within the body
      body: BlocListener<TimeseriesBloc, TimeseriesState>( // Listen for general errors maybe
         listener: (context, state) {
            if (state.status == TimeseriesStatus.error && state.errorMessage != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                     SnackBar(content: Text('Error: ${state.errorMessage}'), backgroundColor: Theme.of(context).colorScheme.error),
                  );
            }
         },
         child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // --- Controls Pane (Left) ---
               const SizedBox(
                 width: 300, // Adjust width
                 child: TimeseriesControls(), // Create this widget
               ),
               const VerticalDivider(width: 1, thickness: 1),

               // --- Display Pane (Right) ---
               const Expanded(
                 child: TimeseriesDisplay(), // Create this widget
               ),
            ],
         ),
      ),
    );
  }
}