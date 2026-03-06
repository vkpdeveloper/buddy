import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/pr.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/pages/active_workout_page.dart';
import 'package:buddy/pages/workout_sessions_page.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/providers/pr_provider.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/widgets/app_empty_state.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/exercise_library_sheet.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _TodayWorkoutState { none, inProgress, completed }

class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  int? _activePlanId;
  Map<String, dynamic>? _planData;
  bool _isLoading = true;
  int _selectedDayIndex = 0;
  bool _hasRestoredDaySelection = false;
  final Map<int, _TodayWorkoutState> _todaySessionStateByDayId = {};
  Timer? _stretchTimer;
  int _stretchSecondsLeft = 0;
  int _todayHydrationMl = 0;
  bool _isHydrationLogging = false;
  bool _regenLoading = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadTodayHydration();
  }

  @override
  void dispose() {
    _stretchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.listWorkoutPlans();
      final plans = (res['data'] as List?) ?? [];
      final active = plans
          .where((p) => p['isActive'] == true || p['is_active'] == 1)
          .toList();
      if (active.isEmpty && plans.isNotEmpty) {
        _activePlanId = plans.last['id'];
      } else if (active.isNotEmpty) {
        _activePlanId = active.first['id'];
      }
      if (_activePlanId != null) await _loadPlanDetail(_activePlanId!);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPlanDetail(int id) async {
    try {
      final res = await ApiClient.getWorkoutPlan(id);
      final days =
          ((res['data'] as Map<String, dynamic>?)?['days'] as List?) ??
          const [];
      final nowDayIndex = DateTime.now().weekday - 1;
      final fallbackIndex = days.isEmpty
          ? 0
          : nowDayIndex.clamp(0, days.length - 1);
      final shouldRestoreFromPrefs =
          !_hasRestoredDaySelection || _activePlanId != id;
      final restoredIndex = !shouldRestoreFromPrefs
          ? _selectedDayIndex
                .clamp(0, (days.isEmpty ? 0 : days.length - 1))
                .toInt()
          : await _loadSavedDayIndex(
              planId: id,
              maxLength: days.length,
              fallbackIndex: fallbackIndex,
            );
      setState(() {
        _planData = res['data'];
        _activePlanId = id;
        _selectedDayIndex = restoredIndex;
        _hasRestoredDaySelection = true;
      });
      await _refreshTodaySessionStatus();
    } catch (_) {}
  }

  Future<int> _loadSavedDayIndex({
    required int planId,
    required int maxLength,
    required int fallbackIndex,
  }) async {
    if (maxLength <= 0) return 0;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('workout_selected_day_$planId');
    if (stored == null) return fallbackIndex;
    return stored.clamp(0, maxLength - 1).toInt();
  }

  Future<void> _persistSelectedDayIndex(int index) async {
    final planId = _activePlanId;
    if (planId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workout_selected_day_$planId', index);
  }

  void _onSelectDay(int index) {
    setState(() => _selectedDayIndex = index);
    _persistSelectedDayIndex(index);
  }

  Future<void> _refreshTodaySessionStatus() async {
    final planId = _activePlanId;
    final days = (_planData?['days'] as List?) ?? [];
    if (planId == null || days.isEmpty) return;

    final todayDayNumber = DateTime.now().weekday;
    final todayDay = days.cast<Map>().firstWhere(
      (raw) => (raw['dayNumber'] ?? raw['day_number']) == todayDayNumber,
      orElse: () => <String, dynamic>{},
    );
    if (todayDay.isEmpty) return;

    final dayId = (todayDay['id'] as num?)?.toInt();
    if (dayId == null) return;

    try {
      final res = await ApiClient.getTodayWorkoutSessionStatus(
        planId,
        dayId,
        date: _todayDate,
      );
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? 'none').toString();
      if (!mounted) return;
      setState(() {
        _todaySessionStateByDayId[dayId] = switch (status) {
          'completed' => _TodayWorkoutState.completed,
          'in_progress' => _TodayWorkoutState.inProgress,
          _ => _TodayWorkoutState.none,
        };
      });
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(weeklyWorkoutSummaryProvider);
    } catch (_) {}
  }

  Future<void> _loadTodayHydration() async {
    try {
      final res = await ApiClient.getDailyLog(_todayDate);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _todayHydrationMl = (data['waterMl'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _incrementHydration() async {
    if (_isHydrationLogging) return;
    setState(() => _isHydrationLogging = true);
    try {
      final res = await ApiClient.incrementHydration(_todayDate, amountMl: 250);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      final updated =
          (data['waterMl'] as num?)?.toInt() ?? _todayHydrationMl + 250;
      setState(() => _todayHydrationMl = updated);
      ref.invalidate(homeDashboardProvider);
      AppSnackbar.success(
        context,
        '+250 ml logged ($_todayHydrationMl ml today)',
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not log hydration right now.');
    } finally {
      if (mounted) setState(() => _isHydrationLogging = false);
    }
  }

  void _startStretchTimer({int minutes = 10}) {
    _stretchTimer?.cancel();
    setState(() => _stretchSecondsLeft = minutes * 60);
    _stretchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_stretchSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _stretchSecondsLeft = 0);
        AppSnackbar.success(
          context,
          'Stretch timer complete. Nice recovery block.',
        );
        return;
      }
      setState(() => _stretchSecondsLeft -= 1);
    });
  }

  Future<void> _showRegenerateDialog() async {
    final planId = _activePlanId;
    if (planId == null) return;
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Adjust Your Plan',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textCream,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Got any injuries or things you want to avoid? Tell us and we\'ll rework your workouts around them.',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. bad knee, no overhead pressing, keep it short...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: AppTheme.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
              ),
            ),
          ],
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
              'Update My Plan',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _regenLoading = true);
    try {
      await ApiClient.regenerateWorkoutPlan(
        planId: planId,
        constraints: ctrl.text.trim(),
      );
      if (!mounted) return;
      await _loadPlans();
      ref.invalidate(prMapProvider);
      AppSnackbar.success(context, 'Plan updated!');
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Couldn\'t update your plan. Give it another try.');
    } finally {
      if (mounted) setState(() => _regenLoading = false);
    }
  }

  Future<void> _deleteExercise(Map<String, dynamic> exercise) async {
    final exerciseName = (exercise['name'] ?? 'this exercise').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(
          'Remove Exercise?',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textCream,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Remove $exerciseName from this day? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textSageMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Remove',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.deleteWorkoutExercise(
        (exercise['id'] as num?)?.toInt() ?? 0,
      );
      if (!mounted) return;
      await _loadPlanDetail(_activePlanId!);
      if (!mounted) return;
      AppSnackbar.success(context, 'Exercise removed.');
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not remove exercise. Try again.');
    }
  }

  Future<void> _replaceExercise(
    Map<String, dynamic> day,
    Map<String, dynamic> exercise,
  ) async {
    final exerciseId = (exercise['id'] as num?)?.toInt() ?? 0;
    final dayId = (day['id'] as num?)?.toInt() ?? 0;
    if (exerciseId == 0 || dayId == 0 || !mounted) return;
    await showExerciseLibrarySheet(
      context,
      dayId: dayId,
      replaceExerciseId: exerciseId,
      onAdded: () {
        _loadPlanDetail(_activePlanId!);
        ref.invalidate(prMapProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (prev?.workout != 'done' && next.workout == 'done') {
        _loadPlans();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Column(
        children: [
          _buildHeader(),
          const GeneratingBanner(watchType: 'workout'),
          if (_isLoading)
            Expanded(child: _buildSkeleton())
          else if (_planData == null)
            _buildEmptyState()
          else
            Expanded(child: _buildPlanContent()),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day tabs skeleton
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                7,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShimmerBox(width: 48, height: 36, borderRadius: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Exercise card skeletons
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 22, height: 22, borderRadius: 11),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(
                                  width: double.infinity,
                                  height: 14,
                                  borderRadius: 5,
                                ),
                                const SizedBox(height: 6),
                                ShimmerBox(
                                  width: 70,
                                  height: 9,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ShimmerBox(
                        width: double.infinity,
                        height: 36,
                        borderRadius: 11,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 16,
        24,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRAINING',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Workout Plan',
                  style: GoogleFonts.sora(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Streak chip
          Consumer(
            builder: (_, ref, _) {
              final streak =
                  ref.watch(progressProvider).asData?.value.currentStreak ?? 0;
              if (streak < 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.xpGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.xpGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        color: AppTheme.xpGold,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.xpGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final genStatus = ref.watch(generationStatusProvider);
    final isGenerating =
        genStatus.workout == 'pending' || genStatus.workout == 'generating';

    return Expanded(
      child: AppEmptyState(
        icon: LucideIcons.dumbbell,
        title: isGenerating ? 'Building your plan…' : 'No workout plan yet',
        subtitle: isGenerating
            ? 'We\'re putting together a plan around your goals and equipment. It\'ll be ready in a moment.'
            : 'Your workout plan will appear here once it\'s been generated.',
      ),
    );
  }

  Widget _buildPlanContent() {
    final days = (_planData?['days'] as List?) ?? [];
    final planTitle = _planData?['title'] ?? 'Workout Plan';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan title + cycle badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  planTitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showRegenerateDialog,
                child: _regenLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: const Icon(
                          LucideIcons.refresh_cw,
                          color: AppTheme.textSageMuted,
                          size: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkoutSessionsPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.history,
                        color: AppTheme.textSageMuted,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SESSIONS',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Day tabs
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: days.length,
            itemBuilder: (ctx, i) {
              final day = days[i];
              final label =
                  day['dayLabel'] ?? day['day_label'] ?? 'Day ${i + 1}';
              final isRest =
                  day['isRestDay'] == true || day['is_rest_day'] == 1;
              final isSelected = _selectedDayIndex == i;
              const weekdays = [
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
                'SUN',
              ];
              final weekday = i < 7 ? weekdays[i] : '';
              return GestureDetector(
                onTap: () => _onSelectDay(i),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isRest
                                  ? AppTheme.textSageMuted.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppTheme.primary)
                            : AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (isRest
                                    ? AppTheme.textSageMuted
                                    : AppTheme.primary)
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekday,
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? (isRest
                                        ? AppTheme.textSageMuted
                                        : AppTheme.backgroundDark)
                                  : AppTheme.textSageMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label.toString().toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? (isRest
                                        ? AppTheme.textSageMuted
                                        : AppTheme.backgroundDark)
                                  : AppTheme.textSageMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Exercise list
        Expanded(child: _buildDayExercises(days[_selectedDayIndex])),
      ],
    );
  }

  Widget _buildDayExercises(Map<String, dynamic> day) {
    final isRest = day['isRestDay'] == true || day['is_rest_day'] == 1;
    final exercises = (day['exercises'] as List?) ?? [];
    final dayLabel = day['dayLabel'] ?? day['day_label'] ?? 'Day';
    final dayId = day['id'] as int?;
    final planId = _activePlanId;
    final dayNumber =
        ((day['dayNumber'] ?? day['day_number']) as num?)?.toInt() ??
        (_selectedDayIndex + 1);
    final estimatedDurationSeconds =
        ((day['estimatedDurationSeconds'] ?? day['estimated_duration_seconds'])
                as num?)
            ?.toInt() ??
        _estimateDurationFromExercises(exercises);
    final isTodayPlanDay = dayNumber == DateTime.now().weekday;
    final sessionState = dayId == null
        ? _TodayWorkoutState.none
        : (_todaySessionStateByDayId[dayId] ?? _TodayWorkoutState.none);

    if (isRest) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.textSageMuted.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.moon,
                      color: AppTheme.textSageMuted,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rest Day',
                    style: GoogleFonts.sora(
                      color: AppTheme.textCream,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recovery is where the gains happen.\nLet your muscles rebuild and come back stronger.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildRestActionCard(
              icon: LucideIcons.activity,
              iconColor: AppTheme.primary,
              title: 'Stretch Flow Timer',
              subtitle: _stretchSecondsLeft > 0
                  ? 'Remaining ${_formatCountdown(_stretchSecondsLeft)}'
                  : 'Start a guided 10-minute stretch block.',
              cta: _stretchSecondsLeft > 0 ? 'Restart 10m' : 'Start 10m',
              onTap: () => _startStretchTimer(minutes: 10),
            ),
            const SizedBox(height: 10),
            _buildRestActionCard(
              icon: LucideIcons.droplets,
              iconColor: AppTheme.info,
              title: 'Hydration Quick Log',
              subtitle: 'Today: $_todayHydrationMl ml logged',
              cta: _isHydrationLogging ? 'Logging...' : '+250 ml',
              onTap: _isHydrationLogging ? null : _incrementHydration,
            ),
            const SizedBox(height: 20),
            Text(
              'TODAY\'S FOCUS',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            ..._recoveryTips.map(
              (tip) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: tip.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip.icon, color: tip.color, size: 17),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.subtitle,
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
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      estimatedDurationSeconds > 0
                          ? 'About ${_formatDurationCompact(estimatedDurationSeconds)} to complete'
                          : 'Estimated workout time unavailable',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (planId != null && dayId != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: sessionState == _TodayWorkoutState.completed
                          ? null
                          : () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ActiveWorkoutPage(
                                    dayLabel: dayLabel.toString(),
                                    exercises: exercises,
                                    planId: planId,
                                    dayId: dayId,
                                  ),
                                ),
                              ).then((_) async {
                                await _refreshTodaySessionStatus();
                                ref.invalidate(homeDashboardProvider);
                                ref.invalidate(weeklyWorkoutSummaryProvider);
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isTodayPlanDay &&
                                  sessionState == _TodayWorkoutState.completed
                              ? null
                              : LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.accent],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color:
                              isTodayPlanDay &&
                                  sessionState == _TodayWorkoutState.completed
                              ? AppTheme.cardDark
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              isTodayPlanDay &&
                                  sessionState == _TodayWorkoutState.completed
                              ? Border.all(color: AppTheme.borderDark)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isTodayPlanDay &&
                                      sessionState ==
                                          _TodayWorkoutState.completed
                                  ? LucideIcons.check
                                  : LucideIcons.play,
                              color:
                                  isTodayPlanDay &&
                                      sessionState ==
                                          _TodayWorkoutState.completed
                                  ? AppTheme.primary
                                  : AppTheme.backgroundDark,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isTodayPlanDay &&
                                      sessionState ==
                                          _TodayWorkoutState.completed
                                  ? 'COMPLETED'
                                  : isTodayPlanDay &&
                                        sessionState ==
                                            _TodayWorkoutState.inProgress
                                  ? 'CONTINUE'
                                  : 'START',
                              style: GoogleFonts.plusJakartaSans(
                                color:
                                    isTodayPlanDay &&
                                        sessionState ==
                                            _TodayWorkoutState.completed
                                    ? AppTheme.primary
                                    : AppTheme.backgroundDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
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
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final prMap = ref.watch(prMapProvider).asData?.value ?? {};
              return _buildExerciseItem(
                exercises: exercises,
                day: day,
                index: i,
                prMap: prMap,
              );
            }, childCount: exercises.length),
          ),
        ),
        if (dayId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: GestureDetector(
                onTap: () => showExerciseLibrarySheet(
                  context,
                  dayId: dayId,
                  onAdded: () {
                    _loadPlanDetail(_activePlanId!);
                    ref.invalidate(prMapProvider);
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.plus,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ADD FROM LIBRARY',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 92),
        ),
      ],
    );
  }

  Widget _buildExerciseItem({
    required List<dynamic> exercises,
    required Map<String, dynamic> day,
    required int index,
    required Map<String, PersonalRecord> prMap,
  }) {
    final ex = exercises[index] as Map<String, dynamic>;
    final groupId = ex['supersetGroupId'] ?? ex['superset_group_id'];
    final supersetOrder =
        (ex['supersetOrder'] ?? ex['superset_order'] as num?)?.toInt() ?? 0;

    // Only render superset pair card for the first exercise in the pair (order 0)
    if (groupId != null && supersetOrder != 0) {
      return const SizedBox.shrink();
    }

    if (groupId != null) {
      // Find partner
      final partner = exercises.whereType<Map<String, dynamic>>().firstWhere(
        (e) =>
            (e['supersetGroupId'] ?? e['superset_group_id']) == groupId &&
            ((e['supersetOrder'] ?? e['superset_order'] as num?)?.toInt() ??
                    0) ==
                1,
        orElse: () => <String, dynamic>{},
      );

      if (partner.isNotEmpty) {
        final exName = (ex['name'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
            .trim();
        final partnerName = (partner['name'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
            .trim();
        return _SupersetPairCard(
          exerciseA: ex,
          exerciseB: partner,
          indexA: index,
          indexB: exercises.indexOf(partner),
          prA: prMap[exName],
          prB: prMap[partnerName],
          onUpdate: () => _loadPlanDetail(_activePlanId!),
          onReplaceA: () =>
              _replaceExercise(day, Map<String, dynamic>.from(ex)),
          onReplaceB: () =>
              _replaceExercise(day, Map<String, dynamic>.from(partner)),
        );
      }
    }

    final normalized = (ex['name'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
    return _ExerciseCard(
      exercise: ex,
      index: index,
      pr: prMap[normalized],
      onUpdate: () => _loadPlanDetail(_activePlanId!),
      onReplace: () => _replaceExercise(day, Map<String, dynamic>.from(ex)),
      onDelete: () => _deleteExercise(Map<String, dynamic>.from(ex)),
    );
  }

  int _estimateDurationFromExercises(List<dynamic> exercises) {
    if (exercises.isEmpty) return 0;
    var total = 0;
    for (final raw in exercises) {
      if (raw is! Map) continue;
      final setCount = (raw['sets'] as num?)?.toInt() ?? 3;
      final restRaw = raw['restSeconds'] ?? raw['rest_seconds'];
      final rest = (restRaw as num?)?.toInt() ?? int.tryParse('$restRaw') ?? 60;
      final reps = (raw['repsOrTime'] ?? raw['reps_or_time'] ?? '10-12')
          .toString();
      final secMatch = RegExp(
        r'(\\d+)\\s*(s|sec|second)',
        caseSensitive: false,
      ).firstMatch(reps);
      final minMatch = RegExp(
        r'(\\d+)\\s*(m|min|minute)',
        caseSensitive: false,
      ).firstMatch(reps);
      final perSet = minMatch != null
          ? int.parse(minMatch.group(1)!) * 60
          : secMatch != null
          ? int.parse(secMatch.group(1)!)
          : 55;
      total += (setCount * perSet) + ((setCount - 1).clamp(0, 99) * rest);
    }
    return total + (8 * 60);
  }

  String _formatDurationCompact(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
  }

  String _formatCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Widget _buildRestActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String cta,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: onTap == null
                    ? AppTheme.borderDark
                    : iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: onTap == null
                      ? AppTheme.borderDark
                      : iconColor.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                cta,
                style: GoogleFonts.plusJakartaSans(
                  color: onTap == null ? AppTheme.textSageMuted : iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recovery Tips ────────────────────────────────────────────────────────────

class _RecoveryTip {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _RecoveryTip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

const _recoveryTips = [
  _RecoveryTip(
    icon: LucideIcons.activity,
    title: 'Light Stretching',
    subtitle: '10–15 min to ease muscle tension',
    color: AppTheme.primary,
  ),
  _RecoveryTip(
    icon: LucideIcons.droplets,
    title: 'Stay Hydrated',
    subtitle: 'Aim for at least 2–3 litres today',
    color: AppTheme.info,
  ),
  _RecoveryTip(
    icon: LucideIcons.bed,
    title: 'Prioritise Sleep',
    subtitle: '7–9 hours for optimal recovery',
    color: AppTheme.levelArc,
  ),
  _RecoveryTip(
    icon: LucideIcons.salad,
    title: 'Eat Well',
    subtitle: 'Protein and whole foods fuel repair',
    color: AppTheme.accent,
  ),
];

// ─── Exercise Card ────────────────────────────────────────────────────────────

String _formatRest(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  if (secs == 0) return '$mins min';
  return '${mins}m ${secs}s';
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final int index;
  final PersonalRecord? pr;
  final VoidCallback onUpdate;
  final Future<void> Function() onReplace;
  final Future<void> Function() onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.onUpdate,
    required this.onReplace,
    required this.onDelete,
    this.pr,
  });

  void _showEditSheet(BuildContext context) {
    final setsCtrl = TextEditingController(
      text: (exercise['sets'] ?? 3).toString(),
    );
    final repsCtrl = TextEditingController(
      text: (exercise['repsOrTime'] ?? exercise['reps_or_time'] ?? '10')
          .toString(),
    );
    final restCtrl = TextEditingController(
      text: (exercise['restSeconds'] ?? exercise['rest_seconds'] ?? 60)
          .toString(),
    );
    final notesCtrl = TextEditingController(
      text: (exercise['notes'] ?? '').toString(),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              exercise['name'] ?? 'Exercise',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Field(ctrl: setsCtrl, label: 'Sets'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(ctrl: repsCtrl, label: 'Reps / Time'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(ctrl: restCtrl, label: 'Rest (seconds)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Field(ctrl: notesCtrl, label: 'Notes (optional)', maxLines: 2),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await ApiClient.updateExercise(exercise['id'], {
                  'sets': int.tryParse(setsCtrl.text) ?? exercise['sets'],
                  'repsOrTime': repsCtrl.text,
                  'restSeconds':
                      int.tryParse(restCtrl.text) ?? exercise['restSeconds'],
                  'notes': notesCtrl.text,
                });
                if (context.mounted) Navigator.pop(context);
                onUpdate();
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
                  'SAVE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.backgroundDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] ?? 'Exercise';
    final muscle =
        (exercise['muscleGroup'] ?? exercise['muscle_group'] ?? '') as String;
    final sets = exercise['sets'] ?? 3;
    final reps = (exercise['repsOrTime'] ?? exercise['reps_or_time'] ?? '10–12')
        .toString();
    final restRaw = exercise['restSeconds'] ?? exercise['rest_seconds'] ?? 60;
    final restSecs = (restRaw is int)
        ? restRaw
        : int.tryParse('$restRaw') ?? 60;
    final accentColor = _muscleAccentColor(muscle);
    final isTimeBased = RegExp(
      r'\d+\s*(s|sec|min)',
      caseSensitive: false,
    ).hasMatch(reps);

    return Dismissible(
      key: ValueKey('exercise-${exercise['id']}-${exercise['name']}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          Future.delayed(Duration.zero, onDelete);
        } else {
          Future.delayed(Duration.zero, onReplace);
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.deleteAction,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Icon(LucideIcons.trash_2, color: AppTheme.error, size: 14),
            const SizedBox(width: 6),
            Text(
              'DELETE',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.error,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.swapAction,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(
              LucideIcons.refresh_cw,
              color: AppTheme.textCream,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'SWAP',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.32)),
        ),
        child: Material(
          color: AppTheme.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showEditSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: index + name + edit icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1, right: 10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textCream,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            if (muscle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    muscle.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: accentColor.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          LucideIcons.pencil,
                          color: AppTheme.textSageMuted.withValues(alpha: 0.45),
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        _StatBlock(
                          value: '$sets',
                          label: 'SETS',
                          color: accentColor,
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: AppTheme.borderDark,
                        ),
                        _StatBlock(
                          value: reps,
                          label: isTimeBased ? 'DURATION' : 'REPS',
                          color: AppTheme.textCream,
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: AppTheme.borderDark,
                        ),
                        _StatBlock(
                          value: _formatRest(restSecs),
                          label: 'REST',
                          color: AppTheme.textSageMuted,
                        ),
                      ],
                    ),
                  ),
                  // PR badge
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.trophy,
                          color: AppTheme.xpGold,
                          size: 11,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          pr != null
                              ? 'PR: ${pr!.weightKg}kg × ${pr!.reps} reps'
                              : 'No PR yet',
                          style: GoogleFonts.plusJakartaSans(
                            color: pr != null
                                ? AppTheme.xpGold.withValues(alpha: 0.85)
                                : AppTheme.textSageMuted.withValues(
                                    alpha: 0.45,
                                  ),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

// ─── Superset Pair Card ───────────────────────────────────────────────────────

class _SupersetPairCard extends StatelessWidget {
  final Map<String, dynamic> exerciseA;
  final Map<String, dynamic> exerciseB;
  final int indexA;
  final int indexB;
  final PersonalRecord? prA;
  final PersonalRecord? prB;
  final VoidCallback onUpdate;
  final Future<void> Function() onReplaceA;
  final Future<void> Function() onReplaceB;

  const _SupersetPairCard({
    required this.exerciseA,
    required this.exerciseB,
    required this.indexA,
    required this.indexB,
    required this.onUpdate,
    required this.onReplaceA,
    required this.onReplaceB,
    this.prA,
    this.prB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // SUPERSET label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.zap, color: AppTheme.primary, size: 12),
                const SizedBox(width: 5),
                Text(
                  'SUPERSET',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _SupersetExerciseRow(
            exercise: exerciseA,
            index: indexA,
            pr: prA,
            onUpdate: onUpdate,
            onReplace: onReplaceA,
            isLast: false,
          ),
          // Connector line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.arrow_down,
                    color: AppTheme.primary,
                    size: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(height: 1, color: AppTheme.borderDark),
                ),
              ],
            ),
          ),
          _SupersetExerciseRow(
            exercise: exerciseB,
            index: indexB,
            pr: prB,
            onUpdate: onUpdate,
            onReplace: onReplaceB,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SupersetExerciseRow extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final int index;
  final PersonalRecord? pr;
  final VoidCallback onUpdate;
  final Future<void> Function() onReplace;
  final bool isLast;

  const _SupersetExerciseRow({
    required this.exercise,
    required this.index,
    required this.onUpdate,
    required this.onReplace,
    required this.isLast,
    this.pr,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] ?? 'Exercise';
    final muscle =
        (exercise['muscleGroup'] ?? exercise['muscle_group'] ?? '') as String;
    final sets = exercise['sets'] ?? 3;
    final reps = (exercise['repsOrTime'] ?? exercise['reps_or_time'] ?? '10-12')
        .toString();
    final restRaw = exercise['restSeconds'] ?? exercise['rest_seconds'] ?? 60;
    final restSecs = (restRaw is int)
        ? restRaw
        : int.tryParse('$restRaw') ?? 60;
    final accentColor = _muscleAccentColor(muscle);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, isLast ? 14 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              isLast ? 'B' : 'A',
              style: GoogleFonts.plusJakartaSans(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$sets × $reps  ·  rest ${_formatRest(restSecs)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (pr != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.trophy,
                        color: AppTheme.xpGold,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PR: ${pr!.weightKg}kg × ${pr!.reps}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.xpGold.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _muscleAccentColor(String muscleGroup) {
  final key = muscleGroup.toLowerCase();
  if (key.contains('chest')) return AppTheme.muscleChest;
  if (key.contains('back')) return AppTheme.muscleBack;
  if (key.contains('leg') || key.contains('quad') || key.contains('ham')) {
    return AppTheme.muscleLegs;
  }
  if (key.contains('shoulder') || key.contains('delt')) {
    return AppTheme.muscleShoulders;
  }
  if (key.contains('arm') || key.contains('bicep') || key.contains('tricep')) {
    return AppTheme.muscleArms;
  }
  if (key.contains('core') || key.contains('abs')) return AppTheme.xpGold;
  return AppTheme.primary;
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted.withValues(alpha: 0.55),
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;

  const _Field({required this.ctrl, required this.label, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textCream,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.textSageMuted,
          fontSize: 11,
        ),
        filled: true,
        fillColor: AppTheme.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
