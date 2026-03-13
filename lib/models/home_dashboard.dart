class HomeDashboardData {
  final String date;
  final int sleepMinutes;
  final int activeEnergy;
  final int steps;
  final int hydrationMl;
  final int? restingHr;
  final HomeNextMealData? nextMeal;
  final HomeWorkoutSummaryData? todayWorkoutSummary;

  const HomeDashboardData({
    required this.date,
    required this.sleepMinutes,
    required this.activeEnergy,
    required this.steps,
    required this.hydrationMl,
    required this.restingHr,
    required this.nextMeal,
    required this.todayWorkoutSummary,
  });

  factory HomeDashboardData.fromJson(Map<String, dynamic> j) {
    return HomeDashboardData(
      date: j['date'] as String? ?? '',
      sleepMinutes: (j['sleepMinutes'] as num?)?.toInt() ?? 0,
      activeEnergy: (j['activeEnergy'] as num?)?.toInt() ?? 0,
      steps: (j['steps'] as num?)?.toInt() ?? 0,
      hydrationMl: (j['hydrationMl'] as num?)?.toInt() ?? 0,
      restingHr: (j['restingHr'] as num?)?.toInt(),
      nextMeal: j['nextMeal'] is Map<String, dynamic>
          ? HomeNextMealData.fromJson(j['nextMeal'] as Map<String, dynamic>)
          : null,
      todayWorkoutSummary: j['todayWorkoutSummary'] is Map<String, dynamic>
          ? HomeWorkoutSummaryData.fromJson(
              j['todayWorkoutSummary'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class HomeNextMealData {
  final int id;
  final String type;
  final String label;
  final String mealName;
  final bool isCompleted;

  const HomeNextMealData({
    required this.id,
    required this.type,
    required this.label,
    required this.mealName,
    required this.isCompleted,
  });

  factory HomeNextMealData.fromJson(Map<String, dynamic> j) {
    return HomeNextMealData(
      id: (j['id'] as num?)?.toInt() ?? 0,
      type: j['type'] as String? ?? '',
      label: j['label'] as String? ?? '',
      mealName: j['mealName'] as String? ?? '',
      isCompleted: j['isCompleted'] == true || j['isCompleted'] == 1,
    );
  }
}

class HomeWorkoutSummaryData {
  final int dayId;
  final String dayLabel;
  final bool isRestDay;
  final int exerciseCount;
  final bool isCompletedToday;
  final bool hasInProgressSession;

  const HomeWorkoutSummaryData({
    required this.dayId,
    required this.dayLabel,
    required this.isRestDay,
    required this.exerciseCount,
    required this.isCompletedToday,
    required this.hasInProgressSession,
  });

  factory HomeWorkoutSummaryData.fromJson(Map<String, dynamic> j) {
    return HomeWorkoutSummaryData(
      dayId: (j['dayId'] as num?)?.toInt() ?? 0,
      dayLabel: j['dayLabel'] as String? ?? '',
      isRestDay: j['isRestDay'] == true || j['isRestDay'] == 1,
      exerciseCount: (j['exerciseCount'] as num?)?.toInt() ?? 0,
      isCompletedToday:
          j['isCompletedToday'] == true || j['isCompletedToday'] == 1,
      hasInProgressSession:
          j['hasInProgressSession'] == true || j['hasInProgressSession'] == 1,
    );
  }
}

class WeeklyWorkoutSummary {
  final String weekStart;
  final String weekEndExclusive;
  final int workoutsCompleted;
  final int plannedWorkouts;
  final double completionFraction;

  const WeeklyWorkoutSummary({
    required this.weekStart,
    required this.weekEndExclusive,
    required this.workoutsCompleted,
    required this.plannedWorkouts,
    required this.completionFraction,
  });

  factory WeeklyWorkoutSummary.fromJson(Map<String, dynamic> j) {
    final fraction = (j['completionFraction'] as num?)?.toDouble() ?? 0.0;
    return WeeklyWorkoutSummary(
      weekStart: j['weekStart'] as String? ?? '',
      weekEndExclusive: j['weekEndExclusive'] as String? ?? '',
      workoutsCompleted: (j['workoutsCompleted'] as num?)?.toInt() ?? 0,
      plannedWorkouts: (j['plannedWorkouts'] as num?)?.toInt() ?? 0,
      completionFraction: fraction.clamp(0.0, 1.0),
    );
  }
}

class TodayMealItem {
  final int id;
  final String type;
  final String label;
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;
  final bool isCompleted;

  const TodayMealItem({
    required this.id,
    required this.type,
    required this.label,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.isCompleted,
  });

  factory TodayMealItem.fromJson(Map<String, dynamic> j) => TodayMealItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    type: j['type'] as String? ?? '',
    label: j['label'] as String? ?? '',
    name: j['mealName'] as String? ?? j['name'] as String? ?? '',
    calories: (j['calories'] as num?)?.toInt() ?? 0,
    proteinG: (j['proteinG'] as num?)?.toDouble() ?? 0,
    carbsG: (j['carbsG'] as num?)?.toDouble() ?? 0,
    fatsG: (j['fatsG'] as num?)?.toDouble() ?? 0,
    isCompleted: j['isCompleted'] == true || j['isCompleted'] == 1,
  );
}

class TodayNutritionSummary {
  final int caloriesTarget;
  final int caloriesConsumed;
  final double proteinTargetG;
  final double proteinConsumedG;
  final double carbsTargetG;
  final double carbsConsumedG;
  final double fatsTargetG;
  final double fatsConsumedG;
  final List<TodayMealItem> meals;

  const TodayNutritionSummary({
    required this.caloriesTarget,
    required this.caloriesConsumed,
    required this.proteinTargetG,
    required this.proteinConsumedG,
    required this.carbsTargetG,
    required this.carbsConsumedG,
    required this.fatsTargetG,
    required this.fatsConsumedG,
    required this.meals,
  });

  int get caloriesRemaining =>
      (caloriesTarget - caloriesConsumed).clamp(0, caloriesTarget);
  double get proteinRemainingG =>
      (proteinTargetG - proteinConsumedG).clamp(0, proteinTargetG);
  double get carbsRemainingG =>
      (carbsTargetG - carbsConsumedG).clamp(0, carbsTargetG);
  double get fatsRemainingG =>
      (fatsTargetG - fatsConsumedG).clamp(0, fatsTargetG);
  double get calorieFraction => caloriesTarget > 0
      ? (caloriesConsumed / caloriesTarget).clamp(0.0, 1.0)
      : 0.0;
  double get proteinFraction => proteinTargetG > 0
      ? (proteinConsumedG / proteinTargetG).clamp(0.0, 1.0)
      : 0.0;
  double get carbsFraction => carbsTargetG > 0
      ? (carbsConsumedG / carbsTargetG).clamp(0.0, 1.0)
      : 0.0;
  double get fatsFraction =>
      fatsTargetG > 0 ? (fatsConsumedG / fatsTargetG).clamp(0.0, 1.0) : 0.0;

  factory TodayNutritionSummary.fromJson(Map<String, dynamic> j) {
    final meals =
        (j['meals'] as List?)
            ?.map((e) => TodayMealItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return TodayNutritionSummary(
      caloriesTarget: (j['caloriesTarget'] as num?)?.toInt() ?? 0,
      caloriesConsumed: (j['caloriesConsumed'] as num?)?.toInt() ?? 0,
      proteinTargetG: (j['proteinTargetG'] as num?)?.toDouble() ?? 0,
      proteinConsumedG: (j['proteinConsumedG'] as num?)?.toDouble() ?? 0,
      carbsTargetG: (j['carbsTargetG'] as num?)?.toDouble() ?? 0,
      carbsConsumedG: (j['carbsConsumedG'] as num?)?.toDouble() ?? 0,
      fatsTargetG: (j['fatsTargetG'] as num?)?.toDouble() ?? 0,
      fatsConsumedG: (j['fatsConsumedG'] as num?)?.toDouble() ?? 0,
      meals: meals,
    );
  }
}
