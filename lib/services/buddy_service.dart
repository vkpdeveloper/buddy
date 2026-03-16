import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:buddy/providers/firebase_auth_provider.dart';
import 'package:buddy/services/api_base.dart';

sealed class BuddyStreamEvent {}

class BuddyTextChunk extends BuddyStreamEvent {
  final String text;
  BuddyTextChunk(this.text);
}

class BuddyToolStart extends BuddyStreamEvent {
  final String label;
  BuddyToolStart(this.label);
}

class BuddyApprovalEvent extends BuddyStreamEvent {
  final BuddyApprovalRequest approval;
  BuddyApprovalEvent(this.approval);
}

class BuddyRefreshEvent extends BuddyStreamEvent {
  final List<String> domains;
  BuddyRefreshEvent(this.domains);
}

class BuddyToolCall {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> input;

  const BuddyToolCall({
    required this.toolCallId,
    required this.toolName,
    required this.input,
  });

  factory BuddyToolCall.fromJson(Map<String, dynamic> json) {
    return BuddyToolCall(
      toolCallId: (json['toolCallId'] ?? '').toString(),
      toolName: (json['toolName'] ?? '').toString(),
      input: json['input'] is Map
          ? Map<String, dynamic>.from(json['input'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'tool-call',
      'toolCallId': toolCallId,
      'toolName': toolName,
      'input': input,
    };
  }
}

class BuddyApprovalRequest {
  final String approvalId;
  final BuddyToolCall toolCall;
  final String title;
  final String summary;
  final String confirmLabel;
  final String cancelLabel;

  const BuddyApprovalRequest({
    required this.approvalId,
    required this.toolCall,
    required this.title,
    required this.summary,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  factory BuddyApprovalRequest.fromJson(Map<String, dynamic> json) {
    return BuddyApprovalRequest(
      approvalId: (json['approvalId'] ?? '').toString(),
      toolCall: BuddyToolCall.fromJson(
        Map<String, dynamic>.from(json['toolCall'] as Map),
      ),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      confirmLabel: (json['confirmLabel'] ?? 'Approve').toString(),
      cancelLabel: (json['cancelLabel'] ?? 'Cancel').toString(),
    );
  }
}

final class BuddyService extends ApiBase {
  static Stream<BuddyStreamEvent> buddyChat(
    List<Map<String, dynamic>> messages,
  ) async* {
    final token = await FirebaseAuthProvider.instance.getToken();
    final timeZone = await ApiBase.localTimeZone();
    final request = http.Request(
      'POST',
      Uri.parse('${ApiBase.baseUrl}/api/buddy/chat'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-Timezone': timeZone,
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

        final parsed = _parseSseEvent(rawEvent);
        final eventType = parsed.$1;
        final dataLine = parsed.$2;
        if (dataLine == null ||
            dataLine == '[DONE]' ||
            dataLine == '[ERROR]' ||
            dataLine.isEmpty) {
          continue;
        }

        final event = _toBuddyStreamEvent(eventType, dataLine);
        if (event != null) {
          yield event;
        }
      }

      buffer.clear();
      buffer.write(content);
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      final parsed = _parseSseEvent(remaining);
      final event = parsed.$2 == null
          ? null
          : _toBuddyStreamEvent(parsed.$1, parsed.$2!);
      if (event != null) {
        yield event;
      }
    }
  }

  static (String?, String?) _parseSseEvent(String rawEvent) {
    String? eventType;
    String? dataLine;
    for (final line in rawEvent.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataLine = line.substring(6);
      }
    }
    return (eventType, dataLine);
  }

  static BuddyStreamEvent? _toBuddyStreamEvent(
    String? eventType,
    String dataLine,
  ) {
    try {
      final decoded = jsonDecode(dataLine);
      switch (eventType) {
        case 'tool':
          if (decoded is String && decoded.isNotEmpty) {
            return BuddyToolStart(decoded);
          }
          return null;
        case 'approval':
          if (decoded is Map) {
            return BuddyApprovalEvent(
              BuddyApprovalRequest.fromJson(Map<String, dynamic>.from(decoded)),
            );
          }
          return null;
        case 'refresh':
          if (decoded is List) {
            return BuddyRefreshEvent(
              decoded.map((item) => item.toString()).toList(),
            );
          }
          return null;
        case 'text':
        default:
          if (decoded is String && decoded.isNotEmpty) {
            return BuddyTextChunk(decoded);
          }
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
