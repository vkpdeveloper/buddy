import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/models/body_measurement.dart';

/// All body measurement entries (for sparkline charts), newest first.
final bodyHistoryProvider = FutureProvider<List<BodyMeasurement>>((ref) async {
  final res = await ApiClient.getBodyHistory();
  final list = (res['data'] as List?) ?? [];
  return list
      .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// The single most recent measurement — used to pre-fill the log form and show
/// delta values on the chart tiles.
final latestBodyMeasurementProvider = FutureProvider<BodyMeasurement?>((
  ref,
) async {
  final res = await ApiClient.getLatestBodyMeasurement();
  final data = res['data'];
  if (data == null) return null;
  return BodyMeasurement.fromJson(data as Map<String, dynamic>);
});
