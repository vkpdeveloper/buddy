import 'dart:convert';
import 'package:buddy/models/pr.dart';
import 'package:buddy/models/exercise_catalog.dart';
import 'package:buddy/services/api_base.dart';

final class WorkoutService extends ApiBase {
  static Future<Map<String, dynamic>> listWorkoutPlans() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/workout/plans'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutPlan(int id) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/workout/plans/$id'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getWeeklyWorkoutSummary() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/workout/summary/weekly'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> generateWorkoutPlan() async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/workout/generate'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateExercise(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/workout/exercises/$id'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> replaceWorkoutExercise(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/workout/exercises/$id/replace'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> deleteWorkoutExercise(int id) async {
    final res = await ApiBase.client.delete(
      Uri.parse('${ApiBase.baseUrl}/api/workout/exercises/$id'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> startSession(
    int planId,
    int dayId, {
    String? date,
  }) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/workout/sessions'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'planId': planId, 'dayId': dayId, 'date': date}),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getTodayWorkoutSessionStatus(
    int planId,
    int dayId, {
    required String date,
  }) async {
    final uri = Uri.parse(
      '${ApiBase.baseUrl}/api/workout/sessions/today',
    ).replace(
      queryParameters: {
        'planId': '$planId',
        'dayId': '$dayId',
        'date': date,
      },
    );
    final res = await ApiBase.client.get(uri, headers: await ApiBase.authHeaders());
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSession(int id) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/workout/sessions/$id'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSessionHistory({
    String range = '30d',
  }) async {
    final uri = Uri.parse(
      '${ApiBase.baseUrl}/api/workout/sessions/history',
    ).replace(queryParameters: {'range': range});
    final res = await ApiBase.client.get(uri, headers: await ApiBase.authHeaders());
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> logWorkoutSession(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/workout/sessions/$id/log'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> completeSession(
    int id,
    int durationSeconds,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/workout/sessions/$id'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({
        'completedAt': DateTime.now().toIso8601String(),
        'totalDurationSeconds': durationSeconds,
      }),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> completeSessionWithGamification(
    int id, {
    required int durationSeconds,
    required int totalExercises,
    required int completedExercises,
    required int totalRests,
    required int skippedRests,
    required int completedSets,
    int? pausedDurationSeconds,
    Map<String, dynamic>? warmupData,
    Map<String, dynamic>? cooldownData,
    List<Map<String, dynamic>>? setLogs,
    List<Map<String, dynamic>>? sessionNotes,
    List<Map<String, dynamic>>? hrSnapshots,
    String? dayLabel,
  }) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/workout/sessions/$id/complete'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({
        'totalDurationSeconds': durationSeconds,
        'totalExercises': totalExercises,
        'completedExercises': completedExercises,
        'totalRests': totalRests,
        'skippedRests': skippedRests,
        'completedSets': completedSets,
        'pausedDurationSeconds': pausedDurationSeconds,
        'warmupData': warmupData,
        'cooldownData': cooldownData,
        'setLogs': setLogs,
        'sessionNotes': sessionNotes,
        'hrSnapshots': hrSnapshots,
        'dayLabel': dayLabel,
      }),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, PersonalRecord>> getPersonalRecords() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/exercises/prs'),
      headers: await ApiBase.authHeaders(),
    );
    final decoded = ApiBase.decode(res);
    final rawMap = (decoded['data'] as Map<String, dynamic>?) ?? {};
    return rawMap.map(
      (key, value) =>
          MapEntry(key, PersonalRecord.fromJson(value as Map<String, dynamic>)),
    );
  }

  static Future<List<ExerciseCatalogItem>> getExerciseCatalog({
    String? muscleGroup,
  }) async {
    final uri = Uri.parse('${ApiBase.baseUrl}/api/exercises').replace(
      queryParameters: muscleGroup != null
          ? {'muscleGroup': muscleGroup}
          : null,
    );
    final res = await ApiBase.client.get(uri, headers: await ApiBase.authHeaders());
    final decoded = ApiBase.decode(res);
    final list = (decoded['data'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ExerciseCatalogItem.fromJson)
        .toList();
  }

  static Future<void> addExerciseToDay(
    int dayId,
    ExerciseCatalogItem exercise,
  ) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/workout/days/$dayId/exercises'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({
        'name': exercise.name,
        'muscleGroup': exercise.muscleGroup,
        'equipment': exercise.equipment,
        'category': exercise.category,
        'notes': exercise.notes,
        'sets': 3,
        'repsOrTime': '10-12',
        'restSeconds': 60,
      }),
    );
    ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> regenerateWorkoutPlan({
    required int planId,
    String? constraints,
  }) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/workout/regenerate'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'planId': planId, 'constraints': constraints ?? ''}),
    );
    return ApiBase.decode(res);
  }
}
