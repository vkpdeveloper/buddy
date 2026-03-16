import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static Future<String>? _timeZoneFuture;

  static String get baseUrl => EnvInstance.instance.apiBaseUrl;

  static Future<String> localTimeZone() {
    return _timeZoneFuture ??= _loadLocalTimeZone();
  }

  static Future<String> _loadLocalTimeZone() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      return _normalizeTimezone(local.identifier);
    } catch (_) {
      return 'UTC';
    }
  }

  static Future<Map<String, String>> authHeaders({
    bool includeJsonContentType = true,
    String accept = 'application/json',
  }) async {
    final token = await FirebaseAuthProvider.instance.getToken();
    final timeZone = await localTimeZone();
    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      'Accept': accept,
      'X-Timezone': timeZone,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> decode(http.Response res) {
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      debugPrint('[API ${res.statusCode}] ${res.request?.url} → ${res.body}');
      final error = json['error'];
      final String message;
      if (error is String) {
        message = error;
      } else if (error is Map) {
        // Zod validation error — collect issue messages
        final issues = error['issues'];
        if (issues is List && issues.isNotEmpty) {
          message = issues
              .map((i) {
                final path = (i['path'] as List?)?.join('.') ?? '';
                final msg = i['message'] ?? '';
                return path.isNotEmpty ? '$path: $msg' : '$msg';
              })
              .join(', ');
        } else {
          message = 'API error ${res.statusCode}';
        }
      } else {
        message = 'API error ${res.statusCode}';
      }
      throw ApiException(message, res.statusCode);
    }
    return json;
  }
}

String _normalizeTimezone(String id) {
  const aliases = {
    'Asia/Calcutta': 'Asia/Kolkata',
    'Asia/Katmandu': 'Asia/Kathmandu',
    'Asia/Rangoon': 'Asia/Yangon',
    'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    'Asia/Dacca': 'Asia/Dhaka',
    'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
    'Pacific/Ponape': 'Pacific/Pohnpei',
    'Atlantic/Faeroe': 'Atlantic/Faroe',
  };
  return aliases[id] ?? id;
}
