import 'package:buddy/services/api_base.dart';

final class GenerationService extends ApiBase {
  static Future<Map<String, dynamic>> triggerGeneration() async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/generation/trigger'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getGenerationStatus() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/generation/status'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }
}
