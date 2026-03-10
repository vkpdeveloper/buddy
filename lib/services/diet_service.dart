import 'dart:convert';
import 'package:buddy/services/api_base.dart';

final class DietService extends ApiBase {
  static Future<Map<String, dynamic>> listDietPlans() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/diet/plans'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getDietPlan(int id) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/diet/plans/$id'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getDietFoods() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/diet/foods'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateMeal(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/diet/meals/$id'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getDietLog(String date) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/diet/log/$date'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> logMealCompletion(
    String date,
    int mealId,
    bool isCompleted,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/diet/log/$date'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'mealId': mealId, 'isCompleted': isCompleted}),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> logActualMeal(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/diet/log/$date/actual'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateDietDay(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/diet/days/$id'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> reorderDietMeals(
    int dayId,
    List<int> mealIds,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/diet/days/$dayId/reorder'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'mealIds': mealIds}),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> deleteDietPlan(int id) async {
    final res = await ApiBase.client.delete(
      Uri.parse('${ApiBase.baseUrl}/api/diet/plans/$id'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }
}
