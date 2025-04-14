import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_event.dart';
 // Import Historic Plots Bloc if needed for "View Result" navigation
 // import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
 // import 'package:fradar_ui/app/bloc/app_bloc.dart'; // For navigation

class JobListItem extends StatelessWidget {
  final Job job;

  const JobListItem({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(job.status, Theme.of(context));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(_getJobTypeIcon(job.jobType), color: statusColor),
        title: Text('${job.jobType.name.toUpperCase()} Task (${job.taskId.substring(0, 8)})'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${job.statusDetails} (${job.status.name})', style: TextStyle(color: statusColor)),
             if (job.errorMessage != null)
                Text('Error: ${job.errorMessage}', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            Text('Submitted: ${job.submittedAt != null ? dateFormat.format(job.submittedAt!.toLocal()) : 'N/A'}'),
            // TODO: Display relevant parameters from job.parameters nicely
            // Text('Params: ${job.parameters['variable']} @ ${job.parameters['elevation']}°'...)
          ],
        ),
        trailing: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
              // --- Action Buttons ---
              if (job.status == JobStatusEnum.success)
                 IconButton(
                    icon: const Icon(Icons.download_done),
                    color: Colors.green,
                    tooltip: 'Download Result',
                    onPressed: () {
                       // TODO: Trigger download via repository
                       print('TODO: Trigger download for ${job.taskId}');
                       _triggerDownload(context, job);
                    },
                 ),
              // TODO: Add Retry button if job.status == failure
              // TODO: Add Cancel button if job.status == pending/running (if API supports)

              // Delete Button (always available?)
              IconButton(
                 icon: const Icon(Icons.delete_outline),
                 color: Colors.red[300],
                 tooltip: 'Delete Record',
                 onPressed: () {
                     // Optional: Show confirmation dialog
                     context.read<TasksBloc>().add(DeleteTask(job.taskId));
                 },
              ),
           ],
        ),
        isThreeLine: true, // Adjust based on subtitle content
      ),
    );
  }

  IconData _getJobTypeIcon(JobType type) {
     switch(type) {
       case JobType.animation: return Icons.movie_filter_outlined;
       case JobType.timeseries: return Icons.timeline_outlined;
       case JobType.accumulation: return Icons.water_drop_outlined;
       default: return Icons.help_outline;
     }
  }

  Color _getStatusColor(JobStatusEnum status, ThemeData theme) {
     switch(status) {
        case JobStatusEnum.success: return Colors.green;
        case JobStatusEnum.failure: return theme.colorScheme.error;
        case JobStatusEnum.revoked: return Colors.orange;
        case JobStatusEnum.pending: return Colors.blue;
        case JobStatusEnum.running: return Colors.blue; // Same as pending visually?
        default: return theme.disabledColor;
     }
  }

   // Helper to trigger download (avoids repository access directly in widget)
   void _triggerDownload(BuildContext context, Job job) {
      final tasksBloc = context.read<TasksBloc>();
      // Access repository via TasksBloc is not ideal.
      // Better: TasksBloc dispatches an event like DownloadJobResult(job)
      // The bloc then calls repository.downloadAnimationResult(job) etc.
      // For now, just printing.
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Initiating download for ${job.taskId}... (Implementation needed in Bloc/Repo)')),
      );
      // Example: tasksBloc.add(DownloadJobResult(job));
   }
}