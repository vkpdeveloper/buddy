import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:buddy/providers/firebase_auth_provider.dart';
import 'package:buddy/services/api_base.dart';

// ─── Buddy stream event types ─────────────────────────────────────────────────

sealed class BuddyStreamEvent {}

class BuddyTextChunk extends BuddyStreamEvent {
  final String text;
  BuddyTextChunk(this.text);
}

class BuddyToolStart extends BuddyStreamEvent {
  final String label;
  BuddyToolStart(this.label);
}

// ─── BuddyService ─────────────────────────────────────────────────────────────

final class BuddyService extends ApiBase {
  /// Streams typed events from Buddy AI via SSE.
  static Stream<BuddyStreamEvent> buddyChat(
    List<Map<String, dynamic>> messages,
  ) async* {
    final token = await FirebaseAuthProvider.instance.getToken();
    final request = http.Request(
      'POST',
      Uri.parse('${ApiBase.baseUrl}/api/buddy/chat'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      if (token != null) 'Authorization': 'Bearer $token',
    });
    request.body = jsonEncode({'messages': messages});

    final http.StreamedResponse response;
    try {
      response = await ApiBase.client.send(request);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }

    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw Exception('Buddy chat ${response.statusCode}: $body');
    }

    final buffer = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var content = buffer.toString();

      while (content.contains('\n\n')) {
        final boundary = content.indexOf('\n\n');
        final rawEvent = content.substring(0, boundary);
        content = content.substring(boundary + 2);

        String? eventType;
        String? dataLine;
        for (final line in rawEvent.split('\n')) {
          if (line.startsWith('event: ')) {
            eventType = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            dataLine = line.substring(6);
          }
        }

        if (dataLine == null ||
            dataLine == '[DONE]' ||
            dataLine == '[ERROR]' ||
            dataLine.isEmpty) {
          continue;
        }

        try {
          final value = jsonDecode(dataLine) as String;
          if (value.isEmpty) continue;
          if (eventType == 'tool') {
            yield BuddyToolStart(value);
          } else {
            yield BuddyTextChunk(value);
          }
        } catch (_) {}
      }

      buffer.clear();
      buffer.write(content);
    }

    final remaining = buffer.toString().trim();
    if (remaining.startsWith('data: ')) {
      final data = remaining.substring(6);
      if (data != '[DONE]' && data != '[ERROR]' && data.isNotEmpty) {
        try {
          final text = jsonDecode(data) as String;
          if (text.isNotEmpty) yield BuddyTextChunk(text);
        } catch (_) {}
      }
    }
  }
}
