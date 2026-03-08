import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:buddy/providers/firebase_auth_provider.dart';
import 'package:buddy/services/api_base.dart';

final class MediaService extends ApiBase {
  static Future<Map<String, dynamic>> uploadMealPhoto(
    File photo,
    String mimeType,
  ) async {
    final token = await FirebaseAuthProvider.instance.getToken();
    final bytes = await photo.readAsBytes();
    final fileName = photo.path.split('/').last;
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiBase.baseUrl}/api/diet/media/upload'),
    );
    req.fields['mimeType'] = mimeType;
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> analyzeMealPhoto(
    int attachmentId,
  ) async {
    final res = await ApiBase.client.post(
      Uri.parse(
        '${ApiBase.baseUrl}/api/diet/media/$attachmentId/analyze',
      ),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> logQuickMeal(
    String date,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/diet/log/$date/quick'),
      headers: await ApiBase.authHeaders(),
      body: jsonEncode(data),
    );
    return ApiBase.decode(res);
  }

  static Future<Map<String, dynamic>> getMealAttachment(
    int attachmentId,
  ) async {
    final res = await ApiBase.client.get(
      Uri.parse('${ApiBase.baseUrl}/api/diet/media/$attachmentId'),
      headers: await ApiBase.authHeaders(),
    );
    return ApiBase.decode(res);
  }
}
