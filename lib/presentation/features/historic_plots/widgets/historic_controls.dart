// lib/presentation/features/historic_plots/widgets/historic_controls.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_bloc.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_event.dart';
import 'package:fradar_ui/presentation/features/historic_plots/bloc/historic_plots_state.dart';

class HistoricControls extends StatefulWidget {
  const HistoricControls({super.key});

  @override
  State<HistoricControls> createState() => _HistoricControlsState();
}

class _HistoricControlsState extends State<HistoricControls> {
  // Controllers for optional region input
  final _minLonController = TextEditingController();
  final _maxLonController = TextEditingController();
  final _minLatController = TextEditingController();
  final _maxLatController = TextEditingController();

  // Controllers to *display* selected dates/times (not for direct input)
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // TODO: Get these lists from config/points later
  final List<String> _variables = const ['RATE', 'DBZ', 'VR', 'WIDTH'];
  final List<double> _elevations = const [
    2.5,
    3.5,
    4.5,
    5.5,
    7.5,
    10.0,
    12.5,
    15.0,
  ];
  // Date Formatter for display
  final _displayFormatter = DateFormat(
    'yyyy-MM-dd HH:mm',
  ); // Local time display format

  Future<void> _selectStartDateTime(
    BuildContext context,
    HistoricPlotsState currentState,
  ) async {
    final bloc = context.read<HistoricPlotsBloc>();
    final now = DateTime.now();
    final firstAllowedDate = DateTime(2020);

    // --- Pick Start Date ---
    final DateTime? startDate = await showDatePicker(
      context: context,
      initialDate: currentState.startDt.toLocal(),
      firstDate: firstAllowedDate,
      lastDate: currentState.endDt.toLocal(), // Start cannot be after End
    );
    if (startDate == null || !context.mounted) return;

    // --- Pick Start Time ---
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentState.startDt.toLocal()),
    );
    if (startTime == null) return;

    // Combine and Validate
    final newStartDtLocal = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );

    // Ensure new Start is not after existing End
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
      return; // Don't update if invalid relative to end time
    }

    // Dispatch Event with UTC DateTime
    bloc.add(ParametersChanged(startDt: newStartDtLocal.toUtc()));
  }

  // --- Helper Function for End DateTime Selection ---
  Future<void> _selectEndDateTime(
    BuildContext context,
    HistoricPlotsState currentState,
  ) async {
    final bloc = context.read<HistoricPlotsBloc>();
    final now = DateTime.now();

    // --- Pick End Date ---
    final DateTime? endDate = await showDatePicker(
      context: context,
      initialDate: currentState.endDt.toLocal(),
      firstDate: currentState.startDt.toLocal(), // End cannot be before Start
      lastDate: now.add(const Duration(days: 1)),
    );
    if (endDate == null || !context.mounted) return;

    // --- Pick End Time ---
    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentState.endDt.toLocal()),
    );
    if (endTime == null) return;

    // Combine and Validate
    final newEndDtLocal = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      endTime.hour,
      endTime.minute,
    );

    // Ensure new End is after existing Start
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
      return; // Don't update if invalid relative to start time
    }

    // Dispatch Event with UTC DateTime
    bloc.add(ParametersChanged(endDt: newEndDtLocal.toUtc()));
  }

  @override
  void dispose() {
    _minLonController.dispose();
    _maxLonController.dispose();
    _minLatController.dispose();
    _maxLatController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  // Helper to parse region text fields
  List<double>? _parseRegion() {
    final minLon = double.tryParse(_minLonController.text);
    final maxLon = double.tryParse(_maxLonController.text);
    final minLat = double.tryParse(_minLatController.text);
    final maxLat = double.tryParse(_maxLatController.text);

    if (minLon != null && maxLon != null && minLat != null && maxLat != null) {
      // Basic validation: min < max
      if (minLon < maxLon && minLat < maxLat) {
        return [minLon, maxLon, minLat, maxLat];
      }
    }
    return null; // Return null if any field is invalid or validation fails
  }

  @override
  Widget build(BuildContext context) {
    // Use BlocBuilder to access state for default values and disabling controls
    return BlocBuilder<HistoricPlotsBloc, HistoricPlotsState>(
      builder: (context, state) {
        final bloc = context.read<HistoricPlotsBloc>();
        final bool interactionDisabled =
            !state.canGenerateOrExport; // Disable if job is running

        
        // Update display fields when state changes (showing local time)
        _startDateController.text = _displayFormatter.format(state.startDt.toLocal());
        _endDateController.text = _displayFormatter.format(state.endDt.toLocal());

        // Update controllers if state changes (and not currently editing - basic check)
        // This could be more sophisticated to avoid disrupting user input
        final currentRegion = state.region;
        if (currentRegion != null && currentRegion.length == 4) {
          if (currentRegion[0].toString() != _minLonController.text)
            _minLonController.text = currentRegion[0].toString();
          if (currentRegion[1].toString() != _maxLonController.text)
            _maxLonController.text = currentRegion[1].toString();
          if (currentRegion[2].toString() != _minLatController.text)
            _minLatController.text = currentRegion[2].toString();
          if (currentRegion[3].toString() != _maxLatController.text)
            _maxLatController.text = currentRegion[3].toString();
        } else {
          // Clear fields if region is null in state and fields are not empty
          if (_minLonController.text.isNotEmpty) _minLonController.clear();
          if (_maxLonController.text.isNotEmpty) _maxLonController.clear();
          if (_minLatController.text.isNotEmpty) _minLatController.clear();
          if (_maxLatController.text.isNotEmpty) _maxLatController.clear();
        }

        return SingleChildScrollView(
          // Allow scrolling if content overflows
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Make buttons fill width
            children: [
              Text('Parameters', style: Theme.of(context).textTheme.titleLarge),
              const Divider(),

              // --- Variable ---
              DropdownButtonFormField<String>(
                value: state.variable,
                items:
                    _variables
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged:
                    interactionDisabled
                        ? null
                        : (value) {
                          if (value != null)
                            bloc.add(ParametersChanged(variable: value));
                        },
                decoration: const InputDecoration(
                  labelText: 'Variable',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // --- Elevation ---
              DropdownButtonFormField<double>(
                value: state.elevation,
                items:
                    _elevations
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('${e.toStringAsFixed(1)}°'),
                          ),
                        )
                        .toList(),
                onChanged:
                    interactionDisabled
                        ? null
                        : (value) {
                          if (value != null)
                            bloc.add(ParametersChanged(elevation: value));
                        },
                decoration: const InputDecoration(
                  labelText: 'Elevation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // --- Date Range ---
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
                            : () => _selectStartDateTime(context, state),
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
                            : () => _selectEndDateTime(context, state),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- Region (Optional) ---
              Text(
                'Region (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinateInput(
                      _minLonController,
                      'Min Lon',
                      interactionDisabled,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildCoordinateInput(
                      _maxLonController,
                      'Max Lon',
                      interactionDisabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinateInput(
                      _minLatController,
                      'Min Lat',
                      interactionDisabled,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _buildCoordinateInput(
                      _maxLatController,
                      'Max Lat',
                      interactionDisabled,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        interactionDisabled
                            ? null
                            : () => bloc.add(
                              ParametersChanged(region: _parseRegion()),
                            ),
                    child: const Text('Apply Region'),
                  ),
                  TextButton(
                    onPressed:
                        (interactionDisabled || state.region == null)
                            ? null
                            : () => bloc.add(
                              const ParametersChanged(region: null),
                            ), // Clear region event needed
                    child: const Text('Clear Region'),
                  ),
                ],
              ),
              const Divider(),

              // --- Action Button ---
              ElevatedButton(
                onPressed:
                    interactionDisabled
                        ? null
                        : () {
                          if (state.variable == 'RATE') {
                            bloc.add(FetchFrames());
                          } else {
                            bloc.add(GenerateOrExportAnimation());
                          }
                        },
                // Change label based on variable
                child: Text(
                  state.variable == 'RATE'
                      ? 'Fetch Frames'
                      : 'Generate Animation',
                ),
              ),
              const SizedBox(height: 10),

              // Optional: Show active job status if monitoring
              if (state.status == HistoricPlotsStatus.submittingJob ||
                  state.status == HistoricPlotsStatus.monitoringJob)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.status == HistoricPlotsStatus.submittingJob
                              ? 'Submitting Job...'
                              : 'Monitoring Job: ${state.activeJob?.taskId.substring(0, 8) ?? '...'} - ${state.activeJob?.statusDetails ?? ''}',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Helper for coordinate input fields
  Widget _buildCoordinateInput(
    TextEditingController controller,
    String label,
    bool disabled,
  ) {
    return TextFormField(
      controller: controller,
      enabled: !disabled,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^-?\d*\.?\d*'),
        ), // Allow digits, decimal, minus
      ],
    );
  }
}
