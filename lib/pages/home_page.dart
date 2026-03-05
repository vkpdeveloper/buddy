import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/health_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HealthDashboard(onNavigate: (i) => setState(() => _currentIndex = i)),
      const DietPlanPage(),
      const WorkoutPage(),
      const GrowthPage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: pages),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNavigation(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
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
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HeaderSection(),
            const GeneratingBanner(),
            const _PermissionBanner(),
            const _HeroHealthScore(),
            _QuickActionsRow(onNavigate: onNavigate),
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

class _QuickActionsRow extends StatelessWidget {
  final void Function(int) onNavigate;
  const _QuickActionsRow({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
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
                subtitle: 'Today\'s meals',
                onTap: () => onNavigate(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _TrainCard(onTap: () => onNavigate(2))),
          ],
        ),
      ),
    );
  }
}

class _TrainCard extends StatefulWidget {
  final VoidCallback onTap;
  const _TrainCard({required this.onTap});

  @override
  State<_TrainCard> createState() => _TrainCardState();
}

class _TrainCardState extends State<_TrainCard> {
  bool? _isRestDay;

  @override
  void initState() {
    super.initState();
    _checkRestDay();
  }

  Future<void> _checkRestDay() async {
    try {
      final res = await ApiClient.listWorkoutPlans();
      final plans = (res['data'] as List?) ?? [];
      final active = plans
          .where((p) => p['isActive'] == true || p['is_active'] == 1)
          .toList();
      final planId = active.isNotEmpty
          ? active.first['id']
          : (plans.isNotEmpty ? plans.last['id'] : null);
      if (planId == null) {
        if (mounted) setState(() => _isRestDay = false);
        return;
      }
      final detail = await ApiClient.getWorkoutPlan(planId as int);
      final days = (detail['data']?['days'] as List?) ?? [];
      final todayIdx = DateTime.now().weekday - 1;
      if (days.length > todayIdx) {
        final day = days[todayIdx];
        if (mounted) {
          setState(
            () =>
                _isRestDay =
                    day['isRestDay'] == true || day['is_rest_day'] == 1,
          );
        }
      } else {
        if (mounted) setState(() => _isRestDay = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isRestDay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRest = _isRestDay ?? false;
    return _QuickActionCard(
      icon: isRest ? LucideIcons.moon : LucideIcons.dumbbell,
      label: isRest ? 'REST DAY' : 'TRAIN',
      subtitle: isRest ? 'Recover & recharge' : 'Workout plan',
      onTap: widget.onTap,
      muted: isRest,
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
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderDark),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                style: GoogleFonts.crimsonPro(
                  color: AppTheme.textCream,
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroHealthScore extends ConsumerWidget {
  const _HeroHealthScore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(todayStepsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            stepsAsync.when(
              data: (steps) {
                final score = (steps / 100).clamp(0, 100).toInt();
                final progress = score / 100.0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.05),
                            blurRadius: 40,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
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
                        Text(
                          '$score',
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
                );
              },
              loading: () =>
                  const ShimmerBox(width: 192, height: 192, borderRadius: 96),
              error: (_, _) => const SizedBox(
                width: 192,
                height: 192,
                child: Center(
                  child: Text(
                    'Error',
                    style: TextStyle(color: AppTheme.textCream),
                  ),
                ),
              ),
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
                String hrText = '--';
                if (hrRaw != null) {
                  final s = hrRaw.toString();
                  final match = RegExp(r'\d+\.?\d*').firstMatch(s);
                  if (match != null) hrText = match.group(0)!.split('.').first;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _LiveStat(
                        label: 'STEPS',
                        value: steps.toString(),
                        icon: LucideIcons.footprints,
                      ),
                      _StatDivider(),
                      _LiveStat(
                        label: 'KCAL',
                        value: kcal.toInt().toString(),
                        icon: LucideIcons.flame,
                      ),
                      _StatDivider(),
                      _LiveStat(
                        label: 'BPM',
                        value: hrText,
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
  final String value;
  final IconData icon;
  const _LiveStat({
    required this.label,
    required this.value,
    required this.icon,
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
        Text(
          value,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
    if (hours >= 8) return const Color(0xFF6FCF97);
    if (hours >= 7) return AppTheme.primary;
    if (hours >= 6) return AppTheme.xpGold;
    return const Color(0xFFEB5757);
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
                      child: Container(
                        height: 8,
                        color: const Color(0xFF4A6FA5), // deep blue
                      ),
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
                      child: Container(
                        height: 8,
                        color: const Color(0xFF9B7EC8), // soft purple for REM
                      ),
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
                    color: const Color(0xFF4A6FA5),
                    label: 'Deep',
                    duration: '${deepMins ~/ 60}h ${deepMins % 60}m',
                  ),
                  _SleepStageItem(
                    color: AppTheme.primary.withValues(alpha: 0.7),
                    label: 'Light',
                    duration: '${lightMins ~/ 60}h ${lightMins % 60}m',
                  ),
                  _SleepStageItem(
                    color: const Color(0xFF9B7EC8),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
      final res = await ApiClient.getDailyLog(_todayDate);
      if (mounted) {
        setState(() {
          _targetMl = target;
          _waterMl = res['data']?['waterMl'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addWater() async {
    final newValue = _waterMl + 250;
    setState(() => _waterMl = newValue);
    try {
      await ApiClient.updateDailyLog(_todayDate, {'waterMl': newValue});
    } catch (_) {
      // silently fail — local state already updated
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.borderDark,
              color: AppTheme.primary,
              minHeight: 4,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
            color: Colors.black.withValues(alpha: 0.1),
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
            ],
          );
        },
      ),
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
        color: AppTheme.backgroundDark.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2)),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: AppTheme.backgroundDark,
                  size: 32,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
          ],
        ),
      ),
    );
  }
}
