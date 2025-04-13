import 'package:equatable/equatable.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();
}

class NavigationItemSelected extends AppEvent {
  const NavigationItemSelected(this.selectedIndex);
  final int selectedIndex;

  @override
  List<Object> get props => [selectedIndex];
}