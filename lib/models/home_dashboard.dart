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

  const HomeWorkoutSummaryData({
    required this.dayId,
    required this.dayLabel,
    required this.isRestDay,
    required this.exerciseCount,
    required this.isCompletedToday,
  });

  factory HomeWorkoutSummaryData.fromJson(Map<String, dynamic> j) {
    return HomeWorkoutSummaryData(
      dayId: (j['dayId'] as num?)?.toInt() ?? 0,
      dayLabel: j['dayLabel'] as String? ?? '',
      isRestDay: j['isRestDay'] == true || j['isRestDay'] == 1,
      exerciseCount: (j['exerciseCount'] as num?)?.toInt() ?? 0,
      isCompletedToday:
          j['isCompletedToday'] == true || j['isCompletedToday'] == 1,
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
