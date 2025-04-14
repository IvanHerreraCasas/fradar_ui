// lib/presentation/features/timeseries/widgets/graph_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:intl/intl.dart';
import 'package:fradar_ui/domain/models/timeseries_datapoint.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_bloc.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_event.dart';
import 'package:fradar_ui/presentation/features/timeseries/bloc/timeseries_state.dart';

class GraphDisplay extends StatelessWidget {
  const GraphDisplay({super.key});

  // Helper to format timestamp for bottom axis
  String _formatTimestamp(
    double timestampMillis,
    DateTime startDt,
    DateTime endDt,
  ) {
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestampMillis.toInt()).toLocal();
    final range = endDt.difference(startDt);
    // Adjust format based on range
    if (range.inDays > 1) {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    } else {
      return DateFormat('HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimeseriesBloc, TimeseriesState>(
      builder: (context, state) {
        final bloc = context.read<TimeseriesBloc>();
        final selectedAndAvailablePoints =
            state.availablePoints
                .where((p) => state.selectedPointNames.contains(p.name))
                .toList(); // Keep original point info

        if (state.selectedPointNames.isEmpty) {
          return const Center(
            child: Text('Select one or more points from the controls panel.'),
          );
        }

        // Show loading or initial message before data is attempted
        if (state.status == TimeseriesStatus.idle ||
            state.status == TimeseriesStatus.pointsLoadError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Ready to load graph data."),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.query_stats),
                  label: const Text('Load Graph Data'),
                  onPressed: () => bloc.add(FetchDataForSelectedPoints()),
                ),
              ],
            ),
          );
        }
        if (state.status == TimeseriesStatus.loadingData &&
            state.pointData.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          ); // Overall loading before first data comes in
        }

        // --- Build List of Charts ---
        return Column(
          children: [
            // Optional: Central "Fetch/Refresh Data" Button? Or rely on auto-fetch? Add explicit button for clarity.
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.query_stats, size: 18),
                label: const Text('Fetch/Refresh Graph Data'),
                onPressed:
                    state.status == TimeseriesStatus.loadingData
                        ? null
                        : () => bloc.add(FetchDataForSelectedPoints()),
              ),
            ),
            const Divider(height: 1),
            // List of charts
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: selectedAndAvailablePoints.length,
                itemBuilder: (context, index) {
                  final point = selectedAndAvailablePoints[index];
                  final pointName = point.name;
                  final data = state.pointData[pointName];
                  final isLoading =
                      state.pointLoadingStatus[pointName] ?? false;
                  final errorMsg = state.pointErrorStatus[pointName];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Title and Status ---
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pointName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              if (errorMsg != null)
                                Tooltip(
                                  message: errorMsg,
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // --- Chart Area ---
                          SizedBox(
                            height: 200, // Fixed height for each chart
                            child:
                                (data != null &&
                                        data.isNotEmpty &&
                                        errorMsg == null)
                                    ? _buildSingleChart(context, state, data)
                                    : Center(
                                      child: Text(
                                        isLoading
                                            ? 'Loading...'
                                            : (errorMsg ??
                                                'No data loaded or error.'),
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 8),

                          // --- Export Button ---
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              // Enable only if data is loaded and no error
                              onPressed:
                                  (data != null &&
                                          data.isNotEmpty &&
                                          errorMsg == null &&
                                          !isLoading)
                                      ? () => bloc.add(
                                        ExportPointDataClicked(pointName),
                                      )
                                      : null,
                              child: const Text(
                                'Export CSV',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper to build a single LineChart
  Widget _buildSingleChart(
    BuildContext context,
    TimeseriesState state,
    List<TimeseriesDataPoint> data,
  ) {
    // Calculate min/max Y specific to this point's data
    double minY = 0;
    double maxY = double.minPositive;
    final spots =
        data.map((dp) {
          if (dp.value.isFinite) {
            if (dp.value < minY) minY = dp.value;
            if (dp.value > maxY) maxY = dp.value;
          }
          return FlSpot(
            dp.timestamp.millisecondsSinceEpoch.toDouble(),
            dp.value.isNaN ? 0 : dp.value,
          );
        }).toList();

    // Adjust Y range slightly
    if (minY >= maxY) {
      minY = 0;
      maxY = 10;
    } else {
      final range = maxY - minY;
      maxY += range * 0.1;
    }

    return LineChart(
      LineChartData(
        clipData: FlClipData.all(),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        minX: state.startDt.millisecondsSinceEpoch.toDouble(),
        maxX: state.endDt.millisecondsSinceEpoch.toDouble(),
        minY: minY,
        maxY: maxY,
        // --- Titles ---
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval:
                  (state.endDt.millisecondsSinceEpoch -
                      state.startDt.millisecondsSinceEpoch) /
                  4, // Fewer labels maybe
              getTitlesWidget:
                  (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 8.0,
                    child: Text(
                      _formatTimestamp(value, state.startDt, state.endDt),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40, // interval: // Auto interval usually okay
              getTitlesWidget:
                  (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 4.0,
                    child: Text(
                      meta.formattedValue,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
            ),
          ),
        ),
        // --- Line Data (Only one line per chart now) ---
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary, // Use theme color
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        // --- Touch Tooltip ---
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            //tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(2)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: _formatTimestamp(
                        barSpot.x,
                        state.startDt,
                        state.endDt,
                      ),
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    ),
                  ],
                  textAlign: TextAlign.left,
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
      duration: const Duration(milliseconds: 150),
    );
  }
}
