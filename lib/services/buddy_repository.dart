import 'package:buddy/models/buddy_chat.dart';
import 'package:buddy/services/buddy_service.dart';

class BuddyRepository {
  const BuddyRepository();

  Future<List<BuddySessionSummary>> listSessions() async {
    final decoded = await BuddyService.listSessions();
    final items = (decoded['data'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((item) => BuddySessionSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BuddySessionSummary> createSession() async {
    final decoded = await BuddyService.createSession();
    return BuddySessionSummary.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<BuddySessionDetail> getSessionDetail(String sessionId) async {
    final decoded = await BuddyService.getSessionDetail(sessionId);
    return BuddySessionDetail.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<BuddySessionSummary> renameSession(
    String sessionId,
    String title,
  ) async {
    final decoded = await BuddyService.updateSession(sessionId, {'title': title});
    return BuddySessionSummary.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<BuddySessionSummary> setPinned(
    String sessionId,
    bool isPinned,
  ) async {
    final decoded = await BuddyService.updateSession(
      sessionId,
      {'isPinned': isPinned},
    );
    return BuddySessionSummary.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    await BuddyService.deleteSession(sessionId);
  }

  Stream<BuddyStreamEvent> sendUserMessage(
    String sessionId, {
    required String text,
    List<int> attachmentIds = const [],
  }) {
    return BuddyService.streamSessionChat(sessionId, {
      'kind': 'user',
      'text': text,
      if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
    });
  }

  Stream<BuddyStreamEvent> respondToApproval(
    String sessionId, {
    required String approvalId,
    required bool approved,
  }) {
    return BuddyService.streamSessionChat(sessionId, {
      'kind': 'approval',
      'approvalId': approvalId,
      'approved': approved,
    });
  }
}
