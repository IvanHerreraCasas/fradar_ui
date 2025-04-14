// lib/domain/models/plot_frame.dart
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class PlotFrame extends Equatable {
  const PlotFrame({
    required this.datetimeStr, // YYYYMMDD_HHMM format from API
    required this.dateTimeUtc, // Parsed DateTime object
  });

  final String datetimeStr;
  final DateTime dateTimeUtc;

  // Cache the formatter
  static final _parser = DateFormat("yyyyMMdd_HHmm");

  factory PlotFrame.fromJson(Map<String, dynamic> json) {
    final dtStr = json['datetime_str'] as String? ?? '';
    DateTime parsedDt;
    try {
      // Assume the string represents UTC time
      parsedDt = _parser.parseUtc(dtStr);
    } catch (_) {
      // Handle parsing error - use epoch or throw?
      parsedDt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return PlotFrame(datetimeStr: dtStr, dateTimeUtc: parsedDt);
  }

  @override
  List<Object?> get props => [datetimeStr, dateTimeUtc];
}