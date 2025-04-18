import 'package:equatable/equatable.dart';

class AppState extends Equatable {
  const AppState({this.selectedIndex = 0}); // Default to first item

  final int selectedIndex;

  AppState copyWith({int? selectedIndex}) {
    return AppState(selectedIndex: selectedIndex ?? this.selectedIndex);
  }

  @override
  List<Object> get props => [selectedIndex];
}
