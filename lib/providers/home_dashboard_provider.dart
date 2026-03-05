import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/home_dashboard.dart';
import 'package:buddy/services/api_client.dart';

String _todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final res = await ApiClient.getHomeSummary(_todayDate());
  return HomeDashboardData.fromJson(res['data'] as Map<String, dynamic>);
});

final weeklyWorkoutSummaryProvider = FutureProvider<WeeklyWorkoutSummary>((
  ref,
) async {
  final res = await ApiClient.getWeeklyWorkoutSummary();
  return WeeklyWorkoutSummary.fromJson(res['data'] as Map<String, dynamic>);
});
