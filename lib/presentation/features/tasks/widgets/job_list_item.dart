import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_state.dart';
import 'package:intl/intl.dart';
import 'package:fradar_ui/domain/models/job.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_bloc.dart';
import 'package:fradar_ui/presentation/features/tasks/bloc/tasks_event.dart';

class JobListItem extends StatelessWidget {
  final Job job;

  const JobListItem({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(job.status, Theme.of(context));
    // More concise date format maybe
    final paramDateFormat = DateFormat('dd-MM-yy HH:mm');
    final timestampDateFormat = DateFormat('MMM d, HH:mm:ss');
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final subtitleStyle = textTheme.bodySmall?.copyWith(color: theme.hintColor);

    // --- Build Parameter Widgets ---
    final List<Widget> parameterWidgets = _buildParameterWidgets(
      job,
      subtitleStyle,
      paramDateFormat,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1.0,
      child: ListTile(
        leading: Tooltip(
          // Add tooltip to icon
          message: job.jobType.name,
          child: Icon(
            _getJobTypeIcon(job.jobType),
            color: statusColor,
            size: 30,
          ),
        ),
        // --- Title: Type and Status ---
        title: Text(
          '${_formatJobType(job.jobType)} (${job.taskId.substring(0, 8)}) - ${job.status.name.toUpperCase()}',
          style: textTheme.titleSmall?.copyWith(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        // --- Subtitle: Parameters and Timestamps ---
        subtitle: Padding(
          // Add padding for subtitle column
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Important for Column in ListTile
            children: [
              // Display relevant parameters first
              ...parameterWidgets,
              // Then timestamps and errors
              if (job.submittedAt != null)
                Text(
                  'Submitted: ${timestampDateFormat.format(job.submittedAt!.toLocal())}',
                  style: subtitleStyle,
                ),
              if (job.lastCheckedAt != null &&
                  job.lastCheckedAt !=
                      job.submittedAt) // Show only if different
                Text(
                  'Last Check: ${timestampDateFormat.format(job.lastCheckedAt!.toLocal())}',
                  style: subtitleStyle,
                ),
              if (job.errorMessage != null)
                Text(
                  'Error: ${job.errorMessage}',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
        // --- Trailing Actions ---
        trailing: BlocBuilder<TasksBloc, TasksState>(
          // Rebuild actions based on processing state
          // Build only when the processingTaskId changes relevant to this item
          buildWhen:
              (prev, current) =>
                  (prev.processingTaskId == job.taskId &&
                      current.processingTaskId != job.taskId) ||
                  (prev.processingTaskId != job.taskId &&
                      current.processingTaskId == job.taskId),
          builder: (context, state) {
            // Show loading indicator if this task is being processed
            if (state.processingTaskId == job.taskId) {
              return const Padding(
                padding: EdgeInsets.all(8.0), // Adjust padding as needed
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            // Otherwise, show buttons
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildActionButtons(context, job, state), // Pass state
            );
          },
        ),
        // Let ListTile determine if it needs three lines based on content
        // isThreeLine: true, // Remove this, let it adapt
      ),
    );
  }

  // --- Helper Functions ---

  // Helper to format job type name nicely
  String _formatJobType(JobType type) {
    switch (type) {
      case JobType.animation:
        return 'Animation';
      case JobType.timeseries:
        return 'Timeseries';
      case JobType.accumulation:
        return 'Accumulation';
      default:
        return 'Unknown Job';
    }
  }

  // --- Updated Helper to build parameter display widgets ---
  List<Widget> _buildParameterWidgets(
    Job job,
    TextStyle? style,
    DateFormat dateFormat,
  ) {
    final List<Widget> widgets = [];
    final params = job.parameters;

    // --- Job Type Specific Parameters ---
    switch (job.jobType) {
      case JobType.animation:
        if (params['variable'] != null) {
          widgets.add(
            Text(
              'Var: ${params['variable']} @ ${params['elevation']}°',
              style: style,
            ),
          );
        }
        // Could add extent display if needed: if (params['extent'] != null) ...
        break;
      case JobType.timeseries:
        if (params['pointName'] != null) {
          widgets.add(Text('Point: ${params['pointName']}', style: style));
        }
        if (params['variable'] != null) {
          widgets.add(Text('Var: ${params['variable']}', style: style));
        }
        break;
      case JobType.accumulation:
        if (params['pointName'] != null) {
          widgets.add(Text('Point: ${params['pointName']}', style: style));
        }
        if (params['interval'] != null) {
          widgets.add(Text('Interval: ${params['interval']}', style: style));
        }
        if (params['rateVariable'] != null) {
          widgets.add(
            Text('Rate Var: ${params['rateVariable']}', style: style),
          );
        }
        break;
      case JobType.unknown:
        break;
    }

    // --- Date/Time Range (Common to most jobs) ---
    final startDtStr = params['startDt'] as String?;
    final endDtStr = params['endDt'] as String?;
    final startDt = startDtStr != null ? DateTime.tryParse(startDtStr) : null;
    final endDt = endDtStr != null ? DateTime.tryParse(endDtStr) : null;

    if (startDt != null && endDt != null) {
      // Display range in local time for readability
      widgets.add(
        Text(
          'Range: ${dateFormat.format(startDt.toLocal())} - ${dateFormat.format(endDt.toLocal())}',
          style: style,
        ),
      );
    } else if (startDt != null) {
      widgets.add(
        Text('Start: ${dateFormat.format(startDt.toLocal())}', style: style),
      );
    } else if (endDt != null) {
      widgets.add(
        Text('End: ${dateFormat.format(endDt.toLocal())}', style: style),
      );
    }

    // Add spacing if any parameters were added
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 4));
    }
    return widgets;
  }

  // Helper for action buttons
  List<Widget> _buildActionButtons(
    BuildContext context,
    Job job,
    TasksState state,
  ) {
    final bloc = context.read<TasksBloc>();
    final List<Widget> buttons = [];
    final bool canDownload = job.status == JobStatusEnum.success;

    // Download Button (always show if successful?)
    if (canDownload) {
      buttons.add(
        IconButton(
          icon: const Icon(Icons.download_outlined), // Changed icon
          color: Colors.green,
          tooltip: 'Download Result',
          iconSize: 20, // Smaller icon
          onPressed: () {
            // Dispatch the actual download event
            bloc.add(DownloadJobResultRequested(job));
          },
        ),
      );
    }

    // TODO: Add Retry button if job.status == failure
    // TODO: Add Cancel button if job.status == pending/running

    // Delete Button
    buttons.add(
      IconButton(
        icon: const Icon(Icons.delete_forever_outlined), // Changed icon
        color: Colors.red[300],
        tooltip: 'Delete Task Record',
        iconSize: 20, // Smaller icon
        onPressed: () {
          // Optional: Show confirmation
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Delete Task?'),
                  content: Text(
                    'Are you sure you want to delete the record for task ${job.taskId.substring(0, 8)}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        bloc.add(DeleteTask(job.taskId));
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
          );
          // bloc.add(DeleteTask(job.taskId)); // Direct delete without confirmation
        },
      ),
    );

    return buttons;
  }

  IconData _getJobTypeIcon(JobType type) {
    switch (type) {
      case JobType.animation:
        return Icons.movie_filter_outlined;
      case JobType.timeseries:
        return Icons.timeline_outlined;
      case JobType.accumulation:
        return Icons.water_drop_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(JobStatusEnum status, ThemeData theme) {
    switch (status) {
      case JobStatusEnum.success:
        return Colors.green;
      case JobStatusEnum.failure:
        return theme.colorScheme.error;
      case JobStatusEnum.revoked:
        return Colors.orange;
      case JobStatusEnum.pending:
        return Colors.blue;
      case JobStatusEnum.running:
        return Colors.blue; // Same as pending visually?
      default:
        return theme.disabledColor;
    }
  }
}
