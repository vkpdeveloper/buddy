import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/growth.dart';
import 'package:buddy/services/body_service.dart';

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
