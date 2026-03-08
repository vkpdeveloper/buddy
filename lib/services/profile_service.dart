import 'dart:convert';
import 'package:buddy/services/api_base.dart';

final class ProfileService extends ApiBase {
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/profile'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<bool> isProfileCompleted() async {
    try {
      final res = await getProfile();
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return false;
      return data['profile_completed'] == true ||
          data['profile_completed'] == 1;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/profile'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }
}
