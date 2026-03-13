import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/widgets/app_snackbar.dart';

class DailyGoalsPage extends StatefulWidget {
  const DailyGoalsPage({super.key});

  @override
  State<DailyGoalsPage> createState() => _DailyGoalsPageState();
}

class _DailyGoalsPageState extends State<DailyGoalsPage> {
  double _stepGoal = 10000;
  double _sleepTarget = 7.5;
  double _waterTargetMl = 2500;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stepGoal = prefs.getDouble('step_goal') ?? 10000;
      _sleepTarget = prefs.getDouble('sleep_target') ?? 7.5;
      _waterTargetMl = (prefs.getInt('water_target_ml') ?? 2500).toDouble();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('step_goal', _stepGoal);
    await prefs.setDouble('sleep_target', _sleepTarget);
    await prefs.setInt('water_target_ml', _waterTargetMl.toInt());
    if (mounted) {
      AppSnackbar.success(context, 'Goals saved.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: const Icon(
                      LucideIcons.chevron_left,
                      color: AppTheme.textCream,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Daily Goals',
                  style: GoogleFonts.sora(
                    color: AppTheme.textCream,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderDark, height: 1),
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
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
                      activeColor: AppTheme.primary,
                      inactiveColor: AppTheme.borderDark,
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
                      activeColor: AppTheme.primary,
                      inactiveColor: AppTheme.borderDark,
                      onChanged: (v) => setState(
                          () => _sleepTarget = (v * 2).round() / 2.0),
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
                      activeColor: AppTheme.primary,
                      inactiveColor: AppTheme.borderDark,
                      onChanged: (v) => setState(
                          () => _waterTargetMl = (v / 250).round() * 250.0),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SAVE GOALS',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
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
                        color: AppTheme.textCream,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '  $unit',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
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
