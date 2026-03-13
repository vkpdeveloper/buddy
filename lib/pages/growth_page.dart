import 'dart:math' as math;
import 'dart:io';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/body_measurement.dart';
import 'package:buddy/models/growth.dart';
import 'package:buddy/providers/body_provider.dart';
import 'package:buddy/providers/growth_provider.dart';
import 'package:buddy/providers/health_provider.dart';
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
    ref.invalidate(latestWeightProvider);
    ref.invalidate(latestHeightProvider);
    ref.invalidate(progressProvider);
    for (int i = 0; i < 4; i++) {
      ref.invalidate(weeklyCaloriesProvider(i));
    }
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
                              backgroundColor: AppTheme.actionSurface,
                              foregroundColor: AppTheme.actionForeground,
                            ),
                            icon: sharing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.actionForeground,
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
                        title: 'Could not load Progress',
                        subtitle: '$e',
                      ),
                    ],
                  ),
                  data: (overview) {
                    return _GrowthBody(
                      overview: overview,
                      onEditGoals: () => _showGoalEditSheet(overview.goals),
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

// ─── New Growth Body ─────────────────────────────────────────────────────────

class _GrowthBody extends ConsumerStatefulWidget {
  final GrowthOverviewData overview;
  final VoidCallback onEditGoals;

  const _GrowthBody({required this.overview, required this.onEditGoals});

  @override
  ConsumerState<_GrowthBody> createState() => _GrowthBodyState();
}

class _GrowthBodyState extends ConsumerState<_GrowthBody> {
  int _timeRangeIndex = 0; // 0=90d, 1=6m, 2=1y, 3=all
  int _weekOffset = 0; // 0=this week, 1=last, 2=2wks ago, 3=3wks ago
  static const _timeLabels = ['90 Days', '6 Months', '1 Year', 'All Time'];
  static const _weekLabels = [
    'This Week',
    'Last Week',
    '2 wks. ago',
    '3 wks. ago',
  ];

  List<GrowthTrendPoint> _filteredTrend() {
    final trend = widget.overview.weightTrend;
    if (trend.isEmpty) return trend;
    final now = DateTime.now();
    DateTime cutoff;
    switch (_timeRangeIndex) {
      case 0:
        cutoff = now.subtract(const Duration(days: 90));
      case 1:
        cutoff = now.subtract(const Duration(days: 180));
      case 2:
        cutoff = now.subtract(const Duration(days: 365));
      default:
        return trend;
    }
    return trend.where((p) {
      final d = DateTime.tryParse(p.date);
      return d != null && d.isAfter(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final photosAsync = ref.watch(growthPhotosProvider);
    final weightAsync = ref.watch(latestWeightProvider);
    final heightAsync = ref.watch(latestHeightProvider);
    final profileAsync = ref.watch(userProfileMeasurementsProvider);
    final weeklyAsync = ref.watch(weeklyCaloriesProvider(_weekOffset));
    final filteredTrend = _filteredTrend();

    final profileData = profileAsync.asData?.value;

    // Use weight from logs → Health Connect → user profile (onboarding)
    final effectiveWeightKg =
        overview.currentWeightKg ??
        weightAsync.asData?.value ??
        profileData?.weightKg;

    // Height: Health Connect → user profile (onboarding)
    final effectiveHeightCm =
        heightAsync.asData?.value ?? profileData?.heightCm;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 92,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Top stats row: weight + streak
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _WeightCard(
                    currentKg: effectiveWeightKg,
                    goalKg: overview.goals.weightGoalKg,
                    lastLogDate: overview.lastLogDate,
                    onEdit: widget.onEditGoals,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _StreakCard(streak: overview.currentStreak)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Time range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SegmentedSelector(
              labels: _timeLabels,
              selectedIndex: _timeRangeIndex,
              onChanged: (i) => setState(() => _timeRangeIndex = i),
            ),
          ),
          const SizedBox(height: 16),
          // Goal progress chart
          _GoalProgressChartCard(
            trend: filteredTrend,
            goalKg: overview.goals.weightGoalKg,
            currentKg: effectiveWeightKg,
            onEditGoal: widget.onEditGoals,
          ),
          const SizedBox(height: 20),
          // Progress photos
          _ProgressPhotosSection(photosAsync: photosAsync),
          const SizedBox(height: 20),
          // Weekly calories section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SegmentedSelector(
              labels: _weekLabels,
              selectedIndex: _weekOffset,
              onChanged: (i) => setState(() => _weekOffset = i),
            ),
          ),
          const SizedBox(height: 16),
          _WeeklyCaloriesSection(weeklyAsync: weeklyAsync),
          const SizedBox(height: 20),
          // BMI card
          _BmiCard(weightKg: effectiveWeightKg, heightCm: effectiveHeightCm),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final double? currentKg;
  final double? goalKg;
  final String? lastLogDate;
  final VoidCallback onEdit;

  const _WeightCard({
    required this.currentKg,
    required this.goalKg,
    required this.lastLogDate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalKg != null && currentKg != null;
    final progress = hasGoal ? (currentKg! / goalKg!).clamp(0.0, 1.2) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.95)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131318), Color(0xFF14161A), AppTheme.cardDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY WEIGHT',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentKg != null ? currentKg!.toStringAsFixed(1) : '—',
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'kg',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (goalKg != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: AppTheme.borderDark,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Goal ${goalKg!.toStringAsFixed(1)} kg',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (lastLogDate != null) ...[
            const SizedBox(height: 2),
            Text(
              'Last: $lastLogDate',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1=Mon..7=Sun
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.xpGold.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.xpGold.withValues(alpha: 0.07),
            const Color(0xFF14161A),
            AppTheme.cardDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowSoft.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.flame, color: AppTheme.xpGold, size: 12),
              const SizedBox(width: 4),
              Text(
                'STREAK',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.xpGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$streak',
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'days',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = i < (today - 1); // past days this week
              final isToday = i == today - 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekdays[i],
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                      fontSize: 8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? AppTheme.xpGold
                          : isActive && streak > 0
                          ? AppTheme.xpGold.withValues(alpha: 0.45)
                          : AppTheme.borderDark,
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: AppTheme.xpGold.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SegmentedSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.8)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131318), AppTheme.cardDark],
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected
                        ? AppTheme.oledBlack
                        : AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GoalProgressChartCard extends StatelessWidget {
  final List<GrowthTrendPoint> trend;
  final double? goalKg;
  final double? currentKg;
  final VoidCallback onEditGoal;

  const _GoalProgressChartCard({
    required this.trend,
    required this.goalKg,
    required this.currentKg,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = trend.length >= 2;
    final startKg = trend.isNotEmpty ? trend.first.value : null;
    final latestKg = currentKg;
    double? progressPct;
    if (startKg != null && latestKg != null && goalKg != null) {
      final total = (startKg - goalKg!).abs();
      final done = (startKg - latestKg).abs();
      progressPct = total > 0 ? (done / total * 100).clamp(0, 100) : null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.borderDark.withValues(alpha: 0.95),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowSoft.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Weight Progress',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (progressPct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      '${progressPct.toStringAsFixed(0)}% of goal',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEditGoal,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.oledBlack.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.textMain.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.pencil,
                      size: 12,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!hasData && currentKg == null)
              Text(
                'Log a check-in to start tracking your weight trend.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              )
            else if (!hasData && currentKg != null)
              _BaselineWeightChart(currentKg: currentKg!, goalKg: goalKg)
            else
              SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _WeightChartPainter(points: trend, goalKg: goalKg),
                  size: const Size(double.infinity, 140),
                ),
              ),
            if (hasData || currentKg != null) ...[
              const SizedBox(height: 10),
              Text(
                goalKg != null
                    ? "Getting started is the hardest part. You're ready for this!"
                    : 'Set a goal weight to track your progress.',
                style: GoogleFonts.plusJakartaSans(
                  color: hasData
                      ? AppTheme.textSageMuted
                      : const Color(0xFF4CAF50),
                  fontSize: 11,
                  fontStyle: hasData ? FontStyle.italic : FontStyle.normal,
                  fontWeight: hasData ? FontWeight.normal : FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Shows a flat starting-weight baseline with Y-axis labels when there are no logs yet
class _BaselineWeightChart extends StatelessWidget {
  final double currentKg;
  final double? goalKg;

  const _BaselineWeightChart({required this.currentKg, this.goalKg});

  @override
  Widget build(BuildContext context) {
    const rowCount = 5;
    final step = 0.2;
    final midVal = (currentKg * 2).round() / 2; // round to nearest 0.5
    final labels = List.generate(
      rowCount,
      (i) => midVal + (rowCount ~/ 2 - i) * step,
    );

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Y-axis labels
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: labels
                .map(
                  (v) => Text(
                    v.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 9,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
          // Chart area
          Expanded(
            child: CustomPaint(
              painter: _BaselineChartPainter(
                currentKg: currentKg,
                labels: labels,
                goalKg: goalKg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineChartPainter extends CustomPainter {
  final double currentKg;
  final List<double> labels;
  final double? goalKg;

  _BaselineChartPainter({
    required this.currentKg,
    required this.labels,
    required this.goalKg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minV = labels.last;
    final maxV = labels.first;
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;

    double toY(double v) => size.height - ((v - minV) / range) * size.height;

    // Draw dashed grid lines
    final gridPaint = Paint()
      ..color = AppTheme.borderDark.withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (final v in labels) {
      final y = toY(v);
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 8, size.width), y),
          gridPaint,
        );
        x += 14;
      }
    }

    // Draw goal dashed line
    if (goalKg != null && goalKg! >= minV && goalKg! <= maxV) {
      final goalY = toY(goalKg!);
      final goalPaint = Paint()
        ..color = AppTheme.xpGold.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, goalY),
          Offset(math.min(x + 8, size.width), goalY),
          goalPaint,
        );
        x += 14;
      }
    }

    // Draw solid baseline at currentKg
    final baseY = toY(currentKg);
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = AppTheme.textCream
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_BaselineChartPainter old) =>
      old.currentKg != currentKg || old.goalKg != goalKg;
}

class _WeightChartPainter extends CustomPainter {
  final List<GrowthTrendPoint> points;
  final double? goalKg;

  _WeightChartPainter({required this.points, required this.goalKg});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const hPad = 8.0;
    const vPad = 12.0;

    final values = points.map((p) => p.value).toList();
    final allValues = [...values, if (goalKg != null) goalKg!];
    var minV = allValues.reduce(math.min);
    var maxV = allValues.reduce(math.max);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;
    minV -= range * 0.1;
    maxV += range * 0.1;
    final safeRange = maxV - minV;

    double toY(double v) =>
        size.height -
        vPad -
        ((v - minV) / safeRange) * (size.height - 2 * vPad);
    double toX(int i) =>
        hPad + (i / (points.length - 1)) * (size.width - 2 * hPad);

    // Draw goal line
    if (goalKg != null) {
      final goalY = toY(goalKg!);
      final dashPaint = Paint()
        ..color = AppTheme.xpGold.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      double x = hPad;
      while (x < size.width - hPad) {
        canvas.drawLine(
          Offset(x, goalY),
          Offset(math.min(x + 8, size.width - hPad), goalY),
          dashPaint,
        );
        x += 14;
      }
    }

    // Draw area fill
    final chartPoints = List.generate(
      points.length,
      (i) => Offset(toX(i), toY(values[i])),
    );
    final fillPath = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (int i = 1; i < chartPoints.length; i++) {
      final cp = (chartPoints[i - 1] + chartPoints[i]) / 2;
      fillPath.quadraticBezierTo(
        chartPoints[i - 1].dx,
        chartPoints[i - 1].dy,
        cp.dx,
        cp.dy,
      );
    }
    fillPath.lineTo(chartPoints.last.dx, size.height - vPad);
    fillPath.lineTo(chartPoints.first.dx, size.height - vPad);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primary.withValues(alpha: 0.2),
            AppTheme.primary.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    final linePath = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (int i = 1; i < chartPoints.length; i++) {
      final cp = (chartPoints[i - 1] + chartPoints[i]) / 2;
      linePath.quadraticBezierTo(
        chartPoints[i - 1].dx,
        chartPoints[i - 1].dy,
        cp.dx,
        cp.dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppTheme.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Draw last point dot
    canvas.drawCircle(chartPoints.last, 4, Paint()..color = AppTheme.primary);
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.points != points || old.goalKg != goalKg;
}

class _ProgressPhotosSection extends ConsumerWidget {
  final AsyncValue<List<GrowthPhotoData>> photosAsync;
  const _ProgressPhotosSection({required this.photosAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.borderDark.withValues(alpha: 0.95),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowSoft.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Photos',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            photosAsync.when(
              loading: () => const SizedBox(height: 60),
              error: (_, _) => const SizedBox.shrink(),
              data: (photos) {
                if (photos.isEmpty) {
                  return Text(
                    'No photos yet. Upload a progress photo to get started.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  );
                }
                final preview = photos.take(3).toList();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...preview.map(
                        (p) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderDark.withValues(alpha: 0.7),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              p.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.backgroundDark,
                                child: const Icon(
                                  LucideIcons.image,
                                  color: AppTheme.textSageMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (photos.length > 3)
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppTheme.oledBlack.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderDark.withValues(alpha: 0.7),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${photos.length - 3}',
                            style: GoogleFonts.sora(
                              color: AppTheme.textSageMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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

class _WeeklyCaloriesSection extends StatelessWidget {
  final AsyncValue<List<DailyCalorieSummary>> weeklyAsync;
  const _WeeklyCaloriesSection({required this.weeklyAsync});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.borderDark.withValues(alpha: 0.95),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowSoft.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Calories',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            weeklyAsync.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              error: (_, _) => Text(
                'Could not load weekly data.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                ),
              ),
              data: (days) {
                if (days.isEmpty) {
                  return Text(
                    'No calorie data logged for this week.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  );
                }
                final totalCal = days.fold<int>(0, (s, d) => s + d.calories);
                final maxCal = days
                    .map((d) => d.calories)
                    .fold<int>(1, math.max);

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalCal',
                          style: GoogleFonts.sora(
                            color: AppTheme.textCream,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            'kcal total',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: days.map((d) {
                          final frac = maxCal > 0 ? d.calories / maxCal : 0.0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: frac.clamp(0.04, 1.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: frac > 0.01
                                                ? AppTheme.primary
                                                : AppTheme.borderDark,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    d.dayLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textSageMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _LegendDot(color: AppTheme.primary, label: 'Calories'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

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
            color: AppTheme.textSageMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _BmiCard extends StatelessWidget {
  final double? weightKg;
  final double? heightCm;
  static const Color _underweightColor = Color(0xFF35B8FF);
  static const Color _healthyColor = Color(0xFF42C27A);
  static const Color _overweightColor = Color(0xFFF0BE4C);
  static const Color _obeseColor = Color(0xFFEB6758);

  const _BmiCard({required this.weightKg, required this.heightCm});

  @override
  Widget build(BuildContext context) {
    double? bmi;
    if (weightKg != null && heightCm != null && heightCm! > 0) {
      final hm = heightCm! / 100;
      bmi = weightKg! / (hm * hm);
    }

    String? category;
    Color categoryColor = AppTheme.textSageMuted;
    double? markerFrac;
    if (bmi != null) {
      if (bmi < 18.5) {
        category = 'Underweight';
        categoryColor = _underweightColor;
        markerFrac = (bmi / 18.5) * 0.25;
      } else if (bmi < 25) {
        category = 'Healthy';
        categoryColor = _healthyColor;
        markerFrac = 0.25 + ((bmi - 18.5) / 6.5) * 0.25;
      } else if (bmi < 30) {
        category = 'Overweight';
        categoryColor = _overweightColor;
        markerFrac = 0.5 + ((bmi - 25) / 5) * 0.25;
      } else {
        category = 'Obese';
        categoryColor = _obeseColor;
        markerFrac = math.min(0.75 + ((bmi - 30) / 10) * 0.25, 1.0);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Semantics(
        container: true,
        label: bmi == null
            ? 'BMI unavailable. Add your latest weight and height to calculate it.'
            : 'BMI ${bmi.toStringAsFixed(2)}. Current range $category.',
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.borderDark.withValues(alpha: 0.95),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A151B), Color(0xFF14161A), AppTheme.cardDark],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your BMI',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message:
                        'BMI uses your weight and height to estimate your current range.',
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.oledBlack.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textMain.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.info,
                        size: 14,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (bmi == null)
                Text(
                  'Add your latest weight and height to calculate your BMI range.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      bmi.toStringAsFixed(2),
                      style: GoogleFonts.sora(
                        color: AppTheme.textCream,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _BmiStatusPill(
                            label: category!,
                            color: categoryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Opacity(
                opacity: bmi == null ? 0.45 : 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return SizedBox(
                      height: 18,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              width: double.infinity,
                              height: 6,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      _underweightColor,
                                      _healthyColor,
                                      _overweightColor,
                                      _obeseColor,
                                    ],
                                    stops: [0.0, 0.38, 0.68, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (markerFrac != null)
                            Positioned(
                              left: (markerFrac.clamp(0.02, 0.98) * width) - 1,
                              top: -4,
                              bottom: -4,
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: AppTheme.textCream,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: bmi == null ? 0.65 : 1,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: const [
                    _LegendDot(color: _underweightColor, label: 'Underweight'),
                    _LegendDot(color: _healthyColor, label: 'Healthy'),
                    _LegendDot(color: _overweightColor, label: 'Overweight'),
                    _LegendDot(color: _obeseColor, label: 'Obese'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _BmiStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Original Growth Support Widgets ──────────────────────────────────────────

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
                  'PROGRESS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'Progress',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _IconAction(
            icon: LucideIcons.share_2,
            onTap: onShareTap,
            tooltip: 'Share growth progress',
          ),
          const SizedBox(width: 10),
          _IconAction(
            icon: LucideIcons.image_plus,
            onTap: onPhotoTap,
            tooltip: 'Add progress photo',
          ),
          const SizedBox(width: 10),
          _IconAction(
            icon: LucideIcons.plus,
            onTap: onLogTap,
            tooltip: 'Log measurements',
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

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
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: ExcludeSemantics(
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
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
        label:
            'Level ${overview.currentLevel}, ${overview.levelLabel}. ${overview.totalXp} XP. ${overview.currentStreak} day streak. ${(overview.levelProgressFraction * 100).toStringAsFixed(0)}% to next level.',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.levelArc.withValues(alpha: 0.35),
            ),
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

  @override
  Widget build(BuildContext context) {
    final activeMetrics = metrics.where((m) => m.latestValue != null).toList();
    if (activeMetrics.isEmpty) return const SizedBox.shrink();

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
            itemCount: activeMetrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.26,
            ),
            itemBuilder: (_, i) {
              final metric = activeMetrics[i];
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
                  child: ExcludeSemantics(
                    child: Column(
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (metric.latestValue == null)
                              Text(
                                '—',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textCream,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            else ...[
                              Text(
                                metric.latestValue!.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textCream,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                metric.unit,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textSageMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (metric.sparkline.length >= 2) ...[
                              if (metric.deltaSinceLast != null) ...[
                                const SizedBox(width: 6),
                                _DeltaBadge(
                                  label: 'vs last',
                                  delta: metric.deltaSinceLast!,
                                  unit: metric.unit == '%'
                                      ? '%'
                                      : ' ${metric.unit}',
                                ),
                              ] else if (metric.deltaSinceStart != null) ...[
                                const SizedBox(width: 6),
                                _DeltaBadge(
                                  label: 'vs start',
                                  delta: metric.deltaSinceStart!,
                                  unit: metric.unit == '%'
                                      ? '%'
                                      : ' ${metric.unit}',
                                ),
                              ],
                            ],
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
                    ),
                  ),
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
  final double delta;
  final String unit;

  const _DeltaBadge({
    required this.label,
    required this.delta,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final isDown = delta < 0;
    final color = isDown ? AppTheme.success : AppTheme.error;
    final icon = isDown ? LucideIcons.trending_down : LucideIcons.trending_up;
    final absValue = delta.abs().toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            '$absValue$unit $label',
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                        label:
                            'Photo comparison slider. Drag left or right to compare first and latest progress photos.',
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

class _AchievementsCard extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _AchievementsCard({required this.items});

  @override
  State<_AchievementsCard> createState() => _AchievementsCardState();
}

class _AchievementsCardState extends State<_AchievementsCard> {
  bool _showLocked = false;

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.items
        .where((e) => e['isUnlocked'] == true)
        .toList();
    final locked = widget.items.where((e) => e['isUnlocked'] != true).toList();

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
            Row(
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
                const Spacer(),
                if (unlocked.isNotEmpty)
                  Text(
                    '${unlocked.length} earned',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.xpGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (unlocked.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Complete workouts and log check-ins to earn achievements.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 11,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              _AchievementGrid(items: unlocked),
            ],
            if (locked.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _showLocked = !_showLocked),
                child: Row(
                  children: [
                    Text(
                      _showLocked
                          ? 'Hide locked'
                          : 'Show all (${locked.length} locked)',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showLocked
                          ? LucideIcons.chevron_up
                          : LucideIcons.chevron_down,
                      size: 13,
                      color: AppTheme.textSageMuted,
                    ),
                  ],
                ),
              ),
              if (_showLocked) ...[
                const SizedBox(height: 10),
                _AchievementGrid(items: locked, muted: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool muted;

  const _AchievementGrid({required this.items, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
        final name = item['name']?.toString() ?? 'Achievement';
        final unlockedAt = unlocked
            ? (item['unlockedAt'] ?? '').toString().replaceAll(' 00:00:00', '')
            : '';
        return Semantics(
          label:
              '$name, ${unlocked ? 'unlocked${unlockedAt.isNotEmpty ? ' $unlockedAt' : ''}' : 'locked'}, +${item['xpReward'] ?? 0} XP',
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
                  name,
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
                  unlocked ? 'Unlocked $unlockedAt' : 'Locked',
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
                backgroundColor: AppTheme.actionSurface,
                foregroundColor: AppTheme.actionForeground,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.actionForeground,
                      ),
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
      // Write to Health Connect (fire-and-forget)
      final weightKg = _values['weightKg'];
      final bodyFat = _values['bodyFatPercent'];
      if (weightKg != null && weightKg > 0) writeWeightToHC(weightKg);
      if (bodyFat != null && bodyFat > 0) writeBodyFatToHC(bodyFat);
      if (weightKg != null && weightKg > 0 && bodyFat != null && bodyFat > 0) {
        writeLeanBodyMassToHC(weightKg: weightKg, bodyFatPercent: bodyFat);
      }
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
                      backgroundColor: AppTheme.actionSurface,
                      foregroundColor: AppTheme.actionForeground,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.actionForeground,
                            ),
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
                  backgroundColor: AppTheme.actionSurface,
                  foregroundColor: AppTheme.actionForeground,
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
