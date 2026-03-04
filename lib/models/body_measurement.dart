class BodyMeasurement {
  final int id;
  final String date;
  final double? weightKg;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armsCm;
  final double? thighsCm;
  final String notes;
  final int xpEarned;
  final String? createdAt;

  const BodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armsCm,
    this.thighsCm,
    this.notes = '',
    this.xpEarned = 0,
    this.createdAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) {
    double? dbl(String camel, String snake) =>
        ((j[camel] ?? j[snake]) as num?)?.toDouble();
    int? int_(String camel, String snake) =>
        ((j[camel] ?? j[snake]) as num?)?.toInt();
    return BodyMeasurement(
      id: (j['id'] as num?)?.toInt() ?? 0,
      date: j['date'] as String? ?? '',
      weightKg: dbl('weightKg', 'weight_kg'),
      chestCm: dbl('chestCm', 'chest_cm'),
      waistCm: dbl('waistCm', 'waist_cm'),
      hipsCm: dbl('hipsCm', 'hips_cm'),
      armsCm: dbl('armsCm', 'arms_cm'),
      thighsCm: dbl('thighsCm', 'thighs_cm'),
      notes: j['notes'] as String? ?? '',
      xpEarned: int_('xpEarned', 'xp_earned') ?? 0,
      createdAt: (j['createdAt'] ?? j['created_at']) as String?,
    );
  }
}

class BodyLogResult {
  final int xpEarned;
  final double multiplier;
  final int previousLevel;
  final int newLevel;
  final int newTotalXp;
  final String levelLabel;
  final bool didLevelUp;
  final List<Map<String, dynamic>> newAchievements;

  const BodyLogResult({
    required this.xpEarned,
    required this.multiplier,
    required this.previousLevel,
    required this.newLevel,
    required this.newTotalXp,
    required this.levelLabel,
    required this.didLevelUp,
    required this.newAchievements,
  });

  factory BodyLogResult.fromJson(Map<String, dynamic> j) => BodyLogResult(
    xpEarned: (j['xpEarned'] as num?)?.toInt() ?? 0,
    multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
    previousLevel: (j['previousLevel'] as num?)?.toInt() ?? 1,
    newLevel: (j['newLevel'] as num?)?.toInt() ?? 1,
    newTotalXp: (j['newTotalXp'] as num?)?.toInt() ?? 0,
    levelLabel: j['levelLabel'] as String? ?? '',
    didLevelUp: j['didLevelUp'] as bool? ?? false,
    newAchievements: ((j['newAchievements'] as List?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList(),
  );
}
