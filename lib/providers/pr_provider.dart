import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/pr.dart';
import 'package:buddy/services/workout_service.dart';

final prMapProvider = FutureProvider<Map<String, PersonalRecord>>((ref) async {
  return WorkoutService.getPersonalRecords();
});
