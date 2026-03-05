import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/pages/home_page.dart';

// Equipment option data
class _EquipmentOption {
  final String id;
  final String label;
  final IconData icon;
  const _EquipmentOption(this.id, this.label, this.icon);
}

const _equipmentOptions = [
  _EquipmentOption('dumbbells', 'Dumbbells', LucideIcons.dumbbell),
  _EquipmentOption('barbells', 'Barbells', LucideIcons.activity),
  _EquipmentOption('cable', 'Cables', LucideIcons.cable),
  _EquipmentOption('smith_machine', 'Smith Machine', LucideIcons.grid_3x3),
  _EquipmentOption('leg_press', 'Leg Press', LucideIcons.armchair),
  _EquipmentOption('bench', 'Bench', LucideIcons.minus),
  _EquipmentOption('pullup_bar', 'Pull-up Bar', LucideIcons.expand),
  _EquipmentOption('bodyweight', 'Bodyweight', LucideIcons.user),
];

class FitnessOnboardingExtension extends ConsumerStatefulWidget {
  final Future<void> Function() onComplete;
  final int totalSteps;
  final int startStep;
  const FitnessOnboardingExtension({
    super.key,
    required this.onComplete,
    this.totalSteps = 5,
    this.startStep = 3,
  });

  @override
  ConsumerState<FitnessOnboardingExtension> createState() =>
      _FitnessOnboardingExtensionState();
}

