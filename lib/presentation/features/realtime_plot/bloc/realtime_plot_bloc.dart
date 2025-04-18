import 'dart:async';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/models/plot_update.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'realtime_plot_event.dart';
import 'realtime_plot_state.dart';

class RealtimePlotBloc extends Bloc<RealtimePlotEvent, RealtimePlotState> {
  final RadprocRepository _radprocRepository;
  StreamSubscription<PlotUpdate>? _sseSubscription;
  // TODO: Add subscription for SSE connection state changes if needed

  RealtimePlotBloc({required RadprocRepository radprocRepository})
    : _radprocRepository = radprocRepository,
      super(const RealtimePlotState()) {
    // Initial state

    on<LoadRealtimePlot>(_onLoadRealtimePlot);
    on<VariableSelected>(_onVariableSelected);
    on<ElevationSelected>(_onElevationSelected);
    on<SsePlotUpdateReceived>(_onSsePlotUpdateReceived);
    on<SseErrorOccurred>(_onSseErrorOccurred);

    // Start listening to SSE updates immediately
    _listenToSseUpdates();
  }

  void _listenToSseUpdates() {
    // Ensure any previous subscription is cancelled
    _sseSubscription?.cancel();
    log('Bloc: Subscribing to SSE plot updates...', name: "RealtimePlotBloc");
    _sseSubscription = _radprocRepository.getPlotUpdates().listen(
      (update) {
        // Add internal event when update received
        add(SsePlotUpdateReceived(update));
      },
      onError: (error) {
        log('Bloc: SSE Stream error: $error', name: "RealtimePlotBloc");
        add(SseErrorOccurred(error)); // Add internal error event
      },
      onDone: () {
        log('Bloc: SSE Stream closed.', name: "RealtimePlotBloc");
        // Optionally update SSE status message in state
      },
    );
    // TODO: Listen to SSE connection state if SseService exposes it
    // and update state.sseStatusMessage accordingly.
  }

  Future<void> _onLoadRealtimePlot(
    LoadRealtimePlot event,
    Emitter<RealtimePlotState> emit,
  ) async {
    emit(
      state.copyWith(
        status: RealtimePlotStatus.loading,
        clearError: true,
        clearPlotData: true,
      ),
    );
    try {
      final imageData = await _radprocRepository.fetchRealtimePlot(
        state.selectedVariable,
        state.selectedElevation,
      );
      emit(
        state.copyWith(
          status: RealtimePlotStatus.success,
          plotImageData: imageData,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RealtimePlotStatus.error,
          errorMessage: 'Failed to load plot: $e',
        ),
      );
    }
  }

  void _onVariableSelected(
    VariableSelected event,
    Emitter<RealtimePlotState> emit,
  ) {
    if (event.variable != state.selectedVariable) {
      emit(state.copyWith(selectedVariable: event.variable));
      add(LoadRealtimePlot()); // Reload plot for new variable
    }
  }

  void _onElevationSelected(
    ElevationSelected event,
    Emitter<RealtimePlotState> emit,
  ) {
    if (event.elevation != state.selectedElevation) {
      emit(state.copyWith(selectedElevation: event.elevation));
      add(LoadRealtimePlot()); // Reload plot for new elevation
    }
  }

  void _onSsePlotUpdateReceived(
    SsePlotUpdateReceived event,
    Emitter<RealtimePlotState> emit,
  ) {
    // Check if the update matches the currently selected parameters
    if (event.update.variable == state.selectedVariable &&
        event.update.elevation == state.selectedElevation) {
      log(
        'Bloc: Relevant SSE update received. Reloading plot.',
        name: "RealtimePlotBloc",
      );
      add(LoadRealtimePlot()); // Trigger reload
    } else {
      log(
        'Bloc: Ignoring irrelevant SSE update for ${event.update.variable}/${event.update.elevation}',
        name: "RealtimePlotBloc",
      );
    }
  }

  void _onSseErrorOccurred(
    SseErrorOccurred event,
    Emitter<RealtimePlotState> emit,
  ) {
    // Update SSE status message, maybe show persistent error?
    emit(state.copyWith(sseStatusMessage: 'SSE Error: ${event.error}'));
  }

  @override
  Future<void> close() {
    _sseSubscription?.cancel();
    // Note: Repository dispose (which disposes SseService) should happen elsewhere
    return super.close();
  }
}
