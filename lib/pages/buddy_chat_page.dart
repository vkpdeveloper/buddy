import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:buddy/app_theme.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/providers/body_provider.dart';
import 'package:buddy/providers/growth_provider.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/buddy_service.dart';
import 'package:buddy/services/media_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/utils/motion_preferences.dart';
import 'package:buddy/widgets/app_buttons.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

enum _Role { user, assistant, error }

class _ChatMessage {
  final _Role role;
  final String content;
  final _ChatAttachment? attachment;
  const _ChatMessage({
    required this.role,
    required this.content,
    this.attachment,
  });
}

class _ChatAttachment {
  final int attachmentId;
  final String localPath;
  final String? signedUrl;

  const _ChatAttachment({
    required this.attachmentId,
    required this.localPath,
    this.signedUrl,
  });
}

class _ComposerAttachment {
  final File file;
  final int attachmentId;
  final String? signedUrl;
  final bool isAnalyzing;

  const _ComposerAttachment({
    required this.file,
    required this.attachmentId,
    required this.signedUrl,
    required this.isAnalyzing,
  });

  _ComposerAttachment copyWith({
    File? file,
    int? attachmentId,
    String? signedUrl,
    bool? isAnalyzing,
  }) {
    return _ComposerAttachment(
      file: file ?? this.file,
      attachmentId: attachmentId ?? this.attachmentId,
      signedUrl: signedUrl ?? this.signedUrl,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }
}

const _kSuggestions = [
  'What\'s in my workout today?',
  'What should I eat after training?',
  'How am I doing this week?',
  'Show me my full diet plan',
  'Review my workout program',
  'How\'s my streak looking?',
];

String _todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class BuddyChatPage extends ConsumerStatefulWidget {
  const BuddyChatPage({super.key});

  @override
  ConsumerState<BuddyChatPage> createState() => _BuddyChatPageState();
}

class _BuddyChatPageState extends ConsumerState<BuddyChatPage>
    with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _apiMessages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  String? _userName;
  bool _isStreaming = false;
  bool _isUploadingAttachment = false;
  String _streamingContent = '';
  String? _activeToolLabel;
  BuddyApprovalRequest? _pendingApproval;
  BuddyApprovalRequest? _streamingApprovalRequest;
  _ComposerAttachment? _composerAttachment;
  bool _sawApprovalOrRefreshEvent = false;
  StreamSubscription<BuddyStreamEvent>? _streamSub;

