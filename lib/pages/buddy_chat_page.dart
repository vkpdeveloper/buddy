import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:buddy/app_theme.dart';
import 'package:buddy/utils/motion_preferences.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/services/buddy_service.dart';
import 'package:buddy/services/profile_service.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

enum _Role { user, assistant, error }

class _ChatMessage {
  final _Role role;
  final String content;
  const _ChatMessage({required this.role, required this.content});
}

const _kSuggestions = [
  'What\'s in my workout today?',
  'What should I eat after training?',
  'How am I doing this week?',
  'Show me my full diet plan',
  'Review my workout program',
  'How\'s my streak looking?',
];

// ─── Page ─────────────────────────────────────────────────────────────────────

class BuddyChatPage extends StatefulWidget {
  const BuddyChatPage({super.key});

  @override
  State<BuddyChatPage> createState() => _BuddyChatPageState();
}

class _BuddyChatPageState extends State<BuddyChatPage>
    with TickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _userName;
  bool _isStreaming = false;
  String _streamingContent = '';
  String? _activeToolLabel;
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
    if (trimmed.isEmpty || _isStreaming) return;

    _inputCtrl.clear();
    _focusNode.unfocus();

    // Remove any trailing error message before adding the new user turn
    setState(() {
      _messages.removeWhere((m) => m.role == _Role.error);
      _messages.add(_ChatMessage(role: _Role.user, content: trimmed));
      _isStreaming = true;
      _streamingContent = '';
      _activeToolLabel = null;
    });

    _scrollToBottom();

    final apiMessages = _apiHistory();
    _startStream(apiMessages);
  }

  // ─── Retry ──────────────────────────────────────────────────────────────────

  void _retryLast() {
    if (_isStreaming) return;

    // Strip error bubble, keep user message, resend
    setState(() {
      _messages.removeWhere((m) => m.role == _Role.error);
      _isStreaming = true;
      _streamingContent = '';
      _activeToolLabel = null;
    });

    _scrollToBottom();
    _startStream(_apiHistory());
  }

  // ─── Stream orchestration ───────────────────────────────────────────────────

  /// Returns message history suitable for the API (excludes error messages).
  List<Map<String, dynamic>> _apiHistory() {
    return _messages
        .where((m) => m.role != _Role.error)
        .map(
          (m) => {
            'role': m.role == _Role.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }

  void _startStream(List<Map<String, dynamic>> apiMessages) {
    _streamSub?.cancel();

    try {
      _streamSub = BuddyService.buddyChat(apiMessages).listen(
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
      if (_streamingContent.isNotEmpty) {
        _messages.add(
          _ChatMessage(role: _Role.assistant, content: _streamingContent),
        );
      } else {
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
    });
    _scrollToBottom();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputBar(bottomPad),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.oledBlack,
      elevation: 0,
      leading: AppBackButton(
        onPressed: () => Navigator.pop(context),
      ),
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
                      color: AppTheme.textSageMuted,
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
          color: AppTheme.borderDark.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final hasContent = _messages.isNotEmpty || _isStreaming;
    if (!hasContent) return _buildEmptyState();

    final streamingBubble = _isStreaming ? 1 : 0;
    final itemCount = _messages.length + streamingBubble;

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          final msg = _messages[index];
          return _MessageTile(
            message: msg,
            onRetry: msg.role == _Role.error ? _retryLast : null,
          );
        }
        // Streaming bubble
        if (_streamingContent.isEmpty) {
          if (_activeToolLabel != null) {
            return _ToolStatusBubble(label: _activeToolLabel!);
          }
          return _ThinkingBubble(animation: _dotAnimCtrl);
        }
        return _AssistantBubble(content: _streamingContent, isStreaming: true);
      },
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
                color: AppTheme.borderDark.withValues(alpha: 0.95),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A151B),
                  Color(0xFF14161A),
                  AppTheme.cardDark,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowSoft.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.brain,
              color: AppTheme.textCream,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _userName != null ? 'Hey $_userName,' : 'Hey,',
            style: AppTheme.displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What can I help you with?',
            style: AppTheme.displayStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Workouts, diet, macros, recovery — all yours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppTheme.textSageMuted,
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

  Widget _buildInputBar(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
      decoration: BoxDecoration(
        color: AppTheme.oledBlack,
        border: Border(
          top: BorderSide(color: AppTheme.borderDark.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 130),
              decoration: BoxDecoration(
                color: AppTheme.cardRaised,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _isStreaming
                      ? AppTheme.borderDark.withValues(alpha: 0.4)
                      : AppTheme.borderDark,
                ),
              ),
              child: Semantics(
                textField: true,
                label: 'Message Buddy',
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  enabled: !_isStreaming,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: _isStreaming
                        ? 'Buddy is thinking…'
                        : 'Ask Buddy something…',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(
            isStreaming: _isStreaming,
            onTap: () => _sendMessage(_inputCtrl.text),
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
      _Role.user => _UserBubble(content: message.content),
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
  const _UserBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22, left: 52),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardRaised,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(5),
            ),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 14,
              height: 1.55,
            ),
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
                    color: AppTheme.textSageMuted,
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
                      color: AppTheme.cardRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.rotate_ccw,
                          size: 12,
                          color: AppTheme.textSageMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
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

// ─── Markdown Content ─────────────────────────────────────────────────────────

class _MarkdownContent extends StatelessWidget {
  final String content;
  const _MarkdownContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.plusJakartaSans(
      color: AppTheme.textMain,
      fontSize: 14,
      height: 1.65,
    );

    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: base,
        strong: GoogleFonts.plusJakartaSans(
          color: AppTheme.textCream,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.65,
        ),
        em: GoogleFonts.plusJakartaSans(
          color: AppTheme.textMain,
          fontSize: 14,
          fontStyle: FontStyle.italic,
          height: 1.65,
        ),
        h1: AppTheme.displayStyle(fontSize: 18, fontWeight: FontWeight.w700),
        h2: AppTheme.displayStyle(fontSize: 15, fontWeight: FontWeight.w600),
        h3: GoogleFonts.plusJakartaSans(
          color: AppTheme.textCream,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        listBullet: base,
        code: GoogleFonts.sourceCodePro(
          color: AppTheme.textCream,
          backgroundColor: AppTheme.cardRaised,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.cardRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderDark),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.borderDark.withValues(alpha: 0.8),
              width: 3,
            ),
          ),
        ),
        blockquote: GoogleFonts.plusJakartaSans(
          color: AppTheme.textSageMuted,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
        tableHead: GoogleFonts.plusJakartaSans(
          color: AppTheme.textCream,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tableBody: GoogleFonts.plusJakartaSans(
          color: AppTheme.textMain,
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
              child: const Icon(
                LucideIcons.loader_circle,
                color: AppTheme.textSageMuted,
                size: 13,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
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
            color: AppTheme.textSageMuted.withValues(alpha: opacity),
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
          color: AppTheme.textSageMuted,
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
          color: AppTheme.textSageMuted,
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
        color: AppTheme.cardRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.textMain,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─── Send Button ─────────────────────────────────────────────────────────────

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
        color: isStreaming ? AppTheme.cardRaised : AppTheme.textCream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStreaming ? AppTheme.borderDark : AppTheme.transparent,
        ),
      ),
      child: AnimatedContainer(
        duration: motionDuration(context, const Duration(milliseconds: 200)),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: isStreaming
            ? const _SpinnerIcon()
            : const Icon(
                LucideIcons.arrow_up,
                color: AppTheme.oledBlack,
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
        child: const Icon(
          LucideIcons.loader_circle,
          color: AppTheme.textSageMuted,
          size: 20,
        ),
      ),
    );
  }
}
