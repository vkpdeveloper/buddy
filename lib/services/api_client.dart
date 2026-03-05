import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiClient {
  // Change this to your server's LAN IP if testing on a physical device
  // e.g., 'http://192.168.1.100:3000'
  static const String baseUrl = 'http://macmini:3000';

  static final _client = http.Client();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ─── Profile ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  // ─── Diet Plans ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listDietPlans() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/plans'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietPlan(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/plans/$id'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateDietPlan() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/diet/generate'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietFoods() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/foods'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateMeal(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/diet/meals/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getDietLog(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/diet/log/$date'),
      headers: _headers,
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
      headers: _headers,
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
      headers: _headers,
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
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode({'mealIds': mealIds}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> deleteDietPlan(int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/diet/plans/$id'),
      headers: _headers,
    );
    return _decode(res);
  }

  // ─── Workout Plans ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listWorkoutPlans() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/plans'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutPlan(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/plans/$id'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWeeklyWorkoutSummary() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/summary/weekly'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateWorkoutPlan() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/workout/generate'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateExercise(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/exercises/$id'),
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode(data),
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
      headers: _headers,
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
    final res = await _client.get(uri, headers: _headers);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSession(int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/workout/sessions/$id'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWorkoutSessionHistory({
    String range = '30d',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/workout/sessions/history',
    ).replace(queryParameters: {'range': range});
    final res = await _client.get(uri, headers: _headers);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logWorkoutSession(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/workout/sessions/$id/log'),
      headers: _headers,
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
      headers: _headers,
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
      headers: _headers,
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

  // ─── Progress ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProgress() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/progress'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getAchievements() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/progress/achievements'),
      headers: _headers,
    );
    return _decode(res);
  }

  // ─── Daily Logs ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDailyLog(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/$date'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateDailyLog(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/logs/$date'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getWeekLogs() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/week'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getHomeSummary(String date) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/logs/home-summary/$date'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> incrementHydration(
    String date, {
    int amountMl = 250,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/logs/$date/hydration/increment'),
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getBodyHistory() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/history'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getLatestBodyMeasurement() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/latest'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthOverview() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/growth'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthPhotos() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/photos'),
      headers: _headers,
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
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );
    req.headers['Accept'] = 'application/json';

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthGoals() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/body/goals'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> updateGrowthGoals({
    double? weightGoalKg,
    double? bodyFatGoalPercent,
  }) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/api/body/goals'),
      headers: _headers,
      body: jsonEncode({
        'weightGoalKg': weightGoalKg,
        'bodyFatGoalPercent': bodyFatGoalPercent,
      }),
    );
    return _decode(res);
  }

  // ─── Generation ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> triggerGeneration() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/generation/trigger'),
      headers: _headers,
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getGenerationStatus() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/api/generation/status'),
      headers: _headers,
    );
    return _decode(res);
  }

  // ─── TTS ─────────────────────────────────────────────────────────────

  /// Downloads the full MP3 from the TTS endpoint and returns the raw bytes.
  static Future<Uint8List> ttsBytes(
    String text, {
    String voice = 'aura-2-orion-en',
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/api/tts'),
      headers: {'Content-Type': 'application/json', 'Accept': 'audio/mpeg'},
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
