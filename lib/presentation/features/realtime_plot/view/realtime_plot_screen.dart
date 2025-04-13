import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/bloc/realtime_plot_bloc.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/bloc/realtime_plot_event.dart';
import 'package:fradar_ui/presentation/features/realtime_plot/view/realtime_plot_view.dart';

class RealtimePlotScreen extends StatelessWidget {
  const RealtimePlotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RealtimePlotBloc(
        radprocRepository: context.read<RadprocRepository>(),
      )..add(LoadRealtimePlot()), // Trigger initial load
      child: const RealtimePlotView(),
    );
  }
}