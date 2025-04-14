// lib/presentation/features/historic_plots/view/historic_plots_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
// Import the view
import 'package:fradar_ui/presentation/features/historic_plots/view/historic_plots_view.dart';

class HistoricPlotsScreen extends StatelessWidget {
  const HistoricPlotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HistoricPlotsBloc(
        radprocRepository: context.read<RadprocRepository>(),
      ),
      // ..add(LoadInitialHistoricData()), // Uncomment if initial load needed
      child: const HistoricPlotsView(),
    );
  }
}