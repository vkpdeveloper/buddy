import 'dart:convert';

import 'package:buddy/services/api_base.dart';

final class TargetsService extends ApiBase {
  static Future<Map<String, dynamic>> getTargets() async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/targets'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> updateTargets({
    int? dailySteps,
    double? dailySleepTarget,
    int? dailyWaterMl,
    double? targetWeight,
    bool includeTargetWeight = false,
    int? dailyCalorieBurn,
  }) async {
    final payload = <String, dynamic>{};
    if (dailySteps != null) payload['dailySteps'] = dailySteps;
    if (dailySleepTarget != null) {
      payload['dailySleepTarget'] = dailySleepTarget;
    }
    if (dailyWaterMl != null) payload['dailyWaterMl'] = dailyWaterMl;
    if (includeTargetWeight || targetWeight != null) {
      payload['targetWeight'] = targetWeight;
    }
    if (dailyCalorieBurn != null) {
      payload['dailyCalorieBurn'] = dailyCalorieBurn;
    }

    final res = await ApiBase.client.put(
      Uri.parse('${ApiBase.baseUrl}/api/targets'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(payload),
    );
    return ApiBase.decode(res);
  }
}
