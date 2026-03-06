class PersonalRecord {
  final int id;
  final String exerciseNameNormalized;
  final String exerciseNameDisplay;
  final double weightKg;
  final int reps;
  final String achievedAt;
  final int? sessionId;

  const PersonalRecord({
    required this.id,
    required this.exerciseNameNormalized,
    required this.exerciseNameDisplay,
    required this.weightKg,
    required this.reps,
    required this.achievedAt,
    this.sessionId,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: (json['id'] as num).toInt(),
      exerciseNameNormalized: json['exerciseNameNormalized']?.toString() ??
          json['exercise_name_normalized']?.toString() ?? '',
      exerciseNameDisplay: json['exerciseNameDisplay']?.toString() ??
          json['exercise_name_display']?.toString() ?? '',
      weightKg: (json['weightKg'] ?? json['weight_kg'] as num).toDouble(),
      reps: (json['reps'] as num).toInt(),
      achievedAt: json['achievedAt']?.toString() ?? json['achieved_at']?.toString() ?? '',
      sessionId: (json['sessionId'] ?? json['session_id'] as num?)?.toInt(),
    );
  }
}
