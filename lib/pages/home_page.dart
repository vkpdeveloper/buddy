import 'dart:math' as math;
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/pages/profile_page.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/models/home_dashboard.dart';
import 'package:buddy/models/user_targets.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/pages/diet_plan_page.dart';
import 'package:buddy/pages/workout_page.dart';
import 'package:buddy/pages/growth_page.dart';
import 'package:buddy/pages/buddy_chat_page.dart';
import 'package:buddy/utils/motion_preferences.dart';
import 'package:buddy/services/logs_service.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/services/home_dashboard_preferences.dart';
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
    if (animate && !prefersReducedMotion(context)) {
      _pageController.animateToPage(
        index,
        duration: motionDuration(context, const Duration(milliseconds: 260)),
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
          _PendingPlanRevealWatcher(
            onOpenPlan: () => _goToTab(0, animate: false),
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

class _PendingPlanRevealWatcher extends ConsumerStatefulWidget {
  final VoidCallback onOpenPlan;

  const _PendingPlanRevealWatcher({required this.onOpenPlan});

  @override
  ConsumerState<_PendingPlanRevealWatcher> createState() =>
      _PendingPlanRevealWatcherState();
}

class _PendingPlanRevealWatcherState
    extends ConsumerState<_PendingPlanRevealWatcher> {
  bool _pendingReveal = false;
  bool _dialogOpen = false;
  bool _revealScheduled = false;
  bool _clearScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadPendingState();
  }

  Future<void> _loadPendingState() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_plan_reveal') ?? false;
    if (!mounted) return;
    setState(() => _pendingReveal = pending);
    if (pending) {
      ref.read(generationStatusProvider.notifier).startPolling();
    }
  }

  Future<void> _clearPendingReveal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_plan_reveal', false);
    if (mounted) {
      setState(() {
        _pendingReveal = false;
        _dialogOpen = false;
        _revealScheduled = false;
        _clearScheduled = false;
      });
    }
  }

  Future<void> _showRevealDialog() async {
    if (mounted) {
      setState(() {
        _dialogOpen = true;
        _revealScheduled = false;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final goalDate = prefs.getString('pending_plan_goal_date') ?? '--';
    final paceLabel =
        prefs.getString('pending_plan_pace_label') ?? 'Steady pace';
    final calories = prefs.getInt('pending_plan_calories') ?? 0;
    final daysPerWeek = prefs.getInt('pending_plan_days_per_week') ?? 4;
    final builtAround =
        prefs.getString('pending_plan_built_around') ?? 'your routine';
    if (!mounted) return;
    var openPlan = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppTheme.oledBlack,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      LucideIcons.x,
                      color: AppTheme.textSageMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                Text(
                  'Buddy finished building the parts that were still in progress. Your first targets are locked in.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _RevealRow(label: 'Target date', value: goalDate),
                const SizedBox(height: 12),
                _RevealRow(label: 'Target pace', value: paceLabel),
                const SizedBox(height: 12),
                _RevealRow(label: 'Daily calories', value: '$calories kcal'),
                const SizedBox(height: 12),
                _RevealRow(
                  label: 'Training',
                  value: '$daysPerWeek days per week',
                ),
                const SizedBox(height: 12),
                _RevealRow(label: 'Built around', value: builtAround),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      openPlan = true;
                      Navigator.of(context).pop();
                    },
                    child: const Text('See today’s plan'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'I’ll check this in a minute',
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
      ),
    );
    if (openPlan) {
      widget.onOpenPlan();
    }
    await _clearPendingReveal();
  }

  void _scheduleReveal() {
    if (_dialogOpen || _revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRevealDialog();
    });
  }

  void _schedulePendingClear() {
    if (_clearScheduled) return;
    _clearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _clearPendingReveal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_pendingReveal) return const SizedBox.shrink();

    final status = ref.watch(generationStatusProvider);
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (_pendingReveal && !_dialogOpen && next.isDone) {
        _scheduleReveal();
      } else if (_pendingReveal && next.hasFailed) {
        _clearPendingReveal();
      }
    });

    if (_pendingReveal && !_dialogOpen && status.isDone) {
      _scheduleReveal();
    } else if (_pendingReveal && status.hasFailed) {
      _schedulePendingClear();
    }

    return const SizedBox.shrink();
  }
}

class _RevealRow extends StatelessWidget {
  final String label;
  final String value;

  const _RevealRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.oledBlack,
        borderRadius: BorderRadius.circular(18),
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
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Health Dashboard ─────────────────────────────────────────────────────

class _HealthDashboard extends ConsumerStatefulWidget {
  final void Function(int) onNavigate;
  const _HealthDashboard({required this.onNavigate});

  @override
  ConsumerState<_HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends ConsumerState<_HealthDashboard> {
  DateTime _selectedDate = DateTime.now();
  late final AppLifecycleListener _healthLifecycleListener;

  @override
  void initState() {
    super.initState();
    _healthLifecycleListener = AppLifecycleListener(
      onResume: _handleHealthAppResume,
    );
  }

  @override
  void dispose() {
    _healthLifecycleListener.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _handleHealthAppResume() {
    if (!mounted) return;
    refreshHealthPermissionState(ref);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      refreshHealthPermissionState(ref);
    });
  }

