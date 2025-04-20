import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/domain/repositories/radproc_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required RadprocRepository radprocRepository})
    : _radprocRepository = radprocRepository,
      super(const SettingsState()) {
    // Initial state
    on<LoadSettings>(_onLoadSettings);
    on<ApiUrlChanged>(_onApiUrlChanged);
    on<SaveSettingsClicked>(_onSaveSettingsClicked);
  }

  final RadprocRepository _radprocRepository;

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: SettingsStatus.loading));
    try {
      final currentUrl = await _radprocRepository.getApiBaseUrl();
      emit(
        state.copyWith(
          apiUrl: currentUrl ?? '', // Use empty string if null
          status: SettingsStatus.loaded,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: 'Failed to load settings: $e',
        ),
      );
    }
  }

  void _onApiUrlChanged(ApiUrlChanged event, Emitter<SettingsState> emit) {
    // Update the URL in the state and mark as editing
    emit(
      state.copyWith(
        apiUrl: event.apiUrl,
        status: SettingsStatus.editing,
        clearError: true,
      ),
    );
  }

  Future<void> _onSaveSettingsClicked(
    SaveSettingsClicked event,
    Emitter<SettingsState> emit,
  ) async {
    // Use the URL currently held in the state
    final urlToSave = state.apiUrl.trim(); // Trim whitespace

    // Optional: Basic URL validation
    if (urlToSave.isEmpty ) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: 'Invalid URL format.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: SettingsStatus.saving, clearError: true));
    try {
      // Save to storage AND update Dio client via repository method
      await _radprocRepository.saveApiBaseUrl(urlToSave);
      emit(state.copyWith(status: SettingsStatus.success));
      // Transition back to loaded state after success message is shown (optional)
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(status: SettingsStatus.loaded));
    } catch (e) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          errorMessage: 'Failed to save settings: $e',
        ),
      );
    }
  }
}
