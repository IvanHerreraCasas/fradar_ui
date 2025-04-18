// lib/presentation/features/historic_plots/view/historic_plots_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_state.dart';
import 'package:fradar_ui/presentation/features/historic_plots/widgets/historic_controls.dart';
import 'package:fradar_ui/presentation/features/historic_plots/widgets/historic_display.dart';

class HistoricPlotsView extends StatelessWidget {
  const HistoricPlotsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a listener for snackbars (errors, maybe download readiness)
      body: BlocListener<HistoricPlotsBloc, HistoricPlotsState>(
        listener: (context, state) {
          if (state.status == HistoricPlotsStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.errorMessage}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
          } else if (state.status ==
              HistoricPlotsStatus.animationReadyToDownload) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Animation ready to download.')),
              );
          }
          // Add other listeners if needed (e.g., for download success/failure)
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            // --- Controls Pane (Left) ---
            const SizedBox(
              width: 300, // Adjust width as needed
              child: HistoricControls(),
            ),
            const VerticalDivider(width: 1, thickness: 1),

            // --- Display Pane (Right) ---
            const Expanded(child: HistoricDisplay()),
          ],
        ),
      ),
    );
  }
}
