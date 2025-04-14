import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'package:fradar_ui/presentation/features/tasks/view/tasks_view.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_event.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TasksBloc(
        radprocRepository: context.read<RadprocRepository>(),
      )..add(LoadTasks()), // Load tasks on creation
      child: const TasksView(),
    );
  }
}