class WorkoutSessionHistoryData {
  final String range;
  final WorkoutSessionHistoryMeta meta;
  final WorkoutSessionHistorySummary summary;
  final WorkoutSessionHistorySeries series;
  final List<WorkoutSessionHistoryItem> sessions;

  const WorkoutSessionHistoryData({
    required this.range,
    required this.meta,
    required this.summary,
    required this.series,
    required this.sessions,
  });

  factory WorkoutSessionHistoryData.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionHistoryData(
      range: json['range'] as String? ?? '30d',
      meta: WorkoutSessionHistoryMeta.fromJson(
        (json['meta'] as Map<String, dynamic>?) ?? const {},
      ),
      summary: WorkoutSessionHistorySummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      series: WorkoutSessionHistorySeries.fromJson(
        (json['series'] as Map<String, dynamic>?) ?? const {},
      ),
      sessions: ((json['sessions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSessionHistoryItem.fromJson)
          .toList(),
    );
  }
}

class WorkoutSessionHistoryMeta {
  final String bucket;
  final String bucketLabel;
  final int rangeDays;
  final int historyLimit;
  final int points;

  const WorkoutSessionHistoryMeta({
    required this.bucket,
    required this.bucketLabel,
    required this.rangeDays,
    required this.historyLimit,
    required this.points,
  });

  factory WorkoutSessionHistoryMeta.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionHistoryMeta(
      bucket: json['bucket'] as String? ?? 'day',
      bucketLabel: json['bucketLabel'] as String? ?? 'Daily',
      rangeDays: (json['rangeDays'] as num?)?.toInt() ?? 0,
      historyLimit: (json['historyLimit'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkoutSessionHistorySummary {
  final int totalSessions;
  final int totalDurationSeconds;
  final int avgDurationSeconds;
  final int totalVolume;
  final int totalXpEarned;
  final double consistencyScore;
  final int currentStreak;
  final int longestStreak;
  final double avgSessionsPerWeek;
  final String? lastCompletedAt;

  const WorkoutSessionHistorySummary({
    required this.totalSessions,
    required this.totalDurationSeconds,
    required this.avgDurationSeconds,
    required this.totalVolume,
    required this.totalXpEarned,
    required this.consistencyScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.avgSessionsPerWeek,
    required this.lastCompletedAt,
  });

  factory WorkoutSessionHistorySummary.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionHistorySummary(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      avgDurationSeconds: (json['avgDurationSeconds'] as num?)?.toInt() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toInt() ?? 0,
      totalXpEarned: (json['totalXpEarned'] as num?)?.toInt() ?? 0,
      consistencyScore: (json['consistencyScore'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      avgSessionsPerWeek: (json['avgSessionsPerWeek'] as num?)?.toDouble() ?? 0,
      lastCompletedAt: json['lastCompletedAt'] as String?,
    );
  }
}

class WorkoutSessionHistorySeries {
  final List<WorkoutSessionHistoryPoint> volume;
  final List<WorkoutSessionHistoryPoint> duration;
  final List<WorkoutSessionHistoryPoint> frequency;

  const WorkoutSessionHistorySeries({
    required this.volume,
    required this.duration,
    required this.frequency,
  });

  factory WorkoutSessionHistorySeries.fromJson(Map<String, dynamic> json) {
    final frequencyRaw = json['frequency'] ?? json['consistency'];
    return WorkoutSessionHistorySeries(
      volume: _parsePoints(json['volume']),
      duration: _parsePoints(json['duration']),
      frequency: _parsePoints(frequencyRaw),
    );
  }

  static List<WorkoutSessionHistoryPoint> _parsePoints(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WorkoutSessionHistoryPoint.fromJson)
        .toList();
  }
}

class WorkoutSessionHistoryPoint {
  final String date;
  final String label;
  final double value;

  const WorkoutSessionHistoryPoint({
    required this.date,
    required this.label,
    required this.value,
  });

  factory WorkoutSessionHistoryPoint.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionHistoryPoint(
      date: json['date'] as String? ?? '',
      label: json['label'] as String? ?? json['date'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkoutSessionHistoryItem {
  final int id;
  final String date;
  final String? startedAt;
  final String? completedAt;
  final String dayLabel;
  final int totalDurationSeconds;
  final int totalVolume;
  final int completedExercises;
  final int totalExercises;
  final int xpEarned;

  const WorkoutSessionHistoryItem({
    required this.id,
    required this.date,
    required this.startedAt,
    required this.completedAt,
    required this.dayLabel,
    required this.totalDurationSeconds,
    required this.totalVolume,
    required this.completedExercises,
    required this.totalExercises,
    required this.xpEarned,
  });

  factory WorkoutSessionHistoryItem.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
      dayLabel: json['dayLabel'] as String? ?? 'Workout',
      totalDurationSeconds:
          (json['totalDurationSeconds'] as num?)?.toInt() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toInt() ?? 0,
      completedExercises: (json['completedExercises'] as num?)?.toInt() ?? 0,
      totalExercises: (json['totalExercises'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xpEarned'] as num?)?.toInt() ?? 0,
    );
  }
}
