import 'dart:convert';
import 'package:buddy/services/api_base.dart';

final class LogsService extends ApiBase {
  static Future<Map<String, dynamic>> getDailyLog(String date) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/logs/$date'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateDailyLog(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/logs/$date'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getWeekLogs({int weekOffset = 0}) async {
    final uri = weekOffset == 0
        ? Uri.parse('${ApiBase.baseUrl}/api/logs/week')
        : Uri.parse('${ApiBase.baseUrl}/api/logs/week?offset=$weekOffset');
    final res = await ApiBase.client.get(
      uri,
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getHomeSummary(String date) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/logs/home-summary/$date'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> incrementHydration(
    String date, {
    int amountMl = 250,
  }) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/logs/$date/hydration/increment'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'amountMl': amountMl}),
    );
    return ApiBase.decode(res);
  }
}
