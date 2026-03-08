import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:buddy/config/env.dart';
import 'package:buddy/providers/firebase_auth_provider.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

abstract class ApiBase {
  static final http.Client client = http.Client();

  static String get baseUrl => EnvInstance.instance.apiBaseUrl;

  static Future<Map<String, String>> authHeaders() async {
    final token = await FirebaseAuthProvider.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> decode(http.Response res) {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        json['error'] as String? ?? 'API error ${res.statusCode}',
        res.statusCode,
      );
    }
    return json;
  }
}
