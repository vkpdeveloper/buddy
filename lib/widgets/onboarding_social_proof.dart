import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/widgets/app_buttons.dart';

/// Self-contained social proof screen for onboarding.
/// Drop it into the PageView as a step — it manages its own entry animations.
class OnboardingSocialProofPage extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingSocialProofPage({super.key, required this.onNext});

  @override
  State<OnboardingSocialProofPage> createState() =>
      _OnboardingSocialProofPageState();
}

class _OnboardingSocialProofPageState extends State<OnboardingSocialProofPage>
    with TickerProviderStateMixin {
  late final AnimationController _barsController;
  late final AnimationController _statsController;
  late final AnimationController _fadeController;

  // Bar heights as fractions of the chart container height
  static const double _leftBarFraction = 0.28;
  static const double _rightBarFraction = 0.84;

  // Stats that count up
  static const _stats = [
    _Stat(value: 3.0, suffix: '×', label: 'more consistent\nwith a plan'),
    _Stat(value: 87.0, suffix: '%', label: 'still going\npast week 4'),
    _Stat(value: 3.8, suffix: ' kg', label: 'avg. first-month\nresult'),
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Staggered entry: fade → bars → stats
    _fadeController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _barsController.forward();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _statsController.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _barsController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'People with a plan actually win.',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildComparisonChart(context),
                  const SizedBox(height: 28),
                  _buildStatsRow(context),
                  const SizedBox(height: 24),
                  _buildSourceNote(context),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
            child: _buildCTA(),
          ),
        ],
      ),
    );
  }

  // ─── Comparison bar chart ────────────────────────────────────────────────

  Widget _buildComparisonChart(BuildContext context) {
    // Reserve space at top for the value label so the bar never overflows.
    const chartHeight = 220.0;
    const valueLabelReserve = 44.0;
    const barAreaHeight = chartHeight - valueLabelReserve;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONSISTENCY AFTER 8 WEEKS',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: chartHeight,
            child: AnimatedBuilder(
              animation: _barsController,
              builder: (context, _) {
                final curve = CurvedAnimation(
                  parent: _barsController,
                  curve: Curves.easeOutCubic,
                );
                final leftProgress = CurvedAnimation(
                  parent: _barsController,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                ).value;
                final rightProgress = curve.value;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildBar(
                        context: context,
                        progress: leftProgress,
                        fraction: _leftBarFraction,
                        barAreaHeight: barAreaHeight,
                        color: context.colors.textMuted,
                        valueLabel: '${(_leftBarFraction * 100).round()}%',
                        isWinner: false,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildBar(
                        context: context,
                        progress: rightProgress,
                        fraction: _rightBarFraction,
                        barAreaHeight: barAreaHeight,
                        color: context.colors.primary,
                        valueLabel: '${(_rightBarFraction * 100).round()}%',
                        isWinner: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Baseline rule
          Container(height: 1, color: context.colors.border),
          const SizedBox(height: 10),
          // Column labels live below the baseline, not inside the chart SizedBox
          Row(
            children: [
              Expanded(
                child: Text(
                  'On your own',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'With Buddy',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                LucideIcons.info,
                size: 11,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Based on internal user data comparing tracked vs untracked users.',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBar({
    required BuildContext context,
    required double progress,
    required double fraction,
    required double barAreaHeight,
    required Color color,
    required String valueLabel,
    required bool isWinner,
  }) {
    // Bar height is a fraction of the reserved bar area (not the full chart height),
    // so the value label above never pushes the column past its bounds.
    final barHeight = max(barAreaHeight * fraction * progress, 0.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: progress > 0.6 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              valueLabel,
              style: GoogleFonts.plusJakartaSans(
                color: isWinner ? context.colors.primary : context.colors.textMuted,
                fontSize: isWinner ? 22 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: isWinner ? context.colors.primary : color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ─── Stats row ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: _stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;
        final delay = index * 0.15;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < _stats.length - 1 ? 10 : 0),
            child: AnimatedBuilder(
              animation: _statsController,
              builder: (context, _) {
                final progress = CurvedAnimation(
                  parent: _statsController,
                  curve: Interval(
                    delay,
                    min(delay + 0.6, 1.0),
                    curve: Curves.easeOutCubic,
                  ),
                ).value;

                final displayValue = stat.value * progress;
                final formatted = stat.value % 1 == 0
                    ? displayValue.round().toString()
                    : displayValue.toStringAsFixed(1);

                return _buildStatCard(
                  context: context,
                  value: formatted,
                  suffix: stat.suffix,
                  label: stat.label,
                  opacity: progress,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String value,
    required String suffix,
    required String label,
    required double opacity,
  }) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: suffix,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Source note ─────────────────────────────────────────────────────────

  Widget _buildSourceNote(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            LucideIcons.shield_check,
            color: context.colors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'These numbers come from users who set a goal and tracked it inside Buddy for at least 8 weeks.',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  // ─── CTA ─────────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    return AppPrimaryButton(label: 'I\'M READY', onPressed: widget.onNext);
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _Stat {
  final double value;
  final String suffix;
  final String label;
  const _Stat({required this.value, required this.suffix, required this.label});
}
