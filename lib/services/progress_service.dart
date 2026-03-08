import 'package:buddy/services/api_base.dart';

final class ProgressService extends ApiBase {
  static Future<Map<String, dynamic>> getProgress() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/progress'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getAchievements() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/progress/achievements'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }
}
