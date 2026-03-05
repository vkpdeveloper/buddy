import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/pages/active_workout_page.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/providers/generation_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPlans();
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
      setState(() {
        _planData = res['data'];
        _activePlanId = id;
        // Auto-select today's weekday (Mon=0 ... Sun=6)
        _selectedDayIndex = DateTime.now().weekday - 1;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (prev?.workout != 'done' && next.workout == 'done') {
        _loadPlans();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                  style: GoogleFonts.crimsonPro(
                    color: AppTheme.textCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.dumbbell,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isGenerating ? 'Building your plan…' : 'No workout plan yet',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGenerating
                    ? 'We\'re putting together a plan around your goals and equipment. It\'ll be ready in a moment.'
                    : 'Your workout plan will appear here once it\'s been generated.',
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
              final isToday = DateTime.now().weekday - 1 == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
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

    if (isRest) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
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
                    style: GoogleFonts.crimsonPro(
                      color: AppTheme.textCream,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${exercises.length} exercises',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 12,
                  ),
                ),
                if (planId != null && dayId != null)
                  GestureDetector(
                    onTap: () {
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
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.play,
                            color: AppTheme.backgroundDark,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'START',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.backgroundDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
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
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ExerciseCard(
                exercise: exercises[i],
                index: i,
                onUpdate: () => _loadPlanDetail(_activePlanId!),
              ),
              childCount: exercises.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
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
    color: Color(0xFF6BAED6),
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
  if (secs == 0) return '${mins} min';
  return '${mins}m ${secs}s';
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final int index;
  final VoidCallback onUpdate;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.onUpdate,
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
    const accentColor = AppTheme.primary;
    final isTimeBased = RegExp(
      r'\d+\s*(s|sec|min)',
      caseSensitive: false,
    ).hasMatch(reps);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Material(
        color: Colors.transparent,
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
                                    color: accentColor.withValues(alpha: 0.75),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
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