  late AnimationController _dotAnimCtrl;
  late AnimationController _fadeInCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _dotAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeOut);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final res = await ProfileService.getProfile();
      final name = (res['data'] as Map<String, dynamic>?)?['name'] as String?;
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _userName = name.split(' ').first);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _dotAnimCtrl.dispose();
    _fadeInCtrl.dispose();
    super.dispose();
  }

  // ─── Scrolling ──────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ─── Send ───────────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (_isStreaming || _isUploadingAttachment || _pendingApproval != null) {
      return;
    }
    if (trimmed.isEmpty && _composerAttachment == null) return;

    final attachment = _composerAttachment == null
        ? null
        : _ChatAttachment(
            attachmentId: _composerAttachment!.attachmentId,
            localPath: _composerAttachment!.file.path,
            signedUrl: _composerAttachment!.signedUrl,
          );

    _inputCtrl.clear();
    _focusNode.unfocus();

    final apiContent = attachment == null
        ? trimmed
        : '${trimmed.isEmpty ? 'Please inspect this meal photo.' : trimmed}\n\n[User attached a meal photo. attachmentId=${attachment.attachmentId}. Call getMealPhotoAttachment with this attachmentId if you need to inspect or log it.]';

    // Remove any trailing error message before adding the new user turn
    setState(() {
      _messages.removeWhere((m) => m.role == _Role.error);
      _messages.add(
        _ChatMessage(
          role: _Role.user,
          content: trimmed,
          attachment: attachment,
        ),
      );
      _apiMessages.add({'role': 'user', 'content': apiContent});
      _isStreaming = true;
      _streamingContent = '';
      _activeToolLabel = null;
      _composerAttachment = null;
      _streamingApprovalRequest = null;
      _sawApprovalOrRefreshEvent = false;
    });

    _scrollToBottom();
    _startStream();
  }

  // ─── Retry ──────────────────────────────────────────────────────────────────

  void _retryLast() {
    if (_isStreaming || _isUploadingAttachment || _pendingApproval != null) {
      return;
    }

    // Strip error bubble, keep user message, resend
    setState(() {
      _messages.removeWhere((m) => m.role == _Role.error);
      _isStreaming = true;
      _streamingContent = '';
      _activeToolLabel = null;
      _streamingApprovalRequest = null;
      _sawApprovalOrRefreshEvent = false;
    });

    _scrollToBottom();
    _startStream();
  }

  Future<void> _pickMealPhoto() async {
    if (_isStreaming ||
        _isUploadingAttachment ||
        _composerAttachment != null ||
        _pendingApproval != null) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _MealPhotoSourceSheet(),
    );
    if (!mounted || source == null) return;

    await _pickMealPhotoFromSource(source);
  }

  Future<void> _pickMealPhotoFromSource(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final mimeType = _mimeTypeForPath(file.path);

      setState(() => _isUploadingAttachment = true);

      final upload = await MediaService.uploadMealPhoto(file, mimeType);
      final data = Map<String, dynamic>.from(upload['data'] as Map);
      final attachmentId = (data['id'] as num?)?.toInt();
      if (attachmentId == null) {
        throw Exception('Upload did not return an attachment id.');
      }

      if (!mounted) return;
      setState(() {
        _composerAttachment = _ComposerAttachment(
          file: file,
          attachmentId: attachmentId,
          signedUrl: data['signedUrl']?.toString(),
          isAnalyzing: true,
        );
      });

      unawaited(_startMealPhotoAnalysis(attachmentId));
    } catch (err) {
      if (!mounted) return;
      _showSnack('Meal photo upload failed.');
      debugPrint('[BuddyChat] meal photo upload error: $err');
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _startMealPhotoAnalysis(int attachmentId) async {
    try {
      await MediaService.analyzeMealPhoto(attachmentId);
    } catch (err) {
      debugPrint('[BuddyChat] meal photo analyze error: $err');
    } finally {
      if (mounted && _composerAttachment?.attachmentId == attachmentId) {
        setState(() {
          _composerAttachment = _composerAttachment?.copyWith(
            isAnalyzing: false,
          );
        });
      }
    }
  }

  Future<void> _respondToApproval({required bool approved}) async {
    final approval = _pendingApproval;
    if (approval == null || _isStreaming || _isUploadingAttachment) return;

    setState(() {
      _pendingApproval = null;
      _isStreaming = true;
      _streamingContent = '';
      _activeToolLabel = null;
      _streamingApprovalRequest = null;
      _sawApprovalOrRefreshEvent = false;
    });

    _apiMessages.add({
      'role': 'tool',
      'content': [
        {
          'type': 'tool-approval-response',
          'approvalId': approval.approvalId,
          'approved': approved,
        },
      ],
    });

    _scrollToBottom();
    _startStream();
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _startStream() {
    _streamSub?.cancel();

    try {
      _streamSub = BuddyService.buddyChat(_apiMessages).listen(
        (event) {
          if (!mounted) return;
          switch (event) {
            case BuddyToolStart(:final label):
              setState(() => _activeToolLabel = label);
            case BuddyTextChunk(:final text):
              setState(() {
                _activeToolLabel = null;
                _streamingContent += text;
              });
            case BuddyApprovalEvent(:final approval):
              setState(() {
                _activeToolLabel = null;
                _pendingApproval = approval;
                _streamingApprovalRequest = approval;
                _sawApprovalOrRefreshEvent = true;
              });
            case BuddyRefreshEvent(:final domains):
              _handleRefreshDomains(domains);
              setState(() {
                _activeToolLabel = null;
                _sawApprovalOrRefreshEvent = true;
              });
          }
          _scrollToBottom();
        },
        onDone: _onStreamDone,
        onError: _onStreamError,
        cancelOnError: true,
      );
    } catch (e) {
      _onStreamError(e);
    }
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() {
      if (_streamingApprovalRequest != null) {
        final approvalContent = <Map<String, dynamic>>[];
        if (_streamingContent.isNotEmpty) {
          approvalContent.add({'type': 'text', 'text': _streamingContent});
        }
        approvalContent.add({
          'type': 'tool-approval-request',
          'approvalId': _streamingApprovalRequest!.approvalId,
          'toolCall': _streamingApprovalRequest!.toolCall.toJson(),
        });
        _apiMessages.add({'role': 'assistant', 'content': approvalContent});
      } else if (_streamingContent.isNotEmpty) {
        _apiMessages.add({'role': 'assistant', 'content': _streamingContent});
      }

      if (_streamingContent.isNotEmpty) {
        _messages.add(
          _ChatMessage(role: _Role.assistant, content: _streamingContent),
        );
      } else if (!_sawApprovalOrRefreshEvent) {
        // Model called a tool but produced no text — or stream was empty
        _messages.add(
          const _ChatMessage(
            role: _Role.error,
            content: "Hmm, I didn't get a response back. Want to try again?",
          ),
        );
      }
      _isStreaming = false;
      _streamingContent = '';
      _activeToolLabel = null;
      _streamingApprovalRequest = null;
      _sawApprovalOrRefreshEvent = false;
    });
    _scrollToBottom();
  }

  void _onStreamError(dynamic err) {
    if (!mounted) return;
    debugPrint('[BuddyChat] stream error: $err');
    setState(() {
      _messages.add(
        const _ChatMessage(
          role: _Role.error,
          content: "Something went wrong. Check your connection and retry.",
        ),
      );
      _isStreaming = false;
      _streamingContent = '';
      _activeToolLabel = null;
      _streamingApprovalRequest = null;
      _sawApprovalOrRefreshEvent = false;
    });
    _scrollToBottom();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputBar(context, bottomPad),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.background,
      elevation: 0,
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
      titleSpacing: 0,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buddy',
                style: AppTheme.displayStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              if (_isStreaming)
                FadeTransition(
                  opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _dotAnimCtrl,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Text(
                    'Thinking…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: context.colors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: context.colors.border.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final hasContent =
        _messages.isNotEmpty || _isStreaming || _pendingApproval != null;
    if (!hasContent) return _buildEmptyState();

    final children = <Widget>[
      for (final msg in _messages)
        _MessageTile(
          message: msg,
          onRetry: msg.role == _Role.error ? _retryLast : null,
        ),
      if (_isStreaming)
        _streamingContent.isEmpty
            ? (_activeToolLabel != null
                  ? _ToolStatusBubble(label: _activeToolLabel!)
                  : _ThinkingBubble(animation: _dotAnimCtrl))
            : _AssistantBubble(content: _streamingContent, isStreaming: true),
      if (_pendingApproval != null)
        _ApprovalCard(
          approval: _pendingApproval!,
          onConfirm: () => _respondToApproval(approved: true),
          onCancel: () => _respondToApproval(approved: false),
        ),
    ];

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.95),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: context.colors.cardGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.brain,
              color: context.colors.textPrimary,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _userName != null ? 'Hey $_userName,' : 'Hey,',
            style: AppTheme.displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What can I help you with?',
            style: AppTheme.displayStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Workouts, diet, macros, recovery — all yours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: context.colors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _kSuggestions
                .map(
                  (s) => _SuggestionChip(text: s, onTap: () => _sendMessage(s)),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, double bottomPad) {
    final isComposerLocked =
        _isStreaming || _isUploadingAttachment || _pendingApproval != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          top: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_composerAttachment != null) ...[
            _ComposerAttachmentPreview(
              attachment: _composerAttachment!,
              onRemove: _isStreaming || _isUploadingAttachment
                  ? null
                  : () => setState(() => _composerAttachment = null),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    maxHeight: 130,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.cardRaised,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isComposerLocked
                          ? context.colors.border.withValues(alpha: 0.4)
                          : context.colors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                          child: Center(
                            child: _AttachButton(
                              isBusy:
                                  isComposerLocked ||
                                  _composerAttachment != null,
                              onTap: _pickMealPhoto,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          textField: true,
                          label: 'Message Buddy',
                          child: TextField(
                            controller: _inputCtrl,
                            focusNode: _focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            enabled: !isComposerLocked,
                            style: GoogleFonts.plusJakartaSans(
                              color: context.colors.textPrimary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: _isUploadingAttachment
                                  ? 'Uploading photo…'
                                  : _pendingApproval != null
                                  ? 'Approve or cancel the pending change…'
                                  : _isStreaming
                                  ? 'Buddy is thinking…'
                                  : _composerAttachment != null
                                  ? 'Add context for this meal photo…'
                                  : 'Ask Buddy something…',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: context.colors.textMuted,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                0,
                                13,
                                18,
                                13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                isStreaming: isComposerLocked,
                onTap: () => _sendMessage(_inputCtrl.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Message Tile ─────────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;
  const _MessageTile({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      _Role.user => _UserBubble(
        content: message.content,
        attachment: message.attachment,
      ),
      _Role.error => _ErrorBubble(
        content: message.content,
        onRetry: onRetry ?? () {},
      ),
      _Role.assistant => _AssistantBubble(content: message.content),
    };
  }
}

// ─── User Bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String content;
  final _ChatAttachment? attachment;
  const _UserBubble({required this.content, this.attachment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22, left: 52),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.cardRaised,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(5),
            ),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attachment != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(attachment!.localPath),
                    width: 184,
                    height: 132,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 184,
                      height: 132,
                      color: context.colors.background,
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.image,
                        color: context.colors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.camera,
                      size: 12,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Meal photo attached',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (content.trim().isNotEmpty) const SizedBox(height: 10),
              ],
              if (content.trim().isNotEmpty)
                Text(
                  content,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Assistant Bubble ─────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final String content;
  final bool isStreaming;
  const _AssistantBubble({required this.content, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarkdownContent(content: content),
          if (isStreaming) ...[const SizedBox(height: 6), _BlinkingCursor()],
        ],
      ),
    );
  }
}

// ─── Error Bubble ─────────────────────────────────────────────────────────────

class _ErrorBubble extends StatelessWidget {
  final String content;
  final VoidCallback onRetry;
  const _ErrorBubble({required this.content, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textMuted,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.cardRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.rotate_ccw,
                          size: 12,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final BuddyApprovalRequest approval;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ApprovalCard({
    required this.approval,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 22, right: 16),
      decoration: colors.cardDecoration(
        borderColor: colors.warning.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'CONFIRMATION',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              approval.title,
              style: GoogleFonts.plusJakartaSans(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (approval.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                approval.summary,
                style: GoogleFonts.plusJakartaSans(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppPressable(
                    onPressed: onCancel,
                    minHeight: 44,
                    borderRadius: BorderRadius.circular(16),
                    decoration: BoxDecoration(
                      color: colors.cardRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Center(
                      child: Text(
                        approval.cancelLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppPressable(
                    onPressed: onConfirm,
                    minHeight: 44,
                    borderRadius: BorderRadius.circular(16),
                    decoration: BoxDecoration(
                      color: colors.actionSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        approval.confirmLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.actionForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerAttachmentPreview extends StatelessWidget {
  final _ComposerAttachment attachment;
  final VoidCallback? onRemove;

  const _ComposerAttachmentPreview({required this.attachment, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: colors.cardDecoration(radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                attachment.file,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal photo ready',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attachment.isAnalyzing
                        ? 'Analysis started. You can send it now.'
                        : 'Attached to your next Buddy message.',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textMuted,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              AppPressable(
                onPressed: onRemove,
                minHeight: 34,
                minWidth: 34,
                borderRadius: BorderRadius.circular(12),
                decoration: BoxDecoration(
                  color: colors.cardRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(LucideIcons.x, size: 16, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Markdown Content ─────────────────────────────────────────────────────────

class _MarkdownContent extends StatelessWidget {
  final String content;
  const _MarkdownContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.plusJakartaSans(
      color: context.colors.textSecondary,
      fontSize: 14,
      height: 1.65,
    );

    return MarkdownBody(
      data: content,
      imageBuilder: (uri, title, alt) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              uri.toString(),
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: context.colors.cardRaised,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.textMuted,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                color: context.colors.cardRaised,
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.image_off,
                  color: context.colors.textMuted,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
      styleSheet: MarkdownStyleSheet(
        p: base,
        strong: GoogleFonts.plusJakartaSans(
          color: context.colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.65,
        ),
        em: GoogleFonts.plusJakartaSans(
          color: context.colors.textSecondary,
          fontSize: 14,
          fontStyle: FontStyle.italic,
          height: 1.65,
        ),
        h1: AppTheme.displayStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
        h2: AppTheme.displayStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
        h3: GoogleFonts.plusJakartaSans(
          color: context.colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        listBullet: base,
        code: GoogleFonts.sourceCodePro(
          color: context.colors.textPrimary,
          backgroundColor: context.colors.cardRaised,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: context.colors.cardRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: context.colors.border.withValues(alpha: 0.8),
              width: 3,
            ),
          ),
        ),
        blockquote: GoogleFonts.plusJakartaSans(
          color: context.colors.textMuted,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
        tableHead: GoogleFonts.plusJakartaSans(
          color: context.colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tableBody: GoogleFonts.plusJakartaSans(
          color: context.colors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─── Tool Status Bubble ───────────────────────────────────────────────────────

class _ToolStatusBubble extends StatefulWidget {
  final String label;
  const _ToolStatusBubble({required this.label});

  @override
  State<_ToolStatusBubble> createState() => _ToolStatusBubbleState();
}

class _ToolStatusBubbleState extends State<_ToolStatusBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: Icon(
                LucideIcons.loader_circle,
                color: context.colors.textMuted,
                size: 13,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thinking Bubble ──────────────────────────────────────────────────────────

class _ThinkingBubble extends StatelessWidget {
  final AnimationController animation;
  const _ThinkingBubble({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [_AnimatedDots(controller: animation)],
      ),
    );
  }
}

class _AnimatedDots extends AnimatedWidget {
  const _AnimatedDots({required AnimationController controller})
    : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as AnimationController).value;
    return Row(
      children: List.generate(3, (i) {
        final phase = (t - i * 0.18) % 1.0;
        final opacity = (math.sin(phase * 2 * math.pi) * 0.5 + 0.5).clamp(
          0.25,
          1.0,
        );
        return Container(
          margin: const EdgeInsets.only(right: 5),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: context.colors.textMuted.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ─── Blinking Cursor ──────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      _ctrl
        ..stop()
        ..value = 1;
      return;
    }
    if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return Container(
        width: 2,
        height: 14,
        decoration: BoxDecoration(
          color: context.colors.textMuted,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 2,
        height: 14,
        decoration: BoxDecoration(
          color: context.colors.textMuted,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─── Suggestion Chip ──────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onPressed: onTap,
      semanticsLabel: text,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(22),
      decoration: BoxDecoration(
        color: context.colors.cardRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: context.colors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─── Send Button ─────────────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onTap;

  const _AttachButton({required this.isBusy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onPressed: isBusy ? null : onTap,
      semanticsLabel: isBusy ? 'Attachment unavailable' : 'Attach meal photo',
      minHeight: 28,
      minWidth: 28,
      borderRadius: BorderRadius.circular(14),
      child: Icon(
        LucideIcons.paperclip,
        color: isBusy ? context.colors.textMuted : context.colors.textSecondary,
        size: 18,
      ),
    );
  }
}

class _MealPhotoSourceSheet extends StatelessWidget {
  const _MealPhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Pick image from',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose where to add your meal photo from.',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _MealPhotoSourceOption(
              icon: LucideIcons.image,
              label: 'Gallery',
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            _MealPhotoSourceOption(
              icon: LucideIcons.camera,
              label: 'Camera',
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealPhotoSourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MealPhotoSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onPressed: onTap,
      minHeight: 56,
      borderRadius: BorderRadius.circular(18),
      decoration: BoxDecoration(
        color: colors.cardRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, color: colors.textPrimary, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onTap;
  const _SendButton({required this.isStreaming, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onPressed: isStreaming ? null : onTap,
      semanticsLabel: isStreaming ? 'Buddy is responding' : 'Send message',
      minHeight: 48,
      minWidth: 48,
      borderRadius: BorderRadius.circular(24),
      decoration: BoxDecoration(
        color: isStreaming
            ? context.colors.cardRaised
            : context.colors.actionSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStreaming ? context.colors.border : AppTheme.transparent,
        ),
      ),
      child: AnimatedContainer(
        duration: motionDuration(context, const Duration(milliseconds: 200)),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: isStreaming
            ? const _SpinnerIcon()
            : Icon(
                LucideIcons.arrow_up,
                color: context.colors.background,
                size: 20,
              ),
      ),
    );
  }
}

class _SpinnerIcon extends StatefulWidget {
  const _SpinnerIcon();

  @override
  State<_SpinnerIcon> createState() => _SpinnerIconState();
}

class _SpinnerIconState extends State<_SpinnerIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: Icon(
          LucideIcons.loader_circle,
          color: context.colors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
