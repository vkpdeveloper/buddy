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

    final bool relevant = switch (watchType) {
      'diet' => status.diet == 'pending' || status.diet == 'generating',
      'workout' =>
        status.workout == 'pending' || status.workout == 'generating',
      _ => status.isGenerating,
    };

    if (!relevant) return const SizedBox.shrink();

    final label = _label(watchType, status);
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
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary,
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

  String _label(String? type, GenerationStatus status) {
    if (type == 'diet') return 'Building your diet plan — won\'t be long!';
    if (type == 'workout') return 'Building your workout plan — won\'t be long!';
    if (status.diet == 'done') return 'Almost there — finishing your workout plan…';
    if (status.workout == 'done') return 'Almost there — finishing your diet plan…';
    return 'Getting your plans ready, just a moment…';
  }
}
