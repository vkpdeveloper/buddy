import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/pages/active_workout_page.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/widgets/shimmer_loading.dart';

class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  int? _activePlanId;
  Map<String, dynamic>? _planData;
  bool _isLoading = true;
  bool _isGenerating = false;
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

  Future<void> _generateNewPlan() async {
    setState(() => _isGenerating = true);
    try {
      final res = await ApiClient.generateWorkoutPlan();
      final planId = res['data']?['planId'];
      if (planId != null) await _loadPlanDetail(planId);
      setState(() => _selectedDayIndex = 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate. Check your connection.',
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
      }
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          _buildHeader(),
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
          Row(
            children: List.generate(
              7,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShimmerBox(width: 48, height: 36, borderRadius: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Exercise card skeletons
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ShimmerBox(width: 32, height: 32, borderRadius: 16),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShimmerBox(
                              width: double.infinity,
                              height: 14,
                              borderRadius: 6,
                            ),
                            const SizedBox(height: 6),
                            ShimmerBox(width: 80, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShimmerBox(width: 48, height: 32, borderRadius: 8),
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
          _isGenerating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                )
              : GestureDetector(
                  onTap: _generateNewPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GENERATE',
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
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
              'No workout plan yet',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a personalised plan\nbased on your equipment & goals',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _generateNewPlan,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'GENERATE WORKOUT',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.backgroundDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Text(
                  (_planData?['cycleType'] ?? _planData?['cycle_type'] ?? 'PPL')
                      .toString()
                      .toUpperCase()
                      .replaceAll('_', ' '),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😴', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Rest Day',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Recovery is part of the program.',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 13,
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

// ─── Exercise Card ────────────────────────────────────────────────────────────

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
                  child: _Field(ctrl: restCtrl, label: 'Rest (s)'),
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
    final muscle = exercise['muscleGroup'] ?? exercise['muscle_group'] ?? '';
    final sets = exercise['sets'] ?? 3;
    final reps = exercise['repsOrTime'] ?? exercise['reps_or_time'] ?? '10-12';
    final rest = exercise['restSeconds'] ?? exercise['rest_seconds'] ?? 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showEditSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Index number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                      if (muscle.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            muscle.toString().toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sets × $reps',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.timer,
                          color: AppTheme.textSageMuted,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${rest}s',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.pencil,
                  color: AppTheme.textSageMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
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
