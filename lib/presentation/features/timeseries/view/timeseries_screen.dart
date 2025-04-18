import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_event.dart';
import 'package:fradar_ui/presentation/features/timeseries/view/timeseries_view.dart';

class TimeseriesScreen extends StatelessWidget {
  const TimeseriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => TimeseriesBloc(
            radprocRepository: context.read<RadprocRepository>(),
          )..add(LoadPoints()), // Load points list on creation
      child: const TimeseriesView(),
    );
  }
}