  Future<void> _refresh() async {
    invalidateAllHealthProviders(ref);
    ref.invalidate(progressProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(userTargetsProvider);
    ref.invalidate(weeklyWorkoutSummaryProvider);
    ref.invalidate(todayNutritionSummaryProvider(_dateKey(_selectedDate)));
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _dateKey(_selectedDate);
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardDark,
      onRefresh: _refresh,
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
            _WeekDatePicker(
              selected: _selectedDate,
              onDateSelected: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 8),
            _NutritionCarousel(
              dateKey: dateKey,
              onNavigateToDiet: () => widget.onNavigate(1),
            ),
            const SizedBox(height: 12),
            _TodayWorkoutCard(onNavigate: widget.onNavigate),
            const SizedBox(height: 12),
            _TodayMealsFeed(dateKey: dateKey),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Actions Row ────────────────────────────────────────────────────────

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
          _ProfileAvatar(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
            levelFraction: progress?.levelProgressFraction ?? 0.0,
            level: progress?.currentLevel ?? 1,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final VoidCallback onTap;
  final double levelFraction;
  final int level;

  const _ProfileAvatar({
    required this.onTap,
    required this.levelFraction,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL;
    return AppPressable(
      onPressed: onTap,
      semanticsLabel: 'Open profile, level $level',
      minHeight: 50,
      minWidth: 50,
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: levelFraction,
              strokeWidth: 2.5,
              backgroundColor: AppTheme.borderDark,
              valueColor: const AlwaysStoppedAnimation(AppTheme.xpGold),
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(color: AppTheme.borderDark, width: 1.5),
            ),
            child: ClipOval(
              child: photoURL != null && photoURL.isNotEmpty
                  ? Image.network(
                      photoURL,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => const Center(
                        child: Icon(
                          LucideIcons.user,
                          color: AppTheme.textSageMuted,
                          size: 18,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        LucideIcons.user,
                        color: AppTheme.textSageMuted,
                        size: 18,
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.oledBlack,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.xpGold.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                'LVL $level',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.xpGold,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
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

class _WeekDatePicker extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onDateSelected;

  const _WeekDatePicker({required this.selected, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Find Sunday of current week
    final weekday = today.weekday % 7; // Mon=1..Sun=0 → Sun=0
    final sunday = today.subtract(Duration(days: weekday));
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = sunday.add(Duration(days: i));
          final isToday = day == today;
          final isSelected =
              day == DateTime(selected.year, selected.month, selected.day);
          final isPast = day.isBefore(today);

          return Expanded(
            child: GestureDetector(
              onTap: () => onDateSelected(day),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[i],
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primary, width: 1.5)
                          : isPast && !isSelected
                          ? Border.all(
                              color: AppTheme.borderDark,
                              width: 1,
                              strokeAlign: BorderSide.strokeAlignCenter,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected
                            ? AppTheme.primary
                            : isToday
                            ? AppTheme.primary
                            : AppTheme.textSageMuted,
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NutritionCarousel extends ConsumerStatefulWidget {
  final String dateKey;
  final VoidCallback onNavigateToDiet;
  const _NutritionCarousel({
    required this.dateKey,
    required this.onNavigateToDiet,
  });

  @override
  ConsumerState<_NutritionCarousel> createState() => _NutritionCarouselState();
}

class _NutritionCarouselState extends ConsumerState<_NutritionCarousel> {
  final _controller = PageController();
  int _page = 0;

  bool _showConsumed = HomeDashboardPreferences.showConsumed;
  bool _requestingHealthAccess = false;

  // Keeps last-known nutrition data alive during provider re-fetch so _CountingNumber
  // stays mounted and can animate from old→new values when a meal is actually checked.
  TodayNutritionSummary? _lastNutrition;
  bool? _lastHasHealthPermission;
  int? _lastSteps;
  double? _lastEnergy;
  HomeDashboardData? _lastHomeData;
  UserTargets? _lastTargets;

  void _toggleCaloriesMode() async {
    final next = !_showConsumed;
    setState(() => _showConsumed = next);
    await HomeDashboardPreferences.setShowConsumed(next);
  }

  Future<void> _handleHealthAccessTap() async {
    if (_requestingHealthAccess) return;

    setState(() => _requestingHealthAccess = true);
    try {
      final granted = await requestHealthPermissions(ref);
      if (!mounted || granted) return;

      AppSnackbar.error(
        context,
        'Health access is still off. You can enable it from the profile screen if the prompt does not appear.',
      );
    } finally {
      if (mounted) {
        setState(() => _requestingHealthAccess = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nutritionAsync = ref.watch(
      effectiveTodayNutritionSummaryProvider(widget.dateKey),
    );
    final permissionAsync = ref.watch(healthPermissionProvider);
    final stepsAsync = ref.watch(todayStepsProvider);
    final energyAsync = ref.watch(todayActiveEnergyProvider);
    final homeAsync = ref.watch(homeDashboardProvider);
    final targetsAsync = ref.watch(userTargetsProvider);

    return Column(
      children: [
        SizedBox(
          height: 308,
          child: PageView(
            controller: _controller,
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              // Page 1: Calories + Macros
              _buildCaloriesPage(nutritionAsync),
              // Page 2: Activity + Hydration
              _buildActivityPage(
                permissionAsync,
                stepsAsync,
                energyAsync,
                homeAsync,
                targetsAsync,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _page == i ? AppTheme.primary : AppTheme.borderDark,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCaloriesPage(AsyncValue<TodayNutritionSummary> nutritionAsync) {
    // Cache last known data so widgets stay mounted during re-fetch.
    // This lets _CountingNumber animate from old→new when a meal is checked,
    // rather than unmounting (shimmer) and remounting without animation.
    final freshData = nutritionAsync.asData?.value;
    if (freshData != null) _lastNutrition = freshData;
    final n = freshData ?? _lastNutrition;

    if (n == null) {
      if (nutritionAsync.hasError) return _CaloriesEmptyCard();
      return const _NutritionCarouselSkeleton();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // ── Top: Calorie card ──────────────────────────────────────
          GestureDetector(
            onTap: _toggleCaloriesMode,
            child: Container(
              height: 136,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderDark),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.xpGold.withValues(alpha: 0.06),
                    AppTheme.primary.withValues(alpha: 0.03),
                    AppTheme.cardDark,
                  ],
                  stops: const [0.0, 0.26, 1.0],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.shadowSoft,
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _CaloriesDisplay(
                      showConsumed: _showConsumed,
                      consumed: n.caloriesConsumed,
                      remaining: n.caloriesRemaining,
                      target: n.caloriesTarget,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CalorieRingIcon(fraction: n.calorieFraction, size: 86),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Bottom: 3 Macro cards ──────────────────────────────────
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MacroCard(
                    label: 'Protein',
                    value: _showConsumed
                        ? n.proteinConsumedG.round()
                        : n.proteinRemainingG.round(),
                    target: _showConsumed ? n.proteinTargetG.round() : null,
                    showConsumed: _showConsumed,
                    unit: 'g',
                    fraction: n.proteinFraction,
                    icon: '🍗',
                    iconColor: const Color(0xFFE87B6F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroCard(
                    label: 'Carbs',
                    value: _showConsumed
                        ? n.carbsConsumedG.round()
                        : n.carbsRemainingG.round(),
                    target: _showConsumed ? n.carbsTargetG.round() : null,
                    showConsumed: _showConsumed,
                    unit: 'g',
                    fraction: n.carbsFraction,
                    icon: '🌾',
                    iconColor: const Color(0xFFC89A4F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroCard(
                    label: 'Fats',
                    value: _showConsumed
                        ? n.fatsConsumedG.round()
                        : n.fatsRemainingG.round(),
                    target: _showConsumed ? n.fatsTargetG.round() : null,
                    showConsumed: _showConsumed,
                    unit: 'g',
                    fraction: n.fatsFraction,
                    icon: '🥑',
                    iconColor: const Color(0xFF6B94D4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage(
    AsyncValue<bool> permissionAsync,
    AsyncValue<int> stepsAsync,
    AsyncValue<double> energyAsync,
    AsyncValue<HomeDashboardData> homeAsync,
    AsyncValue<UserTargets> targetsAsync,
  ) {
    final freshPermission = permissionAsync.hasError
        ? false
        : permissionAsync.asData?.value;
    if (freshPermission != null) {
      _lastHasHealthPermission = freshPermission;
    }
    final hasPermission = freshPermission ?? _lastHasHealthPermission;

    final freshSteps = freshPermission == true
        ? stepsAsync.asData?.value
        : null;
    if (freshSteps != null) {
      _lastSteps = freshSteps;
    }
    final steps = hasPermission == true ? freshSteps ?? _lastSteps : null;

    final freshEnergy = freshPermission == true
        ? energyAsync.asData?.value
        : null;
    if (freshEnergy != null) {
      _lastEnergy = freshEnergy;
    }
    final energy = hasPermission == true ? freshEnergy ?? _lastEnergy : null;

    final freshHomeData = homeAsync.asData?.value;
    if (freshHomeData != null) {
      _lastHomeData = freshHomeData;
    }
    final homeData = freshHomeData ?? _lastHomeData;

    final freshTargets = targetsAsync.asData?.value;
    if (freshTargets != null) {
      _lastTargets = freshTargets;
    }
    final targets =
        freshTargets ?? _lastTargets ?? const UserTargets.defaults();

    final isWaitingForPermission =
        hasPermission == null && !permissionAsync.hasError;
    final isWaitingForActivityData =
        hasPermission == true &&
        ((steps == null && !stepsAsync.hasError) ||
            (energy == null && !energyAsync.hasError));
    final isWaitingForHomeData = homeData == null && !homeAsync.hasError;
    final isWaitingForTargets =
        freshTargets == null && _lastTargets == null && !targetsAsync.hasError;

    if (isWaitingForPermission ||
        isWaitingForActivityData ||
        isWaitingForHomeData ||
        isWaitingForTargets) {
      return const _ActivityCarouselSkeleton();
    }

    final hydrationMl = homeData?.hydrationMl ?? 0;
    final targetMl = targets.dailyWaterMl;
    final stepGoal = targets.dailySteps;
    final currentSteps = hasPermission == true ? steps ?? 0 : 0;
    final remainingSteps = math.max(stepGoal - currentSteps, 0);
    final burnedCalories = hasPermission == true ? energy?.toInt() ?? 0 : 0;
    final remainingBurnedCalories = math.max(
      targets.dailyCalorieBurn - burnedCalories,
      0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 144,
            child: Row(
              children: [
                Expanded(
                  child: hasPermission == false
                      ? _HealthConnectActivityCard(
                          onTap: _handleHealthAccessTap,
                          loading: _requestingHealthAccess,
                        )
                      : _ActivityMetricCard(
                          accentColor: AppTheme.primary,
                          icon: LucideIcons.footprints,
                          label: 'STEPS',
                          currentValue: currentSteps,
                          remainingValue: remainingSteps,
                          targetValue: stepGoal,
                          showRemaining: !_showConsumed,
                          currentSubtitle: 'Walking today',
                          remainingSubtitle: 'Steps left',
                          onTap: _toggleCaloriesMode,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActivityMetricCard(
                    accentColor: AppTheme.error,
                    icon: LucideIcons.flame,
                    label: 'BURNED',
                    currentValue: burnedCalories,
                    remainingValue: remainingBurnedCalories,
                    targetValue: targets.dailyCalorieBurn,
                    showRemaining: !_showConsumed,
                    unit: 'kcal',
                    currentSubtitle: 'Calories burned',
                    remainingSubtitle: 'Calories left',
                    onTap: _toggleCaloriesMode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _HydrationOverviewCard(
              hydrationMl: hydrationMl,
              targetMl: targetMl,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionCarouselSkeleton extends StatelessWidget {
  const _NutritionCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ShimmerBox(width: double.infinity, height: 136, borderRadius: 22),
          SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 20,
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

class _ActivityCarouselSkeleton extends StatelessWidget {
  const _ActivityCarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 144,
            child: Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 22,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 22,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesEmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Center(
          child: Text(
            'No diet plan active — set up your diet to see nutrition targets.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountingNumber extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _CountingNumber({required this.value, required this.style});

  @override
  State<_CountingNumber> createState() => _CountingNumberState();
}

class _CountingNumberState extends State<_CountingNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _anim = Tween<double>(
      begin: widget.value.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_CountingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final from = _anim.value;
      _anim = Tween<double>(
        begin: from,
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) =>
          Text('${_anim.value.round()}', style: widget.style),
    );
  }
}

class _CaloriesDisplay extends StatelessWidget {
  final bool showConsumed;
  final int consumed;
  final int remaining;
  final int target;

  const _CaloriesDisplay({
    required this.showConsumed,
    required this.consumed,
    required this.remaining,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final mainValue = showConsumed ? consumed : remaining;
    final keyword = showConsumed ? 'eaten' : 'left';
    final numStyle = GoogleFonts.sora(
      color: AppTheme.textCream,
      fontSize: 52,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _CountingNumber(value: mainValue, style: numStyle),
            if (showConsumed) ...[
              const SizedBox(width: 6),
              Text(
                '/$target',
                style: GoogleFonts.sora(
                  color: AppTheme.textSageMuted,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            children: [
              const TextSpan(text: 'Calories '),
              TextSpan(
                text: keyword,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalorieRingIcon extends StatelessWidget {
  final double fraction;
  final double size;

  const _CalorieRingIcon({required this.fraction, required this.size});

  @override
  Widget build(BuildContext context) {
    const strokeWidth = 8.0;
    final innerSize = size * 0.75;
    final iconSize = innerSize * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingProgressPainter(
              fraction: fraction.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              trackColor: AppTheme.borderDark.withValues(alpha: 0.6),
              progressColor: AppTheme.xpGold.withValues(alpha: 0.75),
            ),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              color: AppTheme.xpGold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.xpGold.withValues(alpha: 0.12),
              ),
            ),
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -1),
                child: Icon(
                  LucideIcons.flame,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double fraction;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  const _RingProgressPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    if (fraction <= 0) return;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final int value;
  final int? target;
  final bool showConsumed;
  final String unit;
  final double fraction;
  final String icon;
  final Color iconColor;

  const _MacroCard({
    required this.label,
    required this.value,
    this.target,
    this.showConsumed = false,
    required this.unit,
    required this.fraction,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final keyword = showConsumed ? 'eaten' : 'left';
    final ringSize = 64.0;
    final innerSize = ringSize * 0.70;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [iconColor.withValues(alpha: 0.08), AppTheme.cardDark],
          stops: const [0.0, 0.34],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowSoft,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _CountingNumber(
                value: value,
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              if (target != null) ...[
                const SizedBox(width: 3),
                Text(
                  '/$target$unit',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$label $keyword',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(ringSize),
                    painter: _RingProgressPainter(
                      fraction: fraction.clamp(0.0, 1.0),
                      strokeWidth: 6,
                      trackColor: AppTheme.borderDark.withValues(alpha: 0.45),
                      progressColor: iconColor.withValues(alpha: 0.75),
                    ),
                  ),
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: TextStyle(fontSize: innerSize * 0.45),
                      ),
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
}

class _ActivityMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int currentValue;
  final int remainingValue;
  final int targetValue;
  final bool showRemaining;
  final String currentSubtitle;
  final String remainingSubtitle;
  final Color accentColor;
  final String? unit;
  final VoidCallback? onTap;

  const _ActivityMetricCard({
    required this.icon,
    required this.label,
    required this.currentValue,
    required this.remainingValue,
    required this.targetValue,
    required this.showRemaining,
    required this.currentSubtitle,
    required this.remainingSubtitle,
    required this.accentColor,
    this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentBorder = accentColor.withValues(alpha: 0.22);
    final displayValue = showRemaining ? remainingValue : currentValue;
    final subtitle = showRemaining ? remainingSubtitle : currentSubtitle;

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accentBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.14),
                AppTheme.cardDark,
                AppTheme.cardDark,
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -18,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.12),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(icon, color: AppTheme.textCream, size: 16),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _CountingNumber(
                            value: displayValue,
                            style: GoogleFonts.sora(
                              color: AppTheme.textCream,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                          if (!showRemaining) ...[
                            const SizedBox(width: 5),
                            Text(
                              '/$targetValue',
                              style: GoogleFonts.sora(
                                color: AppTheme.textSageMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                height: 1.0,
                              ),
                            ),
                          ],
                          if (unit != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              unit!,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textSageMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textMain,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthConnectActivityCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _HealthConnectActivityCard({
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.14),
            AppTheme.cardDark,
            AppTheme.cardDark,
          ],
          stops: const [0.0, 0.34, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -18,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  width: 1.4,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.oledBlack.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.heart_handshake,
                      color: AppTheme.primary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ACTIVITY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Connect Health',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  color: AppTheme.textCream,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Steps and calories stay here once connected.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textMain,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              _HealthConnectInlinePrompt(onTap: onTap, loading: loading),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthConnectInlinePrompt extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _HealthConnectInlinePrompt({
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Connect Health access',
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.oledBlack.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.footprints,
                  color: AppTheme.textCream,
                  size: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Allow access',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textCream,
                      ),
                    )
                  : const Icon(
                      LucideIcons.arrow_right,
                      color: AppTheme.textCream,
                      size: 14,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hydration Overview Card ────────────────────────────────────────────────
// Follows the same object philosophy as _CaloriesDisplay:
//  • ConsumerStatefulWidget manages optimistic local offset
//  • _HydrationDisplay is a pure stateless display widget
//  • _AnimatedHydrationBar drives smooth progress animation
//  • _HydrationAddButton handles press-scale micro-interaction
class _HydrationOverviewCard extends ConsumerStatefulWidget {
  final int hydrationMl;
  final int targetMl;

  const _HydrationOverviewCard({
    required this.hydrationMl,
    required this.targetMl,
  });

  @override
  ConsumerState<_HydrationOverviewCard> createState() =>
      _HydrationOverviewCardState();
}

class _HydrationOverviewCardState
    extends ConsumerState<_HydrationOverviewCard> {
  // Optimistic offset — added instantly on tap, cleared when provider syncs.
  int _localOffset = 0;

  int get _displayMl => widget.hydrationMl + _localOffset;
  double get _displayFraction => (_displayMl / widget.targetMl).clamp(0.0, 1.0);

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void didUpdateWidget(_HydrationOverviewCard old) {
    super.didUpdateWidget(old);
    // Provider updated with the real persisted value — clear local offset.
    if (old.hydrationMl != widget.hydrationMl) {
      _localOffset = 0;
    }
  }

  void _addWater() {
    // Instant optimistic update — no spinner needed.
    setState(() => _localOffset += 250);
    LogsService.incrementHydration(_todayDate, amountMl: 250)
        .then((_) {
          ref.invalidate(homeDashboardProvider);
          writeHydrationToHC(ml: 250);
        })
        .catchError((_) {
          // Rollback on network failure.
          if (mounted) {
            setState(() => _localOffset = math.max(0, _localOffset - 250));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderDark),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.info.withValues(alpha: 0.06),
            AppTheme.primary.withValues(alpha: 0.03),
            AppTheme.cardDark,
          ],
          stops: const [0.0, 0.26, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _HydrationDisplay(
                    ml: _displayMl,
                    targetMl: widget.targetMl,
                  ),
                ),
                const SizedBox(width: 12),
                _HydrationAddButton(onTap: _addWater),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AnimatedHydrationBar(fraction: _displayFraction),
        ],
      ),
    );
  }
}

// Pure display widget — mirrors _CaloriesDisplay in structure.
class _HydrationDisplay extends StatelessWidget {
  final int ml;
  final int targetMl;

  const _HydrationDisplay({required this.ml, required this.targetMl});

  @override
  Widget build(BuildContext context) {
    final isDone = ml >= targetMl;
    final numStyle = GoogleFonts.sora(
      color: AppTheme.textCream,
      fontSize: 52,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _CountingNumber(value: ml, style: numStyle),
            const SizedBox(width: 6),
            Text(
              '/$targetMl',
              style: GoogleFonts.sora(
                color: AppTheme.textSageMuted,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            children: [
              const TextSpan(text: 'ml '),
              TextSpan(
                text: isDone ? 'goal hit' : 'consumed',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Animated progress bar — smoothly tweens to the new fraction on each update.
class _AnimatedHydrationBar extends StatefulWidget {
  final double fraction;

  const _AnimatedHydrationBar({required this.fraction});

  @override
  State<_AnimatedHydrationBar> createState() => _AnimatedHydrationBarState();
}

class _AnimatedHydrationBarState extends State<_AnimatedHydrationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _anim = Tween<double>(
      begin: 0.0,
      end: widget.fraction,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AnimatedHydrationBar old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction) {
      final from = _anim.value;
      _anim = Tween<double>(
        begin: from,
        end: widget.fraction,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: _anim.value,
          minHeight: 6,
          backgroundColor: AppTheme.borderDark,
          valueColor: AlwaysStoppedAnimation(AppTheme.info),
        ),
      ),
    );
  }
}

// + button with press-scale micro-interaction (120 ms, easeOutCubic).
class _HydrationAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HydrationAddButton({required this.onTap});

  @override
  State<_HydrationAddButton> createState() => _HydrationAddButtonState();
}

class _HydrationAddButtonState extends State<_HydrationAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add 250 ml of water',
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppTheme.cardRaised,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.plus,
              color: AppTheme.textCream,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends ConsumerWidget {
  final void Function(int) onNavigate;
  const _TodayWorkoutCard({required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeDashboardProvider);
    final workout = homeAsync.asData?.value.todayWorkoutSummary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => onNavigate(2),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  workout?.isRestDay == true
                      ? LucideIcons.moon
                      : LucideIcons.dumbbell,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S WORKOUT',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _workoutLabel(workout),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (workout?.hasInProgressSession == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Resume',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  LucideIcons.chevron_right,
                  color: AppTheme.textSageMuted,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _workoutLabel(HomeWorkoutSummaryData? w) {
    if (w == null) return 'No workout planned';
    if (w.isRestDay) return 'Rest Day — Recover & recharge';
    if (w.isCompletedToday) return '${w.dayLabel} — Completed ✓';
    if (w.hasInProgressSession) return '${w.dayLabel} — In progress';
    return '${w.dayLabel} • ${w.exerciseCount} exercises';
  }
}

class _TodayMealsFeed extends ConsumerStatefulWidget {
  final String dateKey;
  const _TodayMealsFeed({required this.dateKey});

  @override
  ConsumerState<_TodayMealsFeed> createState() => _TodayMealsFeedState();
}

class _TodayMealsFeedState extends ConsumerState<_TodayMealsFeed>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 420);
  static const Duration _rollbackDuration = Duration(milliseconds: 220);
  static const double _mealCardHeight = 64;
  static const double _mealCardGap = 8;

  late final AnimationController _transitionController;
  _MealFeedTransition? _activeTransition;
  List<TodayMealItem>? _optimisticPendingMeals;
  TodayNutritionSummary? _lastNutrition;
  bool _mealMutationInFlight = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _TodayMealsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateKey == widget.dateKey) return;

    _transitionController.stop();
    _transitionController.value = 0;
    _activeTransition = null;
    _optimisticPendingMeals = null;
    _lastNutrition = null;
    _mealMutationInFlight = false;
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  List<TodayMealItem> _pendingMealsFor(TodayNutritionSummary summary) {
    return summary.meals.where((meal) => !meal.isCompleted).toList();
  }

  bool _sameMealIds(List<TodayMealItem> a, List<TodayMealItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  double _slotTop(int index) => index * (_mealCardHeight + _mealCardGap);

  double _stageHeightForCount(int count) {
    if (count <= 0) return 0;
    return (count * _mealCardHeight) + ((count - 1) * _mealCardGap);
  }

  void _scheduleOptimisticClearIfSynced(
    List<TodayMealItem> actualPendingMeals,
  ) {
    final optimisticPendingMeals = _optimisticPendingMeals;
    if (_activeTransition != null || optimisticPendingMeals == null) return;
    if (!_sameMealIds(optimisticPendingMeals, actualPendingMeals)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeTransition != null) return;

      final freshPendingMeals = _lastNutrition == null
          ? const <TodayMealItem>[]
          : _pendingMealsFor(_lastNutrition!);

      if (_optimisticPendingMeals == null ||
          !_sameMealIds(_optimisticPendingMeals!, freshPendingMeals)) {
        return;
      }

      setState(() => _optimisticPendingMeals = null);
    });
  }

  Future<void> _playTransition(_MealFeedTransition transition) async {
    _transitionController
      ..stop()
      ..duration = transition.duration
      ..value = 0;
    await _transitionController.forward();
  }

  TodayNutritionSummary? _currentNutritionSummary() {
    final summaryAsync = ref.read(
      effectiveTodayNutritionSummaryProvider(widget.dateKey),
    );
    return summaryAsync.asData?.value ?? _lastNutrition;
  }

  void _setOptimisticNutritionSummary(TodayNutritionSummary? summary) {
    ref
        .read(todayNutritionOptimisticSummaryProvider(widget.dateKey).notifier)
        .set(summary);
  }

  Future<void> _syncNutritionSummary() async {
    try {
      final syncedSummary = await ref.refresh(
        todayNutritionSummaryProvider(widget.dateKey).future,
      );
      _lastNutrition = syncedSummary;
      _setOptimisticNutritionSummary(null);
    } catch (_) {
      // Keep the optimistic snapshot if sync fails after a successful log.
    }
  }

  Future<void> _checkMeal(
    TodayMealItem meal,
    List<TodayMealItem> pendingMeals,
    bool reduceMotion,
  ) async {
    if (_mealMutationInFlight || _activeTransition != null) return;

    final previousSummary = _currentNutritionSummary();
    final optimisticSummary = previousSummary?.withMealCompletion(
      meal.id,
      isCompleted: true,
    );
    final currentPendingMeals = List<TodayMealItem>.from(pendingMeals);
    final previousVisibleMeals = currentPendingMeals.take(2).toList();
    final tappedSlotIndex = previousVisibleMeals.indexWhere(
      (item) => item.id == meal.id,
    );
    if (tappedSlotIndex == -1) return;

    final nextPendingMeals = currentPendingMeals
        .where((item) => item.id != meal.id)
        .toList();
    final nextVisibleMeals = nextPendingMeals.take(2).toList();

    if (mounted) {
      setState(() => _mealMutationInFlight = true);
    }
    if (optimisticSummary != null) {
      _setOptimisticNutritionSummary(optimisticSummary);
    }

    try {
      if (reduceMotion) {
        if (mounted) {
          setState(() => _optimisticPendingMeals = nextPendingMeals);
        }

        try {
          await DietService.logMealCompletion(widget.dateKey, meal.id, true);
          await _syncNutritionSummary();
        } catch (_) {
          _setOptimisticNutritionSummary(previousSummary);
          if (mounted) {
            setState(() => _optimisticPendingMeals = currentPendingMeals);
            AppSnackbar.error(context, 'Could not log this meal right now.');
          }
        }
        return;
      }

      final forwardTransition = _MealFeedTransition(
        direction: _MealFeedTransitionDirection.forward,
        duration: _transitionDuration,
        tappedMealId: meal.id,
        tappedSlotIndex: tappedSlotIndex,
        fromVisibleMeals: previousVisibleMeals,
        toVisibleMeals: nextVisibleMeals,
      );

      if (mounted) {
        setState(() => _activeTransition = forwardTransition);
      }

      final requestFuture = DietService.logMealCompletion(
        widget.dateKey,
        meal.id,
        true,
      );

      await _playTransition(forwardTransition);
      if (!mounted) return;

      setState(() {
        _activeTransition = null;
        _optimisticPendingMeals = nextPendingMeals;
      });

      Object? requestError;
      try {
        await requestFuture;
      } catch (error) {
        requestError = error;
      }

      if (!mounted) return;

      if (requestError == null) {
        await _syncNutritionSummary();
        return;
      }

      _setOptimisticNutritionSummary(previousSummary);
      final rollbackTransition = _MealFeedTransition(
        direction: _MealFeedTransitionDirection.rollback,
        duration: _rollbackDuration,
        tappedMealId: meal.id,
        tappedSlotIndex: tappedSlotIndex,
        fromVisibleMeals: nextVisibleMeals,
        toVisibleMeals: previousVisibleMeals,
      );

      setState(() => _activeTransition = rollbackTransition);
      await _playTransition(rollbackTransition);
      if (!mounted) return;

      setState(() {
        _activeTransition = null;
        _optimisticPendingMeals = currentPendingMeals;
      });
      AppSnackbar.error(context, 'Could not log this meal right now.');
    } finally {
      if (mounted) {
        setState(() => _mealMutationInFlight = false);
      }
    }
  }

  Widget _buildStateCard({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required TodayMealItem meal,
    required bool enabled,
    required bool showChecked,
    required bool reduceMotion,
    required List<TodayMealItem> pendingMeals,
  }) {
    return Container(
      height: _mealCardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: enabled
                ? () => _checkMeal(meal, pendingMeals, reduceMotion)
                : null,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showChecked ? AppTheme.success : Colors.transparent,
                border: Border.all(
                  color: showChecked ? AppTheme.success : AppTheme.borderDark,
                  width: 1.5,
                ),
              ),
              child: showChecked
                  ? const Icon(LucideIcons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.label.isNotEmpty ? meal.label : meal.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meal.name.isNotEmpty ? meal.name : 'Meal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${meal.calories} kcal',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<_MealCardVisual> _transitionVisuals(_MealFeedTransition transition) {
    final mealsById = <int, TodayMealItem>{
      for (final meal in transition.fromVisibleMeals) meal.id: meal,
      for (final meal in transition.toVisibleMeals) meal.id: meal,
    };
    final visuals = <_MealCardVisual>[];
    final ids = <int>{
      ...transition.fromVisibleMeals.map((meal) => meal.id),
      ...transition.toVisibleMeals.map((meal) => meal.id),
    };

    for (final id in ids) {
      final fromIndex = transition.fromVisibleMeals.indexWhere(
        (meal) => meal.id == id,
      );
      final toIndex = transition.toVisibleMeals.indexWhere(
        (meal) => meal.id == id,
      );
      visuals.add(
        _MealCardVisual(
          meal: mealsById[id]!,
          fromIndex: fromIndex == -1 ? null : fromIndex,
          toIndex: toIndex == -1 ? null : toIndex,
        ),
      );
    }

    visuals.sort((a, b) {
      final priorityCompare = _visualPriority(b).compareTo(_visualPriority(a));
      if (priorityCompare != 0) return priorityCompare;

      final aTapped = a.fromIndex == transition.tappedSlotIndex ? 1 : 0;
      final bTapped = b.fromIndex == transition.tappedSlotIndex ? 1 : 0;
      return bTapped.compareTo(aTapped);
    });
    return visuals;
  }

  int _visualPriority(_MealCardVisual visual) {
    final fromIndex = visual.fromIndex;
    final toIndex = visual.toIndex;

    if (fromIndex != null && toIndex == null) return 3;
    if (fromIndex != null && toIndex != null && fromIndex != toIndex) return 2;
    if (fromIndex == null && toIndex != null) return 0;
    return 1;
  }

  Widget _buildAnimatedStage(
    _MealFeedTransition transition,
    List<TodayMealItem> pendingMeals,
    bool reduceMotion,
  ) {
    final visuals = _transitionVisuals(transition);
    final stageCount = math.max(
      transition.fromVisibleMeals.length,
      transition.toVisibleMeals.length,
    );

    return ClipRect(
      child: SizedBox(
        height: _stageHeightForCount(stageCount),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final travelDistance = constraints.maxWidth + 40;
            return AnimatedBuilder(
              animation: _transitionController,
              builder: (context, _) {
                final progress = _transitionController.value;
                final exitSlide = Curves.easeInCubic.transform(progress);
                final moveSlide = const Interval(
                  0.12,
                  0.88,
                  curve: Curves.easeOutCubic,
                ).transform(progress);
                final enterSlide =
                    transition.direction == _MealFeedTransitionDirection.forward
                    ? const Interval(
                        0.28,
                        1,
                        curve: Curves.easeOutCubic,
                      ).transform(progress)
                    : const Interval(
                        0.04,
                        0.8,
                        curve: Curves.easeOutCubic,
                      ).transform(progress);
                final exitFade =
                    1 -
                    const Interval(
                      0.38,
                      1,
                      curve: Curves.easeOutCubic,
                    ).transform(progress);

                return Stack(
                  children: [
                    for (final visual in visuals)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _animatedTopForVisual(visual, moveSlide),
                        child: Transform.translate(
                          offset: Offset(
                            _animatedXForVisual(
                              visual,
                              transition.direction,
                              exitSlide,
                              enterSlide,
                              travelDistance,
                            ),
                            0,
                          ),
                          child: Opacity(
                            opacity: _animatedOpacityForVisual(
                              visual,
                              enterSlide,
                              exitFade,
                            ),
                            child: _buildMealCard(
                              meal: visual.meal,
                              enabled: false,
                              showChecked:
                                  transition.direction ==
                                      _MealFeedTransitionDirection.forward &&
                                  visual.meal.id == transition.tappedMealId &&
                                  visual.toIndex == null,
                              reduceMotion: reduceMotion,
                              pendingMeals: pendingMeals,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _animatedTopForVisual(_MealCardVisual visual, double moveSlide) {
    final fromIndex = visual.fromIndex;
    final toIndex = visual.toIndex;

    if (fromIndex != null && toIndex != null && fromIndex != toIndex) {
      final fromTop = _slotTop(fromIndex);
      final toTop = _slotTop(toIndex);
      return fromTop + ((toTop - fromTop) * moveSlide);
    }

    return _slotTop(toIndex ?? fromIndex ?? 0);
  }

  double _animatedXForVisual(
    _MealCardVisual visual,
    _MealFeedTransitionDirection direction,
    double exitSlide,
    double enterSlide,
    double travelDistance,
  ) {
    if (visual.fromIndex != null && visual.toIndex == null) {
      final multiplier = direction == _MealFeedTransitionDirection.forward
          ? -1.0
          : 1.0;
      return travelDistance * exitSlide * multiplier;
    }

    if (visual.fromIndex == null && visual.toIndex != null) {
      final startX = direction == _MealFeedTransitionDirection.forward
          ? travelDistance
          : -travelDistance * 0.65;
      return startX * (1 - enterSlide);
    }

    return 0;
  }

  double _animatedOpacityForVisual(
    _MealCardVisual visual,
    double enterSlide,
    double exitFade,
  ) {
    if (visual.fromIndex != null && visual.toIndex == null) {
      return exitFade.clamp(0.0, 1.0).toDouble();
    }
    if (visual.fromIndex == null && visual.toIndex != null) {
      return enterSlide.clamp(0.0, 1.0).toDouble();
    }
    return 1;
  }

  Widget _buildIdleStage(
    List<TodayMealItem> visibleMeals,
    List<TodayMealItem> pendingMeals,
    bool reduceMotion,
  ) {
    return SizedBox(
      height: _stageHeightForCount(visibleMeals.length),
      child: Stack(
        children: [
          for (var index = 0; index < visibleMeals.length; index++)
            Positioned(
              left: 0,
              right: 0,
              top: _slotTop(index),
              child: _buildMealCard(
                meal: visibleMeals[index],
                enabled: !_mealMutationInFlight,
                showChecked: false,
                reduceMotion: reduceMotion,
                pendingMeals: pendingMeals,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);
    final nutritionAsync = ref.watch(
      effectiveTodayNutritionSummaryProvider(widget.dateKey),
    );
    final freshNutrition = nutritionAsync.asData?.value;
    if (freshNutrition != null) {
      _lastNutrition = freshNutrition;
    }

    final nutrition = freshNutrition ?? _lastNutrition;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "TODAY'S MEALS",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ),
          if (nutrition == null)
            if (nutritionAsync.hasError)
              const SizedBox.shrink()
            else
              const ShimmerBox(
                width: double.infinity,
                height: 80,
                borderRadius: 14,
              )
          else ...[
            Builder(
              builder: (context) {
                final actualPendingMeals = _pendingMealsFor(nutrition);
                _scheduleOptimisticClearIfSynced(actualPendingMeals);

                final optimisticPendingMeals = _optimisticPendingMeals;
                final effectivePendingMeals =
                    optimisticPendingMeals != null &&
                        !_sameMealIds(
                          optimisticPendingMeals,
                          actualPendingMeals,
                        )
                    ? optimisticPendingMeals
                    : actualPendingMeals;

                if (_activeTransition != null) {
                  return _buildAnimatedStage(
                    _activeTransition!,
                    effectivePendingMeals,
                    reduceMotion,
                  );
                }

                if (nutrition.meals.isEmpty) {
                  return _buildStateCard(
                    icon: LucideIcons.utensils,
                    iconColor: AppTheme.textSageMuted,
                    message: 'No meals logged yet — tap Diet to log.',
                  );
                }

                if (effectivePendingMeals.isEmpty) {
                  return _buildStateCard(
                    icon: LucideIcons.circle_check,
                    iconColor: AppTheme.success,
                    message: 'All meals logged for today!',
                  );
                }

                final visibleMeals = effectivePendingMeals.take(2).toList();
                return _buildIdleStage(
                  visibleMeals,
                  effectivePendingMeals,
                  reduceMotion,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

enum _MealFeedTransitionDirection { forward, rollback }

class _MealFeedTransition {
  final _MealFeedTransitionDirection direction;
  final Duration duration;
  final int tappedMealId;
  final int tappedSlotIndex;
  final List<TodayMealItem> fromVisibleMeals;
  final List<TodayMealItem> toVisibleMeals;

  const _MealFeedTransition({
    required this.direction,
    required this.duration,
    required this.tappedMealId,
    required this.tappedSlotIndex,
    required this.fromVisibleMeals,
    required this.toVisibleMeals,
  });
}

class _MealCardVisual {
  final TodayMealItem meal;
  final int? fromIndex;
  final int? toIndex;

  const _MealCardVisual({
    required this.meal,
    required this.fromIndex,
    required this.toIndex,
  });
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────

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
            icon: LucideIcons.house,
            label: 'HOME',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: LucideIcons.utensils,
            label: 'DIET',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          // Center Buddy AI button
          Transform.translate(
            offset: const Offset(0, -20),
            child: AppPressable(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const BuddyChatPage())),
              semanticsLabel: 'Open Buddy AI Chat',
              minHeight: 66,
              minWidth: 66,
              borderRadius: BorderRadius.circular(22),
              decoration: BoxDecoration(
                color: AppTheme.cardRaised,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.borderDark.withValues(alpha: 0.9),
                ),
              ),
              child: const SizedBox(
                width: 66,
                height: 66,
                child: _BuddyFabIcon(),
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
            label: 'PROGRESS',
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
    final color = isActive ? AppTheme.textMain : AppTheme.textSageMuted;
    return AppPressable(
      onPressed: onTap,
      semanticsLabel: label,
      selected: isActive,
      minWidth: 66,
      minHeight: 56,
      borderRadius: BorderRadius.circular(16),
      excludeChildSemantics: true,
      child: SizedBox(
        width: 66,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 180),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 3,
                child: Center(
                  child: AnimatedOpacity(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 160),
                    ),
                    curve: Curves.easeOut,
                    opacity: isActive ? 1 : 0,
                    child: Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.textMain,
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

// ── Buddy FAB animated icon ────────────────────────────────────────────────
//
// A compact idle face that stays friendly and alive inside the FAB.
// Instead of morphing into a letter, it cycles through a small set of upbeat
// expressions: blinks, winks, and smile shifts with randomized timing.
// ─────────────────────────────────────────────────────────────────────────

class _BuddyFabIcon extends StatefulWidget {
  const _BuddyFabIcon();

  @override
  State<_BuddyFabIcon> createState() => _BuddyFabIconState();
}

class _BuddyFabIconState extends State<_BuddyFabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final math.Random _random = math.Random();
  _BuddyExpression _expression = _BuddyExpression.blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _expression.duration);
    _startCycle();
  }

  Future<void> _startCycle() async {
    while (mounted) {
      await Future.delayed(_idleDelay());
      if (!mounted) break;

      final nextExpression = _pickNextExpression();
      if (mounted) {
        setState(() => _expression = nextExpression);
      }
      _ctrl.duration = nextExpression.duration;
      await _ctrl.forward(from: 0.0);
    }
  }

  Duration _idleDelay() => Duration(milliseconds: 1600 + _random.nextInt(2200));

  _BuddyExpression _pickNextExpression() {
    final candidates = _BuddyExpression.values
        .where((expression) => expression != _expression)
        .toList(growable: false);
    return candidates[_random.nextInt(candidates.length)];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: _BuddyFacePainter(t: _ctrl.value, expression: _expression),
          ),
        ),
      ),
    );
  }
}

enum _BuddyExpression {
  blink(Duration(milliseconds: 620)),
  doubleBlink(Duration(milliseconds: 920)),
  rightWink(Duration(milliseconds: 760)),
  cheerfulBlink(Duration(milliseconds: 880)),
  grinBounce(Duration(milliseconds: 980)),
  playfulWink(Duration(milliseconds: 860));

  const _BuddyExpression(this.duration);

  final Duration duration;
}

class _BuddyFacePainter extends CustomPainter {
  final double t;
  final _BuddyExpression expression;

  const _BuddyFacePainter({required this.t, required this.expression});

  // ── Face geometry (canvas 44×44, centre = 22) ───────────────────────────
  static const _leftEye = Offset(15, 13.6);
  static const _rightEye = Offset(29, 13.6);
  static const double _eyeR = 3.5;
  static const _smileCenterX = 22.0;
  static const _smileBaseY = 27.0;

  // ── Paints ───────────────────────────────────────────────────────────────
  static Paint _stroke({double alpha = 1.0}) => Paint()
    ..color = AppTheme.textCream.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill({double alpha = 1.0}) => Paint()
    ..color = AppTheme.textCream.withValues(alpha: alpha)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _sampleFrame();
    _drawEye(
      canvas,
      center: _leftEye.translate(0, frame.eyeYOffset),
      scaleY: frame.leftEyeScaleY,
    );
    _drawEye(
      canvas,
      center: _rightEye.translate(0, frame.eyeYOffset),
      scaleY: frame.rightEyeScaleY,
    );
    _drawSmile(canvas, frame);
  }

  _BuddyFaceFrame _sampleFrame() {
    switch (expression) {
      case _BuddyExpression.blink:
        final pulse = _pulse(t, 0.18, 0.34, 0.52);
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - pulse,
          rightEyeScaleY: 1.0 - pulse,
        );
      case _BuddyExpression.doubleBlink:
        final first = _pulse(t, 0.08, 0.20, 0.34);
        final second = _pulse(t, 0.44, 0.58, 0.76);
        final blink = math.max(first, second);
        final smileLift = 0.35 * second;
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - blink,
          rightEyeScaleY: 1.0 - blink,
          smileDepth: 4.4 + smileLift,
          smileWidth: 10.0 + smileLift * 0.5,
        );
      case _BuddyExpression.rightWink:
        final wink = _pulse(t, 0.16, 0.34, 0.66);
        final smileEase = _pulse(t, 0.12, 0.42, 0.82);
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - wink * 0.06,
          rightEyeScaleY: 1.0 - wink,
          smileTilt: 1.0 * smileEase,
          smileWidth: 10.3 + 0.5 * smileEase,
          smileDepth: 4.5 + 0.2 * smileEase,
        );
      case _BuddyExpression.cheerfulBlink:
        final blink = _pulse(t, 0.18, 0.36, 0.58);
        final smileEase = _pulse(t, 0.08, 0.44, 0.86);
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - blink * 0.92,
          rightEyeScaleY: 1.0 - blink * 0.92,
          smileWidth: 10.0 + smileEase * 1.2,
          smileDepth: 4.4 + smileEase * 1.0,
          smileYOffset: smileEase * 0.25,
        );
      case _BuddyExpression.grinBounce:
        final squint = _pulse(t, 0.14, 0.46, 0.86);
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - squint * 0.42,
          rightEyeScaleY: 1.0 - squint * 0.42,
          smileWidth: 10.0 + squint * 1.7,
          smileDepth: 4.4 + squint * 1.3,
          smileYOffset: squint * 0.4,
          eyeYOffset: -0.2 * squint,
        );
      case _BuddyExpression.playfulWink:
        final wink = _pulse(t, 0.18, 0.32, 0.60);
        final bounce = _pulse(t, 0.12, 0.40, 0.84);
        return _BuddyFaceFrame(
          leftEyeScaleY: 1.0 - wink * 0.18,
          rightEyeScaleY: 1.0 - wink,
          smileWidth: 10.1 + bounce * 1.0,
          smileDepth: 4.5 + bounce * 0.9,
          smileTilt: 1.4 * bounce,
          smileYOffset: bounce * 0.2,
          eyeYOffset: -0.15 * bounce,
        );
    }
  }

  double _pulse(double value, double start, double peak, double end) {
    if (value <= start || value >= end) return 0.0;
    if (value < peak) {
      final rise = (value - start) / (peak - start);
      return Curves.easeInOut.transform(rise.clamp(0.0, 1.0));
    }
    final fall = 1.0 - (value - peak) / (end - peak);
    return Curves.easeInOut.transform(fall.clamp(0.0, 1.0));
  }

  void _drawEye(
    Canvas canvas, {
    required Offset center,
    required double scaleY,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, scaleY.clamp(0.06, 1.0));
    canvas.drawCircle(Offset.zero, _eyeR, _fill());
    canvas.restore();
  }

  void _drawSmile(Canvas canvas, _BuddyFaceFrame frame) {
    final startY = _smileBaseY - frame.smileTilt * 0.5 + frame.smileYOffset;
    final endY = _smileBaseY + frame.smileTilt * 0.5 + frame.smileYOffset;
    final start = Offset(_smileCenterX - frame.smileWidth, startY);
    final end = Offset(_smileCenterX + frame.smileWidth, endY);
    final controlDepth = frame.smileDepth + frame.smileYOffset;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          _smileCenterX - frame.smileWidth * 0.55,
          startY + controlDepth,
          _smileCenterX + frame.smileWidth * 0.55,
          endY + controlDepth,
          end.dx,
          end.dy,
        ),
      _stroke(),
    );
  }

  @override
  bool shouldRepaint(_BuddyFacePainter old) =>
      old.t != t || old.expression != expression;
}

class _BuddyFaceFrame {
  final double leftEyeScaleY;
  final double rightEyeScaleY;
  final double smileWidth;
  final double smileDepth;
  final double smileTilt;
  final double smileYOffset;
  final double eyeYOffset;

  const _BuddyFaceFrame({
    this.leftEyeScaleY = 1.0,
    this.rightEyeScaleY = 1.0,
    this.smileWidth = 10.0,
    this.smileDepth = 4.4,
    this.smileTilt = 0.0,
    this.smileYOffset = 0.0,
    this.eyeYOffset = 0.0,
  });
}
