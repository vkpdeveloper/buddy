import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/buddy_chat.dart';
import 'package:buddy/providers/buddy_provider.dart';
import 'package:buddy/services/media_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/utils/motion_preferences.dart';
import 'package:buddy/widgets/app_buttons.dart';

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

class BuddyChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  const BuddyChatPage({super.key, required this.sessionId});

  @override
  ConsumerState<BuddyChatPage> createState() => _BuddyChatPageState();
}

class _BuddyChatPageState extends ConsumerState<BuddyChatPage>
    with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  String? _userName;
  bool _isUploadingAttachment = false;
  _ComposerAttachment? _composerAttachment;

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
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _dotAnimCtrl.dispose();
    _fadeInCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) {
        return;
      }
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage(BuddySessionState sessionState, String text) async {
    if (sessionState.isStreaming ||
        _isUploadingAttachment ||
        sessionState.pendingApproval != null) {
      return;
    }

    final attachment = _composerAttachment == null
        ? null
        : BuddyDraftAttachment(
            attachmentId: _composerAttachment!.attachmentId,
            localPath: _composerAttachment!.file.path,
            signedUrl: _composerAttachment!.signedUrl,
          );

    if (text.trim().isEmpty && attachment == null) {
      return;
    }

    final controller = ref.read(buddySessionProvider(widget.sessionId).notifier);
    await controller.sendUserMessage(text: text, attachment: attachment);

    if (!mounted) {
      return;
    }

    _inputCtrl.clear();
    _focusNode.unfocus();
    setState(() => _composerAttachment = null);
    _scrollToBottom();
  }

  Future<void> _respondToApproval({
    required BuddySessionState sessionState,
    required bool approved,
  }) async {
    if (sessionState.pendingApproval == null ||
        sessionState.isStreaming ||
        _isUploadingAttachment) {
      return;
    }

    final controller = ref.read(buddySessionProvider(widget.sessionId).notifier);
    await controller.respondToApproval(approved: approved);
    _scrollToBottom();
  }

  Future<void> _pickMealPhoto(BuddySessionState sessionState) async {
    if (sessionState.isStreaming ||
        _isUploadingAttachment ||
        _composerAttachment != null ||
        sessionState.pendingApproval != null) {
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
    if (!mounted || source == null) {
      return;
    }

    await _pickMealPhotoFromSource(source);
  }

  Future<void> _pickMealPhotoFromSource(ImageSource source) async {
    try {
      final picked = await _pickMealPhotoFile(source);
      if (picked == null) {
        return;
      }

      final file = File(picked.path);
      final mimeType = _mimeTypeForPath(file.path);

      setState(() => _isUploadingAttachment = true);

      final upload = await MediaService.uploadMealPhoto(file, mimeType);
      final data = Map<String, dynamic>.from(upload['data'] as Map);
      final attachmentId = (data['id'] as num?)?.toInt();
      if (attachmentId == null) {
        throw Exception('Upload did not return an attachment id.');
      }

      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      _showSnack(_mealPhotoUploadErrorMessage(err, source));
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

  Future<XFile?> _pickMealPhotoFile(ImageSource source) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1280,
        requestFullMetadata: !(Platform.isIOS && source == ImageSource.gallery),
      );
    } on PlatformException catch (err) {
      if (!_isIosGalleryRepresentationError(err, source)) {
        rethrow;
      }

      debugPrint(
        '[BuddyChat] retrying iOS gallery pick without transforms: $err',
      );

      return _imagePicker.pickImage(source: source, requestFullMetadata: false);
    }
  }

  bool _isIosGalleryRepresentationError(
    PlatformException err,
    ImageSource source,
  ) {
    return Platform.isIOS &&
        source == ImageSource.gallery &&
        err.code == 'invalid_image';
  }

  String _mealPhotoUploadErrorMessage(Object err, ImageSource source) {
    if (err is PlatformException &&
        _isIosGalleryRepresentationError(err, source)) {
      return 'That photo format could not be loaded from Photos. Try another image or use the camera.';
    }

    return 'Meal photo upload failed.';
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRenameDialog(BuddySessionState sessionState) async {
    final controller = TextEditingController(
      text: sessionState.session?.title ?? 'New Session',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.cardRaised,
        title: Text(
          'Rename session',
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Session title',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) {
      return;
    }

    await ref
        .read(buddySessionProvider(widget.sessionId).notifier)
        .renameSession(title);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.cardRaised,
        title: Text(
          'Delete session?',
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This removes the full conversation history from Buddy.',
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.background,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(buddySessionProvider(widget.sessionId).notifier).deleteSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BuddySessionState>(buddySessionProvider(widget.sessionId), (
      previous,
      next,
    ) {
      final messageCountChanged = previous?.messages.length != next.messages.length;
      final streamingChanged =
          previous?.streamingContent != next.streamingContent ||
          previous?.pendingApproval != next.pendingApproval ||
          previous?.errorMessage != next.errorMessage;

      if (messageCountChanged || streamingChanged) {
        _scrollToBottom();
      }

      if (!(previous?.isDeleted ?? false) && next.isDeleted && mounted) {
        Navigator.of(context).pop();
      }
    });

    final sessionState = ref.watch(buddySessionProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: _buildAppBar(context, sessionState),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            Expanded(child: _buildMessageList(sessionState)),
            _buildInputBar(context, sessionState, MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BuddySessionState sessionState,
  ) {
    return AppBar(
      backgroundColor: context.colors.background,
      elevation: 0,
      leading: AppBackButton(onPressed: () => Navigator.pop(context)),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              sessionState.session?.title ?? 'Buddy',
              key: ValueKey(sessionState.session?.title ?? 'Buddy'),
              style: AppTheme.displayStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          if (sessionState.isStreaming)
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
      actions: [
        PopupMenuButton<_ChatMenuAction>(
          icon: Icon(
            LucideIcons.ellipsis_vertical,
            color: context.colors.textMuted,
            size: 18,
          ),
          color: context.colors.cardRaised,
          onSelected: (action) async {
            switch (action) {
              case _ChatMenuAction.pin:
                await ref
                    .read(buddySessionProvider(widget.sessionId).notifier)
                    .togglePinned();
                break;
              case _ChatMenuAction.rename:
                await _showRenameDialog(sessionState);
                break;
              case _ChatMenuAction.delete:
                await _confirmDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _ChatMenuAction.pin,
              child: Text(
                sessionState.session?.isPinned == true ? 'Unpin' : 'Pin',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.rename,
              child: Text(
                'Rename',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.delete,
              child: Text(
                'Delete',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: context.colors.border.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMessageList(BuddySessionState sessionState) {
    final hasContent =
        sessionState.messages.isNotEmpty ||
        sessionState.isStreaming ||
        sessionState.pendingApproval != null ||
        sessionState.errorMessage != null;

    if (sessionState.isLoading && !hasContent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasContent) {
      return _buildEmptyState(sessionState);
    }

    final children = <Widget>[
      for (final message in sessionState.messages) _MessageTile(message: message),
      if (sessionState.isStreaming)
        sessionState.streamingContent.isEmpty
            ? (sessionState.activeToolLabel != null
                  ? _ToolStatusBubble(label: sessionState.activeToolLabel!)
                  : _ThinkingBubble(animation: _dotAnimCtrl))
            : _AssistantBubble(
                content: sessionState.streamingContent,
                isStreaming: true,
              ),
      if (sessionState.pendingApproval != null)
        _ApprovalCard(
          approval: sessionState.pendingApproval!,
          onConfirm: () =>
              _respondToApproval(sessionState: sessionState, approved: true),
          onCancel: () =>
              _respondToApproval(sessionState: sessionState, approved: false),
        ),
      if (sessionState.errorMessage != null)
        _ErrorBubble(content: sessionState.errorMessage!),
    ];

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: children,
    );
  }

  Widget _buildEmptyState(BuddySessionState sessionState) {
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
                  (suggestion) => _SuggestionChip(
                    text: suggestion,
                    onTap: () => _sendMessage(sessionState, suggestion),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    BuddySessionState sessionState,
    double bottomPad,
  ) {
    final isComposerLocked =
        sessionState.isStreaming ||
        _isUploadingAttachment ||
        sessionState.pendingApproval != null;

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
              onRemove: sessionState.isStreaming || _isUploadingAttachment
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
                              onTap: () => _pickMealPhoto(sessionState),
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
                                  : sessionState.pendingApproval != null
                                  ? 'Approve or cancel the pending change…'
                                  : sessionState.isStreaming
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
                onTap: () => _sendMessage(sessionState, _inputCtrl.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ChatMenuAction { pin, rename, delete }

class _MessageTile extends StatelessWidget {
  final BuddyChatMessage message;

  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      BuddyMessageRole.user => _UserBubble(message: message),
      BuddyMessageRole.buddy => _AssistantBubble(content: message.message),
    };
  }
}

class _UserBubble extends StatelessWidget {
  final BuddyChatMessage message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final hasText = message.message.trim().isNotEmpty;

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
              if (message.attachments.isNotEmpty) ...[
                for (final attachment in message.attachments) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildUserAttachmentImage(context, attachment),
                  ),
                ],
                if (hasText) const SizedBox(height: 10),
              ],
              if (hasText)
                Text(
                  message.message,
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

  Widget _buildUserAttachmentImage(
    BuildContext context,
    BuddyMessageAttachment attachment,
  ) {
    final localPath = attachment.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        width: 184,
        height: 132,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _attachmentFallback(context),
      );
    }

    if (attachment.signedUrl != null && attachment.signedUrl!.isNotEmpty) {
      return Image.network(
        attachment.signedUrl!,
        width: 184,
        height: 132,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _attachmentFallback(context),
      );
    }

    return _attachmentFallback(context);
  }

  Widget _attachmentFallback(BuildContext context) {
    return Container(
      width: 184,
      height: 132,
      color: context.colors.background,
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.image,
        color: context.colors.textMuted,
        size: 20,
      ),
    );
  }
}

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

class _ErrorBubble extends StatelessWidget {
  final String content;

  const _ErrorBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22, right: 16),
      child: Text(
        content,
        style: GoogleFonts.plusJakartaSans(
          color: context.colors.textMuted,
          fontSize: 14,
          height: 1.55,
        ),
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
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  attachment.file,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: AppPressable(
                  onPressed: onRemove,
                  minHeight: 34,
                  minWidth: 34,
                  borderRadius: BorderRadius.circular(12),
                  decoration: BoxDecoration(
                    color: colors.cardRaised.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(LucideIcons.x, size: 16, color: colors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
      semanticsLabel: isStreaming ? 'Send unavailable' : 'Send message',
      minHeight: 48,
      minWidth: 48,
      borderRadius: BorderRadius.circular(24),
      decoration: BoxDecoration(
        color: isStreaming
            ? context.colors.cardRaised
            : context.colors.actionSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStreaming
              ? context.colors.border
              : context.colors.actionSurface,
        ),
      ),
      child: Icon(
        LucideIcons.arrow_up,
        color: isStreaming
            ? context.colors.textMuted
            : context.colors.actionForeground,
        size: 18,
      ),
    );
  }
}
