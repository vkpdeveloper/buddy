import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class DietPlanPage extends ConsumerStatefulWidget {
  const DietPlanPage({super.key});

  @override
  ConsumerState<DietPlanPage> createState() => _DietPlanPageState();
}

class _DietPlanPageState extends ConsumerState<DietPlanPage>
    with TickerProviderStateMixin {
  int? _activePlanId;
  Map<String, dynamic>? _planData;
  Map<int, bool> _todayLog = {}; // mealId -> isCompleted
  bool _isLoading = true;
  int _selectedDayIndex = 0;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.listDietPlans();
      final plans = (res['data'] as List?) ?? [];
      final active = plans
          .where((p) => p['isActive'] == true || p['is_active'] == 1)
          .toList();
      if (active.isEmpty && plans.isNotEmpty) {
        _activePlanId = plans.last['id'];
      } else if (active.isNotEmpty) {
        _activePlanId = active.first['id'];
      }
      if (_activePlanId != null) {
        await _loadPlanDetail(_activePlanId!);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadPlanDetail(int id) async {
    try {
      final results = await Future.wait([
        ApiClient.getDietPlan(id),
        ApiClient.getDietLog(_todayDate),
      ]);
      final planRes = results[0];
      final logRes = results[1];
      final rawLog = (logRes['data'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _planData = planRes['data'];
        _activePlanId = id;
        _todayLog = rawLog.map((k, v) => MapEntry(int.parse(k), v == true));
        // Auto-select today's weekday (Mon=0 ... Sun=6)
        _selectedDayIndex = DateTime.now().weekday - 1;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (prev?.diet != 'done' && next.diet == 'done') {
        _loadPlans();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          _buildHeader(),
          const GeneratingBanner(watchType: 'diet'),
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
          // Macro bar skeleton
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderDark),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                4,
                (_) => ShimmerBox(width: 52, height: 32, borderRadius: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Day tabs skeleton
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                7,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShimmerBox(width: 44, height: 36, borderRadius: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Meal card skeletons
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ShimmerBox(width: 28, height: 28, borderRadius: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShimmerBox(width: 60, height: 8, borderRadius: 4),
                            const SizedBox(height: 6),
                            ShimmerBox(
                              width: double.infinity,
                              height: 13,
                              borderRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      ShimmerBox(width: 50, height: 32, borderRadius: 8),
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
    return Container(
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
                  'NUTRITION',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Diet Plan',
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final genStatus = ref.watch(generationStatusProvider);
    final isGenerating =
        genStatus.diet == 'pending' || genStatus.diet == 'generating';

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
                  LucideIcons.utensils,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isGenerating ? 'Building your plan…' : 'No diet plan yet',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textCream,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGenerating
                    ? 'We\'re crafting a personalised meal plan based on your preferences. It\'ll be ready shortly.'
                    : 'Your diet plan will appear here once it\'s been generated.',
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
    if (days.isEmpty) return _buildEmptyState();

    final plan = _planData!;
    final totalProtein = (plan['proteinG'] ?? plan['protein_g'] ?? 0)
        .toDouble();
    final totalCarbs = (plan['carbsG'] ?? plan['carbs_g'] ?? 0).toDouble();
    final totalFat = (plan['fatG'] ?? plan['fat_g'] ?? 0).toDouble();
    final totalCals = (plan['totalCalories'] ?? plan['total_calories'] ?? 0)
        .toDouble();

    return Column(
      children: [
        // Macro summary
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroChip(
                label: 'KCAL',
                value: totalCals.toInt().toString(),
                color: AppTheme.textCream,
              ),
              _MacroChip(
                label: 'PROTEIN',
                value: '${totalProtein.toInt()}g',
                color: AppTheme.primary,
              ),
              _MacroChip(
                label: 'CARBS',
                value: '${totalCarbs.toInt()}g',
                color: const Color(0xFFB5C9AD),
              ),
              _MacroChip(
                label: 'FAT',
                value: '${totalFat.toInt()}g',
                color: AppTheme.textSageMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Day tabs
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: days.length,
            itemBuilder: (ctx, i) {
              final day = days[i];
              final dayName =
                  (day['dayName'] ?? day['day_name'] ?? 'Day ${i + 1}')
                      as String;
              final isCompleted =
                  day['isCompleted'] == true || day['is_completed'] == 1;
              final isSelected = _selectedDayIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.borderDark,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isCompleted)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            LucideIcons.circle_check,
                            size: 13,
                            color: AppTheme.backgroundDark,
                          ),
                        ),
                      Text(
                        dayName.substring(0, 3).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected
                              ? AppTheme.backgroundDark
                              : AppTheme.textSageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Meals list
        Expanded(child: _buildDayMeals(days[_selectedDayIndex])),
      ],
    );
  }

  Widget _buildDayMeals(Map<String, dynamic> day) {
    final meals = (day['meals'] as List?) ?? [];
    final dayProtein = (day['proteinG'] ?? day['protein_g'] ?? 0).toDouble();
    final dayCalories = (day['totalCalories'] ?? day['total_calories'] ?? 0)
        .toDouble();
    final isCompleted = day['isCompleted'] == true || day['is_completed'] == 1;
    final dayId = day['id'] as int;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayCalories.toInt()} kcal  •  ${dayProtein.toInt()}g protein',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await ApiClient.updateDietDay(dayId, {
                      'isCompleted': !isCompleted,
                    });
                    await _loadPlanDetail(_activePlanId!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCompleted
                            ? AppTheme.primary
                            : AppTheme.borderDark,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted
                              ? LucideIcons.circle_check
                              : LucideIcons.circle,
                          color: isCompleted
                              ? AppTheme.primary
                              : AppTheme.textSageMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isCompleted ? 'DONE' : 'MARK DAY',
                          style: GoogleFonts.plusJakartaSans(
                            color: isCompleted
                                ? AppTheme.primary
                                : AppTheme.textSageMuted,
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
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final meal = meals[i];
              final mealId = meal['id'] as int;
              final isCompletedToday = _todayLog[mealId] ?? false;
              return _MealCard(
                meal: meal,
                isCompletedToday: isCompletedToday,
                onToggle: (completed) async {
                  await ApiClient.logMealCompletion(
                    _todayDate,
                    mealId,
                    completed,
                  );
                  setState(() => _todayLog[mealId] = completed);
                },
                onUpdate: () => _loadPlanDetail(_activePlanId!),
              );
            }, childCount: meals.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Meal Card ────────────────────────────────────────────────────────────────

class _MealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
  final bool isCompletedToday;
  final Future<void> Function(bool) onToggle;
  final VoidCallback onUpdate;
  const _MealCard({
    required this.meal,
    required this.isCompletedToday,
    required this.onToggle,
    required this.onUpdate,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard>
    with SingleTickerProviderStateMixin {
  late bool _isCompleted;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.isCompletedToday;
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    if (_isCompleted) _checkController.value = 1.0;
  }

  @override
  void didUpdateWidget(_MealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompletedToday != widget.isCompletedToday) {
      setState(() => _isCompleted = widget.isCompletedToday);
      if (_isCompleted) {
        _checkController.forward(from: 0);
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _toggleDone() async {
    final newValue = !_isCompleted;
    setState(() => _isCompleted = newValue);
    if (newValue) {
      _checkController.forward(from: 0);
    } else {
      _checkController.reverse();
    }
    await widget.onToggle(newValue);
  }

  List<Map<String, String>> _parseIngredients(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> list = raw is String ? jsonDecode(raw) : raw as List;
      return list
          .map(
            (e) => {
              'name': (e['name'] ?? '').toString(),
              'quantity': (e['quantity'] ?? '').toString(),
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _showDetailSheet(BuildContext context) {
    final meal = widget.meal;
    final name = meal['mealName'] ?? meal['meal_name'] ?? 'Meal';
    final calories = meal['calories'] ?? 0;
    final protein = (meal['proteinG'] ?? meal['protein_g'] ?? 0).toDouble();
    final carbs = (meal['carbsG'] ?? meal['carbs_g'] ?? 0).toDouble();
    final fat = (meal['fatG'] ?? meal['fat_g'] ?? 0).toDouble();
    final notes = meal['notes'] ?? '';
    final recipe = (meal['recipe'] ?? '').toString();
    final ingredients = _parseIngredients(meal['ingredients']);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showEditSheet(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.borderDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.pencil,
                            color: AppTheme.textSageMuted,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Macros row
                  Row(
                    children: [
                      _MacroChip(
                        label: 'KCAL',
                        value: '$calories',
                        color: AppTheme.textCream,
                      ),
                      const SizedBox(width: 16),
                      _MacroChip(
                        label: 'PROTEIN',
                        value: '${protein.toInt()}g',
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 16),
                      _MacroChip(
                        label: 'CARBS',
                        value: '${carbs.toInt()}g',
                        color: const Color(0xFFB5C9AD),
                      ),
                      const SizedBox(width: 16),
                      _MacroChip(
                        label: 'FAT',
                        value: '${fat.toInt()}g',
                        color: AppTheme.textSageMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Ingredients
                  Text(
                    'INGREDIENTS',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (ingredients.isEmpty)
                    Text(
                      'No ingredient details available.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 13,
                      ),
                    )
                  else
                    ...ingredients.asMap().entries.map((entry) {
                      final i = entry.key;
                      final ing = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 12, top: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(
                                  alpha: 0.6 - (i * 0.05).clamp(0, 0.5),
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ing['name'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textCream,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              ing['quantity'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'NOTE',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notes,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],

                  if (recipe.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'HOW TO MAKE',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSageMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MarkdownBody(
                      data: recipe,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
                          fontSize: 13,
                          height: 1.65,
                        ),
                        listBullet: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
                          fontSize: 13,
                          height: 1.65,
                        ),
                        listIndent: 16,
                        blockSpacing: 4,
                        strong: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final meal = widget.meal;
    final nameCtrl = TextEditingController(
      text: meal['mealName'] ?? meal['meal_name'] ?? '',
    );
    final calCtrl = TextEditingController(
      text: (meal['calories'] ?? 0).toString(),
    );
    final protCtrl = TextEditingController(
      text: (meal['proteinG'] ?? meal['protein_g'] ?? 0).toString(),
    );
    final carbsCtrl = TextEditingController(
      text: (meal['carbsG'] ?? meal['carbs_g'] ?? 0).toString(),
    );
    final fatCtrl = TextEditingController(
      text: (meal['fatG'] ?? meal['fat_g'] ?? 0).toString(),
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
            const SizedBox(height: 20),
            Text(
              'EDIT MACROS',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            _EditField(controller: nameCtrl, label: 'Meal Name'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _EditField(
                    controller: calCtrl,
                    label: 'Calories',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EditField(
                    controller: protCtrl,
                    label: 'Protein (g)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _EditField(
                    controller: carbsCtrl,
                    label: 'Carbs (g)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EditField(
                    controller: fatCtrl,
                    label: 'Fat (g)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await ApiClient.updateMeal(meal['id'], {
                  'mealName': nameCtrl.text,
                  'calories': int.tryParse(calCtrl.text) ?? meal['calories'],
                  'proteinG':
                      double.tryParse(protCtrl.text) ?? meal['proteinG'],
                  'carbsG': double.tryParse(carbsCtrl.text) ?? meal['carbsG'],
                  'fatG': double.tryParse(fatCtrl.text) ?? meal['fatG'],
                });
                if (context.mounted) Navigator.pop(context);
                widget.onUpdate();
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
                  'SAVE CHANGES',
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
    final meal = widget.meal;
    final name = meal['mealName'] ?? meal['meal_name'] ?? 'Meal';
    final calories = meal['calories'] ?? 0;
    final protein = (meal['proteinG'] ?? meal['protein_g'] ?? 0).toDouble();
    final mealType = (meal['mealType'] ?? meal['meal_type'] ?? '')
        .toString()
        .replaceAll('_', ' ')
        .toUpperCase();
    final ingredients = _parseIngredients(meal['ingredients']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _isCompleted
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isCompleted
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.borderDark,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetailSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Check button
                GestureDetector(
                  onTap: _toggleDone,
                  child: ScaleTransition(
                    scale: _checkAnimation.drive(Tween(begin: 0.8, end: 1.0)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? AppTheme.primary
                            : AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isCompleted
                              ? AppTheme.primary
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: _isCompleted
                          ? const Icon(
                              LucideIcons.check,
                              color: AppTheme.backgroundDark,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mealType,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          color: _isCompleted
                              ? AppTheme.textSageMuted
                              : AppTheme.textCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: _isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (ingredients.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          ingredients
                              .take(2)
                              .map((i) => i['name'] ?? '')
                              .join(', ') +
                              (ingredients.length > 2
                                  ? ' +${ingredients.length - 2} more'
                                  : ''),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$calories kcal',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${protein.toInt()}g prot',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevron_right,
                  color: AppTheme.textSageMuted.withValues(alpha: 0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textCream,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.textSageMuted,
          fontSize: 12,
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
          horizontal: 14,
          vertical: 10,
        ),
      ),
    );
  }
}
