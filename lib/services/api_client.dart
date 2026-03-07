import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:buddy/config/env.dart';
import 'package:buddy/models/pr.dart';
import 'package:buddy/models/exercise_catalog.dart';
import 'package:buddy/providers/clerk_auth_provider.dart';

class ApiClient {
  static String get baseUrl => EnvInstance.instance.apiBaseUrl;

  static final _client = http.Client();

  static Future<Map<String, String>> _authHeaders() async {
    final token = await ClerkAuthProvider.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Profile ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<bool> isProfileCompleted() async {
    try {
      final res = await getProfile();
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return false;
      return data['profile_completed'] == true ||
          data['profile_completed'] == 1;
    } catch (_) {
      // 404 (no profile) or any other error → not completed
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/profile'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  // ─── Diet Plans ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listDietPlans() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/plans'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietPlan(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/plans/$id'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateDietPlan() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/diet/generate'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietFoods() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/foods'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateMeal(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/meals/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietLog(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/log/$date'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logMealCompletion(
    String date,
    int mealId,
    bool isCompleted,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/log/$date'),
      headers: await _authHeaders(),
      body: jsonEncode({'mealId': mealId, 'isCompleted': isCompleted}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logActualMeal(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/log/$date/actual'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateDietDay(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/days/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> reorderDietMeals(
    int dayId,
    List<int> mealIds,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/days/$dayId/reorder'),
      headers: await _authHeaders(),
      body: jsonEncode({'mealIds': mealIds}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> deleteDietPlan(int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/diet/plans/$id'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ─── Workout Plans ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listWorkoutPlans() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/plans'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutPlan(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/plans/$id'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWeeklyWorkoutSummary() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/summary/weekly'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateWorkoutPlan() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/generate'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateExercise(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/exercises/$id'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> replaceWorkoutExercise(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/exercises/$id/replace'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> deleteWorkoutExercise(int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/workout/exercises/$id'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> startSession(
    int planId,
    int dayId, {
    String? date,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/sessions'),
      headers: await _authHeaders(),
      body: jsonEncode({'planId': planId, 'dayId': dayId, 'date': date}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getTodayWorkoutSessionStatus(
    int planId,
    int dayId, {
    required String date,
  }) async {
    final uri = Uri.parse('$baseUrl/api/workout/sessions/today').replace(
      queryParameters: {'planId': '$planId', 'dayId': '$dayId', 'date': date},
    );
    final res = await _client.get(uri, headers: await _authHeaders());
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSession(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/sessions/$id'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSessionHistory({
    String range = '30d',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/workout/sessions/history',
    ).replace(queryParameters: {'range': range});
    final res = await _client.get(uri, headers: await _authHeaders());
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logWorkoutSession(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/sessions/$id/log'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> completeSession(
    int id,
    int durationSeconds,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/sessions/$id'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'completedAt': DateTime.now().toIso8601String(),
        'totalDurationSeconds': durationSeconds,
      }),
    );
    return _decode(res);
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
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/sessions/$id/complete'),
      headers: await _authHeaders(),
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
    return _decode(res);
  }

  // ─── Exercises & PRs ─────────────────────────────────────────────────

  static Future<Map<String, PersonalRecord>> getPersonalRecords() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/exercises/prs'),
      headers: await _authHeaders(),
    );
    final decoded = _decode(res);
    final rawMap = (decoded['data'] as Map<String, dynamic>?) ?? {};
    return rawMap.map(
      (key, value) =>
          MapEntry(key, PersonalRecord.fromJson(value as Map<String, dynamic>)),
    );
  }

  static Future<List<ExerciseCatalogItem>> getExerciseCatalog({
    String? muscleGroup,
  }) async {
    final uri = Uri.parse('$baseUrl/api/exercises').replace(
      queryParameters: muscleGroup != null
          ? {'muscleGroup': muscleGroup}
          : null,
    );
    final res = await _client.get(uri, headers: await _authHeaders());
    final decoded = _decode(res);
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
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/days/$dayId/exercises'),
      headers: await _authHeaders(),
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
    _decode(res);
  }

  static Future<Map<String, dynamic>> regenerateWorkoutPlan({
    required int planId,
    String? constraints,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/regenerate'),
      headers: await _authHeaders(),
      body: jsonEncode({'planId': planId, 'constraints': constraints ?? ''}),
    );
    return _decode(res);
  }

  // ─── Progress ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProgress() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/progress'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getAchievements() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/progress/achievements'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ─── Daily Logs ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDailyLog(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/$date'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateDailyLog(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/logs/$date'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWeekLogs() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/week'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getHomeSummary(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/home-summary/$date'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> incrementHydration(
    String date, {
    int amountMl = 250,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/logs/$date/hydration/increment'),
      headers: await _authHeaders(),
      body: jsonEncode({'amountMl': amountMl}),
    );
    return _decode(res);
  }

  // ─── Body Measurements ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> logBodyMeasurement(
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/body/log'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getBodyHistory() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/history'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getLatestBodyMeasurement() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/latest'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthOverview() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/growth'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthPhotos() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/photos'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> uploadGrowthPhoto({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String date,
    int? measurementId,
    String note = '',
  }) async {
    final token = await ClerkAuthProvider.instance.getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/body/photos'),
    );
    req.fields['date'] = date;
    req.fields['note'] = note;
    req.fields['mimeType'] = mimeType;
    if (measurementId != null && measurementId > 0) {
      req.fields['measurementId'] = '$measurementId';
    }
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthGoals() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/goals'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateGrowthGoals({
    double? weightGoalKg,
    double? bodyFatGoalPercent,
  }) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/body/goals'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'weightGoalKg': weightGoalKg,
        'bodyFatGoalPercent': bodyFatGoalPercent,
      }),
    );
    return _decode(res);
  }

  // ─── Meal Media ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadMealPhoto(
    File photo,
    String mimeType,
  ) async {
    final token = await ClerkAuthProvider.instance.getToken();
    final bytes = await photo.readAsBytes();
    final fileName = photo.path.split('/').last;
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/diet/media/upload'),
    );
    req.fields['mimeType'] = mimeType;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> analyzeMealPhoto(int attachmentId) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/diet/media/$attachmentId/analyze'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logQuickMeal(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/diet/log/$date/quick'),
      headers: await _authHeaders(),
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getMealAttachment(int attachmentId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/media/$attachmentId'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ─── Buddy AI Chat ────────────────────────────────────────────────────

  /// Streams chat tokens from Buddy AI via SSE.
  /// Properly parses SSE by accumulating bytes and splitting on the \n\n
  /// event boundary — prevents half-event reads from dropping tokens.
  static Stream<String> buddyChat(
    List<Map<String, dynamic>> messages,
  ) async* {
    final token = await ClerkAuthProvider.instance.getToken();
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/buddy/chat'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.body = jsonEncode({'messages': messages});

    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }

    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw Exception('Buddy chat ${response.statusCode}: $body');
    }

    // Buffer accumulates raw bytes until we have a complete SSE event (\n\n).
    final buffer = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var content = buffer.toString();

      // SSE events are separated by a blank line (\n\n).
      // Process every complete event before the last incomplete one.
      while (content.contains('\n\n')) {
        final boundary = content.indexOf('\n\n');
        final event = content.substring(0, boundary);
        content = content.substring(boundary + 2); // skip past \n\n

        for (final line in event.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6); // do NOT trim — JSON strings preserve whitespace
          if (data == '[DONE]' || data == '[ERROR]' || data.isEmpty) continue;
          try {
            final text = jsonDecode(data) as String;
            if (text.isNotEmpty) yield text;
          } catch (_) {
            // Malformed JSON chunk — skip silently
          }
        }
      }

      // Stash the incomplete trailing event back into the buffer
      buffer.clear();
      buffer.write(content);
    }

    // Drain any final bytes that arrived without a trailing \n\n
    final remaining = buffer.toString().trim();
    if (remaining.startsWith('data: ')) {
      final data = remaining.substring(6);
      if (data != '[DONE]' && data != '[ERROR]' && data.isNotEmpty) {
        try {
          final text = jsonDecode(data) as String;
          if (text.isNotEmpty) yield text;
        } catch (_) {}
      }
    }
  }

  // ─── Generation ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> triggerGeneration() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/generation/trigger'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGenerationStatus() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/generation/status'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ─── TTS ─────────────────────────────────────────────────────────────

  /// Downloads the full MP3 from the TTS endpoint and returns the raw bytes.
  static Future<Uint8List> ttsBytes(
    String text, {
    String voice = 'aura-2-orion-en',
  }) async {
    final token = await ClerkAuthProvider.instance.getToken();
    final res = await _client.post(
      Uri.parse('$baseUrl/api/tts'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text, 'voice': voice}),
    );
    if (res.statusCode != 200) {
      throw Exception('TTS failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _decode(http.Response res) {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(json['error'] ?? 'API error ${res.statusCode}');
    }
    return json;
  }
}
