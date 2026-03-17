import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:buddy/models/buddy_chat.dart';
import 'package:buddy/providers/body_provider.dart';
import 'package:buddy/providers/growth_provider.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/buddy_repository.dart';
import 'package:buddy/services/buddy_service.dart';

const _buddyUnset = Object();

final buddyRepositoryProvider = Provider<BuddyRepository>(
  (ref) => const BuddyRepository(),
);

class BuddySessionListState {
  final List<BuddySessionSummary> sessions;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  const BuddySessionListState({
    required this.sessions,
    required this.isLoading,
    required this.isCreating,
    required this.errorMessage,
  });

  factory BuddySessionListState.initial() => const BuddySessionListState(
    sessions: [],
    isLoading: true,
    isCreating: false,
    errorMessage: null,
  );

  BuddySessionListState copyWith({
    List<BuddySessionSummary>? sessions,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BuddySessionListState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class BuddySessionState {
  final BuddySessionSummary? session;
  final List<BuddyChatMessage> messages;
  final BuddyApprovalRequest? pendingApproval;
  final bool isLoading;
  final bool isStreaming;
  final String streamingContent;
  final String? activeToolLabel;
  final String? errorMessage;
  final bool isDeleted;

  const BuddySessionState({
    required this.session,
    required this.messages,
    required this.pendingApproval,
    required this.isLoading,
    required this.isStreaming,
    required this.streamingContent,
    required this.activeToolLabel,
    required this.errorMessage,
    required this.isDeleted,
  });

  factory BuddySessionState.initial({BuddySessionSummary? session}) =>
      BuddySessionState(
        session: session,
        messages: const [],
        pendingApproval: null,
        isLoading: true,
        isStreaming: false,
        streamingContent: '',
        activeToolLabel: null,
        errorMessage: null,
        isDeleted: false,
      );

  BuddySessionState copyWith({
    Object? session = _buddyUnset,
    List<BuddyChatMessage>? messages,
    Object? pendingApproval = _buddyUnset,
    bool? isLoading,
    bool? isStreaming,
    String? streamingContent,
    Object? activeToolLabel = _buddyUnset,
    String? errorMessage,
    bool clearError = false,
    bool? isDeleted,
  }) {
    return BuddySessionState(
      session: identical(session, _buddyUnset)
          ? this.session
          : session as BuddySessionSummary?,
      messages: messages ?? this.messages,
      pendingApproval: identical(pendingApproval, _buddyUnset)
          ? this.pendingApproval
          : pendingApproval as BuddyApprovalRequest?,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      activeToolLabel: identical(activeToolLabel, _buddyUnset)
          ? this.activeToolLabel
          : activeToolLabel as String?,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class BuddySessionListNotifier extends Notifier<BuddySessionListState> {
  BuddyRepository get _repository => ref.read(buddyRepositoryProvider);

  @override
  BuddySessionListState build() {
    _load();
    return BuddySessionListState.initial();
  }

  Future<void> _load() async {
    try {
      final sessions = await _repository.listSessions();
      state = state.copyWith(
        sessions: _sortSessions(sessions),
        isLoading: false,
        clearError: true,
      );
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> refresh() => _load();

  Future<BuddySessionSummary?> createSession() async {
    if (state.isCreating) {
      return null;
    }

    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final session = await _repository.createSession();
      upsertSession(session);
      state = state.copyWith(isCreating: false, clearError: true);
      return session;
    } catch (err) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: err.toString(),
      );
      return null;
    }
  }

  Future<BuddySessionSummary?> renameSession(
    String sessionId,
    String title,
  ) async {
    try {
      final session = await _repository.renameSession(sessionId, title);
      upsertSession(session);
      return session;
    } catch (err) {
      state = state.copyWith(errorMessage: err.toString());
      return null;
    }
  }

  Future<BuddySessionSummary?> setPinned(
    String sessionId,
    bool isPinned,
  ) async {
    try {
      final session = await _repository.setPinned(sessionId, isPinned);
      upsertSession(session);
      return session;
    } catch (err) {
      state = state.copyWith(errorMessage: err.toString());
      return null;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      await _repository.deleteSession(sessionId);
      removeSession(sessionId);
      return true;
    } catch (err) {
      state = state.copyWith(errorMessage: err.toString());
      return false;
    }
  }

  void upsertSession(BuddySessionSummary summary) {
    final next = [...state.sessions];
    final index = next.indexWhere((item) => item.id == summary.id);
    if (index >= 0) {
      next[index] = summary;
    } else {
      next.add(summary);
    }
    state = state.copyWith(sessions: _sortSessions(next), clearError: true);
  }

  void removeSession(String sessionId) {
    state = state.copyWith(
      sessions: state.sessions.where((item) => item.id != sessionId).toList(),
    );
  }

  void patchSession(
    String sessionId, {
    String? title,
    bool? isPinned,
    String? lastMessagePreview,
    BuddyMessageRole? lastMessageRole,
    bool? hasPendingApproval,
    DateTime? activityAt,
    DateTime? updatedAt,
  }) {
    final next = [...state.sessions];
    final index = next.indexWhere((item) => item.id == sessionId);
    if (index < 0) {
      return;
    }

    next[index] = next[index].copyWith(
      title: title,
      isPinned: isPinned,
      lastMessagePreview: lastMessagePreview,
      lastMessageRole: lastMessageRole,
      hasPendingApproval: hasPendingApproval,
      activityAt: activityAt,
      updatedAt: updatedAt,
    );
    state = state.copyWith(sessions: _sortSessions(next), clearError: true);
  }

  List<BuddySessionSummary> _sortSessions(List<BuddySessionSummary> sessions) {
    final next = [...sessions];
    next.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      final activityCompare = b.activityAt.compareTo(a.activityAt);
      if (activityCompare != 0) {
        return activityCompare;
      }

      return b.createdAt.compareTo(a.createdAt);
    });
    return next;
  }
}

class BuddySessionController extends Notifier<BuddySessionState> {
  BuddySessionController(this.sessionId);

  final String sessionId;

  BuddyRepository get _repository => ref.read(buddyRepositoryProvider);
  BuddySessionListNotifier get _listNotifier =>
      ref.read(buddySessionListProvider.notifier);

  StreamSubscription<BuddyStreamEvent>? _streamSub;
  final List<String> _completedAssistantSegments = [];
  BuddyApprovalRequest? _streamingApprovalRequest;
  bool _sawApprovalOrRefreshEvent = false;

  @override
  BuddySessionState build() {
    ref.onDispose(() => _streamSub?.cancel());

    BuddySessionSummary? seeded;
    for (final item in ref.read(buddySessionListProvider).sessions) {
      if (item.id == sessionId) {
        seeded = item;
        break;
      }
    }

    _load();
    return BuddySessionState.initial(session: seeded);
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.getSessionDetail(sessionId);
      state = state.copyWith(
        session: detail.session,
        messages: detail.messages,
        pendingApproval: detail.pendingApproval,
        isLoading: false,
        clearError: true,
      );
      _listNotifier.upsertSession(detail.session);
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> refresh() => _load();

  Future<void> sendUserMessage({
    required String text,
    BuddyDraftAttachment? attachment,
  }) async {
    if (state.isStreaming || state.pendingApproval != null) {
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty && attachment == null) {
      return;
    }

    final optimisticAttachments = attachment == null
        ? const <BuddyMessageAttachment>[]
        : [
            BuddyMessageAttachment(
              id: 'draft-${attachment.attachmentId}',
              kind: BuddyAttachmentKind.mealPhoto,
              mealMediaAttachmentId: attachment.attachmentId,
              signedUrl: attachment.signedUrl,
              analysisStatus: null,
              localPath: attachment.localPath,
            ),
          ];

    final optimisticMessage = BuddyChatMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      role: BuddyMessageRole.user,
      message: trimmed,
      sentAt: DateTime.now(),
      model: null,
      tokens: null,
      tokenCountStatus: BuddyTokenCountStatus.unknown,
      attachments: optimisticAttachments,
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticMessage],
      pendingApproval: null,
      isStreaming: true,
      streamingContent: '',
      activeToolLabel: null,
      clearError: true,
    );

    _completedAssistantSegments.clear();
    _streamingApprovalRequest = null;
    _sawApprovalOrRefreshEvent = false;

    final now = DateTime.now();
    _listNotifier.patchSession(
      sessionId,
      lastMessagePreview: trimmed.isNotEmpty ? trimmed : 'Meal photo',
      lastMessageRole: BuddyMessageRole.user,
      hasPendingApproval: false,
      activityAt: now,
      updatedAt: now,
    );

    _startStream(
      _repository.sendUserMessage(
        sessionId,
        text: trimmed,
        attachmentIds: attachment == null ? const [] : [attachment.attachmentId],
      ),
    );
  }

  Future<void> respondToApproval({required bool approved}) async {
    final approval = state.pendingApproval;
    if (approval == null || state.isStreaming) {
      return;
    }

    state = state.copyWith(
      pendingApproval: null,
      isStreaming: true,
      streamingContent: '',
      activeToolLabel: null,
      clearError: true,
    );

    _completedAssistantSegments.clear();
    _streamingApprovalRequest = null;
    _sawApprovalOrRefreshEvent = false;

    _listNotifier.patchSession(
      sessionId,
      hasPendingApproval: false,
      updatedAt: DateTime.now(),
    );

    _startStream(
      _repository.respondToApproval(
        sessionId,
        approvalId: approval.approvalId,
        approved: approved,
      ),
    );
  }

  Future<void> renameSession(String title) async {
    final summary = await _listNotifier.renameSession(sessionId, title);
    if (summary != null) {
      state = state.copyWith(session: summary, clearError: true);
    }
  }

  Future<void> togglePinned() async {
    final session = state.session;
    if (session == null) {
      return;
    }

    final summary = await _listNotifier.setPinned(sessionId, !session.isPinned);
    if (summary != null) {
      state = state.copyWith(session: summary, clearError: true);
    }
  }

  Future<void> deleteSession() async {
    final deleted = await _listNotifier.deleteSession(sessionId);
    if (deleted) {
      state = state.copyWith(isDeleted: true, clearError: true);
    }
  }

  void _startStream(Stream<BuddyStreamEvent> stream) {
    _streamSub?.cancel();
    _streamSub = stream.listen(
      (event) {
        switch (event) {
          case BuddyToolStart(:final label):
            _flushStreamingAssistantSegment();
            state = state.copyWith(activeToolLabel: label);
          case BuddyTextChunk(:final text):
            state = state.copyWith(
              activeToolLabel: null,
              streamingContent: '${state.streamingContent}$text',
            );
          case BuddyApprovalEvent(:final approval):
            _flushStreamingAssistantSegment();
            _streamingApprovalRequest = approval;
            _sawApprovalOrRefreshEvent = true;
            state = state.copyWith(
              pendingApproval: approval,
              activeToolLabel: null,
            );
          case BuddyPipelineEvent(:final payload):
            final message = payload['message']?.toString().trim() ?? '';
            final label = payload['label']?.toString().trim() ?? '';
            final phase = payload['phase']?.toString().trim() ?? '';

            if (message.isNotEmpty) {
              _flushStreamingAssistantSegment();
              _appendAssistantMessage(
                message,
                tracksConversation: false,
              );
            }

            _sawApprovalOrRefreshEvent = true;
            state = state.copyWith(
              activeToolLabel: label.isNotEmpty
                  ? label
                  : (phase == 'completed' || phase == 'failed'
                        ? null
                        : state.activeToolLabel),
            );
          case BuddyRefreshEvent(:final domains):
            _handleRefreshDomains(domains);
            _sawApprovalOrRefreshEvent = true;
            state = state.copyWith(activeToolLabel: null);
          case BuddySessionMetaEvent(:final sessionId, :final title):
            if (sessionId != this.sessionId) {
              return;
            }

            final current = state.session;
            if (current != null) {
              final updated = current.copyWith(title: title);
              state = state.copyWith(session: updated);
              _listNotifier.patchSession(this.sessionId, title: title);
            } else {
              _listNotifier.patchSession(this.sessionId, title: title);
            }
        }
      },
      onDone: _onStreamDone,
      onError: _onStreamError,
      cancelOnError: true,
    );
  }

  void _flushStreamingAssistantSegment() {
    final segment = state.streamingContent;
    if (segment.isEmpty) {
      return;
    }

    _appendAssistantMessage(segment);
    state = state.copyWith(streamingContent: '');
  }

  void _appendAssistantMessage(
    String content, {
    bool tracksConversation = true,
  }) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        BuddyChatMessage(
          id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: BuddyMessageRole.buddy,
          message: content,
          sentAt: DateTime.now(),
          model: null,
          tokens: null,
          tokenCountStatus: BuddyTokenCountStatus.unknown,
          attachments: const [],
        ),
      ],
    );

