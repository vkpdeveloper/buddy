import 'package:buddy/services/api_base.dart';
import 'dart:convert';

final class GenerationService extends ApiBase {
  static Future<Map<String, dynamic>> triggerGeneration({
    List<String>? types,
  }) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/generation/trigger'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode({if (types != null && types.isNotEmpty) 'types': types}),
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
