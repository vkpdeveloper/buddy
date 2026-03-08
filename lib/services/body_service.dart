import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:buddy/providers/firebase_auth_provider.dart';
import 'package:buddy/services/api_base.dart';

final class BodyService extends ApiBase {
  static Future<Map<String, dynamic>> logBodyMeasurement(
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/body/log'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getBodyHistory() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/body/history'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getLatestBodyMeasurement() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/body/latest'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthOverview() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/body/growth'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthPhotos() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/body/photos'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> uploadGrowthPhoto({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String date,
    int? measurementId,
    String note = '',
  }) async {
    final token = await FirebaseAuthProvider.instance.getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiBase.baseUrl}/api/body/photos'),
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
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getGrowthGoals() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/body/goals'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateGrowthGoals({
    double? weightGoalKg,
    double? bodyFatGoalPercent,
  }) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/body/goals'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({
        'weightGoalKg': weightGoalKg,
        'bodyFatGoalPercent': bodyFatGoalPercent,
      }),
    );
    return ApiBase.decode(res);
  }
}
