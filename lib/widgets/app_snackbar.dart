import 'package:buddy/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppSnackbarType { info, success, error }

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

    final (icon, bgColor, borderColor) = switch (type) {
      AppSnackbarType.info => (
        LucideIcons.circle_alert,
        AppTheme.cardDark,
        AppTheme.borderDark,
      ),
      AppSnackbarType.success => (
        LucideIcons.circle_check,
        AppTheme.primary.withValues(alpha: 0.16),
        AppTheme.primary.withValues(alpha: 0.5),
      ),
      AppSnackbarType.error => (
        LucideIcons.circle_alert,
        AppTheme.dangerBg,
        AppTheme.errorBg,
      ),
    };

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppTheme.textCream, size: 16),
            const SizedBox(width: 10),
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

  static void error(BuildContext context, String message, {Duration? duration}) {
    show(
      context,
      message,
      type: AppSnackbarType.error,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
