import 'dart:math' as math;

import 'package:buddy/app_theme.dart';
import 'package:buddy/models/growth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

class GrowthShareCard extends StatelessWidget {
  final GrowthOverviewData overview;

  const GrowthShareCard({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final unlockedAchievements = overview.achievements
        .where((item) => item['isUnlocked'] == true)
        .length;
    final trend = overview.weightTrend;
    final firstWeight = trend.isNotEmpty ? trend.first.value : null;
    final latestWeight = trend.isNotEmpty ? trend.last.value : null;
    final trendDelta = firstWeight != null && latestWeight != null
        ? latestWeight - firstWeight
        : null;

    return _ShareCardShell(
      badge: 'GROWTH SNAPSHOT',
      title: 'Body Progress',
      subtitle: 'Consistency compounds',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Current Weight',
                  value: overview.currentWeightKg == null
                      ? '—'
                      : '${overview.currentWeightKg!.toStringAsFixed(1)} kg',
                  icon: LucideIcons.scale,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Current Streak',
                  value: '${overview.currentStreak} days',
                  icon: LucideIcons.flame,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Level',
                  value: '${overview.currentLevel} ${overview.levelLabel}',
                  icon: LucideIcons.trending_up,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Unlocked',
                  value: '$unlockedAchievements achievements',
                  icon: LucideIcons.trophy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Weight Trend',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        trendDelta == null
                            ? 'No trend yet'
                            : '${trendDelta >= 0 ? '+' : ''}${trendDelta.toStringAsFixed(1)} kg',
                        style: GoogleFonts.plusJakartaSans(
                          color: trendDelta == null
                              ? AppTheme.textSageMuted
                              : trendDelta <= 0
                              ? AppTheme.primary
                              : AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        points: trend.map((point) => point.value).toList(),
                        lineColor: AppTheme.primary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutShareCard extends StatelessWidget {
  final String dayLabel;
  final int durationMinutes;
  final int completedExercises;
  final int totalExercises;
  final int xpEarned;
  final int currentStreak;
  final int newLevel;
  final String levelLabel;
  final List<String> unlockedAchievements;

  const WorkoutShareCard({
    super.key,
    required this.dayLabel,
    required this.durationMinutes,
    required this.completedExercises,
    required this.totalExercises,
    required this.xpEarned,
    required this.currentStreak,
    required this.newLevel,
    required this.levelLabel,
    required this.unlockedAchievements,
  });

  @override
  Widget build(BuildContext context) {
    return _ShareCardShell(
      badge: 'WORKOUT COMPLETE',
      title: dayLabel,
      subtitle: 'Session closed with momentum',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Duration',
                  value: '${durationMinutes}m',
                  icon: LucideIcons.clock_4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Exercises',
                  value: '$completedExercises/$totalExercises',
                  icon: LucideIcons.dumbbell,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ShareMetricBlock(
                  label: 'XP Earned',
                  value: '+$xpEarned',
                  icon: LucideIcons.sparkles,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareMetricBlock(
                  label: 'Streak',
                  value: '$currentStreak days',
                  icon: LucideIcons.flame,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $newLevel · $levelLabel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (unlockedAchievements.isEmpty)
                  Text(
                    'No new achievements this session. Keep stacking sessions.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 11,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: unlockedAchievements
                        .take(4)
                        .map(
                          (name) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.xpGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.xpGold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.xpGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCardShell extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Widget child;

  const _ShareCardShell({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundDark,
              AppTheme.cardDark,
              AppTheme.backgroundDark.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.borderDark.withValues(alpha: 0.85),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              badge,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                color: AppTheme.textCream,
                fontSize: 34,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
            const SizedBox(height: 14),
            Text(
              'Made with Buddy',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareMetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ShareMetricBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;

  const _SparklinePainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = lineColor;

    if (points.length < 2) {
      final y = size.height * 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final minVal = points.reduce(math.min);
    final maxVal = points.reduce(math.max);
    final range = (maxVal - minVal).abs() < 0.0001 ? 1.0 : (maxVal - minVal);
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final dx = size.width * (i / (points.length - 1));
      final normalized = (points[i] - minVal) / range;
      final dy = size.height * (1 - normalized);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..style = PaintingStyle.fill
        ..color = lineColor.withValues(alpha: 0.12),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
