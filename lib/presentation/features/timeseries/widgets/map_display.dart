// lib/presentation/features/timeseries/widgets/map_display.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fradar_ui/domain/models/point.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_state.dart';

class MapDisplay extends StatefulWidget {
  // Changed to StatefulWidget
  const MapDisplay({super.key});

  @override
  State<MapDisplay> createState() => _MapDisplayState();
}

class _MapDisplayState extends State<MapDisplay> {
  // Create a MapController
  late final MapController _mapController;
  bool _initialCenterSet = false; // Flag to move map only once

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // Initialize controller
  }

  @override
  void dispose() {
    _mapController.dispose(); // Dispose controller
    super.dispose();
  }

  // Helper to calculate center (same as before)
  LatLng _calculateCenter(List<Point> points) {
     if (points.isEmpty) {
       // Use Piura, Peru as default
       return const LatLng(-5.1945, -80.6328);
     }
     double avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
     double avgLon = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
     return LatLng(avgLat, avgLon);
  }

  @override
  Widget build(BuildContext context) {
    // Use BlocListener to react to state changes *after* build
    return BlocListener<TimeseriesBloc, TimeseriesState>(
      listener: (context, state) {
         // Move map center *once* when points become available
         if (!_initialCenterSet && state.availablePoints.isNotEmpty && state.status != TimeseriesStatus.loadingPoints) {
            final center = _calculateCenter(state.availablePoints);
            // Determine points actually selected to potentially adjust zoom/bounds
            final selectedPoints = state.availablePoints.where((p) => state.selectedPointNames.contains(p.name)).toList();
            final centerTarget = selectedPoints.isNotEmpty ? _calculateCenter(selectedPoints) : center; // Center on selected if any, else all
            final double targetZoom = 9.5; // Zoom out more if multiple points selected

            log('MapDisplay Listener: Points loaded, moving map center to $centerTarget', name: "MapDisplay");
            _mapController.move(centerTarget, targetZoom); // Adjust zoom as needed
            setState(() { // Use setState to update the flag within the State object
               _initialCenterSet = true;
            });
         }
         // Reset flag if points are cleared (e.g., error state)
         else if (_initialCenterSet && state.availablePoints.isEmpty) {
            setState(() {
               _initialCenterSet = false;
            });
         }
      },
      // BlocBuilder still needed to build Markers based on current selection
      child: BlocBuilder<TimeseriesBloc, TimeseriesState>(
         buildWhen: (prev, current) => prev.selectedPointNames != current.selectedPointNames || prev.availablePoints != current.availablePoints, // Rebuild markers on selection/point list change
         builder: (context, state) {
            final selectedPoints = state.availablePoints
               .where((p) => state.selectedPointNames.contains(p.name))
               .toList();

            final markers = selectedPoints.map((point) {
              return Marker(
                width: 80.0, height: 80.0,
                point: LatLng(point.latitude, point.longitude),
                child: Tooltip(
                   message: '${point.name}\n${point.description}',
                   child: Icon(Icons.location_pin, color: Colors.red[700], size: 35.0),
                ),
              );
            }).toList();

            // Calculate initial center for the *very first build* before listener acts
            final initialMapCenter = _calculateCenter(state.availablePoints);

            return FlutterMap(
               mapController: _mapController, // Provide the controller
               options: MapOptions(
                 // Initial center is still useful for the very first frame
                 initialCenter: initialMapCenter,
                 initialZoom: 9.5,
                 maxZoom: 18.0,
               ),
               children: [
                 TileLayer(
                   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                   userAgentPackageName: 'com.example.fradar_ui', // Use your app's package name
                 ),
                 if (markers.isNotEmpty) MarkerLayer(markers: markers),
               ],
            );
         },
      ),
    );
  }
}