import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/onboarding_projection.dart';

/// The "Aha Moment" screen — shows the user's real projected numbers
/// after just 5 inputs (goal, sex, age, height, weight).
/// Everything is computed live from [projection], nothing is hardcoded.
class OnboardingAhaMomentPage extends StatefulWidget {
  final OnboardingProjection projection;
  final double currentWeight;
  final double targetWeight;
  final String fitnessGoal;
  final VoidCallback onNext;

  const OnboardingAhaMomentPage({
    super.key,
    required this.projection,
    required this.currentWeight,
    required this.targetWeight,
    required this.fitnessGoal,
    required this.onNext,
  });

  @override
  State<OnboardingAhaMomentPage> createState() =>
      _OnboardingAhaMomentPageState();
}

class _OnboardingAhaMomentPageState extends State<OnboardingAhaMomentPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _deltaController;
  late final AnimationController _metricsController;
  late final AnimationController _chartController;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _deltaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _metricsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Staggered reveal: header → delta hero → metrics → chart
    _entryController.forward().then((_) {
      _deltaController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _metricsController.forward();
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _chartController.forward();
      });
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _deltaController.dispose();
    _metricsController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  // ─── Derived values ───────────────────────────────────────────────────────

  double get _delta => (widget.targetWeight - widget.currentWeight).abs();
  bool get _isLoss => widget.targetWeight < widget.currentWeight;
  bool get _isGain => widget.targetWeight > widget.currentWeight;
  bool get _isNeutral => !_isLoss && !_isGain;

  Color get _accentColor {
    if (_isLoss) return AppTheme.success;
    if (_isGain) return AppTheme.info;
    return AppTheme.primary;
  }

  String get _headingLine1 {
    if (_isNeutral) {
      return switch (widget.fitnessGoal) {
        'recomp' => 'Ready to reshape',
        'endurance' => 'Built for endurance',
        _ => 'Your numbers look good',
      };
    }
    return _isLoss ? 'You could lose' : 'You could gain';
  }

  String get _headingLine3 {
    return 'by ${widget.projection.goalDateLabel}.';
  }

  List<double> get _weightSeries {
    const n = 7;
    final delta = widget.targetWeight - widget.currentWeight;
    return List.generate(n, (i) {
      final t = i / (n - 1);
      final eased = switch (widget.fitnessGoal) {
        'fat_loss' => Curves.easeInOutCubic.transform(t),
        'muscle_gain' => Curves.easeOutCubic.transform(t),
        'recomp' => Curves.easeInOut.transform(t),
        _ => Curves.linear.transform(t),
      };
      return widget.currentWeight + (delta * eased);
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeltaHero(),
                const SizedBox(height: 24),
                _buildMetricsCard(),
                const SizedBox(height: 20),
                _buildSparklineCard(),
                const SizedBox(height: 20),
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildCTA(),
        ),
      ],
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────


  // ─── Delta hero ───────────────────────────────────────────────────────────

  Widget _buildDeltaHero() {
    return FadeTransition(
      opacity: _entryController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: "You could lose" or "Your numbers look good"
          Text(
            _headingLine1,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),

          if (!_isNeutral) ...[
            // Line 2: the animated big number (the aha moment)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _delta),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value.toStringAsFixed(1),
                        style: GoogleFonts.plusJakartaSans(
                          color: _accentColor,
                          fontSize: 58,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' kg',
                        style: GoogleFonts.plusJakartaSans(
                          color: _accentColor.withValues(alpha: 0.7),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Line 3: "by August 2025."
            AnimatedBuilder(
              animation: _deltaController,
              builder: (context, _) {
                final progress = CurvedAnimation(
                  parent: _deltaController,
                  curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                );
                return FadeTransition(
                  opacity: progress,
                  child: Text(
                    _headingLine3,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'by ${widget.projection.goalDateLabel}.',
              style: GoogleFonts.plusJakartaSans(
                color: _accentColor,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Metrics card ─────────────────────────────────────────────────────────

  Widget _buildMetricsCard() {
    final metrics = [
      _Metric(
        icon: LucideIcons.flame,
        label: 'Daily calories',
        value: widget.projection.dailyCalories.toDouble(),
        suffix: ' kcal',
        decimals: 0,
        delay: 0.0,
      ),
      _Metric(
        icon: LucideIcons.beef,
        label: 'Daily protein',
        value: widget.projection.proteinG.toDouble(),
        suffix: 'g',
        decimals: 0,
        delay: 0.15,
      ),
      _Metric(
        icon: LucideIcons.calendar_days,
        label: 'Goal date',
        staticValue: widget.projection.goalDateLabel,
        delay: 0.30,
      ),
      _Metric(
        icon: LucideIcons.gauge,
        label: 'Pace',
        staticValue: widget.projection.paceLabel,
        delay: 0.45,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCell(metrics[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCell(metrics[1])),
            ],
          ),
          const SizedBox(height: 1),
          Divider(color: AppTheme.borderDark, height: 24),
          Row(
            children: [
              Expanded(child: _buildMetricCell(metrics[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCell(metrics[3])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(_Metric metric) {
    return AnimatedBuilder(
      animation: _metricsController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _metricsController,
          curve: Interval(
            metric.delay,
            (metric.delay + 0.55).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        );

        String displayValue;
        if (metric.staticValue != null) {
          displayValue = metric.staticValue!;
        } else {
          final animated = (metric.value! * progress.value);
          displayValue = metric.decimals == 0
              ? '${animated.round()}${metric.suffix}'
              : '${animated.toStringAsFixed(metric.decimals!)}${metric.suffix}';
        }

        return FadeTransition(
          opacity: progress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(metric.icon, color: _accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayValue,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Sparkline card ───────────────────────────────────────────────────────

  Widget _buildSparklineCard() {
    final series = _weightSeries;

    return AnimatedBuilder(
      animation: _chartController,
      builder: (context, _) {
        final progress = CurvedAnimation(
          parent: _chartController,
          curve: Curves.easeInOutCubic,
        ).value;

        return Opacity(
          opacity: (_chartController.value * 2).clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEIGHT PROJECTION',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      points: series,
                      progress: progress,
                      lineColor: _accentColor,
                      fillColor: _accentColor.withValues(alpha: 0.10),
                      gridColor: AppTheme.borderDark.withValues(alpha: 0.6),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Today  ${widget.currentWeight.toStringAsFixed(1)} kg',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.projection.goalDateLabel}  ${widget.targetWeight.toStringAsFixed(1)} kg',
                      style: GoogleFonts.plusJakartaSans(
                        color: _accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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
  }

  // ─── Disclaimer ───────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return AnimatedBuilder(
      animation: _chartController,
      builder: (context, _) => Opacity(
        opacity: _chartController.value.clamp(0.0, 1.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.info,
              size: 13,
              color: AppTheme.textSageMuted.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Based on your stats with a moderate activity level. Buddy will recalculate once you complete your profile.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted.withValues(alpha: 0.5),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CTA ─────────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    return GestureDetector(
      onTap: widget.onNext,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _accentColor,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          'THIS LOOKS ACHIEVABLE',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.oledBlack,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Sparkline painter ────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final double progress;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  const _SparklinePainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce(min);
    final maxVal = points.reduce(max);
    final range = (maxVal - minVal).abs();
    // Add 15% padding so the line doesn't hug the edges
    final padded = range < 0.1 ? 2.0 : range * 1.3;
    final mid = (minVal + maxVal) / 2;

    double toY(double v) =>
        size.height - ((v - (mid - padded / 2)) / padded * size.height);
    double toX(int i) => i / (points.length - 1) * size.width;

    // Grid line at current weight
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final gridY = toY(points.first);
    canvas.drawLine(Offset(0, gridY), Offset(size.width, gridY), gridPaint);

    // Build the full smooth path via cubic bezier
    final fullPath = Path();
    fullPath.moveTo(toX(0), toY(points[0]));
    for (int i = 0; i < points.length - 1; i++) {
      final x1 = toX(i);
      final x2 = toX(i + 1);
      final y1 = toY(points[i]);
      final y2 = toY(points[i + 1]);
      final cpX = (x1 + x2) / 2;
      fullPath.cubicTo(cpX, y1, cpX, y2, x2, y2);
    }

    // Clip to animated progress (left-to-right reveal)
    final clipRect = Rect.fromLTWH(0, 0, size.width * progress, size.height);
    canvas.save();
    canvas.clipRect(clipRect);

    // Fill beneath the curve
    final fillPath = Path.from(fullPath);
    fillPath.lineTo(size.width * progress, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [fillColor, fillColor.withValues(alpha: 0)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw the line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(fullPath, linePaint);

    // Dot at current progress tip
    if (progress > 0.02) {
      final tipT = progress.clamp(0.0, 1.0);
      final tipIndex = ((points.length - 1) * tipT).floor()
          .clamp(0, points.length - 2);
      final localT = ((points.length - 1) * tipT) - tipIndex;
      final x1 = toX(tipIndex);
      final x2 = toX(tipIndex + 1);
      final y1 = toY(points[tipIndex]);
      final y2 = toY(points[tipIndex + 1]);
      final tipX = x1 + (x2 - x1) * localT;
      final tipY = y1 + (y2 - y1) * localT;
      canvas.drawCircle(
        Offset(tipX, tipY),
        5,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        Offset(tipX, tipY),
        3,
        Paint()..color = AppTheme.oledBlack,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.points != points;
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _Metric {
  final IconData icon;
  final String label;
  final double? value;
  final String? suffix;
  final int? decimals;
  final String? staticValue;
  final double delay;

  const _Metric({
    required this.icon,
    required this.label,
    this.value,
    this.suffix,
    this.decimals,
    this.staticValue,
    required this.delay,
  });
}
