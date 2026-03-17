import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/buddy_chat.dart';
import 'package:buddy/pages/buddy_chat_page.dart';
import 'package:buddy/providers/buddy_provider.dart';
import 'package:buddy/widgets/app_buttons.dart';

class BuddySessionsPage extends ConsumerWidget {
  const BuddySessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(buddySessionListProvider);
    final notifier = ref.read(buddySessionListProvider.notifier);

    Future<void> openNewChat() async {
      final session = await notifier.createSession();
      if (!context.mounted || session == null) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BuddyChatPage(sessionId: session.id)),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'Buddy',
          style: AppTheme.displayStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _PlainToolbarIconButton(
              icon: state.isCreating
                  ? LucideIcons.loader_circle
                  : LucideIcons.plus,
              onPressed: state.isCreating ? null : openNewChat,
              label: 'New chat',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        color: context.colors.textPrimary,
        backgroundColor: context.colors.cardRaised,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (state.errorMessage != null) ...[
              _ErrorBanner(message: state.errorMessage!),
              const SizedBox(height: 14),
            ],
            if (state.isLoading && state.sessions.isEmpty)
              const _LoadingState()
            else if (state.sessions.isEmpty)
              _EmptyState(isCreating: state.isCreating, onCreate: openNewChat)
            else ...[
              for (var index = 0; index < state.sessions.length; index++) ...[
                _SessionCard(
                  session: state.sessions[index],
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            BuddyChatPage(sessionId: state.sessions[index].id),
                      ),
                    );
                  },
                  onLongPress: () => _showSessionActionsSheet(
                    context,
                    ref,
                    state.sessions[index],
                  ),
                ),
                if (index != state.sessions.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionActionsSheet(
    BuildContext context,
    WidgetRef ref,
    BuddySessionSummary session,
  ) async {
    final action = await showModalBottomSheet<_SessionAction>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SessionActionsSheet(session: session),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _SessionAction.pin:
        await ref
            .read(buddySessionListProvider.notifier)
            .setPinned(session.id, !session.isPinned);
        break;
      case _SessionAction.rename:
        await _showRenameDialog(context, ref, session);
        break;
      case _SessionAction.delete:
        await _confirmDelete(context, ref, session);
        break;
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    BuddySessionSummary session,
  ) async {
    final controller = TextEditingController(text: session.title);
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
        .read(buddySessionListProvider.notifier)
        .renameSession(session.id, title);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BuddySessionSummary session,
  ) async {
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
          'This removes the full conversation history for "${session.title}".',
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
      await ref
          .read(buddySessionListProvider.notifier)
          .deleteSession(session.id);
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SessionSkeletonCard(),
        SizedBox(height: 12),
        _SessionSkeletonCard(),
        SizedBox(height: 12),
        _SessionSkeletonCard(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isCreating;
  final VoidCallback onCreate;

  const _EmptyState({required this.isCreating, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a new chat',
            style: AppTheme.displayStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buddy will save each conversation so you can come back later without losing context.',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'New Chat',
            onPressed: isCreating ? null : onCreate,
            icon: LucideIcons.plus,
            isLoading: isCreating,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final BuddySessionSummary session;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  const _SessionCard({
    required this.session,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            session.title,
                            key: ValueKey(session.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: context.colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (session.isPinned) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          LucideIcons.pin,
                          size: 14,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sessionPreview(session),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SessionAction { pin, rename, delete }

class _PlainToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;

  const _PlainToolbarIconButton({
    required this.icon,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AppPressable(
        onPressed: onPressed,
        semanticsLabel: label,
        minHeight: AppTheme.minimumTouchTarget,
        minWidth: AppTheme.minimumTouchTarget,
        borderRadius: BorderRadius.circular(14),
        child: Icon(
          icon,
          color: onPressed == null
              ? context.colors.textMuted
              : context.colors.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: context.colors.errorBg.withValues(
          alpha: context.colors.isDark ? 0.18 : 0.92,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circle_alert, color: context.colors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textPrimary,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionActionsSheet extends StatelessWidget {
  final BuddySessionSummary session;

  const _SessionActionsSheet({required this.session});

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
              'Chat actions',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _SessionActionOption(
              icon: session.isPinned ? LucideIcons.pin_off : LucideIcons.pin,
              label: session.isPinned ? 'Unpin session' : 'Pin session',
              onTap: () => Navigator.of(context).pop(_SessionAction.pin),
            ),
            const SizedBox(height: 10),
            _SessionActionOption(
              icon: LucideIcons.pencil_line,
              label: 'Rename session',
              onTap: () => Navigator.of(context).pop(_SessionAction.rename),
            ),
            const SizedBox(height: 10),
            _SessionActionOption(
              icon: LucideIcons.trash_2,
              label: 'Delete session',
              color: colors.error,
              onTap: () => Navigator.of(context).pop(_SessionAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionActionOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SessionActionOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolvedColor = color ?? colors.textPrimary;

    return Row(
      children: [
        Expanded(
          child: AppPressable(
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
                Icon(icon, color: resolvedColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: resolvedColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionSkeletonCard extends StatelessWidget {
  const _SessionSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final shimmer = context.colors.textMuted.withValues(
      alpha: context.colors.isDark ? 0.12 : 0.09,
    );

    Widget bar(double width, {double height = 10}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmer,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(170, height: 16),
          const SizedBox(height: 10),
          bar(double.infinity, height: 11),
          const SizedBox(height: 8),
          bar(214, height: 11),
        ],
      ),
    );
  }
}

String _sessionPreview(BuddySessionSummary session) {
  final preview = session.lastMessagePreview?.trim();
  if (preview == null || preview.isEmpty) {
    if (session.hasPendingApproval) {
      return 'Approval needed.';
    }
    return 'No messages yet. Tap to start a new check-in with Buddy.';
  }

  return preview;
}
