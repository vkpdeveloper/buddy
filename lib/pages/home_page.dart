import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/models/home_dashboard.dart';
import 'package:buddy/models/gamification.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/pages/diet_plan_page.dart';
import 'package:buddy/pages/workout_page.dart';
import 'package:buddy/pages/growth_page.dart';
import 'package:buddy/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index, {bool animate = true}) {
    if (_currentIndex == index && _pageController.hasClients) {
      return;
    }
    if (mounted) {
      setState(() => _currentIndex = index);
    }
    if (!_pageController.hasClients) return;
    if (animate) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HealthDashboard(onNavigate: _goToTab),
      const DietPlanPage(),
      const WorkoutPage(),
      const GrowthPage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNavigation(
              currentIndex: _currentIndex,
              onTap: _goToTab,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Health Dashboard (original home content) ─────────────────────────────

class _HealthDashboard extends ConsumerWidget {
  final void Function(int) onNavigate;
  const _HealthDashboard({required this.onNavigate});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(todayStepsProvider);
    ref.invalidate(latestHeartRateProvider);
    ref.invalidate(todayActiveEnergyProvider);
    ref.invalidate(sleepDurationProvider);
    ref.invalidate(latestWeightProvider);
    ref.invalidate(healthPermissionProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(weeklyWorkoutSummaryProvider);
    // Allow providers to rebuild
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: () => _refresh(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HeaderSection(),
            const GeneratingBanner(),
            const _PermissionBanner(),
            const _HeroHealthScore(),
            _QuickActionsRow(onNavigate: onNavigate),
            const _AgendaCard(),
            const _VitalsCarousel(),
            const _ProgressCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  const _SleepCard(),
                  const SizedBox(height: 16),
                  const _WeeklyTrendsCard(),
                  const SizedBox(height: 16),
                  const _HydrationCard(),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        Expanded(child: _BodyMetricsCard()),
                        SizedBox(width: 16),
                        Expanded(child: _MindfulnessCard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Permission Banner ────────────────────────────────────────────────────────

class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(healthPermissionProvider);
    return permAsync.when(
      data: (granted) {
        if (granted) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: GestureDetector(
            onTap: () async {
              await requestHealthPermissions(ref);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.heart_handshake,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connect Health to see your steps, sleep, and calories',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    'Allow →',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ─── Quick Actions Row ────────────────────────────────────────────────────────

class _QuickActionsRow extends ConsumerWidget {
  final void Function(int) onNavigate;
  const _QuickActionsRow({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDashboardProvider);
    final dashboard = homeAsync.asData?.value;
    final nextMealLabel = dashboard?.nextMeal != null
        ? '${dashboard!.nextMeal!.label}: ${dashboard.nextMeal!.mealName}'
        : 'Today\'s meals';
    final workoutSummary = dashboard?.todayWorkoutSummary;
    final trainSubtitle = workoutSummary == null
        ? 'Workout plan'
        : workoutSummary.isRestDay
        ? 'Recover & recharge'
        : workoutSummary.isCompletedToday
        ? 'Completed today'
        : workoutSummary.hasInProgressSession
        ? 'Resume today\'s session'
        : '${workoutSummary.exerciseCount} exercises';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: LucideIcons.utensils,
                label: 'DIET',
                subtitle: nextMealLabel,
                onTap: () => onNavigate(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TrainCard(
                onTap: () => onNavigate(2),
                summary: workoutSummary,
                subtitle: trainSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainCard extends StatelessWidget {
  final VoidCallback onTap;
  final HomeWorkoutSummaryData? summary;
  final String subtitle;
  const _TrainCard({
    required this.onTap,
    required this.summary,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isRest = summary?.isRestDay == true;
    return _QuickActionCard(
      icon: isRest ? LucideIcons.moon : LucideIcons.dumbbell,
      label: isRest ? 'REST DAY' : 'TRAIN',
      subtitle: subtitle,
      onTap: onTap,
      muted: isRest,
    );
  }
}

class _AgendaCard extends ConsumerWidget {
  const _AgendaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDashboardProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: homeAsync.when(
        loading: () => const ShimmerBox(
          width: double.infinity,
          height: 110,
          borderRadius: 20,
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (home) {
          final workout = home.todayWorkoutSummary;
          final nextMeal = home.nextMeal;
          final workoutLabel = workout == null
              ? 'No workout planned'
              : workout.isRestDay
              ? 'Rest day'
              : '${workout.dayLabel} • ${workout.exerciseCount} exercises';

          final mealLabel = nextMeal == null
              ? 'No meal planned'
              : '${nextMeal.label}: ${nextMeal.mealName}';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY\'S AGENDA',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _AgendaRow(
                  icon: LucideIcons.dumbbell,
                  label: workoutLabel,
                  trailing: workout?.isCompletedToday == true
                      ? 'Done'
                      : workout?.hasInProgressSession == true
                      ? 'In progress'
                      : 'Pending',
                ),
                const SizedBox(height: 8),
                _AgendaRow(
                  icon: LucideIcons.utensils,
                  label: mealLabel,
                  trailing: nextMeal?.isCompleted == true ? 'Done' : 'Next',
                ),
                const SizedBox(height: 8),
                _AgendaRow(
                  icon: LucideIcons.droplets,
                  label: '${home.hydrationMl} ml water consumed',
                  trailing: '',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String trailing;
  const _AgendaRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSageMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool muted;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = muted ? AppTheme.textSageMuted : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevron_right,
              color: AppTheme.textSageMuted,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _HeaderSection extends ConsumerStatefulWidget {
  const _HeaderSection();

  @override
  ConsumerState<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends ConsumerState<_HeaderSection> {
  String _userName = 'Athlete';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _liveDate() {
    final now = DateTime.now();
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return '${months[now.month - 1]} ${now.day} • ${days[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider).asData?.value;
    final weekly = ref.watch(weeklyWorkoutSummaryProvider).asData?.value;
    final ringProgress = weekly?.completionFraction ?? 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 16,
        24,
        16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _liveDate(),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_greeting()},\n$_userName',
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
          _StatsRing(
            ringProgress: ringProgress,
            workoutsCompleted: weekly?.workoutsCompleted ?? 0,
            plannedWorkouts: weekly?.plannedWorkouts ?? 0,
            level: progress?.currentLevel,
            streak: progress?.currentStreak,
          ),
        ],
      ),
    );
  }
}

class _StatsRing extends StatelessWidget {
  final double ringProgress;
  final int workoutsCompleted;
  final int plannedWorkouts;
  final int? level;
  final int? streak;

  const _StatsRing({
    required this.ringProgress,
    required this.workoutsCompleted,
    required this.plannedWorkouts,
    this.level,
    this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Workout completion ring
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: ringProgress,
              strokeWidth: 3.5,
              backgroundColor: AppTheme.borderDark,
              color: AppTheme.primary,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Center: level number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (level != null)
                Text(
                  'L$level',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              Text(
                '$workoutsCompleted/$plannedWorkouts',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
          // Streak badge at bottom-right of ring
          if (streak != null && streak! > 0)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.oledBlack,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.xpGold.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$streak🔥',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.xpGold,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroHealthScore extends ConsumerWidget {
  const _HeroHealthScore();

  double _restingHrScore(int? hr) {
    if (hr == null || hr <= 0) return 0.7;
    if (hr <= 55) return 1.0;
    if (hr <= 65) return 0.9;
    if (hr <= 75) return 0.75;
    if (hr <= 85) return 0.6;
    return 0.45;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDashboardProvider).asData?.value;
    final steps = ref
        .watch(todayStepsProvider)
        .when(
          data: (v) => v > 0 ? v : (home?.steps ?? 0),
          loading: () => home?.steps ?? 0,
          error: (_, _) => home?.steps ?? 0,
        );
    final sleep = ref
        .watch(sleepDurationProvider)
        .when(
          data: (v) => v > Duration.zero
              ? v
              : Duration(minutes: home?.sleepMinutes ?? 0),
          loading: () => Duration(minutes: home?.sleepMinutes ?? 0),
          error: (_, _) => Duration(minutes: home?.sleepMinutes ?? 0),
        );
    final activeEnergy = ref
        .watch(todayActiveEnergyProvider)
        .when(
          data: (v) => v > 0 ? v : (home?.activeEnergy ?? 0).toDouble(),
          loading: () => (home?.activeEnergy ?? 0).toDouble(),
          error: (_, _) => (home?.activeEnergy ?? 0).toDouble(),
        );
    final hr = ref
        .watch(latestHeartRateProvider)
        .when(
          data: (v) => v ?? home?.restingHr,
          loading: () => home?.restingHr,
          error: (_, _) => home?.restingHr,
        );

    final stepsNorm = (steps / 10000).clamp(0.0, 1.0);
    final sleepNorm = (sleep.inMinutes / (8 * 60)).clamp(0.0, 1.0);
    final activeNorm = (activeEnergy / 600).clamp(0.0, 1.0);
    final hrNorm = _restingHrScore(hr);
    final score =
        ((stepsNorm * 0.4 + sleepNorm * 0.3 + activeNorm * 0.2 + hrNorm * 0.1) *
                100)
            .round();
    final progress = score / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 192,
                  height: 192,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                ),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: AppTheme.borderDark,
                    color: AppTheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CountUpIntText(
                      value: score,
                      style: const TextStyle(
                        color: AppTheme.textCream,
                        fontSize: 60,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2,
                      ),
                    ),
                    const Text(
                      'HEALTH SCORE',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // — Live activity strip —
            Consumer(
              builder: (_, ref, _) {
                final steps = ref
                    .watch(todayStepsProvider)
                    .when(data: (v) => v, loading: () => 0, error: (_, _) => 0);
                final kcal = ref
                    .watch(todayActiveEnergyProvider)
                    .when(
                      data: (v) => v,
                      loading: () => 0.0,
                      error: (_, _) => 0.0,
                    );
                final hrPoint = ref
                    .watch(latestHeartRateProvider)
                    .when(
                      data: (v) => v,
                      loading: () => null,
                      error: (_, _) => null,
                    );
                final hrRaw = hrPoint;
                int? hrValue;
                if (hrRaw != null) {
                  final s = hrRaw.toString();
                  final match = RegExp(r'\d+\.?\d*').firstMatch(s);
                  if (match != null) {
                    hrValue = int.tryParse(match.group(0)!.split('.').first);
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _LiveStat(
                        label: 'STEPS',
                        value: steps,
                        icon: LucideIcons.footprints,
                      ),
                      _StatDivider(),
                      _LiveStat(
                        label: 'KCAL',
                        value: kcal.toInt(),
                        icon: LucideIcons.flame,
                      ),
                      _StatDivider(),
                      _LiveStat(
                        label: 'BPM',
                        value: hrValue,
                        fallbackText: '--',
                        icon: LucideIcons.heart,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String label;
  final int? value;
  final String fallbackText;
  final IconData icon;
  const _LiveStat({
    required this.label,
    required this.value,
    required this.icon,
    this.fallbackText = '0',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primary, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        value == null
            ? Text(
                fallbackText,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              )
            : _CountUpIntText(
                value: value!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ],
    );
  }
}

class _CountUpIntText extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _CountUpIntText({required this.value, required this.style});

  @override
  State<_CountUpIntText> createState() => _CountUpIntTextState();
}

class _CountUpIntTextState extends State<_CountUpIntText> {
  late int _fromValue;

  @override
  void initState() {
    super.initState();
    _fromValue = 0;
  }

  @override
  void didUpdateWidget(covariant _CountUpIntText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _fromValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _fromValue, end: widget.value),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      onEnd: () => _fromValue = widget.value,
      builder: (_, value, child) => Text('$value', style: widget.style),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppTheme.borderDark);
  }
}

class _VitalsCarousel extends ConsumerWidget {
  const _VitalsCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heartRateAsync = ref.watch(latestHeartRateProvider);
    final stepsAsync = ref.watch(todayStepsProvider);
    final energyAsync = ref.watch(todayActiveEnergyProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          heartRateAsync.when(
            data: (data) => _VitalCard(
              title: 'HEART RHYTHM',
              icon: LucideIcons.heart,
              value: data.toString(),
              unit: 'BPM',
              trend: 'Stable',
              trendIcon: LucideIcons.arrow_down,
            ),
            loading: () =>
                const ShimmerBox(width: 144, height: 144, borderRadius: 24),
            error: (_, _) => const _VitalCard(
              title: 'HEART RHYTHM',
              icon: LucideIcons.heart,
              value: '--',
              unit: 'BPM',
              trend: 'Error',
              trendIcon: LucideIcons.circle_x,
            ),
          ),
          const SizedBox(width: 16),
          stepsAsync.when(
            data: (steps) => _VitalCard(
              title: 'MINDFUL STEPS',
              icon: LucideIcons.trees,
              value: steps.toString(),
              unit: '',
              trend: 'Flowing',
              trendIcon: LucideIcons.check_check,
            ),
            loading: () =>
                const ShimmerBox(width: 144, height: 144, borderRadius: 24),
            error: (_, _) => const _VitalCard(
              title: 'MINDFUL STEPS',
              icon: LucideIcons.trees,
              value: '--',
              unit: '',
              trend: 'Error',
              trendIcon: LucideIcons.circle_x,
            ),
          ),
          const SizedBox(width: 16),
          energyAsync.when(
            data: (energy) => _VitalCard(
              title: 'VITALITY BURN',
              icon: LucideIcons.sun,
              value: energy.toStringAsFixed(0),
              unit: 'KCAL',
              trend: 'Active',
              trendIcon: LucideIcons.trending_up,
            ),
            loading: () =>
                const ShimmerBox(width: 144, height: 144, borderRadius: 24),
            error: (_, _) => const _VitalCard(
              title: 'VITALITY BURN',
              icon: LucideIcons.sun,
              value: '--',
              unit: 'KCAL',
              trend: 'Error',
              trendIcon: LucideIcons.circle_x,
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String unit;
  final String trend;
  final IconData trendIcon;

  const _VitalCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 144,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSageMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                color: AppTheme.primary.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.textCream,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (unit.isNotEmpty)
                    Text(
                      unit,
                      style: const TextStyle(
                        color: AppTheme.textSageMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(trendIcon, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    trend,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepCard extends ConsumerWidget {
  const _SleepCard();

  String _sleepQualityLabel(int hours) {
    if (hours >= 8) return 'Great';
    if (hours >= 7) return 'Good';
    if (hours >= 6) return 'Fair';
    return 'Low';
  }

  Color _sleepQualityColor(int hours) {
    if (hours >= 8) return AppTheme.success;
    if (hours >= 7) return AppTheme.primary;
    if (hours >= 6) return AppTheme.xpGold;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleepAsync = ref.watch(sleepDurationProvider);

    return sleepAsync.when(
      data: (sleepDuration) {
        final hours = sleepDuration.inHours;
        final minutes = sleepDuration.inMinutes.remainder(60);
        final qualityLabel = _sleepQualityLabel(hours);
        final qualityColor = _sleepQualityColor(hours);

        // Approximate stage breakdown based on total sleep
        final totalMins = sleepDuration.inMinutes;
        final deepMins = (totalMins * 0.20).round();
        final remMins = (totalMins * 0.22).round();
        final lightMins = totalMins - deepMins - remMins;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LAST NIGHT',
                        style: TextStyle(
                          color: AppTheme.textSageMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${hours}h',
                            style: const TextStyle(
                              color: AppTheme.textCream,
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${minutes}m',
                            style: const TextStyle(
                              color: AppTheme.textSageMuted,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: qualityColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      qualityLabel,
                      style: TextStyle(
                        color: qualityColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Sleep stage bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      flex: deepMins,
                      child: Container(height: 8, color: AppTheme.sleepDeep),
                    ),
                    Expanded(
                      flex: lightMins,
                      child: Container(
                        height: 8,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    Expanded(
                      flex: remMins,
                      child: Container(height: 8, color: AppTheme.sleepRem),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Stage breakdown with times
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SleepStageItem(
                    color: AppTheme.sleepDeep,
                    label: 'Deep',
                    duration: '${deepMins ~/ 60}h ${deepMins % 60}m',
                  ),
                  _SleepStageItem(
                    color: AppTheme.primary.withValues(alpha: 0.7),
                    label: 'Light',
                    duration: '${lightMins ~/ 60}h ${lightMins % 60}m',
                  ),
                  _SleepStageItem(
                    color: AppTheme.sleepRem,
                    label: 'REM',
                    duration: '${remMins ~/ 60}h ${remMins % 60}m',
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const ShimmerBox(
        width: double.infinity,
        height: 160,
        borderRadius: 24,
      ),
      error: (_, _) => Container(
        height: 160,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Error loading sleep data',
          style: TextStyle(color: AppTheme.textCream),
        ),
      ),
    );
  }
}

class _SleepStageItem extends StatelessWidget {
  final Color color;
  final String label;
  final String duration;
  const _SleepStageItem({
    required this.color,
    required this.label,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSageMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              duration,
              style: const TextStyle(
                color: AppTheme.textCream,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyTrendsCard extends StatelessWidget {
  const _WeeklyTrendsCard();

  @override
  Widget build(BuildContext context) {
    final values = [0.4, 0.6, 0.3, 0.75, 0.5, 0.8, 0.9];
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS WEEK',
            style: TextStyle(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final isLast = index == 6;
                  return Container(
                    width: 12,
                    height: 100 * values[index],
                    decoration: BoxDecoration(
                      color: isLast
                          ? AppTheme.primary
                          : AppTheme.accent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              return Text(
                labels[index],
                style: TextStyle(
                  color: index == 6 ? AppTheme.primary : AppTheme.textSageMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HydrationCard extends ConsumerStatefulWidget {
  const _HydrationCard();

  @override
  ConsumerState<_HydrationCard> createState() => _HydrationCardState();
}

class _HydrationCardState extends ConsumerState<_HydrationCard> {
  int _waterMl = 0;
  int _targetMl = 2500;
  bool _loading = true;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final target = prefs.getInt('water_target_ml') ?? 2500;
      final res = await ApiClient.getHomeSummary(_todayDate);
      if (mounted) {
        setState(() {
          _targetMl = target;
          _waterMl = res['data']?['hydrationMl'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWater() async {
    if (_loading) return;
    final previous = _waterMl;
    final newValue = _waterMl + 250;
    setState(() => _waterMl = newValue);
    try {
      await ApiClient.incrementHydration(_todayDate, amountMl: 250);
      ref.invalidate(homeDashboardProvider);
    } catch (_) {
      if (mounted) setState(() => _waterMl = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cups = (_waterMl / 250).floor();
    final targetCups = (_targetMl / 250).floor();
    final progress = _targetMl > 0
        ? (_waterMl / _targetMl).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.droplet, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'HYDRATION',
                    style: TextStyle(
                      color: AppTheme.textSageMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _loading ? null : _addWater,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _loading ? '—' : '$_waterMl',
                style: const TextStyle(
                  color: AppTheme.textCream,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${_targetMl}ml  ·  $cups / $targetCups cups',
                style: const TextStyle(
                  color: AppTheme.textSageMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppTheme.borderDark,
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyMetricsCard extends StatelessWidget {
  const _BodyMetricsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BODY WEIGHT',
            style: TextStyle(
              color: AppTheme.textSageMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: const [
              Text(
                '74',
                style: TextStyle(
                  color: AppTheme.textCream,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'kg',
                style: TextStyle(
                  color: AppTheme.textSageMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    height: 32 * 0.20,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.50,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.30,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.25,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.40,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.35,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 32 * 0.38,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(4),
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

class _MindfulnessCard extends StatelessWidget {
  const _MindfulnessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.oledBlack.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'MINDFULNESS',
                style: TextStyle(
                  color: AppTheme.textSageMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Feeling Calm',
                style: TextStyle(
                  color: AppTheme.textCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'CALM',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'STRESSED',
                    style: TextStyle(
                      color: AppTheme.textSageMuted,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Progress Card ────────────────────────────────────────────────────────────

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: progressAsync.when(
        loading: () => Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 12, borderRadius: 6),
                const SizedBox(height: 10),
                ShimmerBox(width: double.infinity, height: 6, borderRadius: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ShimmerBox(width: 60, height: 10, borderRadius: 4),
                    const SizedBox(width: 16),
                    ShimmerBox(width: 60, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (prog) {
          final recentAchievements = prog.recentAchievements;
          final leaderboard = prog.soloLeaderboard;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEVEL ${prog.currentLevel} • ${prog.levelLabel.toUpperCase()}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.levelArc,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${prog.totalXp} XP',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textCream,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (prog.currentStreak >= 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
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
                                  '${prog.currentStreak}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.xpGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // XP progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: prog.levelProgressFraction.clamp(0.0, 1.0),
                        backgroundColor: AppTheme.borderDark,
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.levelArc,
                        ),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.dumbbell,
                          color: AppTheme.textSageMuted,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${prog.totalWorkoutsCompleted} sessions',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Recent achievement chips
              if (recentAchievements.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentAchievements.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final a = recentAchievements[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.xpGold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.xpGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.trophy,
                              color: AppTheme.xpGold,
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              a.name,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.xpGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (leaderboard != null) ...[
                const SizedBox(height: 10),
                _SoloLeaderboardCard(data: leaderboard),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SoloLeaderboardCard extends StatelessWidget {
  final SoloLeaderboardData data;
  const _SoloLeaderboardCard({required this.data});

  String _formatWeekRange(String startIso, String endIso) {
    DateTime? start;
    DateTime? endExclusive;
    try {
      start = DateTime.parse(startIso);
      endExclusive = DateTime.parse(endIso);
    } catch (_) {
      return startIso;
    }
    final end = endExclusive.subtract(const Duration(days: 1));
    final startMonth = _monthShort(start.month);
    final endMonth = _monthShort(end.month);
    if (start.month == end.month) {
      return '$startMonth ${start.day}-${end.day}';
    }
    return '$startMonth ${start.day}-$endMonth ${end.day}';
  }

  String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = month - 1;
    if (index < 0 || index >= names.length) return '-';
    return names[index];
  }

  @override
  Widget build(BuildContext context) {
    final topWeeks = data.topWeeks;
    final current = data.currentWeek;
    final trajectory = data.trajectory;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trophy, color: AppTheme.xpGold, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BEST WEEKS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.xpGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Text(
                data.metricLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (topWeeks.isEmpty)
            Text(
              'Finish your first complete week to unlock your personal leaderboard.',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 12,
              ),
            )
          else
            Column(
              children: topWeeks.map((week) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LeaderboardWeekRow(
                    rank: week.rank,
                    label: _formatWeekRange(
                      week.weekStart,
                      week.weekEndExclusive,
                    ),
                    score: week.score,
                    sessions: week.sessionsCompleted,
                    xp: week.totalXp,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${current.score} score',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textCream,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${current.sessionsCompleted} sessions',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textSageMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RANK',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          current.rank == null ? '-' : '#${current.rank}',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.xpGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trajectory.daysRemaining > 0
                      ? 'Projection: ${trajectory.projectedScore} (with ${trajectory.daysRemaining} day${trajectory.daysRemaining == 1 ? '' : 's'} left)'
                      : 'Week closes today: projected ${trajectory.projectedScore}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 11,
                  ),
                ),
                if (current.projectedGapToBest > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${current.projectedGapToBest} points from your best week',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

class _LeaderboardWeekRow extends StatelessWidget {
  final int rank;
  final String label;
  final int score;
  final int sessions;
  final int xp;

  const _LeaderboardWeekRow({
    required this.rank,
    required this.label,
    required this.score,
    required this.sessions,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.xpGold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.xpGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textCream,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$sessions • $xp XP',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textCream,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavigation({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 76 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.oledBlack.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppTheme.borderDark.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: LucideIcons.flower_2,
            label: 'CENTER',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: LucideIcons.utensils,
            label: 'DIET',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          // Center button
          GestureDetector(
            onTap: () => onTap(0),
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: AppTheme.cardRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.borderDark.withValues(alpha: 0.9),
                  ),
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: AppTheme.textCream,
                  size: 30,
                ),
              ),
            ),
          ),
          _NavItem(
            icon: LucideIcons.dumbbell,
            label: 'TRAIN',
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: LucideIcons.trending_up,
            label: 'GROWTH',
            isActive: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textSageMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 3,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    opacity: isActive ? 1 : 0,
                    child: Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(2),
                      ),
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
}
