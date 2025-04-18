import 'package:equatable/equatable.dart';

enum SettingsStatus {
  initial,
  loading,
  loaded,
  editing,
  saving,
  success,
  failure,
}

class SettingsState extends Equatable {
  const SettingsState({
    this.apiUrl = '',
    this.status = SettingsStatus.initial,
    this.errorMessage,
  });

  final String apiUrl; // Current URL in the text field or loaded
  final SettingsStatus status;
  final String? errorMessage;

  SettingsState copyWith({
    String? apiUrl,
    SettingsStatus? status,
    String? errorMessage,
    bool clearError = false, // Helper to clear error message
  }) {
    return SettingsState(
      apiUrl: apiUrl ?? this.apiUrl,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [apiUrl, status, errorMessage];
}
