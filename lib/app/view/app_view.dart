// lib/app/view/app_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/app/bloc/app_bloc.dart';
import 'package:fradar_ui/app/bloc/app_state.dart';

import 'package:fradar_ui/presentation/navigation/expandable_sidebar.dart';

import 'package:fradar_ui/presentation/features/settings/view/settings_screen.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/view/realtime_plot_screen.dart';
import 'package:fradar_ui/presentation/features/historic_plots/view/historic_plots_screen.dart';
import 'package:fradar_ui/presentation/features/timeseries/view/timeseries_screen.dart';
import 'package:fradar_ui/presentation/features/tasks/view/tasks_screen.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppBloc(),
      child: Scaffold(
        body: Row(
          children: [
            const ExpandableSidebar(),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content area that changes based on selection
            Expanded(
              child: BlocBuilder<AppBloc, AppState>(
                builder: (context, state) {
                  // Use IndexedStack to keep screen state alive when switching
                  return IndexedStack(
                    index: state.selectedIndex,
                    children: [
                      const RealtimePlotScreen(),
                      const HistoricPlotsScreen(),
                      const TimeseriesScreen(),
                      const TasksScreen(),
                      const SettingsScreen(),
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
