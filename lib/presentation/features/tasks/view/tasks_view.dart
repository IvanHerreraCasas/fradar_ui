import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_event.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_state.dart';
// Import the list item widget (create next)
import 'package:fradar_ui/presentation/features/tasks/widgets/job_list_item.dart';

class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tasks'),
        actions: [
           // Add Clear Completed button
           BlocBuilder<TasksBloc, TasksState>( // Only show if tasks exist
              buildWhen: (p, c) => p.tasks.isNotEmpty != c.tasks.isNotEmpty,
              builder: (context, state) {
                if (state.tasks.isEmpty) return const SizedBox.shrink();
                return IconButton(
                   icon: const Icon(Icons.delete_sweep_outlined),
                   tooltip: 'Clear Completed/Failed Tasks',
                   onPressed: () => context.read<TasksBloc>().add(ClearTerminatedTasks()),
                );
              },
            ),
            // Add manual refresh button
           IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Task List',
              onPressed: () => context.read<TasksBloc>().add(LoadTasks()),
           ),
        ],
      ),
      body: BlocBuilder<TasksBloc, TasksState>(
        builder: (context, state) {
          if (state.status == TasksStatus.loading && state.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == TasksStatus.error && state.tasks.isEmpty) {
            return Center(child: Text('Error loading tasks: ${state.errorMessage ?? ''}'));
          }
          if (state.tasks.isEmpty) {
            return const Center(child: Text('No background tasks found.'));
          }

          // Display the list
          return ListView.builder(
            itemCount: state.tasks.length,
            itemBuilder: (context, index) {
              final job = state.tasks[index];
              return JobListItem(job: job); // Use the custom widget
            },
          );
        },
      ),
    );
  }
}