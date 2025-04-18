// lib/presentation/navigation/expandable_sidebar.dart
import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fradar_ui/app/bloc/app_bloc.dart';
import 'package:fradar_ui/app/bloc/app_event.dart';

class ExpandableSidebar extends StatefulWidget {
  const ExpandableSidebar({super.key});

  @override
  State<ExpandableSidebar> createState() => _ExpandableSidebarState();
}

class _ExpandableSidebarState extends State<ExpandableSidebar> {
  bool _isExpanded = false;
  Timer? _collapseTimer; // Timer for delayed collapse

  // Define navigation destinations
  final List<NavigationRailDestination> _destinations = const [
     NavigationRailDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar),
      label: Text('Realtime'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text('Historic'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: Text('Timeseries'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: Text('Tasks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  void _expandSidebar() {
    _collapseTimer?.cancel(); // Cancel any pending collapse
    if (!_isExpanded) {
      setState(() {
        _isExpanded = true;
      });
    }
  }

  void _startCollapseTimer() {
     // Start a timer to collapse after a short delay (e.g., 300ms)
     _collapseTimer = Timer(const Duration(milliseconds: 300), () {
         if (mounted && _isExpanded) { // Check if widget is still mounted
            setState(() {
              _isExpanded = false;
            });
         }
     });
  }

  @override
  void dispose() {
     _collapseTimer?.cancel(); // Clean up timer
     super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.select((AppBloc bloc) => bloc.state.selectedIndex);

    // Use MouseRegion to detect hover
    return MouseRegion(
      onEnter: (_) => _expandSidebar(), // Expand when mouse enters
      onExit: (_) => _startCollapseTimer(), // Start timer to collapse when mouse exits
      child: Material(
        elevation: 2.0,
        child: AnimatedContainer( // Add animation for smoother width change
          duration: const Duration(milliseconds: 200),
          width: _isExpanded ? 180 : 72, // Define collapsed and expanded widths
          color: Theme.of(context).canvasColor,
          child: Column(
            children: [
              // Removed the toggle button
              const SizedBox(height: 16), // Add some padding at the top
              Expanded(
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    context.read<AppBloc>().add(NavigationItemSelected(index));
                  },
                  // Use extended=true always, width is controlled by AnimatedContainer
                  extended: _isExpanded,
                  minExtendedWidth: 180, // Keep this for layout calculations
                  // Labels are now always shown when extended is true implicitly
                  // labelType: NavigationRailLabelType.none, // Let extended handle labels
                  destinations: _destinations,
                  // Use leading/trailing for consistent elements if needed
                  // leading: SizedBox(height: 40), // Example placeholder
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}