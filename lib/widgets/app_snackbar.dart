import 'package:buddy/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppSnackbarType { info, success, warning, error }

class AppSnackbar {
  const AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final (icon, iconColor, bgColor, borderColor) = switch (type) {
      AppSnackbarType.info => (
        LucideIcons.info,
        AppTheme.info,
        AppTheme.info.withValues(alpha: 0.08),
        AppTheme.info.withValues(alpha: 0.35),
      ),
      AppSnackbarType.success => (
        LucideIcons.circle_check,
        AppTheme.success,
        AppTheme.success.withValues(alpha: 0.08),
        AppTheme.success.withValues(alpha: 0.35),
      ),
      AppSnackbarType.warning => (
        LucideIcons.triangle_alert,
        AppTheme.warning,
        AppTheme.warning.withValues(alpha: 0.08),
        AppTheme.warning.withValues(alpha: 0.35),
      ),
      AppSnackbarType.error => (
        LucideIcons.circle_x,
        AppTheme.error,
        AppTheme.error.withValues(alpha: 0.08),
        AppTheme.error.withValues(alpha: 0.35),
      ),
    };

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        content: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void info(BuildContext context, String message, {Duration? duration}) {
    show(
      context,
      message,
      type: AppSnackbarType.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: AppSnackbarType.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    show(
      context,
      message,
      type: AppSnackbarType.warning,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void error(BuildContext context, String message, {Duration? duration}) {
    show(
      context,
      message,
      type: AppSnackbarType.error,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
