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
import 'package:buddy/models/onboarding_projection.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/services/auth_service.dart';
import 'package:buddy/services/profile_service.dart';
import 'package:buddy/services/generation_service.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/services/home_dashboard_preferences.dart';
import 'package:buddy/services/targets_service.dart';
import 'package:buddy/pages/home_page.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/onboarding_hero_page.dart';
import 'package:buddy/widgets/onboarding_aha_moment.dart';
import 'package:buddy/widgets/onboarding_social_proof.dart';

class _EquipmentOption {
  final String id;
  final String label;
  final String? imagePath;
  final IconData fallbackIcon;
  const _EquipmentOption(
    this.id,
    this.label,
    this.fallbackIcon, {
    this.imagePath,
  });
}

const _equipmentOptions = [
  _EquipmentOption(
    'dumbbells',
    'Dumbbells',
    LucideIcons.dumbbell,
    imagePath: 'assets/images/equipments/dumbell.png',
  ),
  _EquipmentOption(
    'barbells',
    'Barbells',
    LucideIcons.activity,
    imagePath: 'assets/images/equipments/barbell.png',
  ),
  _EquipmentOption(
    'cable',
    'Cables',
    LucideIcons.cable,
    imagePath: 'assets/images/equipments/cable.png',
  ),
  _EquipmentOption(
    'smith_machine',
    'Smith Machine',
    LucideIcons.grid_3x3,
    imagePath: 'assets/images/equipments/smith_machine.png',
  ),
  _EquipmentOption(
    'leg_press',
    'Leg Press',
    LucideIcons.armchair,
    imagePath: 'assets/images/equipments/leg_press.png',
  ),
  _EquipmentOption(
    'bench',
    'Bench',
    LucideIcons.minus,
    imagePath: 'assets/images/equipments/bench.png',
  ),
  _EquipmentOption(
    'pullup_bar',
    'Pull-up Bar',
    LucideIcons.expand,
    imagePath: 'assets/images/equipments/pull_up_bar.png',
  ),
  _EquipmentOption(
    'bodyweight',
    'Bodyweight',
    LucideIcons.user,
    imagePath: 'assets/images/equipments/bodyweight.png',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;
  late final PageController _pageController = PageController();
  static const int _totalSteps = 18;

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
  String _goalPace = '';
  String _primaryBlocker = '';

  // Step 5 – Lifestyle
  String _activityLevel = '';
  String _experienceLevel = '';
  bool _isConnecting = false;
  bool _isConnected = false;

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
  double _stepGoal = 10000;
  final double _sleepTarget = 7.5;
  double _waterTargetMl = 2500;

  // Generating
  bool _isGenerating = false;
  bool _showFinalReveal = false;
  bool _canContinueWhileGenerating = false;
  OnboardingProjection? _submittedProjection;
  Timer? _continueToAppTimer;

  // Diet defaults
  static const bool _useProteinPowder = true;
  static const String _proteinLevel = 'high';

  bool _isNavigating = false;

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

  bool get _showTargetWeight =>
      _fitnessGoal == 'fat_loss' || _fitnessGoal == 'muscle_gain';

  double get _stepperProgress {
    final rawProgress = (_currentPage + 1) / _totalSteps;
    final visualBoost = _currentPage >= _totalSteps - 1 ? 0.0 : 0.02;
    return (rawProgress + visualBoost).clamp(0.0, 1.0);
  }

  OnboardingProjection get _projection => buildOnboardingProjection(
    goal: _fitnessGoal.isEmpty ? 'fat_loss' : _fitnessGoal,
    sex: _sex.toLowerCase(),
    birthDate: _birthDate,
    weightKg: _weight,
    heightCm: _height,
    activityLevel: _activityLevel.isEmpty
        ? 'moderately_active'
        : _activityLevel,
    goalPace: _goalPace.isEmpty ? 'steady' : _goalPace,
    goalWeightKg: _showTargetWeight ? _targetWeight : null,
  );

  @override
  void initState() {
    super.initState();
    _quoteIndex = Random().nextInt(_quotes.length);
    _fetchDietFoods();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _continueToAppTimer?.cancel();
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
        return true;
      case 1:
        if (_fitnessGoal.isEmpty) {
          AppSnackbar.error(context, 'Pick a goal first.');
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        return true;
      case 4:
        return true;
      case 5:
        if (_currentBodyShape.isEmpty) {
          AppSnackbar.error(context, 'Pick the build closest to you.');
          return false;
        }
        return true;
      case 6:
        if (_goalBodyShape.isEmpty) {
          AppSnackbar.error(context, 'Pick the build you\'re working toward.');
          return false;
        }
        return true;
      case 7:
        return true;
      case 8:
        return true;
      case 9:
        if (_goalPace.isEmpty) {
          AppSnackbar.error(context, 'Pick your pace.');
          return false;
        }
        return true;
      case 10:
        if (_primaryBlocker.isEmpty) {
          AppSnackbar.error(context, 'Pick what usually trips you up.');
          return false;
        }
        return true;
      case 11:
        return true;
      case 12:
        if (_activityLevel.isEmpty) {
          AppSnackbar.error(
            context,
            'Pick the activity level closest to your week.',
          );
          return false;
        }
        return true;
      case 13:
        if (_experienceLevel.isEmpty) {
          AppSnackbar.error(context, 'Pick your training experience.');
          return false;
        }
        return true;
      case 14:
        if (_dietType.isEmpty) {
          AppSnackbar.error(context, 'Select your diet type.');
          return false;
        }
        if (_mealPrepTime.isEmpty) {
          AppSnackbar.error(context, 'How long do you have to cook?');
          return false;
        }
        if (_cookingBy.isEmpty) {
          AppSnackbar.error(context, 'Who cooks your meals?');
          return false;
        }
        return true;
      case 15:
        if (_selectedFoods.isEmpty) {
          AppSnackbar.error(context, 'Pick at least one food you enjoy.');
          return false;
        }
        return true;
      case 16:
        if (_selectedEquipment.isEmpty) {
          AppSnackbar.error(context, 'Select at least one piece of equipment.');
          return false;
        }
        if (_workoutCycle.isEmpty) {
          AppSnackbar.error(context, 'Select your training split.');
          return false;
        }
        if (_preferSupersets == null) {
          if (_experienceLevel == 'beginner') {
            _preferSupersets = false;
          } else {
            AppSnackbar.error(context, 'Select your superset preference.');
            return false;
          }
        }
        return true;
      case 17:
        return true;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (!_validateCurrentPage()) return;
    int nextPage = _currentPage + 1;
    // Skip target weight page for goals that don't need it
    if (nextPage == 8 && !_showTargetWeight) nextPage = 9;
    if (nextPage < _totalSteps) {
      _goToPage(nextPage);
    } else {
      _finalize();
    }
  }

  void _previousPage() {
    if (_currentPage <= 0) return;
    int prevPage = _currentPage - 1;
    if (prevPage == 8 && !_showTargetWeight) prevPage = 7;
    _goToPage(prevPage);
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
        setState(() => _weight = weightResult);
      }

      final heightResult = await ref.read(latestHeightProvider.future);
      if (heightResult != null && mounted) {
        setState(() {
          _height = heightResult;
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

  String _builtAroundSummary() {
    if (_selectedFoods.isNotEmpty) {
      return _selectedFoods.take(3).join(' • ');
    }
    final labels = _equipmentOptions
        .where((option) => _selectedEquipment.contains(option.id))
        .map((option) => option.label)
        .take(3)
        .toList();
    return labels.isEmpty ? 'your routine' : labels.join(' • ');
  }

  Future<void> _persistRevealSummary(
    SharedPreferences prefs,
    OnboardingProjection projection,
  ) async {
    await prefs.setBool('pending_plan_reveal', true);
    await prefs.setString('pending_plan_goal', _fitnessGoal);
    await prefs.setString('pending_plan_goal_date', projection.goalDateLabel);
    await prefs.setString('pending_plan_pace_label', projection.paceLabel);
    await prefs.setInt('pending_plan_calories', projection.dailyCalories);
    await prefs.setInt('pending_plan_days_per_week', _daysPerWeek);
    await prefs.setString('pending_plan_built_around', _builtAroundSummary());
  }

  Future<void> _openAppWhileGenerating() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_plan_reveal', true);
    try {
      await HomeDashboardPreferences.preload();
    } catch (_) {
      // Fall back to defaults if local prefs are unavailable.
    }
    if (!mounted) return;
    _stopQuoteCycle();
    ref.read(generationStatusProvider.notifier).startPolling();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  Future<void> _openAppAfterGenerationFailure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_plan_reveal', false);
    try {
      await HomeDashboardPreferences.preload();
    } catch (_) {
      // Fall back to defaults if local prefs are unavailable.
    }
    if (!mounted) return;
    _stopQuoteCycle();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  Future<void> _completeRevealAndOpenApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_plan_reveal', false);
    try {
      await HomeDashboardPreferences.preload();
    } catch (_) {
      // Fall back to defaults if local prefs are unavailable.
    }
    if (!mounted) return;
    _stopQuoteCycle();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  List<String> _failedGenerationTypes(GenerationStatus status) {
    final failed = <String>[];
    if (status.diet.hasFailed) failed.add('diet');
    if (status.workout.hasFailed) failed.add('workout');
    return failed;
  }

  Future<void> _retryFailedGeneration(GenerationStatus status) async {
    final failedTypes = _failedGenerationTypes(status);
    if (failedTypes.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_plan_reveal', true);
      setState(() => _canContinueWhileGenerating = false);
      _startQuoteCycle();
      await GenerationService.triggerGeneration(types: failedTypes);
      ref
          .read(generationStatusProvider.notifier)
          .startPolling(interval: const Duration(seconds: 2));
      _continueToAppTimer?.cancel();
      _continueToAppTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted || _showFinalReveal) return;
        setState(() => _canContinueWhileGenerating = true);
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not restart plan setup right now.');
    }
  }

  Future<void> _finalize() async {
    final projection = _projection;
    setState(() {
      _isGenerating = true;
      _showFinalReveal = false;
      _canContinueWhileGenerating = false;
      _submittedProjection = projection;
    });
    _startQuoteCycle();
    _continueToAppTimer?.cancel();

    try {
      final age = calculateProfileAge(_birthDate);

      await ProfileService.updateProfile({
        'weight': _weight,
        'height': _height,
        'age': age,
        'sex': _sex.toLowerCase(),
        'goal': _fitnessGoal,
        'weightGoalKg': _showTargetWeight ? _targetWeight : null,
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
        'goalPace': _goalPace,
        'primaryBlocker': _primaryBlocker,
        'currentBodyShape': _currentBodyShape,
        'goalBodyShape': _goalBodyShape,
      });

      final prefs = await SharedPreferences.getInstance();
      await TargetsService.updateTargets(
        dailySteps: _stepGoal.toInt(),
        dailySleepTarget: _sleepTarget,
        dailyWaterMl: _waterTargetMl.toInt(),
        targetWeight: _showTargetWeight ? _targetWeight : null,
        includeTargetWeight: true,
        dailyCalorieBurn: 500,
      );
      await prefs.setDouble('user_height', _height);
      await prefs.setDouble('user_weight', _weight);
      await _persistRevealSummary(prefs, projection);
      // Write initial measurements to Health Connect (fire-and-forget)
      writeHeightToHC(_height);
      writeWeightToHC(_weight);
      await prefs.setString('user_sex', _sex.toLowerCase());
      await prefs.setString('user_birth_date', _birthDate.toIso8601String());

      await GenerationService.triggerGeneration();
      ref
          .read(generationStatusProvider.notifier)
          .startPolling(interval: const Duration(seconds: 2));

      await AuthService.completeOnboarding();
      await prefs.setBool('onboarding_completed', true);
      _continueToAppTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted || _showFinalReveal) return;
        setState(() => _canContinueWhileGenerating = true);
      });
    } catch (e) {
      debugPrint('[onboarding] _finalize error: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_plan_reveal', false);
      if (mounted) {
        _stopQuoteCycle();
        setState(() {
          _isGenerating = false;
          _submittedProjection = null;
        });
        AppSnackbar.error(context, e.toString());
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (_isGenerating && next.hasFailed) {
        _continueToAppTimer?.cancel();
        _stopQuoteCycle();
      }
      if (_isGenerating && !_showFinalReveal && next.isDone) {
        _continueToAppTimer?.cancel();
        _stopQuoteCycle();
        if (mounted) {
          setState(() => _showFinalReveal = true);
        }
      }
    });

    if (_showFinalReveal) return _buildFinalRevealScreen();
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
                SizedBox(
                  width: 36,
                  child: Semantics(
                    button: true,
                    enabled: _currentPage > 0,
                    label: 'Go back',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _currentPage > 0 ? _previousPage : null,
                      child: AnimatedOpacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.32,
                        duration: const Duration(milliseconds: 200),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: Icon(
                            LucideIcons.chevron_left,
                            color: AppTheme.textSageMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildProgressBar()),
                const SizedBox(width: 12),
                const SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildHeroPage(), // 0
                _buildGoalPage(), // 1
                _buildAboutYouPage(), // 2
                _buildHeightPage(), // 3
                _buildWeightPage(), // 4
                _buildBodyNowPage(), // 5
                _buildBodyTargetPage(), // 6
                _buildAhaMomentPage(), // 7
                _buildTargetWeightPage(), // 8
                _buildPacePage(), // 9
                _buildBlockerPage(), // 10
                _buildSocialProofPage(), // 11
                _buildActivityPage(), // 12
                _buildExperiencePage(), // 13
                _buildDietTypePage(), // 14
                _buildFoodsPage(), // 15
                _buildTrainingPage(), // 16
                _buildHealthSyncPage(), // 17
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      height: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.borderDark.withValues(alpha: 0.9)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.borderDark.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * _stepperProgress,
                    decoration: BoxDecoration(
                      color: AppTheme.actionSurface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.actionSurface.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Generating Screen ────────────────────────────────────────────────────

  Widget _buildGeneratingScreen() {
    final status = ref.watch(generationStatusProvider);
    final projection = _submittedProjection ?? _projection;
    final targetWeight = _projectionResultWeight(projection);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final hasFailed = status.hasFailed;
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You\'re on track',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildGeneratingHeroCard(
                        projection: projection,
                        status: status,
                        targetWeight: targetWeight,
                      ),
                      if (hasFailed) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.triangle_alert,
                                color: AppTheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Plan setup paused. Retry now, or open Buddy and pick it back up inside.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textCream,
                                    fontSize: 12,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!hasFailed &&
                          !_canContinueWhileGenerating &&
                          !status.isDone) ...[
                        const SizedBox(height: 18),
                        ExcludeSemantics(
                          child: AnimatedOpacity(
                            opacity: _quoteFadeVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              _quotes[_quoteIndex],
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.primary,
                                fontSize: 13,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasFailed) ...[
                const SizedBox(height: 18),
                _buildPrimaryButton(
                  label: 'RETRY MISSING PIECES',
                  onTap: () => _retryFailedGeneration(status),
                  icon: LucideIcons.refresh_cw,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _openAppAfterGenerationFailure,
                    child: Text(
                      'Open my app for now',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (_canContinueWhileGenerating && !status.isDone) ...[
                const SizedBox(height: 18),
                _buildPrimaryButton(
                  label: 'OPEN MY APP WHILE THIS FINISHES',
                  onTap: _openAppWhileGenerating,
                  icon: LucideIcons.arrow_right,
                ),
                const SizedBox(height: 10),
                Text(
                  'Jump in now. We\'ll finish the rest in the background.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingHeroCard({
    required OnboardingProjection projection,
    required GenerationStatus status,
    required double targetWeight,
  }) {
    final hasFailed = status.hasFailed;
    final accent = _projectionTrendColor(targetWeight);
    final weightSeries = _projectionWeightSeries(targetWeight);
    final chartProgress = status.isDone
        ? 1.0
        : max(
            (status.overallProgressPercent / 100).clamp(0.0, 1.0),
            0.14,
          ).toDouble();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.cardRaised, AppTheme.cardDark, AppTheme.oledBlack],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -44,
            right: -28,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      AppTheme.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildGeneratingInfoPill(
                      icon: LucideIcons.calendar_days,
                      label: projection.goalDateLabel,
                    ),
                    const Spacer(),
                    _buildGeneratingInfoPill(
                      icon: LucideIcons.sparkles,
                      label: '${status.overallProgressPercent}% built',
                      tint: AppTheme.textCream,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'This is where we\'re aiming',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _weight, end: targetWeight),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      '${value.toStringAsFixed(1)} kg',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 0.96,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _generationTargetLine(targetWeight, projection),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 152,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: chartProgress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) {
                      return CustomPaint(
                        painter: _ProjectionTrendPainter(
                          points: weightSeries,
                          progress: progress,
                          lineColor: accent,
                          gridColor: AppTheme.borderDark.withValues(alpha: 0.9),
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Today',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      projection.goalDateLabel,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.oledBlack.withValues(alpha: 0.44),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _generationStatusIcon(status),
                        color: hasFailed
                            ? AppTheme.error
                            : status.isDone
                            ? AppTheme.success
                            : accent,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _generationStatusLine(status),
                            key: ValueKey(_generationStatusLine(status)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (status.overallProgressPercent / 100)
                        .clamp(0, 1)
                        .toDouble(),
                    backgroundColor: AppTheme.borderDark,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingInfoPill({
    required IconData icon,
    required String label,
    Color tint = AppTheme.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.oledBlack.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 13),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _projectionTrendColor(double targetWeight) {
    final delta = targetWeight - _weight;
    if (delta < 0) return AppTheme.success;
    if (delta > 0) return AppTheme.info;
    return AppTheme.textCream;
  }

  String _generationTargetLine(
    double targetWeight,
    OnboardingProjection projection,
  ) {
    final difference = targetWeight - _weight;
    if (difference.abs() < 0.1) {
      return 'Hold steady through ${projection.goalDateLabel} while Buddy tightens the routine around you.';
    }

    final amount = difference.abs().toStringAsFixed(1);
    final direction = difference < 0 ? 'down' : 'up';
    return 'About $amount kg $direction from today by ${projection.goalDateLabel}.';
  }

  String _generationStatusLine(GenerationStatus status) {
    if (status.hasFailed) return 'Plan setup hit a snag.';
    if (status.isDone) return 'Your first week is ready.';

    final message = status.primaryMessage.toLowerCase();
    if (message.contains('calorie target')) {
      return 'Setting calories you can actually sustain';
    }
    if (message.contains('meal')) {
      return 'Building meals around foods you like';
    }
    if (message.contains('equipment')) {
      return 'Matching training to the setup you have';
    }
    if (message.contains('split')) {
      return 'Building workouts around your real week';
    }
    if (message.contains('workout')) {
      return 'Matching training to your goal';
    }
    if (message.contains('first week')) return 'Locking in your first week';
    if (message.contains('reviewing')) return 'Reading your starting point';

    return 'Shaping your plan around your answers';
  }

  IconData _generationStatusIcon(GenerationStatus status) {
    if (status.hasFailed) return LucideIcons.triangle_alert;
    if (status.isDone) return LucideIcons.badge_check;

    final message = status.primaryMessage.toLowerCase();
    if (message.contains('meal') || message.contains('calorie')) {
      return LucideIcons.utensils_crossed;
    }
    if (message.contains('equipment') ||
        message.contains('split') ||
        message.contains('workout')) {
      return LucideIcons.dumbbell;
    }

    return LucideIcons.sparkles;
  }

  Widget _buildFinalRevealScreen() {
    final projection = _submittedProjection ?? _projection;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.badge_check,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your plan is ready',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 24),
              _buildRevealStat('Target pace', projection.paceLabel),
              const SizedBox(height: 12),
              _buildRevealStat(
                'Projected target date',
                projection.goalDateLabel,
              ),
              const SizedBox(height: 12),
              _buildRevealStat(
                'Daily calories',
                '${projection.dailyCalories} kcal',
              ),
              const SizedBox(height: 12),
              _buildRevealStat('Training', '$_daysPerWeek days per week'),
              const SizedBox(height: 12),
              _buildRevealStat('Built around', _builtAroundSummary()),
              const Spacer(),
              _buildPrimaryButton(
                label: 'SEE TODAY\'S PLAN',
                onTap: _completeRevealAndOpenApp,
                icon: LucideIcons.arrow_right,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('pending_plan_reveal', false);
                    if (!mounted) return;
                    setState(() {
                      _showFinalReveal = false;
                      _isGenerating = false;
                    });
                    _goToPage(5);
                  },
                  child: Text(
                    'Adjust my pace',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealStat(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPage() {
    return OnboardingHeroPage(onNext: _nextPage, onSignOut: _signOut);
  }

  Widget _buildBlockerPage() {
    final blockers = [
      (
        'consistency',
        'Consistency slips',
        'You start strong, then routine fades',
      ),
      (
        'food_choices',
        'Food choices get messy',
        'Meals drift when life gets busy',
      ),
      (
        'busy_schedule',
        'Your schedule gets in the way',
        'You need something that fits real days',
      ),
      (
        'lack_of_structure',
        'You need more structure',
        'You do better when the next step is clear',
      ),
      (
        'low_motivation',
        'Motivation drops',
        'You need progress to feel visible early',
      ),
    ];
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What usually trips you up?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 24),
                ...blockers.map((blocker) {
                  final isSelected = _primaryBlocker == blocker.$1;
                  return _buildSelectionCard(
                    title: blocker.$2,
                    subtitle: blocker.$3,
                    isSelected: isSelected,
                    onTap: () => setState(() => _primaryBlocker = blocker.$1),
                  );
                }),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _primaryBlocker.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(_primaryBlocker),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.sparkles,
                                color: AppTheme.primary,
                                size: 13,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  switch (_primaryBlocker) {
                                    'consistency' =>
                                      'We\'ll build habits, not willpower.',
                                    'food_choices' =>
                                      'Every meal will be food you actually want.',
                                    'busy_schedule' =>
                                      'Workouts short enough for real days.',
                                    'lack_of_structure' =>
                                      'You\'ll always know exactly what\'s next.',
                                    'low_motivation' =>
                                      'We\'ll make your first wins happen in week 1.',
                                    _ => 'Buddy adapts to what holds you back.',
                                  },
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(
            label: 'SOLVE THIS FOR ME',
            onTap: _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthSyncPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync your health data.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 22),
                _buildHealthDataCard(),
                const SizedBox(height: 14),
                _buildHealthBenefitsCard(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: Column(
            children: [
              _buildPrimaryButton(
                label: _isConnecting
                    ? 'CONNECTING HEALTH DATA'
                    : _isConnected
                    ? 'BUILD MY PLAN'
                    : 'CONNECT HEALTH DATA',
                onTap: _isConnecting
                    ? () {}
                    : _isConnected
                    ? _finalize
                    : _connectHealthData,
                icon: _isConnected ? LucideIcons.sparkles : LucideIcons.link,
              ),
              const SizedBox(height: 10),
              Text(
                _isConnected
                    ? 'Buddy will use this data the next time it updates your plan.'
                    : 'Takes less than a minute. You can change this later.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 11,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _finalize,
                  child: Text(
                    'I\'ll do this later',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title: $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
    );
  }

  Widget _buildHealthDataCard() {
    final rows = [
      (
        LucideIcons.footprints,
        'Daily steps',
        '${(_stepGoal / 1000).toStringAsFixed(0)}k goal',
      ),
      (
        LucideIcons.moon_star,
        'Sleep tracking',
        '${_sleepTarget.toStringAsFixed(1)}h target',
      ),
      (
        LucideIcons.activity,
        'Calorie burn',
        '~${max(180, (_weight * 4.2).round())} kcal',
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Text(
                  'WHAT GETS SYNCED',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isConnected) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      'Apple Health',
                      style: GoogleFonts.plusJakartaSans(
                        color: _isConnected
                            ? AppTheme.success
                            : AppTheme.textSageMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderDark, height: 1),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(rows[i].$1, color: AppTheme.primary, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].$2,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rows[i].$3,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              const Divider(
                color: AppTheme.borderDark,
                height: 1,
                indent: 18,
                endIndent: 18,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthBenefitsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthBenefitRow(LucideIcons.scale, 'Less manual logging'),
          const SizedBox(height: 14),
          _buildHealthBenefitRow(
            LucideIcons.footprints,
            'Targets grounded in real activity',
          ),
          const SizedBox(height: 14),
          _buildHealthBenefitRow(
            LucideIcons.moon_star,
            'Recovery context built into your plan',
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderDark, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                LucideIcons.shield_check,
                color: AppTheme.primary,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Private and reversible — Buddy only reads, never writes to Health.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBenefitRow(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  double _projectionResultWeight(OnboardingProjection projection) {
    if (_showTargetWeight) return _targetWeight;
    // For goals without a target weight page, use 0.5 kg/week × 12 weeks
    // to match the Aha Moment default projection
    return switch (_fitnessGoal) {
      'recomp' => max(30.0, _weight - 6.0),
      'muscle_gain' => _weight + 3.0,
      'maintain' => _weight,
      'endurance' => _weight,
      _ => max(30.0, _weight - 6.0),
    };
  }

  List<double> _projectionWeightSeries(double targetWeight) {
    const points = 7;
    final change = targetWeight - _weight;
    return List.generate(points, (index) {
      final t = index / (points - 1);
      final eased = switch (_fitnessGoal) {
        'fat_loss' => Curves.easeInOutCubic.transform(t),
        'muscle_gain' => Curves.easeOutCubic.transform(t),
        'recomp' => Curves.easeInOut.transform(t),
        'maintain' || 'endurance' => Curves.linear.transform(t),
        _ => Curves.easeInOut.transform(t),
      };
      return double.parse((_weight + (change * eased)).toStringAsFixed(1));
    });
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
                  'What\'s your #1 goal right now?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
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
                      onTap: () {
                        if (_isNavigating) return;
                        setState(() {
                          _fitnessGoal = g.$1;
                          _isNavigating = true;
                        });
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            _nextPage();
                            setState(() => _isNavigating = false);
                          }
                        });
                      },
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
                                    color: AppTheme.oledBlack,
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
          child: _buildPrimaryButton(
            label: 'THIS IS MY GOAL',
            onTap: _nextPage,
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
                  'Tell us about yourself.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
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
                  'BIRTH YEAR',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInlineYearPicker(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(
            label: 'USE THESE DETAILS',
            onTap: _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableImageCard({
    required String assetPath,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    double height = 160,
    double borderRadius = 18,
    EdgeInsets imagePadding = const EdgeInsets.fromLTRB(8, 8, 8, 36),
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: subtitle == null ? title : '$title: $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.cardDark,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderDark,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius - 1),
                    child: ColoredBox(
                      color: AppTheme.oledBlack,
                      child: Padding(
                        padding: imagePadding,
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, _) => Center(
                            child: Icon(
                              LucideIcons.user,
                              color: AppTheme.textSageMuted.withValues(
                                alpha: 0.4,
                              ),
                              size: subtitle == null ? 36 : 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius - 1),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.58, 1],
                          colors: [
                            AppTheme.transparent,
                            AppTheme.transparent,
                            AppTheme.oledBlack.withValues(alpha: 0.94),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 40,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: subtitle == null ? 15 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted.withValues(
                              alpha: 0.9,
                            ),
                            fontSize: 9,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                        color: AppTheme.oledBlack,
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

  Widget _buildSexImageCard(String label) {
    final isSelected = _sex == label;
    final imgKey = label.toLowerCase();
    return _buildSelectableImageCard(
      assetPath: 'assets/images/body_shapes/${imgKey}_lean.png',
      title: label,
      isSelected: isSelected,
      onTap: () => setState(() => _sex = label),
      height: 158,
      imagePadding: const EdgeInsets.fromLTRB(10, 8, 10, 34),
    );
  }

  Widget _buildInlineYearPicker() {
    final now = DateTime.now();
    const minYear = 1940;
    final maxYear = now.year - 10;
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final currentYear = _birthDate.year.clamp(minYear, maxYear);
    final initialIndex = years.indexOf(currentYear).clamp(0, years.length - 1);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          CupertinoPicker(
            backgroundColor: AppTheme.transparent,
            itemExtent: 52,
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            onSelectedItemChanged: (i) {
              setState(() {
                _birthDate = DateTime(
                  years[i],
                  _birthDate.month,
                  _birthDate.day,
                );
              });
            },
            children: years
                .map(
                  (y) => Center(
                    child: Text(
                      y.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── New pages: Height, Weight, BodyNow, BodyTarget, AhaMoment, TargetWeight, Pace, Activity, Experience, DietType, Foods, SocialProof ───

  Widget _buildHeightPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final heights = List.generate(151, (i) => (100 + i).toDouble());
    final initialIndex = (_height.round() - 100).clamp(0, 150);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              'You\'re ${_height.round()} cm tall.',
              key: ValueKey(_height.round()),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                CupertinoPicker(
                  backgroundColor: AppTheme.transparent,
                  itemExtent: 52,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  onSelectedItemChanged: (i) {
                    setState(() => _height = heights[i]);
                  },
                  children: heights
                      .map(
                        (h) => Center(
                          child: Text(
                            '${h.round()} cm',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 22,
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
          const Spacer(),
          _buildPrimaryButton(label: 'THAT\'S MY HEIGHT', onTap: _nextPage),
        ],
      ),
    );
  }

  Widget _buildWeightPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final weights = List.generate(341, (i) => 30.0 + (i * 0.5));
    final initialIndex = ((_weight - 30.0) / 0.5).round().clamp(0, 340);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              'You weigh ${_weight.toStringAsFixed(1)} kg.',
              key: ValueKey(_weight),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                CupertinoPicker(
                  backgroundColor: AppTheme.transparent,
                  itemExtent: 52,
                  scrollController: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  onSelectedItemChanged: (i) {
                    setState(() {
                      _weight = weights[i];
                      _waterTargetMl = ((_weight * 33) / 250).round() * 250.0;
                    });
                  },
                  children: weights
                      .map(
                        (w) => Center(
                          child: Text(
                            '${w.toStringAsFixed(1)} kg',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 22,
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
          const Spacer(),
          _buildPrimaryButton(label: 'THAT\'S MY WEIGHT', onTap: _nextPage),
        ],
      ),
    );
  }

  Widget _buildBodyNowPage() {
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
                  'Pick the build closest to you.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 24),
                _buildBodyShapeGrid(
                  label: '',
                  selectedValue: _currentBodyShape,
                  onSelect: (v) {
                    setState(() => _currentBodyShape = v);
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (mounted) _nextPage();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyTargetPage() {
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
                  'What are you working toward?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 24),
                _buildBodyShapeGrid(
                  label: '',
                  selectedValue: _goalBodyShape,
                  onSelect: (v) {
                    setState(() => _goalBodyShape = v);
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (mounted) _nextPage();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAhaMomentPage() {
    // At the Aha Moment step the user hasn't picked a target weight or pace yet.
    // Use a fixed 0.5 kg/week over a 12-week window so the numbers are honest.
    const weeklyRate = 0.5;
    const weeks = 12;
    final goal = _fitnessGoal.isEmpty ? 'fat_loss' : _fitnessGoal;
    // Always show a 0.5 kg/week loss projection as the motivating default.
    // The user hasn't fully set their goal yet — this gets recalculated later.
    final projectedTarget = _weight - (weeklyRate * weeks);
    // Pass goalWeightKg: null so _calculateGoalDate uses the 12-week fallback.
    final projection = buildOnboardingProjection(
      goal: goal,
      sex: _sex.toLowerCase(),
      birthDate: _birthDate,
      weightKg: _weight,
      heightCm: _height,
      activityLevel: _activityLevel.isEmpty
          ? 'moderately_active'
          : _activityLevel,
      goalPace: 'steady',
      goalWeightKg: null,
    );
    return OnboardingAhaMomentPage(
      projection: projection,
      currentWeight: _weight,
      targetWeight: projectedTarget,
      fitnessGoal:
          'fat_loss', // always use fat_loss easing/heading for default projection
      onNext: _nextPage,
    );
  }

  Widget _buildTargetWeightPage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final diff = (_targetWeight - _weight).abs();
    final direction = _targetWeight < _weight ? 'down' : 'up';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Where do you want to get to?',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              '${_targetWeight.toStringAsFixed(1)} kg',
              key: ValueKey(_targetWeight),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              diff < 0.1
                  ? 'Same as your current weight.'
                  : 'That\'s ${diff.toStringAsFixed(1)} kg $direction from today.',
              key: ValueKey(_targetWeight),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.borderDark,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _targetWeight,
              min: 30,
              max: 200,
              divisions: 340,
              onChanged: (v) =>
                  setState(() => _targetWeight = (v * 2).round() / 2.0),
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(label: 'SET MY TARGET', onTap: _nextPage),
        ],
      ),
    );
  }

  Widget _buildPacePage() {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final paceOptions = switch (_fitnessGoal) {
      'fat_loss' => [
        ('relaxed', '🐢', 'Easy', '~0.25 kg / week'),
        ('steady', '🐇', 'Steady', '~0.5 kg / week'),
        ('aggressive', '🐆', 'Fast', '~0.75 kg / week'),
      ],
      'muscle_gain' => [
        ('relaxed', '🐢', 'Easy', '~0.15 kg / week'),
        ('steady', '🐇', 'Steady', '~0.25 kg / week'),
        ('aggressive', '🐆', 'Fast', '~0.4 kg / week'),
      ],
      _ => [
        ('relaxed', '🐢', 'Relaxed', 'Lower pressure'),
        ('steady', '🐇', 'Steady', 'Balanced push'),
        ('aggressive', '🐆', 'Fast', 'Higher pressure'),
      ],
    };
    final livePace = _goalPace.isEmpty ? 'steady' : _goalPace;
    final liveProjection = buildOnboardingProjection(
      goal: _fitnessGoal.isEmpty ? 'fat_loss' : _fitnessGoal,
      sex: _sex.toLowerCase(),
      birthDate: _birthDate,
      weightKg: _weight,
      heightCm: _height,
      activityLevel: _activityLevel.isEmpty
          ? 'moderately_active'
          : _activityLevel,
      goalPace: livePace,
      goalWeightKg: _showTargetWeight ? _targetWeight : null,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'Pick your pace.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: paceOptions.map((pace) {
              final isSelected = _goalPace == pace.$1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: pace.$1 != 'aggressive' ? 10 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _goalPace = pace.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.14)
                            : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.borderDark,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(pace.$2, style: const TextStyle(fontSize: 30)),
                          const SizedBox(height: 8),
                          Text(
                            pace.$3,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.textCream
                                  : AppTheme.textSageMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pace.$4,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted,
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _goalPace.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(_goalPace),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar_days,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'At this pace you\'d hit your target by ${liveProjection.goalDateLabel}.',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const Spacer(),
          _buildPrimaryButton(label: 'THIS IS MY PACE', onTap: _nextPage),
        ],
      ),
    );
  }

  Widget _buildSocialProofPage() {
    return OnboardingSocialProofPage(onNext: _nextPage);
  }

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
                  'How active is your typical week?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 24),
                ...levels.map((l) {
                  final isSelected = _activityLevel == l.$1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activityLevel = l.$1);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) _nextPage();
                      });
                    },
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
                                color: AppTheme.oledBlack,
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
      ],
    );
  }

  Widget _buildExperiencePage() {
    final levels = [
      ('beginner', 'Just getting started', '0–1 year'),
      ('intermediate', 'I know the basics', '1–3 years'),
      ('advanced', 'I\'ve been at it a while', '3+ years'),
    ];
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
                  'How long have you been training?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: levels.map((e) {
                    final isSelected = _experienceLevel == e.$1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: e.$1 != 'advanced' ? 10 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _experienceLevel = e.$1);
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) _nextPage();
                              },
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 12,
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
                            child: Column(
                              children: [
                                Text(
                                  e.$2,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isSelected
                                        ? AppTheme.textCream
                                        : AppTheme.textSageMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  e.$3,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textSageMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.check,
                                      color: AppTheme.oledBlack,
                                      size: 12,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDietTypePage() {
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
                  'How do you eat?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
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
                  return GestureDetector(
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
                                color: AppTheme.oledBlack,
                                size: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
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
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  'WHO\'S COOKING?',
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
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(
            label: 'THAT\'S HOW I EAT',
            onTap: _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodsPage() {
    final foods = _dietFoods[_dietType] ?? _fallbackFoods[_dietType] ?? [];
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
                  'Pick foods you actually enjoy.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 28),
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
                        return GestureDetector(
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
                      return GestureDetector(
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
                          child: Text(
                            f,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.oledBlack
                                  : AppTheme.textSageMuted,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
          child: _buildPrimaryButton(
            label: 'THESE ARE MY FOODS',
            onTap: _nextPage,
          ),
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

    // Beginners get "keep it simple" silently — no choice shown.
    final showSupersets = _experienceLevel != 'beginner';

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
                  'Build your training setup.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
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
                  padding: EdgeInsets.zero,
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
                                if (opt.imagePath != null)
                                  Image.asset(
                                    opt.imagePath!,
                                    width: 26,
                                    height: 26,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.textSageMuted,
                                    colorBlendMode: BlendMode.srcIn,
                                  )
                                else
                                  Icon(
                                    opt.fallbackIcon,
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
                if (showSupersets) ...[
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
                  const SizedBox(height: 4),
                  Text(
                    'More efficient, more intense, less time.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
          child: _buildPrimaryButton(
            label: 'BUILD MY WORKOUTS',
            onTap: _nextPage,
            icon: LucideIcons.arrow_right,
          ),
        ),
      ],
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
            color: AppTheme.actionSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.actionForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: AppTheme.actionForeground, size: 18),
                  ],
                ),
              ),
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
                child: _buildSelectableImageCard(
                  assetPath:
                      'assets/images/body_shapes/${_sex.toLowerCase()}_${s.$1}.png',
                  title: s.$2,
                  subtitle: _bfLabel(s.$1),
                  isSelected: isSelected,
                  onTap: () => onSelect(s.$1),
                  height: 138,
                  borderRadius: 14,
                  imagePadding: const EdgeInsets.fromLTRB(6, 8, 6, 38),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Fallback food lists ──────────────────────────────────────────────────

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
}

class _ProjectionTrendPainter extends CustomPainter {
  final List<double> points;
  final double progress;
  final Color lineColor;
  final Color gridColor;

  const _ProjectionTrendPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftInset = 6.0;
    const rightInset = 6.0;
    const topInset = 14.0;
    const bottomInset = 20.0;
    final chartRect = Rect.fromLTWH(
      leftInset,
      topInset,
      size.width - leftInset - rightInset,
      size.height - topInset - bottomInset,
    );

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = chartRect.top + (chartRect.height * (i / 2));
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    if (points.length == 1) {
      final y = chartRect.center.dy;
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        linePaint,
      );
      return;
    }

    final minValue = points.reduce(min);
    final maxValue = points.reduce(max);
    final spread = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : (maxValue - minValue);

    final plotPoints = List<Offset>.generate(points.length, (index) {
      final x =
          chartRect.left + (chartRect.width * (index / (points.length - 1)));
      final normalized = (points[index] - minValue) / spread;
      final y = chartRect.bottom - (normalized * chartRect.height);
      return Offset(x, y);
    });

    final fullPath = _buildSmoothPath(plotPoints);
    final fillPath = Path.from(fullPath)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();

    final baseLinePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fullPath, baseLinePaint);

    final revealRect = Rect.fromLTWH(
      0,
      0,
      size.width * progress.clamp(0, 1),
      size.height,
    );
    canvas.save();
    canvas.clipRect(revealRect);
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.22),
            lineColor.withValues(alpha: 0.04),
          ],
        ).createShader(chartRect),
    );
    canvas.drawPath(
      fullPath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    final activePoint = _interpolatePoint(plotPoints, progress.clamp(0, 1));
    canvas.drawCircle(
      activePoint,
      10,
      Paint()..color = lineColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(activePoint, 4.5, Paint()..color = lineColor);
    canvas.drawCircle(
      activePoint,
      4.5,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.oledBlack,
    );
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midPoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midPoint.dx,
        midPoint.dy,
      );
      if (i == points.length - 1) {
        path.quadraticBezierTo(current.dx, current.dy, current.dx, current.dy);
      }
    }
    return path;
  }

  Offset _interpolatePoint(List<Offset> points, double progress) {
    if (points.length == 1) return points.first;
    final scaled = progress * (points.length - 1);
    final lower = scaled.floor().clamp(0, points.length - 1);
    final upper = scaled.ceil().clamp(0, points.length - 1);
    if (lower == upper) return points[lower];
    final localT = scaled - lower;
    return Offset.lerp(points[lower], points[upper], localT) ?? points[upper];
  }

  @override
  bool shouldRepaint(covariant _ProjectionTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