class _FitnessOnboardingExtensionState
    extends ConsumerState<FitnessOnboardingExtension> {
  int _currentPage = 0;
  late final PageController _pageController = PageController();

  // Page 1: Weight Goal
  String _fitnessGoal = 'build_muscle'; // lose_fat | build_muscle | recomp | maintain
  double _targetWeight = 75.0;

  // Page 2: Activity Level
  String _activityLevel = 'moderately_active';

  // Page 3: Workout Setup
  final Set<String> _selectedEquipment = {'dumbbells', 'bodyweight'};
  String _workoutCycle = 'ppl';

  // Derived from the chosen split — no need to ask separately
  int get _daysPerWeek => const {
    'ppl': 6,
    'upper_lower': 4,
    'ppl_upper': 5,
    'full_body': 3,
  }[_workoutCycle]!;

  // Diet defaults (sent to API)
  final bool _useProteinPowder = true;
  final String _proteinLevel = 'high';
  final Set<String> _preferredMeals = {
    'breakfast',
    'morning_snack',
    'lunch',
    'pre_workout',
    'post_workout',
    'dinner',
    'evening_snack',
  };

  bool _isGenerating = false;
  String? _generatingMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentWeight();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble('user_weight') ?? 75.0;
    if (mounted) setState(() => _targetWeight = w);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finalize();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _finalize() async {
    setState(() {
      _isGenerating = true;
      _generatingMessage = 'Saving your profile...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final weight = prefs.getDouble('user_weight') ?? 70.0;
      final height = prefs.getDouble('user_height') ?? 175.0;
      final sex = prefs.getString('user_sex') ?? 'male';
      final birthDate =
          DateTime.tryParse(prefs.getString('user_birth_date') ?? '') ??
          DateTime(1996, 1, 1);
      final age = DateTime.now().year - birthDate.year;

      final waterTargetMl = prefs.getInt('water_target_ml') ?? 2500;

      // Map UI goal to API goal value
      final goalMap = {
        'lose_fat': 'fat_loss',
        'build_muscle': 'muscle_gain',
        'recomp': 'recomp',
        'maintain': 'maintain',
      };

      await ApiClient.updateProfile({
        'weight': weight,
        'height': height,
        'age': age,
        'sex': sex.toLowerCase(),
        'goal': goalMap[_fitnessGoal] ?? 'muscle_gain',
        'targetWeight': _targetWeight,
        'activityLevel': _activityLevel,
        'weeklyWorkoutDays': _daysPerWeek,
        'equipment': _selectedEquipment.toList(),
        'workoutCycle': _workoutCycle,
        'useProteinPowder': _useProteinPowder,
        'proteinLevel': _proteinLevel,
        'waterTargetMl': waterTargetMl,
        'preferredMeals': _preferredMeals.toList(),
        'profileCompleted': true,
      });

      if (mounted) {
        setState(
          () => _generatingMessage = 'Generating your plan...',
        );
      }
      await Future.wait([
        ApiClient.generateDietPlan(),
        ApiClient.generateWorkoutPlan(),
      ]);

      if (mounted) {
        setState(() => _generatingMessage = 'All set! Let\'s go! 💪');
      }
      await Future.delayed(const Duration(milliseconds: 800));

      await widget.onComplete();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not connect to server. Starting offline.',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 13,
              ),
            ),
            backgroundColor: AppTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Still allow proceeding even if server is offline
        await Future.delayed(const Duration(milliseconds: 500));
        await widget.onComplete();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (_) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) return _buildGeneratingScreen();

    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _previousPage,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      LucideIcons.chevron_left,
                      color: AppTheme.textSageMuted,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(child: _buildPageHeader()),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGoalPage(),
                _buildActivityPage(),
                _buildWorkoutSetupPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _generatingMessage ?? 'Setting up your plan...',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by Gemini AI',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page Header ─────────────────────────────────────────────────────

  Widget _buildPageHeader() {
    final globalStep = widget.startStep + _currentPage;
    final total = widget.totalSteps;
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= globalStep
                  ? AppTheme.primary
                  : AppTheme.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ─── Drum Picker ─────────────────────────────────────────────────────

  void _showDrumPicker({
    required String title,
    required List<String> labels,
    required int initialIndex,
    required ValueChanged<int> onConfirm,
  }) {
    int selectedIndex = initialIndex;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 380,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.transparent,
                  itemExtent: 52,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  selectionOverlay: Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  onSelectedItemChanged: (i) => selectedIndex = i,
                  children: labels
                      .map(
                        (l) => Center(
                          child: Text(
                            l,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: GestureDetector(
                  onTap: () {
                    onConfirm(selectedIndex);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'CONFIRM',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.backgroundDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Page 4: Weight Goal ─────────────────────────────────────────────

  Widget _buildGoalPage() {
    final goals = [
      (
        'lose_fat',
        'Lose Fat',
        'Burn body fat, get leaner',
        '🔥',
        'Calorie deficit + cardio focus',
      ),
      (
        'build_muscle',
        'Build Muscle',
        'Gain size and strength',
        '💪',
        'Calorie surplus + progressive overload',
      ),
      (
        'recomp',
        'Recomp',
        'Lose fat and build muscle at the same time',
        '⚖️',
        'Maintenance calories + high protein',
      ),
      (
        'maintain',
        'Maintain',
        'Keep current physique, stay healthy',
        '📊',
        'Balanced macros + consistency',
      ),
    ];

    final showTargetWeight = _fitnessGoal == 'lose_fat' || _fitnessGoal == 'build_muscle';

    // Target weight picker values: 30–200 kg in 0.5 steps
    final weightValues = List.generate(341, (i) => 30.0 + i * 0.5);
    final weightIndex = weightValues.indexWhere((v) => (v - _targetWeight).abs() < 0.01);

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const SizedBox(height: 32),
          Text(
            'BODY GOAL',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What\'s your\nprimary goal?',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This determines your calorie target, macro split, and how hard your workouts will push you.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),
          ...goals.map((g) {
            final isSelected = _fitnessGoal == g.$1;
            return GestureDetector(
              onTap: () => setState(() => _fitnessGoal = g.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.borderDark,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(g.$4, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.$2,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.textCream
                                  : AppTheme.textSageMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            isSelected ? g.$5 : g.$3,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          color: AppTheme.backgroundDark,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: showTargetWeight
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'TARGET WEIGHT',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showDrumPicker(
                          title: 'Target Weight',
                          labels: weightValues
                              .map((v) => '${v.toStringAsFixed(1)} kg')
                              .toList(),
                          initialIndex: weightIndex < 0 ? 90 : weightIndex,
                          onConfirm: (i) =>
                              setState(() => _targetWeight = weightValues[i]),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _targetWeight.toStringAsFixed(1),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textCream,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'kg',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textSageMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  LucideIcons.chevrons_up_down,
                                  color: AppTheme.primary,
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fitnessGoal == 'lose_fat'
                            ? 'Set a realistic target — aim for 0.5–1 kg/week.'
                            : 'Muscle gain is slow — 0.25–0.5 kg/week is great progress.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
        ),
      ],
    );
  }

  // ─── Page 5: Activity Level ──────────────────────────────────────────

  Widget _buildActivityPage() {
    final levels = [
      ('sedentary', 'Mostly Sitting', 'Desk job or little daily movement', '🪑'),
      (
        'lightly_active',
        'Lightly Active',
        'Short walks, occasional workouts (1–3×/week)',
        '🚶',
      ),
      (
        'moderately_active',
        'Moderately Active',
        'Regular workouts most days (3–5×/week)',
        '🏃',
      ),
      ('very_active', 'Very Active', 'Intense training almost every day', '🏋️'),
      ('athlete', 'Athlete', 'Training twice a day or physical job', '⚡'),
    ];

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const SizedBox(height: 32),
          Text(
            'ACTIVITY LEVEL',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How active are you\nday-to-day?',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be honest — a more accurate answer means a better calorie target for you.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),
          ...levels.map((l) {
            final isSelected = _activityLevel == l.$1;
            return GestureDetector(
              onTap: () => setState(() => _activityLevel = l.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.borderDark,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(l.$4, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.$2,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.textCream
                                  : AppTheme.textSageMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            l.$3,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          color: AppTheme.backgroundDark,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
        ),
      ],
    );
  }

  // ─── Page 6: Workout Setup ───────────────────────────────────────────

  Widget _buildWorkoutSetupPage() {
    final cycles = [
      ('ppl', 'Push-Pull-Legs', 'Classic 3-way split'),
      ('upper_lower', 'Upper-Lower', '4-day split'),
      ('ppl_upper', 'PPL + Upper', '5-6 day advanced'),
      ('full_body', 'Full Body', 'Beginner friendly'),
    ];

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const SizedBox(height: 32),
          Text(
            'WORKOUT SETUP',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What\'s in your gym?',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),

          // Equipment Grid
          Text(
            'AVAILABLE EQUIPMENT',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _equipmentOptions.length,
            itemBuilder: (context, i) {
              final opt = _equipmentOptions[i];
              final isSelected = _selectedEquipment.contains(opt.id);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedEquipment.remove(opt.id);
                  } else {
                    _selectedEquipment.add(opt.id);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.borderDark,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt.icon,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSageMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        opt.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected
                              ? AppTheme.textCream
                              : AppTheme.textSageMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Cycle selector
          Text(
            'TRAINING SPLIT',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...cycles.map((cy) {
            final isSelected = _workoutCycle == cy.$1;
            return GestureDetector(
              onTap: () => setState(() => _workoutCycle = cy.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.borderDark,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cy.$2,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.textCream
                                  : AppTheme.textSageMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            cy.$3,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        LucideIcons.circle_check,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildGenerateButton(),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = LucideIcons.arrow_right,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.backgroundDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: AppTheme.backgroundDark, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.sparkles,
              color: AppTheme.backgroundDark,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'GENERATE MY PLAN',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.backgroundDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
