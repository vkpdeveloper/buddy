class GrowthTrendPoint {
  final String date;
  final double value;

  const GrowthTrendPoint({required this.date, required this.value});

  factory GrowthTrendPoint.fromJson(Map<String, dynamic> j) => GrowthTrendPoint(
    date: j['date'] as String? ?? '',
    value: (j['value'] as num?)?.toDouble() ?? 0,
  );
}

class GrowthMetricCard {
  final String key;
  final String label;
  final String unit;
  final String direction;
  final double? latestValue;
  final double? deltaSinceLast;
  final double? deltaSinceStart;
  final List<GrowthTrendPoint> sparkline;

  const GrowthMetricCard({
    required this.key,
    required this.label,
    required this.unit,
    required this.direction,
    required this.latestValue,
    required this.deltaSinceLast,
    required this.deltaSinceStart,
    required this.sparkline,
  });

  factory GrowthMetricCard.fromJson(Map<String, dynamic> j) => GrowthMetricCard(
    key: j['key'] as String? ?? '',
    label: j['label'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    direction: j['direction'] as String? ?? 'higher',
    latestValue: (j['latestValue'] as num?)?.toDouble(),
    deltaSinceLast: (j['deltaSinceLast'] as num?)?.toDouble(),
    deltaSinceStart: (j['deltaSinceStart'] as num?)?.toDouble(),
    sparkline: ((j['sparkline'] as List?) ?? [])
        .map((e) => GrowthTrendPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class GrowthPhotoData {
  final int id;
  final String date;
  final int? measurementId;
  final String objectKey;
  final String mimeType;
  final int sizeBytes;
  final String note;
  final String imageUrl;
  final String? createdAt;

  const GrowthPhotoData({
    required this.id,
    required this.date,
    required this.measurementId,
    required this.objectKey,
    required this.mimeType,
    required this.sizeBytes,
    required this.note,
    required this.imageUrl,
    this.createdAt,
  });

  factory GrowthPhotoData.fromJson(Map<String, dynamic> j) => GrowthPhotoData(
    id: (j['id'] as num?)?.toInt() ?? 0,
    date: j['date'] as String? ?? '',
    measurementId: (j['measurementId'] as num?)?.toInt() ??
        (j['measurement_id'] as num?)?.toInt(),
    objectKey: j['objectKey'] as String? ?? j['object_key'] as String? ?? '',
    mimeType: j['mimeType'] as String? ?? j['mime_type'] as String? ?? '',
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ??
        (j['size_bytes'] as num?)?.toInt() ??
        0,
    note: j['note'] as String? ?? '',
    imageUrl: j['imageUrl'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? j['created_at'] as String?,
  );
}

class GrowthCompositionPoint {
  final String date;
  final double fatMassKg;
  final double leanMassKg;

  const GrowthCompositionPoint({
    required this.date,
    required this.fatMassKg,
    required this.leanMassKg,
  });

  factory GrowthCompositionPoint.fromJson(Map<String, dynamic> j) =>
      GrowthCompositionPoint(
        date: j['date'] as String? ?? '',
        fatMassKg: (j['fatMassKg'] as num?)?.toDouble() ?? 0,
        leanMassKg: (j['leanMassKg'] as num?)?.toDouble() ?? 0,
      );
}

class GrowthGoalData {
  final double? weightGoalKg;
  final double? bodyFatGoalPercent;
  final double? currentWeightKg;
  final double? currentBodyFatPercent;
  final double? weightRemainingKg;
  final double? bodyFatRemainingPercent;

  const GrowthGoalData({
    required this.weightGoalKg,
    required this.bodyFatGoalPercent,
    required this.currentWeightKg,
    required this.currentBodyFatPercent,
    required this.weightRemainingKg,
    required this.bodyFatRemainingPercent,
  });

  factory GrowthGoalData.fromJson(Map<String, dynamic> j) => GrowthGoalData(
    weightGoalKg: (j['weightGoalKg'] as num?)?.toDouble() ??
        (j['weight_goal_kg'] as num?)?.toDouble(),
    bodyFatGoalPercent: (j['bodyFatGoalPercent'] as num?)?.toDouble() ??
        (j['body_fat_goal_percent'] as num?)?.toDouble(),
    currentWeightKg: (j['currentWeightKg'] as num?)?.toDouble(),
    currentBodyFatPercent: (j['currentBodyFatPercent'] as num?)?.toDouble(),
    weightRemainingKg: (j['weightRemainingKg'] as num?)?.toDouble(),
    bodyFatRemainingPercent: (j['bodyFatRemainingPercent'] as num?)?.toDouble(),
  );
}

class GrowthMilestoneEvent {
  final String key;
  final String label;
  final double value;
  final int xpReward;

  const GrowthMilestoneEvent({
    required this.key,
    required this.label,
    required this.value,
    required this.xpReward,
  });

  factory GrowthMilestoneEvent.fromJson(Map<String, dynamic> j) =>
      GrowthMilestoneEvent(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        value: (j['value'] as num?)?.toDouble() ?? 0,
        xpReward: (j['xpReward'] as num?)?.toInt() ?? 0,
      );
}

class GrowthOverviewData {
  final int totalLogs;
  final String? lastLogDate;
  final double? currentWeightKg;
  final List<GrowthTrendPoint> weightTrend;
  final int totalXp;
  final int currentLevel;
  final String levelLabel;
  final double levelProgressFraction;
  final int currentStreak;
  final List<GrowthMetricCard> metricCards;
  final GrowthPhotoData? firstPhoto;
  final GrowthPhotoData? latestPhoto;
  final List<Map<String, dynamic>> achievements;
  final List<GrowthCompositionPoint> compositionSeries;
  final GrowthGoalData goals;

  const GrowthOverviewData({
    required this.totalLogs,
    required this.lastLogDate,
    required this.currentWeightKg,
    required this.weightTrend,
    required this.totalXp,
    required this.currentLevel,
    required this.levelLabel,
    required this.levelProgressFraction,
    required this.currentStreak,
    required this.metricCards,
    required this.firstPhoto,
    required this.latestPhoto,
    required this.achievements,
    required this.compositionSeries,
    required this.goals,
  });

  factory GrowthOverviewData.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map<String, dynamic>?) ?? {};
    final level = (j['level'] as Map<String, dynamic>?) ?? {};
    final photos = (j['photos'] as Map<String, dynamic>?) ?? {};
    final composition = (j['composition'] as Map<String, dynamic>?) ?? {};

    return GrowthOverviewData(
      totalLogs: (stats['totalLogs'] as num?)?.toInt() ?? 0,
      lastLogDate: stats['lastLogDate'] as String?,
      currentWeightKg: (stats['currentWeightKg'] as num?)?.toDouble(),
      weightTrend: ((stats['weightTrend'] as List?) ?? [])
          .map((e) => GrowthTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalXp: (level['totalXp'] as num?)?.toInt() ?? 0,
      currentLevel: (level['currentLevel'] as num?)?.toInt() ?? 1,
      levelLabel: level['levelLabel'] as String? ?? 'Beginner',
      levelProgressFraction:
          (level['levelProgressFraction'] as num?)?.toDouble() ?? 0,
      currentStreak: (level['currentStreak'] as num?)?.toInt() ?? 0,
      metricCards: ((j['metricCards'] as List?) ?? [])
          .map((e) => GrowthMetricCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      firstPhoto: photos['firstPhoto'] is Map<String, dynamic>
          ? GrowthPhotoData.fromJson(photos['firstPhoto'] as Map<String, dynamic>)
          : null,
      latestPhoto: photos['latestPhoto'] is Map<String, dynamic>
          ? GrowthPhotoData.fromJson(photos['latestPhoto'] as Map<String, dynamic>)
          : null,
      achievements: ((j['achievements'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      compositionSeries: ((composition['series'] as List?) ?? [])
          .map((e) => GrowthCompositionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      goals: GrowthGoalData.fromJson(
        (j['goals'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}
