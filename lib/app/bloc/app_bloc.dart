import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/app/bloc/app_event.dart';
import 'package:fradar_ui/app/bloc/app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) { // Initial state with index 0
    on<NavigationItemSelected>(_onNavigationItemSelected);
  }

  void _onNavigationItemSelected(
      NavigationItemSelected event, Emitter<AppState> emit) {
    emit(state.copyWith(selectedIndex: event.selectedIndex));
  }
}