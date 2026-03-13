import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/models/home_dashboard.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/services/logs_service.dart';
import 'package:buddy/services/workout_service.dart';

String _todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final res = await LogsService.getHomeSummary(_todayDate());
  return HomeDashboardData.fromJson(res['data'] as Map<String, dynamic>);
});

final weeklyWorkoutSummaryProvider = FutureProvider<WeeklyWorkoutSummary>((
  ref,
) async {
  final res = await WorkoutService.getWeeklyWorkoutSummary();
  return WeeklyWorkoutSummary.fromJson(res['data'] as Map<String, dynamic>);
});

TodayNutritionSummary _emptyNutrition() => const TodayNutritionSummary(
  caloriesTarget: 0,
  caloriesConsumed: 0,
  proteinTargetG: 0,
  proteinConsumedG: 0,
  carbsTargetG: 0,
  carbsConsumedG: 0,
  fatsTargetG: 0,
  fatsConsumedG: 0,
  meals: [],
);

final todayNutritionSummaryProvider =
    FutureProvider.family<TodayNutritionSummary, String>((ref, date) async {
  // 1. Find the active diet plan
  final plansRes = await DietService.listDietPlans();
  final plans = (plansRes['data'] as List?) ?? [];
  int? planId;
  final active = plans
      .where((p) => p['isActive'] == true || p['is_active'] == 1)
      .toList();
  if (active.isNotEmpty) {
    planId = active.first['id'] as int;
  } else if (plans.isNotEmpty) {
    planId = plans.last['id'] as int;
  }
  if (planId == null) return _emptyNutrition();

  // 2. Fetch plan details + today's log in parallel
  final results = await Future.wait([
    DietService.getDietPlan(planId),
    DietService.getDietLog(date),
  ]);
  final planData = results[0]['data'] as Map<String, dynamic>;
  final logData = (results[1]['data'] as Map<String, dynamic>?) ?? {};

  // 3. Parse completion map
  final dynamic completionRaw = logData['completionMap'] ?? {};
  final completionMap = <int, bool>{};
  if (completionRaw is Map) {
    completionRaw.forEach((key, value) {
      final id = int.tryParse(key.toString());
      if (id != null) completionMap[id] = value == true;
    });
  }

  // 4. Parse actual logs (user-logged overrides of planned meal nutrition)
  final actualLogsRaw = (logData['actualLogs'] as Map?) ?? {};
  final actualMap = <int, Map<String, dynamic>>{};
  actualLogsRaw.forEach((key, value) {
    final id = int.tryParse(key.toString());
    if (id != null && value is Map) {
      actualMap[id] = Map<String, dynamic>.from(value);
    }
  });

  // 5. Get today's meals from the plan
  final nowDayIndex = DateTime.now().weekday - 1;
  final days = (planData['days'] as List?) ?? [];
  if (days.isEmpty) return _emptyNutrition();

  final dayIndex = nowDayIndex.clamp(0, days.length - 1);
  final day = days[dayIndex] as Map<String, dynamic>;
  final mealsRaw = ((day['meals'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  // 6. Build TodayMealItem list with completion + actual log data
  final meals = mealsRaw.map((m) {
    final id = (m['id'] as num?)?.toInt() ?? 0;
    final isCompleted = completionMap[id] ?? false;
    final actual = actualMap[id];

    final planCalories = (m['calories'] as num?)?.toInt() ?? 0;
    final planProtein = (m['proteinG'] as num?)?.toDouble() ?? 0;
    final planCarbs = (m['carbsG'] as num?)?.toDouble() ?? 0;
    final planFats = ((m['fatG'] ?? m['fatsG']) as num?)?.toDouble() ?? 0;

    final mealType = (m['mealType'] ?? m['meal_type'] ?? '').toString();
    final mealTime = (m['mealTime'] ?? m['meal_time'] ?? '').toString();
    final label = mealTime.isNotEmpty
        ? '$mealTime • ${mealType.toUpperCase().replaceAll('_', ' ')}'
        : mealType.toUpperCase().replaceAll('_', ' ');

    return TodayMealItem(
      id: id,
      type: mealType,
      label: label,
      name: (m['mealName'] ?? m['meal_name'] ?? '').toString(),
      calories: actual != null
          ? (actual['calories'] as num?)?.toInt() ?? planCalories
          : planCalories,
      proteinG: actual != null
          ? (actual['proteinG'] as num?)?.toDouble() ?? planProtein
          : planProtein,
      carbsG: actual != null
          ? (actual['carbsG'] as num?)?.toDouble() ?? planCarbs
          : planCarbs,
      fatsG: actual != null
          ? ((actual['fatG'] ?? actual['fatsG']) as num?)?.toDouble() ??
              planFats
          : planFats,
      isCompleted: isCompleted,
    );
  }).toList();

  // 7. Compute consumed totals from completed meals
  int caloriesConsumed = 0;
  double proteinConsumed = 0, carbsConsumed = 0, fatsConsumed = 0;
  for (final meal in meals) {
    if (meal.isCompleted) {
      caloriesConsumed += meal.calories;
      proteinConsumed += meal.proteinG;
      carbsConsumed += meal.carbsG;
      fatsConsumed += meal.fatsG;
    }
  }

  // Use plan-level day totals when available (more accurate than summing meal calories)
  final caloriesTarget =
      ((day['totalCalories'] ?? day['total_calories']) as num?)?.toInt() ??
      meals.fold<int>(0, (s, m) => s + m.calories);
  final proteinTarget =
      ((day['proteinG'] ?? day['protein_g']) as num?)?.toDouble() ??
      meals.fold<double>(0.0, (s, m) => s + m.proteinG);
  final carbsTarget =
      ((day['carbsG'] ?? day['carbs_g']) as num?)?.toDouble() ??
      meals.fold<double>(0.0, (s, m) => s + m.carbsG);
  final fatsTarget =
      ((day['fatG'] ?? day['fat_g']) as num?)?.toDouble() ??
      meals.fold<double>(0.0, (s, m) => s + m.fatsG);

  return TodayNutritionSummary(
    caloriesTarget: caloriesTarget,
    caloriesConsumed: caloriesConsumed,
    proteinTargetG: proteinTarget,
    proteinConsumedG: proteinConsumed,
    carbsTargetG: carbsTarget,
    carbsConsumedG: carbsConsumed,
    fatsTargetG: fatsTarget,
    fatsConsumedG: fatsConsumed,
    meals: meals,
  );
});