    if (tracksConversation) {
      _completedAssistantSegments.add(content);
    }
  }

  void _onStreamDone() {
    final assistantSegments = [
      ..._completedAssistantSegments,
      if (state.streamingContent.isNotEmpty) state.streamingContent,
    ];
    final assistantText = assistantSegments.join('\n\n').trim();
    final hasApproval = _streamingApprovalRequest != null;

    if (state.streamingContent.isNotEmpty) {
      _appendAssistantMessage(state.streamingContent);
    } else if (assistantSegments.isEmpty && !_sawApprovalOrRefreshEvent) {
      state = state.copyWith(
        errorMessage: "Hmm, I didn't get a response back. Try again shortly.",
      );
    }

    final now = DateTime.now();
    final preview = assistantText.isNotEmpty
        ? assistantText
        : hasApproval
        ? 'Approval needed'
        : null;

    if (preview != null) {
      _listNotifier.patchSession(
        sessionId,
        lastMessagePreview: preview,
        lastMessageRole: BuddyMessageRole.buddy,
        hasPendingApproval: hasApproval,
        activityAt: now,
        updatedAt: now,
      );
    } else if (hasApproval) {
      _listNotifier.patchSession(
        sessionId,
        hasPendingApproval: true,
        updatedAt: now,
      );
    }

    final current = state.session;
    if (current != null) {
      state = state.copyWith(
        session: current.copyWith(
          lastMessagePreview: preview ?? current.lastMessagePreview,
          lastMessageRole: preview != null
              ? BuddyMessageRole.buddy
              : current.lastMessageRole,
          hasPendingApproval: hasApproval,
          activityAt: preview != null ? now : current.activityAt,
          updatedAt: now,
        ),
        isStreaming: false,
        streamingContent: '',
        activeToolLabel: null,
      );
    } else {
      state = state.copyWith(
        isStreaming: false,
        streamingContent: '',
        activeToolLabel: null,
      );
    }

    _completedAssistantSegments.clear();
    _streamingApprovalRequest = null;
    _sawApprovalOrRefreshEvent = false;
  }

  void _onStreamError(Object err) {
    debugPrint('[BuddyChat] stream error: $err');
    state = state.copyWith(
      isStreaming: false,
      streamingContent: '',
      activeToolLabel: null,
      errorMessage: 'Something went wrong. Check your connection and reopen the session.',
    );
    _completedAssistantSegments.clear();
    _streamingApprovalRequest = null;
    _sawApprovalOrRefreshEvent = false;
  }

  void _handleRefreshDomains(List<String> domains) {
    for (final domain in domains) {
      switch (domain) {
        case 'body':
          ref.invalidate(bodyHistoryProvider);
          ref.invalidate(latestBodyMeasurementProvider);
          ref.invalidate(growthOverviewProvider);
          break;
        case 'diet':
          ref.invalidate(todayNutritionSummaryProvider(_todayDate()));
          ref.invalidate(homeDashboardProvider);
          break;
        case 'growth':
          ref.invalidate(growthOverviewProvider);
          ref.invalidate(growthGoalsProvider);
          ref.invalidate(bodyHistoryProvider);
          ref.invalidate(latestBodyMeasurementProvider);
          break;
        case 'home':
          ref.invalidate(homeDashboardProvider);
          ref.invalidate(todayNutritionSummaryProvider(_todayDate()));
          break;
        case 'progress':
          ref.invalidate(progressProvider);
          break;
        case 'targets':
          ref.invalidate(userTargetsProvider);
          ref.invalidate(homeDashboardProvider);
          break;
        case 'workout':
          ref.invalidate(weeklyWorkoutSummaryProvider);
          ref.invalidate(homeDashboardProvider);
          ref.invalidate(progressProvider);
          break;
      }
    }
  }
}

String _todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

final buddySessionListProvider =
    NotifierProvider<BuddySessionListNotifier, BuddySessionListState>(
      BuddySessionListNotifier.new,
    );

final buddySessionProvider =
    NotifierProvider.family<BuddySessionController, BuddySessionState, String>(
      BuddySessionController.new,
    );
