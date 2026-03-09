import 'dart:math' as math;
import 'dart:io';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/body_measurement.dart';
import 'package:buddy/models/growth.dart';
import 'package:buddy/providers/body_provider.dart';
import 'package:buddy/providers/growth_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/body_service.dart';
import 'package:buddy/services/progress_share_service.dart';
import 'package:buddy/widgets/app_empty_state.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/progress_share_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class GrowthPage extends ConsumerStatefulWidget {
  const GrowthPage({super.key});

  @override
  ConsumerState<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends ConsumerState<GrowthPage> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _refresh() async {
    ref.invalidate(growthOverviewProvider);
    ref.invalidate(growthPhotosProvider);
    ref.invalidate(growthGoalsProvider);
    ref.invalidate(bodyHistoryProvider);
    ref.invalidate(latestBodyMeasurementProvider);
    ref.invalidate(progressProvider);
    await Future.delayed(const Duration(milliseconds: 350));
  }

  void _openLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _LogMeasurementSheet(
        onLogged: (result) {
          _refresh();
          _showXpCelebration(result);
        },
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final mimeType = _mimeFromName(file.name);
      if (mimeType == 'image/gif') {
        if (mounted) {
          AppSnackbar.error(context, 'GIF uploads are not supported');
        }
        return;
      }
      final today = DateTime.now().toIso8601String().split('T').first;
      await BodyService.uploadGrowthPhoto(
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
        date: today,
      );
      if (mounted) {
        AppSnackbar.success(context, 'Progress photo added');
      }
      _refresh();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Failed to upload photo: $e');
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.avif')) return 'image/avif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    if (lower.endsWith('.jfif')) return 'image/jpeg';
    return 'image/jpeg';
  }

  void _showGoalEditSheet(GrowthGoalData goals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GoalEditSheet(initial: goals),
    ).then((saved) {
      if (saved == true) {
        _refresh();
      }
    });
  }

  void _showXpCelebration(BodyLogResult result) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: AppTheme.oledBlack.withValues(alpha: 0.7),
      builder: (_) => _XpCelebrationDialog(result: result),
    );
  }

  Future<void> _handleGrowthShare(
    AsyncValue<GrowthOverviewData> overview,
  ) async {
    if (overview.isLoading) {
      AppSnackbar.info(context, 'Fetching latest growth stats...');
      return;
    }
    if (overview.hasError) {
      AppSnackbar.error(context, 'Unable to load growth snapshot');
      return;
    }
    final data = overview.asData?.value;
    if (data == null || data.totalLogs == 0) {
      AppSnackbar.info(context, 'Log a check-in first to share your progress');
      return;
    }
    await _openGrowthSharePreview(data);
  }

  Future<void> _openGrowthSharePreview(GrowthOverviewData overview) async {
    final captureKey = GlobalKey();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var sharing = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: captureKey,
                      child: GrowthShareCard(overview: overview),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Preview your progress card before sharing.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: sharing
                                ? null
                                : () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppTheme.borderDark,
                              ),
                              foregroundColor: AppTheme.textSageMuted,
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: sharing
                                ? null
                                : () async {
                                    setModalState(() => sharing = true);
                                    try {
                                      final bytes =
                                          await ProgressShareService.captureBoundaryPng(
                                            captureKey,
                                          );
                                      await ProgressShareService.sharePngBytes(
                                        pngBytes: bytes,
                                        fileStem:
                                            'growth_snapshot_${DateTime.now().millisecondsSinceEpoch}',
                                        text:
                                            'Tracking progress with Buddy. #fitness',
                                        subject: 'My growth snapshot',
                                      );
                                    } catch (e) {
                                      if (sheetContext.mounted) {
                                        AppSnackbar.error(
                                          sheetContext,
                                          'Could not share snapshot: $e',
                                        );
                                      }
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setModalState(() => sharing = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.oledBlack,
                            ),
                            icon: sharing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.oledBlack,
                                    ),
                                  )
                                : const Icon(LucideIcons.send, size: 16),
                            label: Text(sharing ? 'Sharing...' : 'Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(growthOverviewProvider);

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SafeArea(
        child: Column(
          children: [
            _GrowthHeader(
              onLogTap: _openLogSheet,
              onPhotoTap: _pickAndUploadPhoto,
              onShareTap: () => _handleGrowthShare(overviewAsync),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.cardDark,
                onRefresh: _refresh,
                child: overviewAsync.when(
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 300)],
                  ),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      AppEmptyState(
                        icon: LucideIcons.triangle_alert,
                        title: 'Could not load Growth',
                        subtitle: '$e',
                      ),
                    ],
                  ),
                  data: (overview) {
                    if (overview.totalLogs == 0) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: 80,
                          left: 16,
                          right: 16,
                        ),
                        children: const [
                          AppEmptyState(
                            icon: LucideIcons.trending_up,
                            title: 'No growth logs yet',
                            subtitle:
                                'Start check-ins to unlock trends, goals, body-composition, and milestone rewards.',
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 92),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          _StatsStrip(overview: overview),
                          const SizedBox(height: 16),
                          _LevelCard(overview: overview),
                          const SizedBox(height: 20),
                          _MetricGrid(metrics: overview.metricCards),
                          const SizedBox(height: 20),
                          _PhotoCompareCard(
                            firstPhoto: overview.firstPhoto,
                            latestPhoto: overview.latestPhoto,
                          ),
                          const SizedBox(height: 20),
                          _AchievementsCard(items: overview.achievements),
                          const SizedBox(height: 20),
                          _CompositionCard(series: overview.compositionSeries),
                          const SizedBox(height: 20),
                          _GoalsCard(
                            goals: overview.goals,
                            onEdit: () => _showGoalEditSheet(overview.goals),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthHeader extends StatelessWidget {
  final VoidCallback onLogTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onShareTap;

  const _GrowthHeader({
    required this.onLogTap,
    required this.onPhotoTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROWTH',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'Body Progress',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _IconAction(icon: LucideIcons.share_2, onTap: onShareTap, tooltip: 'Share growth progress'),
          const SizedBox(width: 10),
          _IconAction(icon: LucideIcons.image_plus, onTap: onPhotoTap, tooltip: 'Add progress photo'),
          const SizedBox(width: 10),
          _IconAction(icon: LucideIcons.plus, onTap: onLogTap, tooltip: 'Log measurements'),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconAction({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: ExcludeSemantics(child: Icon(icon, color: AppTheme.primary, size: 20)),
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final GrowthOverviewData overview;

  const _StatsStrip({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatChip(
            label: 'LOGS',
            value: '${overview.totalLogs}',
            icon: LucideIcons.clipboard_list,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'WEIGHT',
            value: overview.currentWeightKg == null
                ? '—'
                : '${overview.currentWeightKg!.toStringAsFixed(1)} kg',
            icon: LucideIcons.scale,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'LAST LOG',
            value: overview.lastLogDate ?? 'Never',
            icon: LucideIcons.calendar,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _LevelCard extends StatelessWidget {
  final GrowthOverviewData overview;

  const _LevelCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Semantics(
        label: 'Level ${overview.currentLevel}, ${overview.levelLabel}. ${overview.totalXp} XP. ${overview.currentStreak} day streak. ${(overview.levelProgressFraction * 100).toStringAsFixed(0)}% to next level.',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.levelArc.withValues(alpha: 0.35)),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL ${overview.currentLevel} • ${overview.levelLabel.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.levelArc,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${overview.totalXp} XP',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.xpGold,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${overview.currentStreak} day streak',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: overview.levelProgressFraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppTheme.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.levelArc,
                    ),
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

class _MetricGrid extends StatelessWidget {
  final List<GrowthMetricCard> metrics;

  const _MetricGrid({required this.metrics});

  Color _deltaColor(GrowthMetricCard metric, double delta) {
    final isPositive = delta >= 0;
    final isHigherGood = metric.direction == 'higher';
    final good = isHigherGood ? isPositive : !isPositive;
    return good ? AppTheme.primary : AppTheme.error;
  }

  String _formatDelta(double v, String unit) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}$unit';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEASUREMENTS',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.26,
            ),
            itemBuilder: (_, i) {
              final metric = metrics[i];
              final metricValueStr = metric.latestValue == null
                  ? 'no data'
                  : '${metric.latestValue!.toStringAsFixed(1)} ${metric.unit}';
              final deltaStr = metric.deltaSinceLast != null
                  ? ', ${metric.deltaSinceLast! >= 0 ? '+' : ''}${metric.deltaSinceLast!.toStringAsFixed(1)} vs last'
                  : '';
              return Semantics(
                label: '${metric.label}: $metricValueStr$deltaStr',
                child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: ExcludeSemantics(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.latestValue == null
                          ? '—'
                          : '${metric.latestValue!.toStringAsFixed(1)} ${metric.unit}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (metric.deltaSinceLast != null)
                          _DeltaBadge(
                            label: 'vs last',
                            value: _formatDelta(
                              metric.deltaSinceLast!,
                              metric.unit == '%' ? '%' : ' ${metric.unit}',
                            ),
                            color: _deltaColor(metric, metric.deltaSinceLast!),
                          ),
                        if (metric.deltaSinceStart != null)
                          _DeltaBadge(
                            label: 'vs start',
                            value: _formatDelta(
                              metric.deltaSinceStart!,
                              metric.unit == '%' ? '%' : ' ${metric.unit}',
                            ),
                            color: _deltaColor(metric, metric.deltaSinceStart!),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (metric.sparkline.length >= 2)
                      SizedBox(
                        width: double.infinity,
                        height: 20,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            metric.sparkline.map((e) => e.value).toList(),
                          ),
                        ),
                      ),
                  ],
                )),
              ),
            );
            },
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DeltaBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PhotoCompareCard extends StatefulWidget {
  final GrowthPhotoData? firstPhoto;
  final GrowthPhotoData? latestPhoto;

  const _PhotoCompareCard({
    required this.firstPhoto,
    required this.latestPhoto,
  });

  @override
  State<_PhotoCompareCard> createState() => _PhotoCompareCardState();
}

class _PhotoCompareCardState extends State<_PhotoCompareCard> {
  double _slider = 0.5;

  void _updateSlider(Offset localPosition, double width) {
    if (width <= 0) return;
    setState(() {
      _slider = (localPosition.dx / width).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHOTO COMPARISON',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.firstPhoto == null || widget.latestPhoto == null)
              Text(
                'Add at least 2 progress photos to compare.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return Semantics(
                        label: 'Photo comparison slider. Drag left or right to compare first and latest progress photos.',
                        child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _updateSlider(details.localPosition, width),
                        onHorizontalDragStart: (details) =>
                            _updateSlider(details.localPosition, width),
                        onHorizontalDragUpdate: (details) =>
                            _updateSlider(details.localPosition, width),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                widget.firstPhoto!.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: ClipRect(
                                clipper: _HorizontalRevealClipper(_slider),
                                child: Image.network(
                                  widget.latestPhoto!.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              left: _slider * width - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: AppTheme.textCream.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            Positioned(
                              left: _slider * width - 14,
                              top: (190 / 2) - 14,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark.withValues(
                                    alpha: 0.92,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.textCream.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 16,
                                  color: AppTheme.textCream.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (widget.firstPhoto != null && widget.latestPhoto != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'FIRST: ${widget.firstPhoto!.date}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'LATEST: ${widget.latestPhoto!.date}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HorizontalRevealClipper extends CustomClipper<Rect> {
  final double ratio;

  _HorizontalRevealClipper(this.ratio);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * ratio, size.height);

  @override
  bool shouldReclip(_HorizontalRevealClipper oldClipper) =>
      oldClipper.ratio != ratio;
}

class _AchievementsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _AchievementsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACHIEVEMENTS',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (_, i) {
                final item = items[i];
                final unlocked = item['isUnlocked'] == true;
                final achievementName = item['name']?.toString() ?? 'Achievement';
                final xpReward = item['xpReward'] ?? 0;
                final unlockedAt = unlocked
                    ? (item['unlockedAt'] ?? '').toString().replaceAll(' 00:00:00', '')
                    : '';
                return Semantics(
                  label: '$achievementName, ${unlocked ? 'unlocked${unlockedAt.isNotEmpty ? ' $unlockedAt' : ''}' : 'locked'}, +$xpReward XP reward',
                  child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppTheme.xpGold.withValues(alpha: 0.08)
                        : AppTheme.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: unlocked
                          ? AppTheme.xpGold.withValues(alpha: 0.35)
                          : AppTheme.borderDark,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            unlocked ? LucideIcons.trophy : LucideIcons.lock,
                            color: unlocked
                                ? AppTheme.xpGold
                                : AppTheme.textSageMuted,
                            size: 14,
                          ),
                          const Spacer(),
                          Text(
                            '+${item['xpReward'] ?? 0} XP',
                            style: GoogleFonts.plusJakartaSans(
                              color: unlocked
                                  ? AppTheme.xpGold
                                  : AppTheme.textSageMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['name']?.toString() ?? 'Achievement',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: unlocked
                              ? AppTheme.textCream
                              : AppTheme.textSageMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        unlocked
                            ? 'Unlocked ${item['unlockedAt'] ?? ''}'.replaceAll(
                                ' 00:00:00',
                                '',
                              )
                            : 'Locked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositionCard extends StatelessWidget {
  final List<GrowthCompositionPoint> series;

  const _CompositionCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final fatSeries = series.map((e) => e.fatMassKg).toList();
    final leanSeries = series.map((e) => e.leanMassKg).toList();
    final firstPoint = series.isNotEmpty ? series.first : null;
    final lastPoint = series.isNotEmpty ? series.last : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardRaised.withValues(alpha: 0.72),
              AppTheme.cardDark,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BODY COMPOSITION',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                if (firstPoint != null && lastPoint != null)
                  Text(
                    '${_formatDateLabel(firstPoint.date)} - ${_formatDateLabel(lastPoint.date)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (series.length < 2)
              Text(
                'Log weight + body fat for at least two entries to view composition trend.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 164,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundDark.withValues(alpha: 0.8),
                        AppTheme.backgroundDark.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CompositionChartPainter(
                            first: fatSeries,
                            second: leanSeries,
                            firstColor: AppTheme.warning,
                            secondColor: AppTheme.info,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: const [
                            _CompositionLegendDot(
                              label: 'Fat Mass',
                              color: AppTheme.warning,
                            ),
                            SizedBox(width: 10),
                            _CompositionLegendDot(
                              label: 'Lean Mass',
                              color: AppTheme.info,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CompositionStatChip(
                      label: 'Fat Mass',
                      value: '${fatSeries.last.toStringAsFixed(1)} kg',
                      delta: fatSeries.last - fatSeries.first,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompositionStatChip(
                      label: 'Lean Mass',
                      value: '${leanSeries.last.toStringAsFixed(1)} kg',
                      delta: leanSeries.last - leanSeries.first,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateLabel(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _CompositionLegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _CompositionLegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textMain,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompositionStatChip extends StatelessWidget {
  final String label;
  final String value;
  final double delta;
  final Color color;

  const _CompositionStatChip({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${isUp ? '+' : ''}${delta.toStringAsFixed(1)} kg',
            style: GoogleFonts.plusJakartaSans(
              color: color.withValues(alpha: 0.95),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  final GrowthGoalData goals;
  final VoidCallback onEdit;

  const _GoalsCard({required this.goals, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasGoal =
        goals.weightGoalKg != null || goals.bodyFatGoalPercent != null;
    final hasCheckIn =
        goals.currentWeightKg != null || goals.currentBodyFatPercent != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Goals',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    hasGoal ? 'Edit' : 'Set',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _summary(hasGoal: hasGoal, hasCheckIn: hasCheckIn),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 10),
            _GoalCompactRow(
              title: 'Weight Goal',
              current: goals.currentWeightKg,
              target: goals.weightGoalKg,
              remaining: goals.weightRemainingKg,
              unit: 'kg',
            ),
            const SizedBox(height: 8),
            _GoalCompactRow(
              title: 'Body Fat Goal',
              current: goals.currentBodyFatPercent,
              target: goals.bodyFatGoalPercent,
              remaining: goals.bodyFatRemainingPercent,
              unit: '%',
            ),
          ],
        ),
      ),
    );
  }

  String _summary({required bool hasGoal, required bool hasCheckIn}) {
    if (!hasGoal) {
      return 'Set your targets to start tracking progress.';
    }
    if (!hasCheckIn) {
      return 'Targets set. Log your first check-in.';
    }
    return 'Updated after each check-in.';
  }
}

class _GoalCompactRow extends StatelessWidget {
  final String title;
  final double? current;
  final double? target;
  final double? remaining;
  final String unit;

  const _GoalCompactRow({
    required this.title,
    required this.current,
    required this.target,
    required this.remaining,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = target != null;
    final remainingValue = remaining?.abs();
    final status = hasTarget
        ? remainingValue == null
              ? 'Target set'
              : '${_format(remainingValue)} $unit left'
        : 'Not set';
    final valueLine = hasTarget
        ? current == null
              ? 'Target ${_format(target)} $unit'
              : '${_format(current)} $unit now • ${_format(target)} $unit target'
        : 'No target yet';

    return Semantics(
      label: '$title: $valueLine. $status.',
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valueLine,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              color: hasTarget ? AppTheme.success : AppTheme.textSageMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _format(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(1);
  }
}

class _GoalEditSheet extends StatefulWidget {
  final GrowthGoalData initial;

  const _GoalEditSheet({required this.initial});

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _bodyFatCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.initial.weightGoalKg?.toStringAsFixed(1) ?? '',
    );
    _bodyFatCtrl = TextEditingController(
      text: widget.initial.bodyFatGoalPercent?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await BodyService.updateGrowthGoals(
        weightGoalKg: double.tryParse(_weightCtrl.text.trim()),
        bodyFatGoalPercent: double.tryParse(_bodyFatCtrl.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Failed to save goals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Your Targets',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set clear targets and we will show your progress after each check-in.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          _GoalInput(controller: _weightCtrl, label: 'Target weight (kg)'),
          const SizedBox(height: 12),
          _GoalInput(controller: _bodyFatCtrl, label: 'Target body fat (%)'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.oledBlack,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Targets'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _GoalInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: GoogleFonts.plusJakartaSans(color: AppTheme.textCream),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: AppTheme.textSageMuted),
        filled: true,
        fillColor: AppTheme.backgroundDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;

  _SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / range) * size.height;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
    canvas.drawCircle(points.last, 2.8, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => oldDelegate.data != data;
}

class _CompositionChartPainter extends CustomPainter {
  final List<double> first;
  final List<double> second;
  final Color firstColor;
  final Color secondColor;

  _CompositionChartPainter({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (first.length < 2 || second.length < 2) return;
    const left = 10.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 16.0;
    final chartRect = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    final allValues = [...first, ...second];
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final range = (maxValue - minValue).abs();
    final padding = math.max(0.8, range * 0.18);
    final lower = minValue - padding;
    final upper = maxValue + padding;
    final safeRange = upper - lower == 0 ? 1.0 : upper - lower;

    final gridPaint = Paint()
      ..color = AppTheme.borderDark.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = chartRect.top + (i / 3) * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final firstPoints = _buildPoints(first, chartRect, lower, safeRange);
    final secondPoints = _buildPoints(second, chartRect, lower, safeRange);

    _drawArea(canvas, chartRect, firstPoints, firstColor);
    _drawArea(canvas, chartRect, secondPoints, secondColor);
    _drawLine(canvas, firstPoints, firstColor);
    _drawLine(canvas, secondPoints, secondColor);
    _drawMarker(canvas, firstPoints.last, firstColor);
    _drawMarker(canvas, secondPoints.last, secondColor);
  }

  List<Offset> _buildPoints(
    List<double> values,
    Rect rect,
    double lower,
    double range,
  ) {
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = rect.left + (i / (values.length - 1)) * rect.width;
      final normalized = ((values[i] - lower) / range).clamp(0.0, 1.0);
      final y = rect.bottom - normalized * rect.height;
      points.add(Offset(x, y));
    }
    return points;
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final prev = points[i - 1];
      final cpX = (prev.dx + current.dx) / 2;
      path.quadraticBezierTo(cpX, prev.dy, current.dx, current.dy);
    }
    return path;
  }

  void _drawArea(Canvas canvas, Rect rect, List<Offset> points, Color color) {
    final stroke = _smoothPath(points);
    final fillPath = Path.from(stroke)
      ..lineTo(points.last.dx, rect.bottom)
      ..lineTo(points.first.dx, rect.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(rect),
    );
  }

  void _drawLine(Canvas canvas, List<Offset> points, Color color) {
    canvas.drawPath(
      _smoothPath(points),
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawMarker(Canvas canvas, Offset point, Color color) {
    canvas.drawCircle(point, 7, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawCircle(point, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CompositionChartPainter oldDelegate) {
    return oldDelegate.first != first ||
        oldDelegate.second != second ||
        oldDelegate.firstColor != firstColor ||
        oldDelegate.secondColor != secondColor;
  }
}

class _LogMeasurementSheet extends StatefulWidget {
  final void Function(BodyLogResult) onLogged;

  const _LogMeasurementSheet({required this.onLogged});

  @override
  State<_LogMeasurementSheet> createState() => _LogMeasurementSheetState();
}

class _LogMeasurementSheetState extends State<_LogMeasurementSheet> {
  final _steps = const [
    _StepConfig('Weight', 'kg', LucideIcons.scale, 'weightKg'),
    _StepConfig('Body Fat', '%', LucideIcons.percent, 'bodyFatPercent'),
    _StepConfig('Chest', 'cm', LucideIcons.activity, 'chestCm'),
    _StepConfig('Waist', 'cm', LucideIcons.minimize_2, 'waistCm'),
    _StepConfig('Hips', 'cm', LucideIcons.circle, 'hipsCm'),
    _StepConfig('Arms', 'cm', LucideIcons.dumbbell, 'armsCm'),
    _StepConfig('Thighs', 'cm', LucideIcons.footprints, 'thighsCm'),
  ];

  int _currentStep = 0;
  final Map<String, double?> _values = {};
  final _controller = TextEditingController();
  XFile? _selectedPhoto;
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (file == null) return;
    final mime = _mimeFromName(file.name);
    if (mime == 'image/gif') {
      if (!mounted) return;
      AppSnackbar.error(context, 'GIF uploads are not supported');
      return;
    }
    if (!mounted) return;
    setState(() => _selectedPhoto = file);
  }

  void _removePhoto() {
    setState(() => _selectedPhoto = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance({bool skip = false}) {
    _values[_steps[_currentStep].key] = skip
        ? null
        : double.tryParse(_controller.text.trim());
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _controller.clear();
      });
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{
        'date': DateTime.now().toIso8601String().split('T').first,
      };
      _values.forEach((key, value) {
        if (value != null) payload[key] = value;
      });

      final res = await BodyService.logBodyMeasurement(payload);
      final result = BodyLogResult.fromJson(
        res['data'] as Map<String, dynamic>,
      );
      if (_selectedPhoto != null && result.measurementId > 0) {
        final mimeType = _mimeFromName(_selectedPhoto!.name);
        if (mimeType != 'image/gif') {
          await BodyService.uploadGrowthPhoto(
            bytes: await _selectedPhoto!.readAsBytes(),
            fileName: _selectedPhoto!.name,
            mimeType: mimeType,
            date: payload['date'] as String,
            measurementId: result.measurementId,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onLogged(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.error(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOG MEASUREMENTS ${_currentStep + 1}/${_steps.length}',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              step.label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: _selectedPhoto == null
                  ? Row(
                      children: [
                        const Icon(
                          LucideIcons.image,
                          color: AppTheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add progress photo for this check-in',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickPhoto,
                          child: const Text('Add'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_selectedPhoto!.path),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Photo attached to this check-in',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickPhoto,
                          child: const Text('Change'),
                        ),
                        TextButton(
                          onPressed: _removePhoto,
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                suffixText: step.unit,
                filled: true,
                fillColor: AppTheme.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _advance(skip: true),
                  child: const Text('Skip'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _advance(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.oledBlack,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isLast ? 'Submit' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.avif')) return 'image/avif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    if (lower.endsWith('.jfif')) return 'image/jpeg';
    return 'image/jpeg';
  }
}

class _StepConfig {
  final String label;
  final String unit;
  final IconData icon;
  final String key;

  const _StepConfig(this.label, this.unit, this.icon, this.key);
}

class _XpCelebrationDialog extends StatelessWidget {
  final BodyLogResult result;

  const _XpCelebrationDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final totalReward =
        result.xpEarned + result.achievementXp + result.milestoneXp;

    return Dialog(
      backgroundColor: AppTheme.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sparkles, color: AppTheme.primary, size: 28),
            const SizedBox(height: 10),
            Text(
              'Check-in logged',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+$totalReward XP',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.xpGold,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (result.newMilestones.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...result.newMilestones.map(
                (m) => Text(
                  'Milestone: ${m['label'] ?? m['key']}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.oledBlack,
                ),
                child: const Text('Awesome'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
