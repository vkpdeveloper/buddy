class UserTargets {
  final int dailySteps;
  final double dailySleepTarget;
  final int dailyWaterMl;
  final double? targetWeight;
  final int dailyCalorieBurn;

  const UserTargets({
    required this.dailySteps,
    required this.dailySleepTarget,
    required this.dailyWaterMl,
    required this.targetWeight,
    required this.dailyCalorieBurn,
  });

  const UserTargets.defaults()
    : dailySteps = 10000,
      dailySleepTarget = 7.0,
      dailyWaterMl = 2500,
      targetWeight = null,
      dailyCalorieBurn = 500;

  factory UserTargets.fromJson(Map<String, dynamic> json) {
    return UserTargets(
      dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 10000,
      dailySleepTarget: (json['dailySleepTarget'] as num?)?.toDouble() ?? 7.0,
      dailyWaterMl: (json['dailyWaterMl'] as num?)?.toInt() ?? 2500,
      targetWeight: (json['targetWeight'] as num?)?.toDouble(),
      dailyCalorieBurn: (json['dailyCalorieBurn'] as num?)?.toInt() ?? 500,
    );
  }
}
