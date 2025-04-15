// lib/presentation/features/timeseries/widgets/timeseries_controls.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/models/point.dart'; // Import Point model
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_event.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_state.dart';
import 'package:fradar_ui/presentation/shared_widgets/variable_selector.dart';

class TimeseriesControls extends StatefulWidget {
  // Changed back to StatefulWidget
  const TimeseriesControls({super.key});

  @override
  State<TimeseriesControls> createState() => _TimeseriesControlsState();
}

class _TimeseriesControlsState extends State<TimeseriesControls> {
  // Changed back
  // Add back display controllers
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // Date Formatter for display
  final _displayFormatter = DateFormat('yyyy-MM-dd HH:mm');

  // --- Re-introduce Helper Function for Start DateTime Selection ---
  Future<void> _selectStartDateTime(
    BuildContext context,
    TimeseriesState currentState,
  ) async {
    final bloc = context.read<TimeseriesBloc>();
    final now = DateTime.now();
    final firstAllowedDate = DateTime(2020);

    final DateTime? startDate = await showDatePicker(
      context: context,
      initialDate: currentState.startDt.toLocal(),
      firstDate: firstAllowedDate,
      lastDate: currentState.endDt.toLocal(),
    );
    if (startDate == null || !context.mounted) return;

    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentState.startDt.toLocal()),
    );
    if (startTime == null) return;

    final newStartDtLocal = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );

    if (newStartDtLocal.isAfter(currentState.endDt.toLocal())) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Start time cannot be after the current end time.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    bloc.add(
      DateTimeRangeChanged(
        start: newStartDtLocal.toUtc(),
        end: currentState.endDt,
      ),
    ); // Keep current end
  }
  // --- End Helper Function ---

  // --- Re-introduce Helper Function for End DateTime Selection ---
  Future<void> _selectEndDateTime(
    BuildContext context,
    TimeseriesState currentState,
  ) async {
    final bloc = context.read<TimeseriesBloc>();
    final now = DateTime.now();

    final DateTime? endDate = await showDatePicker(
      context: context,
      initialDate: currentState.endDt.toLocal(),
      firstDate: currentState.startDt.toLocal(),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (endDate == null || !context.mounted) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentState.endDt.toLocal()),
    );
    if (endTime == null) return;

    final newEndDtLocal = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (newEndDtLocal.isBefore(currentState.startDt.toLocal()) ||
        newEndDtLocal.isAtSameMomentAs(currentState.startDt.toLocal())) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('End time must be after the current start time.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    bloc.add(
      DateTimeRangeChanged(
        start: currentState.startDt,
        end: newEndDtLocal.toUtc(),
      ),
    ); // Keep current start
  }
  // --- End Helper Function ---

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimeseriesBloc, TimeseriesState>(
      listener: (context, state) {
        // Update display fields when state changes (showing local time)
        final formattedStart = _displayFormatter.format(
          state.startDt.toLocal(),
        );
        final formattedEnd = _displayFormatter.format(state.endDt.toLocal());
        if (_startDateController.text != formattedStart)
          _startDateController.text = formattedStart;
        if (_endDateController.text != formattedEnd)
          _endDateController.text = formattedEnd;
      },
      child: BlocBuilder<TimeseriesBloc, TimeseriesState>(
        // buildWhen can be optimized further if needed
        buildWhen:
            (prev, current) => true, // Rebuild on most state changes for now
        builder: (context, state) {
          final bloc = context.read<TimeseriesBloc>();
          final bool interactionDisabled =
              state.status == TimeseriesStatus.loadingPoints ||
              state.status == TimeseriesStatus.loadingData;

          // Initial update for display controllers
          if (_startDateController.text.isEmpty) {
            _startDateController.text = _displayFormatter.format(
              state.startDt.toLocal(),
            );
          }
          if (_endDateController.text.isEmpty) {
            _endDateController.text = _displayFormatter.format(
              state.endDt.toLocal(),
            );
          }

          
          final currentSelectedVariable = state.selectedVariable;

          return Scaffold(
            backgroundColor: Theme.of(context).canvasColor,
            appBar: AppBar(
              title: const Text('Controls'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
            ),
            body:
                state.status == TimeseriesStatus.loadingPoints
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      padding: const EdgeInsets.all(12.0),
                      children: [
                        // Variable Dropdown
                        VariableSelector(
                          precipitation: true,
                          selectedVariable: currentSelectedVariable,
                          onChanged:
                              interactionDisabled
                                  ? null
                                  : (value) {
                                    if (value != null) {
                                      bloc.add(VariableSelected(value));
                                    }
                                  },
                        ),
                        const SizedBox(height: 10),

                        // Interval Selector (Conditional)
                        if (state.isAccumulationSelected) ...[
                          DropdownButtonFormField<String>(
                            value: state.selectedInterval,
                            items:
                                TimeseriesState.defaultIntervals
                                    .map(
                                      (i) => DropdownMenuItem(
                                        value: i,
                                        child: Text(i),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                interactionDisabled
                                    ? null
                                    : (value) {
                                      if (value != null) {
                                        bloc.add(IntervalSelected(value));
                                      }
                                    },
                            decoration: const InputDecoration(
                              labelText: 'Accumulation Interval',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // --- Start DateTime ---
                        TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Start DateTime (Local)',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              tooltip: 'Select Start Date/Time',
                              onPressed:
                                  interactionDisabled
                                      ? null
                                      : () =>
                                          _selectStartDateTime(context, state),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // --- End DateTime ---
                        TextFormField(
                          controller: _endDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'End DateTime (Local)',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              tooltip: 'Select End Date/Time',
                              onPressed:
                                  interactionDisabled
                                      ? null
                                      : () =>
                                          _selectEndDateTime(context, state),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Points List
                        Text(
                          'Points',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        if (state.availablePoints.isEmpty &&
                            state.status != TimeseriesStatus.loadingPoints)
                          const Text('No points available.'),
                        ...state.availablePoints.map((point) {
                          // Use spread operator
                          final bool isSelected = state.selectedPointNames
                              .contains(point.name);
                          final bool isLoading =
                              state.pointLoadingStatus[point.name] ?? false;
                          final String? errorMsg =
                              state.pointErrorStatus[point.name];
                          return CheckboxListTile(
                            title: Text(point.name),
                            subtitle: Text(
                              point.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: isSelected,
                            onChanged:
                                interactionDisabled
                                    ? null
                                    : (bool? value) {
                                      if (value != null) {
                                        bloc.add(
                                          PointSelectionChanged(
                                            point.name,
                                            value,
                                          ),
                                        );
                                      }
                                    },
                            //secondary: isLoading ? const SizedBox(/*...*/) : (errorMsg != null ? Icon(/*...*/) : null),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }).toList(), // Convert iterable to list

                        const SizedBox(height: 20),
                        // "Load Graph Data" button (moved here?) - Or keep in GraphDisplay? Let's keep it in GraphDisplay for now.
                      ],
                    ),
          );
        },
      ),
    );
  }


}
