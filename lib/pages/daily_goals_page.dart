import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/services/targets_service.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/widgets/app_card.dart';

class DailyGoalsPage extends ConsumerStatefulWidget {
  const DailyGoalsPage({super.key});

  @override
  ConsumerState<DailyGoalsPage> createState() => _DailyGoalsPageState();
}

class _DailyGoalsPageState extends ConsumerState<DailyGoalsPage> {
  double _stepGoal = 10000;
  double _sleepTarget = 7.0;
  double _waterTargetMl = 2500;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await TargetsService.getTargets();
      final data = res['data'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      setState(() {
        _stepGoal = (data['dailySteps'] as num?)?.toDouble() ?? 10000;
        _sleepTarget = (data['dailySleepTarget'] as num?)?.toDouble() ?? 7.0;
        _waterTargetMl = (data['dailyWaterMl'] as num?)?.toDouble() ?? 2500;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.error(context, 'Failed to load daily goals.');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await TargetsService.updateTargets(
        dailySteps: _stepGoal.toInt(),
        dailySleepTarget: _sleepTarget,
        dailyWaterMl: _waterTargetMl.toInt(),
      );
      ref.invalidate(userTargetsProvider);
      if (mounted) {
        AppSnackbar.success(context, 'Goals saved.');
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, 'Failed to save goals.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
            child: Row(
              children: [
                AppBackButton(
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 14),
                Text(
                  'Daily Goals',
                  style: GoogleFonts.sora(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.colors.border, height: 1),
          if (_loading)
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.primary,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPad + 24),
                children: [
                  _GoalCard(
                    icon: LucideIcons.footprints,
                    label: 'Daily Steps',
                    displayValue: '${_stepGoal.toInt()}',
                    unit: 'steps',
                    slider: Slider(
                      value: _stepGoal,
                      min: 2000,
                      max: 25000,
                      divisions: 46,
                      activeColor: context.colors.primary,
                      inactiveColor: context.colors.border,
                      onChanged: (v) =>
                          setState(() => _stepGoal = (v / 500).round() * 500.0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GoalCard(
                    icon: LucideIcons.moon,
                    label: 'Sleep Target',
                    displayValue: _sleepTarget.toStringAsFixed(1),
                    unit: 'hours',
                    slider: Slider(
                      value: _sleepTarget,
                      min: 4.0,
                      max: 12.0,
                      divisions: 16,
                      activeColor: context.colors.primary,
                      inactiveColor: context.colors.border,
                      onChanged: (v) =>
                          setState(() => _sleepTarget = (v * 2).round() / 2.0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GoalCard(
                    icon: LucideIcons.droplets,
                    label: 'Daily Water',
                    displayValue:
                        '${(_waterTargetMl / 1000).toStringAsFixed(1)} L',
                    unit: '${_waterTargetMl.toInt()} ml',
                    slider: Slider(
                      value: _waterTargetMl,
                      min: 1000,
                      max: 5000,
                      divisions: 16,
                      activeColor: context.colors.primary,
                      inactiveColor: context.colors.border,
                      onChanged: (v) => setState(
                        () => _waterTargetMl = (v / 250).round() * 250.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppPrimaryButton(
                    label: 'SAVE GOALS',
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String displayValue;
  final String unit;
  final Widget slider;

  const _GoalCard({
    required this.icon,
    required this.label,
    required this.displayValue,
    required this.unit,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.colors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: displayValue,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
