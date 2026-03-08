import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/auth_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/services/generation_service.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/widgets/app_snackbar.dart';

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

  static const _quotes = [
    'Your body can do it.',
    'Progress, not perfection.',
    'Strong starts here.',
    'Move. Fuel. Thrive.',
    'Every rep counts.',
    'Build the life you want.',
    'Consistency is strength.',
    'Show up for yourself.',
  ];
  int _quoteIndex = 0;
  bool _quoteFadeVisible = true;
  Timer? _quoteTimer;

  // Page 1: Weight Goal
  String _fitnessGoal = '';
  double _targetWeight = 75.0;

  // Page 2: Activity Level
  String _activityLevel = '';

  // Page 3: Diet Preferences
  String _dietType = '';
  String _mealPrepTime = '';
  String _cookingBy = '';
  Map<String, List<String>> _dietFoods = {};
  Set<String> _selectedFoods = {};

  // Page 4: Workout Setup
  final Set<String> _selectedEquipment = {};
  String _workoutCycle = '';

  // Page 5: Supersets preference
  bool? _preferSupersets;

  // Derived from the chosen split
  int get _daysPerWeek =>
      const {
        'ppl': 6,
        'upper_lower': 4,
        'ppl_upper': 5,
        'full_body': 3,
      }[_workoutCycle] ??
      4;

  // Diet defaults (sent to API)
  final bool _useProteinPowder = true;
  final String _proteinLevel = 'high';

  // Always-on meals that cannot be deselected
  static const _requiredMeals = {'breakfast', 'lunch', 'dinner'};

  // User-selected meals (starts with just the required three)
  final Set<String> _selectedMeals = {'breakfast', 'lunch', 'dinner'};

  // Canonical meal order for sorting before sending to API
  static const _mealOrder = {
    'breakfast': 0,
    'morning_snack': 1,
    'lunch': 2,
    'pre_workout': 3,
    'post_workout': 4,
    'dinner': 5,
    'evening_snack': 6,
  };

  List<String> get _preferredMeals {
    final sorted = _selectedMeals.toList()
      ..sort((a, b) => (_mealOrder[a] ?? 9) - (_mealOrder[b] ?? 9));
    return sorted;
  }

  bool _isGenerating = false;
  String? _generatingMessage;

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_quotes.length);
    _loadCurrentWeight();
    _fetchDietFoods();
  }

  void _startQuoteCycle() {
    _quoteTimer?.cancel();
    _quoteTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      setState(() => _quoteFadeVisible = false);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _quoteIndex = (_quoteIndex + 1) % _quotes.length;
        _quoteFadeVisible = true;
      });
    });
  }

  void _stopQuoteCycle() {
    _quoteTimer?.cancel();
    _quoteTimer = null;
  }

  Future<void> _fetchDietFoods() async {
    try {
      final res = await DietService.getDietFoods();
      if (res['success'] == true && res['data'] != null) {
        final raw = res['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _dietFoods = raw.map(
              (k, v) => MapEntry(k, List<String>.from(v as List)),
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble('user_weight') ?? 75.0;
    if (mounted) setState(() => _targetWeight = w);
  }

  void _showValidationError(String message) {
    AppSnackbar.error(context, message);
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (_fitnessGoal.isEmpty) {
          _showValidationError('Please select your body goal to continue.');
          return false;
        }
        return true;
      case 1:
        if (_activityLevel.isEmpty) {
          _showValidationError(
            'Please select your activity level to continue.',
          );
          return false;
        }
        return true;
      case 2:
        if (_dietType.isEmpty) {
          _showValidationError('Please select your diet type.');
          return false;
        }
        if (_mealPrepTime.isEmpty) {
          _showValidationError(
            'Please select how much time you have to cook a meal.',
          );
          return false;
        }
        if (_cookingBy.isEmpty) {
          _showValidationError('Please select who cooks your meals.');
          return false;
        }
        if (_selectedFoods.isEmpty) {
          _showValidationError(
            'Pick at least one favourite food so we can personalize your plan.',
          );
          return false;
        }
        return true;
      case 3:
        if (_selectedEquipment.isEmpty) {
          _showValidationError(
            'Please select at least one piece of equipment.',
          );
          return false;
        }
        if (_workoutCycle.isEmpty) {
          _showValidationError('Please select your training split.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (!_validateCurrentPage()) return;
    if (_currentPage < 4) {
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
    _startQuoteCycle();

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

      await ProfileService.updateProfile({
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
        'preferredMeals': _preferredMeals,
        'dietType': _dietType,
        'mealPrepTime': _mealPrepTime,
        'cookingBy': _cookingBy,
        'preferredFoods': _selectedFoods.toList(),
        'profileCompleted': true,
        'preferSupersets': _preferSupersets ?? false,
      });

      if (mounted) {
        setState(() => _generatingMessage = 'Building your plans...');
      }

      // Trigger async generation — must succeed before marking onboarding complete
      await GenerationService.triggerGeneration();
      ref.read(generationStatusProvider.notifier).startPolling();

      // Mark user as fully onboarded — only after profile + generation trigger both succeed
      await AuthService.completeOnboarding();

      if (mounted) {
        setState(() => _generatingMessage = 'All set! Let\'s go!');
      }
      await Future.delayed(const Duration(milliseconds: 600));

      await widget.onComplete();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _stopQuoteCycle();
        setState(() => _isGenerating = false);
        AppSnackbar.error(
          context,
          'Setup failed. Please check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) return _buildGeneratingScreen();

    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Go back',
                  excludeSemantics: true,
                  child: GestureDetector(
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
                _buildDietPreferencesPage(),
                _buildWorkoutSetupPage(),
                _buildSupersetPreferencePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Semantics(
        liveRegion: true,
        label: _generatingMessage ?? 'Setting up your plan...',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
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
              ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: _quoteFadeVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _quotes[_quoteIndex],
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
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
              color: i <= globalStep ? AppTheme.primary : AppTheme.borderDark,
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
                  backgroundColor: AppTheme.transparent,
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
                child: Semantics(
                  button: true,
                  label: 'Confirm selection',
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

    final showTargetWeight =
        _fitnessGoal == 'lose_fat' || _fitnessGoal == 'build_muscle';

    // Target weight picker values: 30–200 kg in 0.5 steps
    final weightValues = List.generate(341, (i) => 30.0 + i * 0.5);
    final weightIndex = weightValues.indexWhere(
      (v) => (v - _targetWeight).abs() < 0.01,
    );

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
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${g.$2}: ${g.$3}',
                    child: GestureDetector(
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
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ExcludeSemantics(
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
                                        color: AppTheme.textSageMuted.withValues(
                                          alpha: 0.7,
                                        ),
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
                                initialIndex: weightIndex < 0
                                    ? 90
                                    : weightIndex,
                                onConfirm: (i) => setState(
                                  () => _targetWeight = weightValues[i],
                                ),
                              ),
                              child: Semantics(
                                button: true,
                                label:
                                    'Target weight: ${_targetWeight.toStringAsFixed(1)} kg, tap to change',
                                child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderDark,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
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
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
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
                             ),
                             const SizedBox(height: 4),
                            Text(
                              _fitnessGoal == 'lose_fat'
                                  ? 'Set a realistic target — aim for 0.5–1 kg/week.'
                                  : 'Muscle gain is slow — 0.25–0.5 kg/week is great progress.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted.withValues(
                                  alpha: 0.6,
                                ),
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
      (
        'sedentary',
        'Mostly Sitting',
        'Desk job or little daily movement',
        '🪑',
      ),
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
      (
        'very_active',
        'Very Active',
        'Intense training almost every day',
        '🏋️',
      ),
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
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${l.$2}: ${l.$3}',
                    child: GestureDetector(
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
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ExcludeSemantics(
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
                                        color: AppTheme.textSageMuted.withValues(
                                          alpha: 0.7,
                                        ),
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

  // ─── Page 5: Diet Preferences ────────────────────────────────────────

  Widget _buildDietPreferencesPage() {
    final foods = _dietFoods[_dietType] ?? _fallbackFoods[_dietType] ?? [];
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    const dietOptions = [
      ('vegetarian', 'Vegetarian', 'Dal, paneer, tofu, curd', '🌿'),
      (
        'non_vegetarian',
        'Non-Vegetarian',
        'Chicken, eggs, fish + Indian staples',
        '🍗',
      ),
      ('vegan', 'Vegan', 'Strictly plant-based, no dairy', '🌱'),
    ];

    const prepOptions = [
      ('15min', '15 min', 'Quick & easy'),
      ('30min', '30 min', 'Standard home cook'),
      ('1hour', '1 hour', 'Elaborate meals ok'),
    ];

    const cookOptions = [('myself', 'Myself', '👤'), ('maid', 'Maid', '🧑‍🍳')];

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
                  'DIET PREFERENCES',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How do you\neat?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This shapes every meal suggestion — proteins, recipes, and timing.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),

                // Diet type
                Text(
                  'DIET TYPE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                ...dietOptions.map((d) {
                  final isSelected = _dietType == d.$1;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${d.$2}: ${d.$3}',
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _dietType = d.$1;
                        _selectedFoods = {};
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Text(d.$4, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.$2,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isSelected
                                            ? AppTheme.textCream
                                            : AppTheme.textSageMuted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      d.$3,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textSageMuted.withValues(
                                          alpha: 0.7,
                                        ),
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
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // How you eat — meals per day
                Text(
                  'HOW YOU EAT',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick the meals that fit your day. Breakfast, lunch & dinner are always included.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        ('breakfast', 'Breakfast', '🌅'),
                        ('morning_snack', 'Morning Snack', '🍎'),
                        ('lunch', 'Lunch', '🥗'),
                        ('pre_workout', 'Pre-Workout', '💪'),
                        ('post_workout', 'Post-Workout', '🥤'),
                        ('dinner', 'Dinner', '🍽️'),
                        ('evening_snack', 'Evening Snack', '🌙'),
                      ].map((meal) {
                        final id = meal.$1;
                        final label = meal.$2;
                        final emoji = meal.$3;
                        final isRequired = _requiredMeals.contains(id);
                        final isSelected = _selectedMeals.contains(id);
                        return Semantics(
                          button: !isRequired,
                          selected: isSelected,
                          enabled: !isRequired,
                          label: isRequired ? '$label (required)' : label,
                          child: GestureDetector(
                            onTap: isRequired
                                ? null
                                : () => setState(() {
                                    if (isSelected) {
                                      _selectedMeals.remove(id);
                                    } else {
                                      _selectedMeals.add(id);
                                    }
                                  }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.borderDark,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ExcludeSemantics(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isSelected
                                            ? AppTheme.textCream
                                            : AppTheme.textSageMuted,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    if (isRequired) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'required',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppTheme.primary,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),

                // Meal prep time
                Text(
                  'MEAL PREP TIME',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: prepOptions.map((p) {
                    final isSelected = _mealPrepTime == p.$1;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: 'Meal prep time: ${p.$2}, ${p.$3}',
                        child: GestureDetector(
                          onTap: () => setState(() => _mealPrepTime = p.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(
                              right: p.$1 != '1hour' ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.borderDark,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  Text(
                                    p.$2,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? AppTheme.textCream
                                          : AppTheme.textSageMuted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.$3,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textSageMuted.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 9,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Who's cooking
                Text(
                  "WHO'S COOKING?",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: cookOptions.map((c) {
                    final isSelected = _cookingBy == c.$1;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: 'Cooked by: ${c.$2}',
                        child: GestureDetector(
                          onTap: () => setState(() => _cookingBy = c.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(
                              right: c.$1 != 'maid' ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.borderDark,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  Text(c.$3, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.$2,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? AppTheme.textCream
                                          : AppTheme.textSageMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Favourite food chips
                if (foods.isNotEmpty) ...[
                  Text(
                    'FAVOURITE FOODS',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to pick the ones you love — the AI will build your plan around them.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: foods.map((f) {
                      final isSelected = _selectedFoods.contains(f);
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: f,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedFoods.remove(f);
                            } else {
                              _selectedFoods.add(f);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.borderDark,
                              ),
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                f,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected
                                      ? AppTheme.backgroundDark
                                      : AppTheme.textSageMuted,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedFoods.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_selectedFoods.length} selected',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
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

  // Fallback food lists if API is unreachable
  static const _fallbackFoods = {
    'vegetarian': [
      'Paneer',
      'Tofu',
      'Moong Dal',
      'Masoor Dal',
      'Chana Dal',
      'Rajma',
      'Chole',
      'Dahi (Curd)',
      'Greek Yogurt',
      'Moong Sprouts',
      'Sattu',
      'Soya Chunks',
      'Skimmed Milk',
      'Peanut Butter',
      'Makhana',
    ],
    'non_vegetarian': [
      'Chicken Breast',
      'Whole Eggs',
      'Egg Whites',
      'Tuna',
      'Salmon',
      'Prawn/Shrimp',
      'Fish (Rohu/Catla)',
      'Lean Mutton Keema',
      'Turkey',
      'Paneer',
      'Moong Dal',
      'Dahi (Curd)',
      'Greek Yogurt',
      'Soya Chunks',
      'Rajma',
    ],
    'vegan': [
      'Tofu',
      'Tempeh',
      'Seitan',
      'Edamame',
      'Moong Dal',
      'Masoor Dal',
      'Chole',
      'Rajma',
      'Quinoa',
      'Hemp Seeds',
      'Soya Chunks',
      'Sattu',
      'Peanut Butter',
      'Lentil Sprouts',
      'Black Beans',
    ],
  };

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
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: opt.label,
                      child: GestureDetector(
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
                          child: ExcludeSemantics(
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
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${cy.$2}: ${cy.$3}',
                    child: GestureDetector(
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
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ExcludeSemantics(
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
                                        color: AppTheme.textSageMuted.withValues(
                                          alpha: 0.6,
                                        ),
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

  Widget _buildSupersetPreferencePage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final options = [
      (true, 'Yes, include supersets',
          'Pair exercises back-to-back for more intensity and time efficiency.'),
      (false, 'Keep it simple',
          'One exercise at a time with full rest between sets.'),
    ];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Do you want supersets?',
                  style: GoogleFonts.sora(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Supersets pair two exercises back-to-back with no rest in between — great for saving time and boosting intensity. For example: Bench Press straight into DB Flyes, then rest.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                ...options.map((opt) {
                  final (value, label, subtitle) = opt;
                  final isSelected = _preferSupersets == value;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '$label: $subtitle',
                    child: GestureDetector(
                      onTap: () => setState(() => _preferSupersets = value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textCream,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textSageMuted,
                                        fontSize: 12,
                                        height: 1.4,
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
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExcludeSemantics(
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
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Semantics(
      button: true,
      label: 'Generate my plan',
      child: GestureDetector(
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
          ),
          child: ExcludeSemantics(
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
        ),
      ),
    );
  }
}
