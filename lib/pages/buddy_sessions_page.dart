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
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        titleSpacing: 0,
        title: Text(
          'Buddy',
          style: AppTheme.displayStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppSurfaceIconButton(
              icon: state.isCreating ? LucideIcons.loader_circle : LucideIcons.plus,
              onPressed: state.isCreating ? null : openNewChat,
              label: 'New Chat',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        color: context.colors.textPrimary,
        backgroundColor: context.colors.cardRaised,
        child: state.sessions.isEmpty && state.isLoading
            ? const _LoadingState()
            : state.sessions.isEmpty
            ? _EmptyState(
                isCreating: state.isCreating,
                onCreate: openNewChat,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                itemBuilder: (context, index) {
                  final session = state.sessions[index];
                  return _SessionCard(
                    session: session,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BuddyChatPage(sessionId: session.id),
                        ),
                      );
                    },
                    onRename: () => _showRenameDialog(context, ref, session),
                    onTogglePinned: () =>
                        notifier.setPinned(session.id, !session.isPinned),
                    onDelete: () => _confirmDelete(context, ref, session),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: state.sessions.length,
              ),
      ),
    );
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

    await ref.read(buddySessionListProvider.notifier).renameSession(
          session.id,
          title,
        );
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
      await ref.read(buddySessionListProvider.notifier).deleteSession(session.id);
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator()),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: context.colors.cardDecoration(radius: 24),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.brain,
            color: context.colors.textPrimary,
            size: 34,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Start a new chat',
          textAlign: TextAlign.center,
          style: AppTheme.displayStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick up earlier conversations later. Buddy will keep your sessions and meal-photo context intact.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textMuted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        AppPrimaryButton(
          label: 'New Chat',
          onPressed: isCreating ? null : onCreate,
          icon: LucideIcons.plus,
          isLoading: isCreating,
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final BuddySessionSummary session;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onOpen,
    required this.onRename,
    required this.onTogglePinned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onPressed: onOpen,
      borderRadius: BorderRadius.circular(22),
      decoration: context.colors.cardDecoration(radius: 22),
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (session.isPinned) ...[
                      Icon(
                        LucideIcons.pin,
                        size: 13,
                        color: context.colors.warning,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          session.title,
                          key: ValueKey(session.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatRelativeTime(session.activityAt),
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  session.lastMessagePreview?.trim().isNotEmpty == true
                      ? session.lastMessagePreview!
                      : 'No messages yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
                if (session.hasPendingApproval) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: context.colors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Approval needed',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_SessionAction>(
            icon: Icon(
              LucideIcons.ellipsis_vertical,
              color: context.colors.textMuted,
              size: 18,
            ),
            color: context.colors.cardRaised,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SessionAction.pin,
                child: Text(
                  session.isPinned ? 'Unpin' : 'Pin',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuItem(
                value: _SessionAction.rename,
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
                value: _SessionAction.delete,
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
            onSelected: (action) {
              switch (action) {
                case _SessionAction.pin:
                  onTogglePinned();
                  break;
                case _SessionAction.rename:
                  onRename();
                  break;
                case _SessionAction.delete:
                  onDelete();
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}

enum _SessionAction { pin, rename, delete }

String _formatRelativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);

  if (diff.inMinutes < 1) {
    return 'Now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) {
    return '${weeks}w';
  }
  final months = (diff.inDays / 30).floor();
  return '${months}mo';
}
