import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load initial settings.
class LoadSettings extends SettingsEvent {}

/// Event triggered when the API URL text field changes.
class ApiUrlChanged extends SettingsEvent {
  const ApiUrlChanged(this.apiUrl);
  final String apiUrl;

  @override
  List<Object?> get props => [apiUrl];
}

/// Event triggered when the save button is pressed.
class SaveSettingsClicked extends SettingsEvent {}
