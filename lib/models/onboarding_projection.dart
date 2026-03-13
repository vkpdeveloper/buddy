class OnboardingProjection {
  final DateTime goalDate;
  final String goalDateLabel;
  final String headline;
  final String paceLabel;
  final int dailyCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const OnboardingProjection({
    required this.goalDate,
    required this.goalDateLabel,
    required this.headline,
    required this.paceLabel,
    required this.dailyCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatProjectionDate(DateTime value) {
  final now = DateTime.now();
  final label = '${_monthNames[value.month - 1]} ${value.day}';
  return value.year != now.year ? '$label, ${value.year}' : label;
}

int calculateProfileAge(DateTime birthDate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - birthDate.year;
  final hasHadBirthday =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hasHadBirthday) age -= 1;
  return age;
}

OnboardingProjection buildOnboardingProjection({
  required String goal,
  required String sex,
  required DateTime birthDate,
  required double weightKg,
  required double heightCm,
  required String activityLevel,
  required String goalPace,
  double? goalWeightKg,
}) {
  final age = calculateProfileAge(birthDate).clamp(10, 100);
  final bmr = _calculateBmr(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    sex: sex,
  );
  final tdee = _calculateTdee(bmr: bmr, activityLevel: activityLevel);
  final dailyCalories = _calculateCalories(goal: goal, tdee: tdee, bmr: bmr);
  final proteinG = _calculateProtein(goal: goal, weightKg: weightKg);
  final fatG = ((dailyCalories * 0.25) / 9).round();
  final carbsG = ((dailyCalories - (proteinG * 4) - (fatG * 9)) / 4).round();
  final goalDate = _calculateGoalDate(
    goal: goal,
    goalPace: goalPace,
    currentWeightKg: weightKg,
    goalWeightKg: goalWeightKg,
  );
  return OnboardingProjection(
    goalDate: goalDate,
    goalDateLabel: formatProjectionDate(goalDate),
    headline: 'You could hit your target by ${formatProjectionDate(goalDate)}',
    paceLabel: _paceLabel(goalPace),
    dailyCalories: dailyCalories,
    proteinG: proteinG,
    carbsG: carbsG,
    fatG: fatG,
  );
}

int _calculateBmr({
  required double weightKg,
  required double heightCm,
  required int age,
  required String sex,
}) {
  final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
  final raw = sex == 'male' ? base + 5 : base - 161;
  return (raw * 0.92).round();
}

int _calculateTdee({required int bmr, required String activityLevel}) {
  const multipliers = <String, double>{
    'sedentary': 1.20,
    'lightly_active': 1.35,
    'moderately_active': 1.48,
    'very_active': 1.65,
    'athlete': 1.80,
  };
  return (bmr * (multipliers[activityLevel] ?? 1.48)).round();
}

int _calculateCalories({
  required String goal,
  required int tdee,
  required int bmr,
}) {
  switch (goal) {
    case 'muscle_gain':
      return tdee + 250;
    case 'fat_loss':
      return (tdee - 500).clamp(bmr + 200, 10000).toInt();
    case 'recomp':
      return tdee - 150;
    case 'maintain':
    case 'endurance':
    default:
      return tdee;
  }
}

int _calculateProtein({required String goal, required double weightKg}) {
  final multiplier = switch (goal) {
    'muscle_gain' || 'recomp' => 2.2,
    'fat_loss' => 2.0,
    _ => 1.8,
  };
  return (weightKg * multiplier).round();
}

DateTime _calculateGoalDate({
  required String goal,
  required String goalPace,
  required double currentWeightKg,
  required double? goalWeightKg,
}) {
  final now = DateTime.now();
  final weeklyRate = switch (goal) {
    'fat_loss' => switch (goalPace) {
      'relaxed' => 0.25,
      'aggressive' => 0.75,
      _ => 0.5,
    },
    'muscle_gain' => switch (goalPace) {
      'relaxed' => 0.15,
      'aggressive' => 0.40,
      _ => 0.25,
    },
    _ => 0.0,
  };
  if (goalWeightKg != null && weeklyRate > 0) {
    final difference = goal == 'fat_loss'
        ? (currentWeightKg - goalWeightKg).clamp(0.0, 1000.0)
        : (goalWeightKg - currentWeightKg).clamp(0.0, 1000.0);
    final weeks = difference <= 0 ? 4.0 : difference / weeklyRate;
    return now.add(Duration(days: (weeks.clamp(4.0, 156.0) * 7).round()));
  }

  final fallbackWeeks = switch (goalPace) {
    'relaxed' => 16,
    'aggressive' => 8,
    _ => 12,
  };
  return now.add(Duration(days: fallbackWeeks * 7));
}

String _paceLabel(String goalPace) {
  return switch (goalPace) {
    'relaxed' => 'Relaxed pace',
    'aggressive' => 'Accelerated pace',
    _ => 'Steady pace',
  };
}
