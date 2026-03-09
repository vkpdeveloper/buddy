import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/services/auth_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/services/generation_service.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/widgets/app_snackbar.dart';

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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;
  late final PageController _pageController = PageController();
  static const int _totalSteps = 7;

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

  // Step 1 – Goal
  String _fitnessGoal = '';

  // Step 2 – About You
  String _sex = 'Male';
  DateTime _birthDate = DateTime(1996, 3, 12);

  // Step 3 – Your Body
  double _height = 170;
  double _weight = 70.0;
  String _currentBodyShape = '';

  // Step 4 – Your Target
  String _goalBodyShape = '';
  double _targetWeight = 65.0;

  // Step 5 – Lifestyle
  String _activityLevel = '';
  String _experienceLevel = '';
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _weightSynced = false;
  bool _heightSynced = false;

  // Step 6 – Diet & Food
  String _dietType = '';
  String _mealPrepTime = '';
  String _cookingBy = '';
  Map<String, List<String>> _dietFoods = {};
  Set<String> _selectedFoods = {};
  static const _requiredMeals = {'breakfast', 'lunch', 'dinner'};
  final Set<String> _selectedMeals = {'breakfast', 'lunch', 'dinner'};
  static const _mealOrder = {
    'breakfast': 0,
    'morning_snack': 1,
    'lunch': 2,
    'pre_workout': 3,
    'post_workout': 4,
    'dinner': 5,
    'evening_snack': 6,
  };

  // Step 7 – Training Setup
  final Set<String> _selectedEquipment = {};
  String _workoutCycle = '';
  bool? _preferSupersets;
  double _stepGoal = 8000;
  double _sleepTarget = 7.5;
  double _waterTargetMl = 2250;

  // Generating
  bool _isGenerating = false;
  String? _generatingMessage;

  // Diet defaults
  static const bool _useProteinPowder = true;
  static const String _proteinLevel = 'high';

  int get _daysPerWeek =>
      const {
        'ppl': 6,
        'upper_lower': 4,
        'ppl_upper': 5,
        'full_body': 3,
      }[_workoutCycle] ??
      4;

  List<String> get _preferredMeals {
    final sorted = _selectedMeals.toList()
      ..sort((a, b) => (_mealOrder[a] ?? 9) - (_mealOrder[b] ?? 9));
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_quotes.length);
    _waterTargetMl = ((_weight * 33) / 250).round() * 250.0;
    _fetchDietFoods();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (_fitnessGoal.isEmpty) {
          AppSnackbar.error(
            context,
            'Please select your primary goal to continue.',
          );
          return false;
        }
        return true;
      case 1:
        return true; // sex has default, birthDate has default
      case 2:
        if (_currentBodyShape.isEmpty) {
          AppSnackbar.error(context, 'Please select your current body shape.');
          return false;
        }
        return true;
      case 3:
        if (_goalBodyShape.isEmpty) {
          AppSnackbar.error(context, 'Please select your goal body shape.');
          return false;
        }
        return true;
      case 4:
        if (_activityLevel.isEmpty) {
          AppSnackbar.error(
            context,
            'Please select your activity level to continue.',
          );
          return false;
        }
        if (_experienceLevel.isEmpty) {
          AppSnackbar.error(
            context,
            'Please select your training experience level.',
          );
          return false;
        }
        return true;
      case 5:
        if (_dietType.isEmpty) {
          AppSnackbar.error(context, 'Please select your diet type.');
          return false;
        }
        if (_mealPrepTime.isEmpty) {
          AppSnackbar.error(
            context,
            'Please select how much time you have to cook a meal.',
          );
          return false;
        }
        if (_cookingBy.isEmpty) {
          AppSnackbar.error(context, 'Please select who cooks your meals.');
          return false;
        }
        if (_selectedFoods.isEmpty) {
          AppSnackbar.error(
            context,
            'Pick at least one favourite food so we can personalize your plan.',
          );
          return false;
        }
        return true;
      case 6:
        if (_selectedEquipment.isEmpty) {
          AppSnackbar.error(
            context,
            'Please select at least one piece of equipment.',
          );
          return false;
        }
        if (_workoutCycle.isEmpty) {
          AppSnackbar.error(context, 'Please select your training split.');
          return false;
        }
        if (_preferSupersets == null) {
          AppSnackbar.error(
            context,
            'Please select your superset preference.',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (!_validateCurrentPage()) return;
    if (_currentPage < _totalSteps - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _finalize();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textCream,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textSageMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _connectHealthData() async {
    setState(() => _isConnecting = true);
    try {
      final granted = await requestHealthPermissions(ref);
      if (!granted) {
        if (mounted) {
          setState(() => _isConnecting = false);
          AppSnackbar.info(
            context,
            'Health Connect permissions denied. You can grant them later in Settings.',
          );
        }
        return;
      }

      await Future.delayed(const Duration(milliseconds: 800));

      ref.invalidate(latestWeightProvider);
      ref.invalidate(latestHeightProvider);
      ref.invalidate(todayStepsProvider);

      final weightResult = await ref.read(latestWeightProvider.future);
      if (weightResult != null && mounted) {
        setState(() {
          _weight = weightResult;
          _weightSynced = true;
          _waterTargetMl = ((_weight * 33) / 250).round() * 250.0;
        });
      }

      final heightResult = await ref.read(latestHeightProvider.future);
      if (heightResult != null && mounted) {
        setState(() {
          _height = heightResult;
          _heightSynced = true;
        });
      }

      final steps = await ref.read(todayStepsProvider.future);
      if (steps > 0 && mounted) {
        final avgSteps = (steps / 1000).round() * 1000;
        if (avgSteps >= 2000) {
          setState(() => _stepGoal = avgSteps.toDouble().clamp(2000, 25000));
        }
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _finalize() async {
    setState(() {
      _isGenerating = true;
      _generatingMessage = 'Saving your profile...';
    });
    _startQuoteCycle();

    try {
      final age = DateTime.now().year - _birthDate.year;

      await ProfileService.updateProfile({
        'weight': _weight,
        'height': _height,
        'age': age,
        'sex': _sex.toLowerCase(),
        'goal': _fitnessGoal,
        'targetWeight': _targetWeight,
        'activityLevel': _activityLevel,
        'weeklyWorkoutDays': _daysPerWeek,
        'equipment': _selectedEquipment.toList(),
        'workoutCycle': _workoutCycle,
        'useProteinPowder': _useProteinPowder,
        'proteinLevel': _proteinLevel,
        'waterTargetMl': _waterTargetMl.toInt(),
        'preferredMeals': _preferredMeals,
        'dietType': _dietType,
        'mealPrepTime': _mealPrepTime,
        'cookingBy': _cookingBy,
        'preferredFoods': _selectedFoods.toList(),
        'profileCompleted': true,
        'preferSupersets': _preferSupersets ?? false,
        'experienceLevel': _experienceLevel,
        'currentBodyShape': _currentBodyShape,
        'goalBodyShape': _goalBodyShape,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('step_goal', _stepGoal);
      await prefs.setDouble('sleep_target', _sleepTarget);
      await prefs.setInt('water_target_ml', _waterTargetMl.toInt());
      await prefs.setDouble('user_height', _height);
      await prefs.setDouble('user_weight', _weight);
      await prefs.setString('user_sex', _sex.toLowerCase());
      await prefs.setString('user_birth_date', _birthDate.toIso8601String());

      if (mounted) setState(() => _generatingMessage = 'Building your plans...');

      await GenerationService.triggerGeneration();
      ref.read(generationStatusProvider.notifier).startPolling();

      await AuthService.completeOnboarding();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) setState(() => _generatingMessage = "All set! Let's go!");
      await Future.delayed(const Duration(milliseconds: 600));

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

  // ─── Build ────────────────────────────────────────────────────────────────

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
                  enabled: _currentPage > 0,
                  label: 'Go back',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _currentPage > 0 ? _previousPage : null,
                    child: AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
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
                ),
                Expanded(child: _buildProgressBar()),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Step ${_currentPage + 1} of $_totalSteps',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGoalPage(),
                _buildAboutYouPage(),
                _buildYourBodyPage(),
                _buildYourTargetPage(),
                _buildLifestylePage(),
                _buildDietPage(),
                _buildTrainingPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(_totalSteps, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color:
                  i <= _currentPage ? AppTheme.primary : AppTheme.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ─── Generating Screen ────────────────────────────────────────────────────

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

  // ─── Step 1: Your Goal ────────────────────────────────────────────────────

  Widget _buildGoalPage() {
    final goals = [
      (
        'fat_loss',
        'Lose Fat',
        'Burn body fat, get leaner',
        '🔥',
        'Calorie deficit + cardio focus',
      ),
      (
        'muscle_gain',
        'Build Muscle',
        'Gain size and strength',
        '💪',
        'Calorie surplus + progressive overload',
      ),
      (
        'recomp',
        'Recomp',
        'Lose fat and build muscle',
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
      (
        'endurance',
        'Endurance',
        'Improve stamina and performance',
        '🏃',
        'Cardio focused + moderate protein',
      ),
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
                  'YOUR GOAL',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "What's your\nprimary goal?",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This determines your calorie target, macro split, and training approach.',
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
                              Text(
                                g.$4,
                                style: const TextStyle(fontSize: 24),
                              ),
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
                                        color: AppTheme.textSageMuted
                                            .withValues(alpha: 0.7),
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
          child: Column(
            children: [
              _buildPrimaryButton(label: 'CONTINUE', onTap: _nextPage),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Not you? Sign out',
                child: GestureDetector(
                  onTap: _signOut,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.log_out,
                          size: 13,
                          color: AppTheme.textSageMuted.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Not you? Sign out',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.textSageMuted.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: About You ────────────────────────────────────────────────────

  Widget _buildAboutYouPage() {
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
                  'ABOUT YOU',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us about\nyourself',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your biological sex and age help us calculate accurate calorie targets.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'BIOLOGICAL SEX',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSexImageCard('Male')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSexImageCard('Female')),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'DATE OF BIRTH',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  label: 'BIRTH DATE',
                  value: _formatDate(_birthDate),
                  unit: '',
                  icon: LucideIcons.calendar,
                  onTap: _showBirthDatePicker,
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

  Widget _buildSexImageCard(String label) {
    final isSelected = _sex == label;
    final imgKey = label.toLowerCase();
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() => _sex = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderDark,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: Image.asset(
                        'assets/images/body_shapes/${imgKey}_lean.png',
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, _) => SizedBox(
                          height: 140,
                          child: Center(
                            child: Icon(
                              LucideIcons.user,
                              color:
                                  AppTheme.textSageMuted.withValues(alpha: 0.4),
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected
                              ? AppTheme.textCream
                              : AppTheme.textSageMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        color: AppTheme.backgroundDark,
                        size: 14,
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

  // ─── Step 3: Your Body ────────────────────────────────────────────────────

  Widget _buildYourBodyPage() {
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
                  'YOUR BODY',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Where are you\nstarting from?",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be honest — this sets the right baseline for your plan.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                if (_isConnected) ...[
                  const SizedBox(height: 12),
                  _buildSyncBadge(),
                ],
                const SizedBox(height: 24),
                _buildMetricCard(
                  label: 'HEIGHT',
                  value: _height.toStringAsFixed(0),
                  unit: 'CM',
                  synced: _heightSynced,
                  onTap: () => _showNumberPicker(
                    title: 'Height (cm)',
                    initial: _height,
                    min: 100,
                    max: 250,
                    onChanged: (v) => setState(() => _height = v),
                  ),
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  label: 'WEIGHT',
                  value: _weight.toStringAsFixed(1),
                  unit: 'KG',
                  synced: _weightSynced,
                  onTap: () => _showNumberPicker(
                    title: 'Weight (kg)',
                    initial: _weight,
                    min: 30,
                    max: 200,
                    decimals: true,
                    onChanged: (v) => setState(() {
                      _weight = v;
                      _waterTargetMl = ((_weight * 33) / 250).round() * 250.0;
                    }),
                  ),
                ),
                const SizedBox(height: 28),
                _buildBodyShapeGrid(
                  label: 'CURRENT BODY SHAPE',
                  selectedValue: _currentBodyShape,
                  onSelect: (v) => setState(() => _currentBodyShape = v),
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

  // ─── Step 4: Your Target ──────────────────────────────────────────────────

  Widget _buildYourTargetPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final showTargetWeight =
        _fitnessGoal == 'fat_loss' || _fitnessGoal == 'muscle_gain';
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
                  'YOUR TARGET',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Where do you\nwant to be?",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your ideal physique and target weight.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                _buildBodyShapeGrid(
                  label: 'GOAL BODY SHAPE',
                  selectedValue: _goalBodyShape,
                  onSelect: (v) => setState(() => _goalBodyShape = v),
                ),
                if (showTargetWeight) ...[
                  const SizedBox(height: 28),
                  Text(
                    'TARGET WEIGHT',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_targetWeight.toStringAsFixed(1)} kg',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _fitnessGoal == 'fat_loss'
                            ? 'Aim for 0.5–1 kg/week'
                            : '0.25–0.5 kg/week is great',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _targetWeight,
                    min: 30,
                    max: 200,
                    divisions: 340,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderDark,
                    onChanged: (v) =>
                        setState(() => _targetWeight = (v * 2).round() / 2.0),
                  ),
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

  // ─── Step 5: Lifestyle ────────────────────────────────────────────────────

  Widget _buildLifestylePage() {
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

    final experienceLevels = [
      ('beginner', 'Beginner', '0 – 1 year', 'Building foundations, form first'),
      (
        'intermediate',
        'Intermediate',
        '1 – 3 years',
        'Progressive overload, more variety',
      ),
      ('advanced', 'Advanced', '3+ years', 'High volume, periodisation'),
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
                  'YOUR LIFESTYLE',
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
                const SizedBox(height: 16),
                // Health sync opt-in chip
                Semantics(
                  button: true,
                  label: _isConnected
                      ? 'Health data synced'
                      : 'Sync from Health Connect',
                  child: GestureDetector(
                    onTap: (_isConnected || _isConnecting)
                        ? null
                        : _connectHealthData,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isConnected
                              ? AppTheme.primary.withValues(alpha: 0.4)
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isConnecting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : Icon(
                                  _isConnected
                                      ? LucideIcons.shield_check
                                      : LucideIcons.heart_pulse,
                                  color: _isConnected
                                      ? AppTheme.primary
                                      : AppTheme.textSageMuted,
                                  size: 16,
                                ),
                          const SizedBox(width: 8),
                          Text(
                            _isConnected
                                ? 'Health data synced ✓'
                                : 'Sync from Health Connect ↗',
                            style: GoogleFonts.plusJakartaSans(
                              color: _isConnected
                                  ? AppTheme.primary
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
                const SizedBox(height: 20),
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
                              Text(
                                l.$4,
                                style: const TextStyle(fontSize: 24),
                              ),
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
                                        color: AppTheme.textSageMuted
                                            .withValues(alpha: 0.7),
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
                const SizedBox(height: 28),
                Text(
                  'TRAINING EXPERIENCE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'How long have you been training consistently?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                ...experienceLevels.map((e) {
                  final isSelected = _experienceLevel == e.$1;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${e.$2}: ${e.$3}',
                    child: GestureDetector(
                      onTap: () => setState(() => _experienceLevel = e.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.$2,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isSelected
                                            ? AppTheme.textCream
                                            : AppTheme.textSageMuted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      isSelected ? e.$4 : e.$3,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textSageMuted
                                            .withValues(alpha: 0.7),
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

  // ─── Step 6: Diet & Food ──────────────────────────────────────────────────

  Widget _buildDietPage() {
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
                  'DIET & FOOD',
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
                              Text(
                                d.$4,
                                style: const TextStyle(fontSize: 22),
                              ),
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
                                        color: AppTheme.textSageMuted
                                            .withValues(alpha: 0.7),
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
                  children: [
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
                                      'req',
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
                          onTap: () =>
                              setState(() => _mealPrepTime = p.$1),
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
                                  Text(
                                    c.$3,
                                    style: const TextStyle(fontSize: 20),
                                  ),
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
                if (foods.isNotEmpty) ...[
                  const SizedBox(height: 28),
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

  // ─── Step 7: Training Setup ───────────────────────────────────────────────

  Widget _buildTrainingPage() {
    final cycles = [
      ('ppl', 'Push-Pull-Legs', 'Classic 3-way split, 6 days'),
      ('upper_lower', 'Upper-Lower', '4-day split'),
      ('ppl_upper', 'PPL + Upper', '5-6 day advanced'),
      ('full_body', 'Full Body', 'Beginner friendly, 3 days'),
    ];

    final supersets = [
      (
        true,
        'Yes, include supersets',
        'Pair exercises back-to-back for more intensity and time efficiency.',
      ),
      (
        false,
        'Keep it simple',
        'One exercise at a time with full rest between sets.',
      ),
    ];

    final burnTarget = (_weight * 30).toInt();
    final recommendedWater =
        ((_weight * 33) / 250).round() * 250.0;

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
                  'TRAINING SETUP',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "What's in\nyour gym?",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 24),
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
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
                                        color: AppTheme.textSageMuted
                                            .withValues(alpha: 0.6),
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
                const SizedBox(height: 24),
                Text(
                  'SUPERSETS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Do you want to pair exercises back-to-back?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                ...supersets.map((opt) {
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
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.1)
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
                const SizedBox(height: 28),
                Text(
                  'DAILY GOALS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set your daily targets. You can change these later in settings.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSliderCard(
                  icon: LucideIcons.trending_up,
                  label: 'DAILY STEP GOAL',
                  badge: 'ACTIVE',
                  displayValue: '${_stepGoal.toInt()}',
                  unit: 'steps',
                  child: Slider(
                    value: _stepGoal,
                    min: 2000,
                    max: 25000,
                    divisions: 46,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderDark,
                    onChanged: (v) => setState(
                      () => _stepGoal = (v / 500).round() * 500.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSliderCard(
                  icon: LucideIcons.moon,
                  label: 'SLEEP TARGET',
                  badge: 'RECOVERY',
                  displayValue: _sleepTarget.toStringAsFixed(1),
                  unit: 'hours',
                  child: Slider(
                    value: _sleepTarget,
                    min: 4.0,
                    max: 12.0,
                    divisions: 16,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderDark,
                    onChanged: (v) => setState(
                      () => _sleepTarget = (v * 2).round() / 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSliderCard(
                  icon: LucideIcons.droplet,
                  label: 'DAILY WATER TARGET',
                  badge: 'HYDRATION',
                  displayValue:
                      '${(_waterTargetMl / 1000).toStringAsFixed(1)} L',
                  unit: '${_waterTargetMl.toInt()} ml',
                  hint: _waterTargetMl == recommendedWater
                      ? 'Recommended for your weight'
                      : null,
                  child: Slider(
                    value: _waterTargetMl,
                    min: 1500,
                    max: 4000,
                    divisions: 10,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.borderDark,
                    onChanged: (v) => setState(
                      () => _waterTargetMl = (v / 250).round() * 250.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.flame,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTIMATED DAILY BURN',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Based on your weight',
                              style: GoogleFonts.plusJakartaSans(
                                color:
                                    AppTheme.textSageMuted.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$burnTarget kcal',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildSliderCard({
    required IconData icon,
    required String label,
    required String badge,
    required String displayValue,
    required String unit,
    required Widget child,
    String? hint,
  }) {
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
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
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
                      text: ' $unit',
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
          if (hint != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                hint,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }

  // ─── Shared Components ────────────────────────────────────────────────────

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = LucideIcons.arrow_right,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
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
            gradient: const LinearGradient(
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

  // ─── Body Shape Grid ──────────────────────────────────────────────────────

  String _bfLabel(String shape) {
    final male = _sex.toLowerCase() == 'male';
    return switch (shape) {
      'skinny' => male ? '14–22% body fat' : '22–28% body fat',
      'lean' => male ? '8–15% body fat' : '14–22% body fat',
      'fat' => male ? '22–32% body fat' : '30–40% body fat',
      _ => '',
    };
  }

  Widget _buildBodyShapeGrid({
    required String label,
    required String selectedValue,
    required ValueChanged<String> onSelect,
  }) {
    const shapes = [('skinny', 'Skinny'), ('lean', 'Lean'), ('fat', 'Fat')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: shapes.map((s) {
            final isSelected = selectedValue == s.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s.$1 != 'fat' ? 8 : 0),
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${s.$2}: ${_bfLabel(s.$1)}',
                  child: GestureDetector(
                    onTap: () => onSelect(s.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.borderDark,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(13),
                              ),
                              child: Image.asset(
                                'assets/images/body_shapes/${_sex.toLowerCase()}_${s.$1}.png',
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, _) => SizedBox(
                                  height: 100,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.user,
                                      color: AppTheme.textSageMuted.withValues(
                                        alpha: 0.4,
                                      ),
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                              child: Column(
                                children: [
                                  Text(
                                    s.$2,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected
                                          ? AppTheme.textCream
                                          : AppTheme.textSageMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _bfLabel(s.$1),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Metric Card ──────────────────────────────────────────────────────────

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String unit,
    IconData? icon,
    bool synced = false,
    required VoidCallback onTap,
  }) {
    final semanticLabel = unit.isNotEmpty
        ? '$label: $value $unit, tap to edit'
        : '$label: $value, tap to edit';
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderDark),
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
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              unit,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (icon != null)
                  Icon(icon, color: AppTheme.textSageMuted, size: 20)
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: synced
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      color: synced
                          ? AppTheme.backgroundDark
                          : AppTheme.primary,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shield_check, color: AppTheme.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            'HEALTH DATA SYNCED',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showBirthDatePicker() {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    const minYear = 1940;
    final maxYear = now.year - 5;
    int selMonth = _birthDate.month;
    int selDay = _birthDate.day;
    int selYear = _birthDate.year;

    int daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;

    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final monthController = FixedExtentScrollController(
      initialItem: selMonth - 1,
    );
    final dayController = FixedExtentScrollController(initialItem: selDay - 1);
    final yearController = FixedExtentScrollController(
      initialItem: years.indexOf(selYear),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final dayCount = daysInMonth(selMonth, selYear);
          if (selDay > dayCount) {
            selDay = dayCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dayController.hasClients) dayController.jumpToItem(selDay - 1);
            });
          }

          Widget col({
            required FixedExtentScrollController controller,
            required List<String> items,
            required ValueChanged<int> onChanged,
            double fontSize = 20,
          }) {
            return Expanded(
              child: CupertinoPicker(
                backgroundColor: AppTheme.transparent,
                itemExtent: 52,
                scrollController: controller,
                selectionOverlay: const SizedBox.shrink(),
                onSelectedItemChanged: (i) {
                  onChanged(i);
                  setSheetState(() {});
                },
                children: items
                    .map(
                      (label) => Center(
                        child: Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }

          return SizedBox(
            height: 420,
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
                  'Date of Birth',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 24,
                        right: 24,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            col(
                              controller: monthController,
                              items: monthNames,
                              fontSize: 17,
                              onChanged: (i) => selMonth = i + 1,
                            ),
                            col(
                              controller: dayController,
                              items: List.generate(
                                dayCount,
                                (i) => (i + 1).toString().padLeft(2, '0'),
                              ),
                              onChanged: (i) => selDay = i + 1,
                            ),
                            col(
                              controller: yearController,
                              items:
                                  years.map((y) => y.toString()).toList(),
                              onChanged: (i) => selYear = years[i],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Semantics(
                    button: true,
                    label: 'Confirm date of birth',
                    child: GestureDetector(
                      onTap: () {
                        final clamped = selDay.clamp(
                          1,
                          daysInMonth(selMonth, selYear),
                        );
                        setState(
                          () => _birthDate = DateTime(selYear, selMonth, clamped),
                        );
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
      ),
    );
  }

  void _showNumberPicker({
    required String title,
    required double initial,
    required double min,
    required double max,
    bool decimals = false,
    required ValueChanged<double> onChanged,
  }) {
    final step = decimals ? 0.5 : 1.0;
    final count = ((max - min) / step).round() + 1;
    final values = List.generate(count, (i) => min + i * step);
    final initialIndex = values.indexWhere((v) => (v - initial).abs() < 0.01);
    _showDrumPicker(
      title: title,
      labels: values
          .map(
            (v) => decimals ? v.toStringAsFixed(1) : v.toStringAsFixed(0),
          )
          .toList(),
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      onConfirm: (i) => onChanged(values[i]),
    );
  }

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
      builder: (ctx) => SizedBox(
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
      ),
    );
  }

  // ─── Fallback food lists ──────────────────────────────────────────────────

  static const _fallbackFoods = {
    'vegetarian': [
      'Paneer', 'Tofu', 'Moong Dal', 'Masoor Dal', 'Chana Dal',
      'Rajma', 'Chole', 'Dahi (Curd)', 'Greek Yogurt', 'Moong Sprouts',
      'Sattu', 'Soya Chunks', 'Skimmed Milk', 'Peanut Butter', 'Makhana',
    ],
    'non_vegetarian': [
      'Chicken Breast', 'Whole Eggs', 'Egg Whites', 'Tuna', 'Salmon',
      'Prawn/Shrimp', 'Fish (Rohu/Catla)', 'Lean Mutton Keema', 'Turkey',
      'Paneer', 'Moong Dal', 'Dahi (Curd)', 'Greek Yogurt', 'Soya Chunks', 'Rajma',
    ],
    'vegan': [
      'Tofu', 'Tempeh', 'Seitan', 'Edamame', 'Moong Dal', 'Masoor Dal',
      'Chole', 'Rajma', 'Quinoa', 'Hemp Seeds', 'Soya Chunks',
      'Sattu', 'Peanut Butter', 'Lentil Sprouts', 'Black Beans',
    ],
  };
}
