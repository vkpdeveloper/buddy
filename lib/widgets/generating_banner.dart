import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/generation_provider.dart';

/// A subtle animated banner shown while diet/workout plans are being generated.
/// Pass [watchType] as 'diet' or 'workout' to watch only one; omit for both.
class GeneratingBanner extends ConsumerWidget {
  final String? watchType;

  const GeneratingBanner({super.key, this.watchType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(generationStatusProvider);
    final job = switch (watchType) {
      'diet' => status.diet,
      'workout' => status.workout,
      _ => null,
    };

    final bool relevant = switch (watchType) {
      'diet' => status.diet.isGenerating,
      'workout' => status.workout.isGenerating,
      _ => status.isGenerating,
    };

    if (!relevant) return const SizedBox.shrink();

    final label = _label(watchType, status);
    final progress = job?.progressPercent ?? status.overallProgressPercent;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: (progress / 100).clamp(0, 1).toDouble(),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.clamp(0, 100)}% ready',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String? type, GenerationStatus status) {
    if (type == 'diet') return status.diet.stageMessage;
    if (type == 'workout') return status.workout.stageMessage;
    return status.primaryMessage;
  }
}
