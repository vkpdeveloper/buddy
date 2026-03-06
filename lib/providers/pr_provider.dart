import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/pr.dart';
import 'package:buddy/services/api_client.dart';

final prMapProvider = FutureProvider<Map<String, PersonalRecord>>((ref) async {
  return ApiClient.getPersonalRecords();
});
