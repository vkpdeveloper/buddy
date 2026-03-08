import 'dart:convert';
import 'dart:typed_data';
import 'package:buddy/providers/firebase_auth_provider.dart';
import 'package:buddy/services/api_base.dart';

final class TtsApiService extends ApiBase {
  static Future<Uint8List> ttsBytes(
    String text, {
    String voice = 'aura-2-orion-en',
  }) async {
    final token = await FirebaseAuthProvider.instance.getToken();
    final res = await ApiBase.client.post(
      Uri.parse('${ApiBase.baseUrl}/api/tts'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text, 'voice': voice}),
    );
    if (res.statusCode != 200) {
      throw Exception('TTS failed: ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
