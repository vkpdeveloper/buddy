import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/growth.dart';
import 'package:buddy/services/body_service.dart';
import 'package:buddy/services/logs_service.dart';
import 'package:buddy/services/profile_service.dart';

final growthOverviewProvider = FutureProvider<GrowthOverviewData>((ref) async {
  final json = await BodyService.getGrowthOverview();
  return GrowthOverviewData.fromJson(json['data'] as Map<String, dynamic>);
});

final growthPhotosProvider = FutureProvider<List<GrowthPhotoData>>((ref) async {
  final json = await BodyService.getGrowthPhotos();
  final list = (json['data'] as List?) ?? [];
  return list
      .map((e) => GrowthPhotoData.fromJson(e as Map<String, dynamic>))
      .toList();
});

final growthGoalsProvider = FutureProvider<GrowthGoalData>((ref) async {
  final json = await BodyService.getGrowthGoals();
  return GrowthGoalData.fromJson(json['data'] as Map<String, dynamic>);
});

/// Weight and height from the user's profile, set during onboarding.
/// Used as a fallback when no growth logs or Health Connect data are available.
final userProfileMeasurementsProvider =
    FutureProvider<({double? weightKg, double? heightCm})>((ref) async {
  try {
    final res = await ProfileService.getProfile();
    final data = (res['data'] as Map<String, dynamic>?) ?? {};
    final weightKg = (data['weight'] as num?)?.toDouble();
    final heightCm = (data['height'] as num?)?.toDouble();
    return (weightKg: weightKg, heightCm: heightCm);
  } catch (_) {
    return (weightKg: null, heightCm: null);
  }
});

final weeklyCaloriesProvider =
    FutureProvider.family<List<DailyCalorieSummary>, int>(
      (ref, weekOffset) async {
        final res = await LogsService.getWeekLogs(weekOffset: weekOffset);
        final list = (res['data'] as List?) ?? [];
        return list
            .map((e) => DailyCalorieSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
