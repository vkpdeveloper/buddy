import 'package:buddy/app_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

class MealAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const MealAnalysisCard({
    super.key,
    required this.analysis,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final signedUrl = analysis['signedUrl'] as String?;
    final status = analysis['aiAnalysisStatus']?.toString() ?? 'pending';
    final result = analysis['analysisResult'] is Map
        ? Map<String, dynamic>.from(analysis['analysisResult'] as Map)
        : null;
    final loggedQuickMeal = analysis['loggedQuickMeal'] is Map
        ? Map<String, dynamic>.from(analysis['loggedQuickMeal'] as Map)
        : null;
    final macros = result?['macros'] is Map
        ? Map<String, dynamic>.from(result!['macros'] as Map)
        : null;
    final calories = (macros?['calories'] as num?)?.toInt();
    final protein = (macros?['proteinG'] as num?)?.toDouble();
    final carbs = (macros?['carbsG'] as num?)?.toDouble();
    final fat = (macros?['fatG'] as num?)?.toDouble();
    final confidence = (result?['confidence'] as num?)?.toDouble();

    final isReady = status == 'completed' && result != null;
    final isFailed = status == 'failed';
    final isLogged = isReady && loggedQuickMeal != null;
    final loggedMealName = loggedQuickMeal?['mealName']?.toString();
    final loggedDate = loggedQuickMeal?['date']?.toString();

    final title = switch ((isLogged, isReady, isFailed)) {
      (true, _, _) => 'Meal logged automatically',
      (_, true, _) => 'Photo analysis complete',
      (_, _, true) => 'Photo analysis failed',
      _ => 'Photo analysis in progress',
    };

    final (badgeLabel, badgeColor, message) = switch (status) {
      'completed' when isLogged => (
        'LOGGED',
        colors.success,
        _loggedMessage(
          mealName: loggedMealName,
          date: loggedDate,
          tappable: onTap != null,
        ),
      ),
      'completed' => (
        'READY',
        colors.success,
        confidence == null
            ? _tapMessage(onTap != null, 'review this meal analysis.')
            : _tapMessage(
                onTap != null,
                'review this meal. ${(confidence * 100).toStringAsFixed(0)}% confident.',
              ),
      ),
      'failed' => (
        'FAILED',
        colors.error,
        onRetry != null
            ? 'Analysis failed. Retry when you are ready.'
            : 'Analysis failed. Try another upload when you are ready.',
      ),
      _ => (
        'ANALYZING',
        colors.primary,
        'Processing in the background. You can keep using the app.',
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isReady ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: colors.cardDecoration(
            borderColor: colors.border.withValues(alpha: 0.95),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealAnalysisThumbnail(
                signedUrl: signedUrl,
                badgeColor: badgeColor,
                colors: colors,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: badgeColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!isFailed && !isReady)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        else if (isReady && onTap != null)
                          Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: colors.textMuted,
                          )
                        else if (isFailed)
                          Icon(
                            LucideIcons.circle_alert,
                            size: 16,
                            color: colors.error,
                          )
                        else
                          Icon(LucideIcons.check, size: 16, color: badgeColor),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.textMuted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                    if (isReady &&
                        calories != null &&
                        protein != null &&
                        carbs != null &&
                        fat != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MealAnalysisStatChip(
                            label: '$calories kcal',
                            color: colors.xpGold,
                          ),
                          _MealAnalysisStatChip(
                            label: '${protein.toStringAsFixed(1)}g protein',
                            color: colors.success,
                          ),
                          _MealAnalysisStatChip(
                            label: '${carbs.toStringAsFixed(1)}g carbs',
                            color: colors.warning,
                          ),
                          _MealAnalysisStatChip(
                            label: '${fat.toStringAsFixed(1)}g fat',
                            color: colors.info,
                          ),
                        ],
                      ),
                    ],
                    if (isFailed && onRetry != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: Icon(
                          LucideIcons.rotate_cw,
                          color: colors.error,
                          size: 14,
                        ),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.error),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tapMessage(bool tappable, String message) {
    if (tappable) {
      return 'Tap to $message';
    }

    return '${message[0].toUpperCase()}${message.substring(1)}';
  }

  String _loggedMessage({
    required String? mealName,
    required String? date,
    required bool tappable,
  }) {
    final prefix = switch ((mealName, date)) {
      (final String name, final String loggedDate)
          when name.trim().isNotEmpty && loggedDate.trim().isNotEmpty =>
        '$name was logged for $loggedDate automatically.',
      (final String name, _) when name.trim().isNotEmpty =>
        '$name was logged automatically.',
      (_, final String loggedDate) when loggedDate.trim().isNotEmpty =>
        'This meal was logged automatically for $loggedDate.',
      _ => 'This meal was logged automatically.',
    };

    if (!tappable) {
      return prefix;
    }

    return '$prefix Tap to review the analysis.';
  }
}

class _MealAnalysisThumbnail extends StatelessWidget {
  final String? signedUrl;
  final Color badgeColor;
  final AppColorScheme colors;

  const _MealAnalysisThumbnail({
    required this.signedUrl,
    required this.badgeColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        height: 88,
        child: signedUrl == null
            ? ColoredBox(
                color: badgeColor.withValues(alpha: 0.12),
                child: Center(
                  child: Icon(
                    LucideIcons.scan_search,
                    size: 22,
                    color: badgeColor,
                  ),
                ),
              )
            : Image.network(
                signedUrl!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : ColoredBox(
                        color: badgeColor.withValues(alpha: 0.08),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.cardRaised,
                  child: Center(
                    child: Icon(
                      LucideIcons.image_off,
                      size: 20,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MealAnalysisStatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MealAnalysisStatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
