enum BuddyTokenCountStatus { exact, unknown }

enum BuddyMessageRole { user, buddy }

enum BuddyAttachmentKind { mealPhoto }

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

  Map<String, dynamic> toJson() {
    return {
      'approvalId': approvalId,
      'toolCall': toolCall.toJson(),
      'title': title,
      'summary': summary,
      'confirmLabel': confirmLabel,
      'cancelLabel': cancelLabel,
    };
  }
}

class BuddyDraftAttachment {
  final int attachmentId;
  final String localPath;
  final String? signedUrl;

  const BuddyDraftAttachment({
    required this.attachmentId,
    required this.localPath,
    this.signedUrl,
  });
}

class BuddyMessageAttachment {
  final String id;
  final BuddyAttachmentKind kind;
  final int? mealMediaAttachmentId;
  final String? signedUrl;
  final String? analysisStatus;
  final String? localPath;

  const BuddyMessageAttachment({
    required this.id,
    required this.kind,
    required this.mealMediaAttachmentId,
    required this.signedUrl,
    required this.analysisStatus,
    this.localPath,
  });

  factory BuddyMessageAttachment.fromJson(Map<String, dynamic> json) {
    return BuddyMessageAttachment(
      id: (json['id'] ?? '').toString(),
      kind: _parseAttachmentKind(json['kind']?.toString()),
      mealMediaAttachmentId:
          (json['mealMediaAttachmentId'] as num?)?.toInt() ??
          (json['meal_media_attachment_id'] as num?)?.toInt(),
      signedUrl: json['signedUrl']?.toString(),
      analysisStatus: json['analysisStatus']?.toString(),
    );
  }

  BuddyMessageAttachment copyWith({
    String? id,
    BuddyAttachmentKind? kind,
    int? mealMediaAttachmentId,
    String? signedUrl,
    String? analysisStatus,
    String? localPath,
  }) {
    return BuddyMessageAttachment(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      mealMediaAttachmentId: mealMediaAttachmentId ?? this.mealMediaAttachmentId,
      signedUrl: signedUrl ?? this.signedUrl,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      localPath: localPath ?? this.localPath,
    );
  }
}

class BuddyChatMessage {
  final String id;
  final BuddyMessageRole role;
  final String message;
  final DateTime sentAt;
  final String? model;
  final int? tokens;
  final BuddyTokenCountStatus tokenCountStatus;
  final List<BuddyMessageAttachment> attachments;

  const BuddyChatMessage({
    required this.id,
    required this.role,
    required this.message,
    required this.sentAt,
    required this.model,
    required this.tokens,
    required this.tokenCountStatus,
    required this.attachments,
  });

  factory BuddyChatMessage.fromJson(Map<String, dynamic> json) {
    return BuddyChatMessage(
      id: (json['id'] ?? '').toString(),
      role: _parseMessageRole(json['role']?.toString()),
      message: (json['message'] ?? '').toString(),
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      model: json['model']?.toString(),
      tokens: (json['tokens'] as num?)?.toInt(),
      tokenCountStatus: _parseTokenCountStatus(
        json['tokenCountStatus']?.toString(),
      ),
      attachments: (((json['attachments'] as List?) ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)))
          .map(BuddyMessageAttachment.fromJson)
          .toList(),
    );
  }

  BuddyChatMessage copyWith({
    String? id,
    BuddyMessageRole? role,
    String? message,
    DateTime? sentAt,
    String? model,
    int? tokens,
    BuddyTokenCountStatus? tokenCountStatus,
    List<BuddyMessageAttachment>? attachments,
  }) {
    return BuddyChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      model: model ?? this.model,
      tokens: tokens ?? this.tokens,
      tokenCountStatus: tokenCountStatus ?? this.tokenCountStatus,
      attachments: attachments ?? this.attachments,
    );
  }
}

class BuddySessionSummary {
  final String id;
  final String title;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime activityAt;
  final String? lastMessagePreview;
  final BuddyMessageRole? lastMessageRole;
  final bool hasPendingApproval;

  const BuddySessionSummary({
    required this.id,
    required this.title,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    required this.activityAt,
    required this.lastMessagePreview,
    required this.lastMessageRole,
    required this.hasPendingApproval,
  });

  factory BuddySessionSummary.fromJson(Map<String, dynamic> json) {
    return BuddySessionSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'New Session').toString(),
      isPinned: json['isPinned'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      activityAt: DateTime.tryParse(json['activityAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastMessagePreview: json['lastMessagePreview']?.toString(),
      lastMessageRole: _parseNullableMessageRole(
        json['lastMessageRole']?.toString(),
      ),
      hasPendingApproval: json['hasPendingApproval'] == true,
    );
  }

  BuddySessionSummary copyWith({
    String? id,
    String? title,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? activityAt,
    String? lastMessagePreview,
    BuddyMessageRole? lastMessageRole,
    bool? hasPendingApproval,
  }) {
    return BuddySessionSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activityAt: activityAt ?? this.activityAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageRole: lastMessageRole ?? this.lastMessageRole,
      hasPendingApproval: hasPendingApproval ?? this.hasPendingApproval,
    );
  }
}

class BuddySessionDetail {
  final BuddySessionSummary session;
  final List<BuddyChatMessage> messages;
  final BuddyApprovalRequest? pendingApproval;

  const BuddySessionDetail({
    required this.session,
    required this.messages,
    required this.pendingApproval,
  });

  factory BuddySessionDetail.fromJson(Map<String, dynamic> json) {
    return BuddySessionDetail(
      session: BuddySessionSummary.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      messages: (((json['messages'] as List?) ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)))
          .map(BuddyChatMessage.fromJson)
          .toList(),
      pendingApproval: json['pendingApproval'] is Map
          ? BuddyApprovalRequest.fromJson(
              Map<String, dynamic>.from(json['pendingApproval'] as Map),
            )
          : null,
    );
  }
}

BuddyAttachmentKind _parseAttachmentKind(String? value) {
  switch (value) {
    case 'meal_photo':
      return BuddyAttachmentKind.mealPhoto;
    default:
      return BuddyAttachmentKind.mealPhoto;
  }
}

BuddyTokenCountStatus _parseTokenCountStatus(String? value) {
  switch (value) {
    case 'exact':
      return BuddyTokenCountStatus.exact;
    default:
      return BuddyTokenCountStatus.unknown;
  }
}

BuddyMessageRole _parseMessageRole(String? value) {
  return _parseNullableMessageRole(value) ?? BuddyMessageRole.buddy;
}

BuddyMessageRole? _parseNullableMessageRole(String? value) {
  switch (value) {
    case 'user':
      return BuddyMessageRole.user;
    case 'buddy':
      return BuddyMessageRole.buddy;
    default:
      return null;
  }
}
