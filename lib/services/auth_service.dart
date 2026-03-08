import 'dart:convert';
import 'package:buddy/services/api_base.dart';

final class AuthService extends ApiBase {
  static Future<void> register({
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/auth/register'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({'email': email, 'name': name, 'photoUrl': photoUrl}),
    );
    ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/auth/me'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<void> completeOnboarding() async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/auth/complete-onboarding'),
      headers: await ApiBase.authHeaders(),
    );
    ApiBase.decode(res);
  }
}
