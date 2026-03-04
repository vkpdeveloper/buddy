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
    extends ConsumerState<FitnessOnboardingExtension>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Page 1: Activity Level
  String _activityLevel = 'moderately_active';

  // Page 2: Workout Setup
  final Set<String> _selectedEquipment = {'dumbbells', 'bodyweight'};
  int _daysPerWeek = 4;
  String _workoutCycle = 'ppl';

  // Diet defaults (sent to API)
  final String _dietGoal = 'muscle_gain';
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _fadeController.reset();
      _fadeController.forward();
    } else {
      _finalize();
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

      await ApiClient.updateProfile({
        'weight': weight,
        'height': height,
        'age': age,
        'sex': sex.toLowerCase(),
        'goal': _dietGoal,
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

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _fadeController.reset();
              _fadeController.forward();
            },
            children: [
              _buildActivityPage(),
              _buildWorkoutSetupPage(),
            ],
          ),
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

  // ─── Page 5: Activity Level ──────────────────────────────────────────

  Widget _buildActivityPage() {
    final levels = [
      ('sedentary', 'Sedentary', 'Desk job, little to no exercise', '🪑'),
      (
        'lightly_active',
        'Lightly Active',
        'Light exercise 1-3 days/week',
        '🚶',
      ),
      (
        'moderately_active',
        'Moderately Active',
        'Exercise 3-5 days/week',
        '🏃',
      ),
      ('very_active', 'Very Active', 'Hard exercise 6-7 days/week', '🏋️'),
      ('athlete', 'Athlete', '2× daily training, physical job', '⚡'),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(),
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
            'This calibrates your calorie targets accurately.',
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
          const SizedBox(height: 24),
          _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
          const SizedBox(height: 32),
        ],
      ),
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildPageHeader(),
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

          // Days per week
          Text(
            'DAYS PER WEEK',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Row(
              children: [
                Text(
                  '$_daysPerWeek days',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _daysPerWeek.toDouble(),
                    min: 2,
                    max: 6,
                    divisions: 4,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderDark,
                    onChanged: (v) => setState(() => _daysPerWeek = v.round()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
          const SizedBox(height: 24),
          _buildGenerateButton(),
          const SizedBox(height: 32),
        ],
      ),
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
