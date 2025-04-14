// lib/app/view/app_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/app/bloc/app_bloc.dart';
import 'package:fradar_ui/app/bloc/app_state.dart';
import 'package:fradar_ui/presentation/navigation/expandable_sidebar.dart';

// Import Feature Screens (create placeholder files for now if they don't exist)
import 'package:fradar_ui/presentation/features/settings/view/settings_screen.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/view/realtime_plot_screen.dart';
import 'package:fradar_ui/presentation/features/historic_plots/view/historic_plots_screen.dart';
// import 'package:fradar_ui/presentation/features/timeseries/view/timeseries_screen.dart';
// import 'package:fradar_ui/presentation/features/tasks/view/tasks_screen.dart';


class AppView extends StatelessWidget {
  const AppView({super.key});

  // Placeholder widgets for screens not yet implemented
  Widget _buildPlaceholder(String title) {
     return Center(child: Text('$title Screen (Not Implemented)'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppBloc(), // Provide the AppBloc for navigation state
      child: Scaffold(
        body: Row(
          children: [
            const ExpandableSidebar(), // Our navigation rail/sidebar
            const VerticalDivider(thickness: 1, width: 1), // Separator
            // Main content area that changes based on selection
            Expanded(
              child: BlocBuilder<AppBloc, AppState>(
                builder: (context, state) {
                  // Use IndexedStack to keep screen state alive when switching
                  return IndexedStack(
                    index: state.selectedIndex,
                    children: [
                      const RealtimePlotScreen(), // Index 0
                      const HistoricPlotsScreen(), // Index 1
                      // TimeseriesScreen(), // Index 2
                       _buildPlaceholder('Timeseries'), // Index 2
                      // TasksScreen(), // Index 3
                      _buildPlaceholder('Tasks'), // Index 3
                      const SettingsScreen(), // Index 4 - We'll implement this next
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}