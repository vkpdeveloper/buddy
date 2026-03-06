class XpBreakdown {
  final int fromExercises;
  final int disciplineBonus;
  final int completionBonus;
  final int durationBonus;
  final int subtotal;
  final double multiplier;
  final int total;

  const XpBreakdown({
    required this.fromExercises,
    required this.disciplineBonus,
    required this.completionBonus,
    required this.durationBonus,
    required this.subtotal,
    required this.multiplier,
    required this.total,
  });

  factory XpBreakdown.fromJson(Map<String, dynamic> j) => XpBreakdown(
    fromExercises: (j['fromExercises'] as num?)?.toInt() ?? 0,
    disciplineBonus: (j['disciplineBonus'] as num?)?.toInt() ?? 0,
    completionBonus: (j['completionBonus'] as num?)?.toInt() ?? 0,
    durationBonus: (j['durationBonus'] as num?)?.toInt() ?? 0,
    subtotal: (j['subtotal'] as num?)?.toInt() ?? 0,
    multiplier: (j['multiplier'] as num?)?.toDouble() ?? 1.0,
    total: (j['total'] as num?)?.toInt() ?? 0,
  );
}

class AchievementData {
  final int id;
  final String slug;
  final String name;
  final String description;
  final int xpReward;
  final String iconName;
  final bool isUnlocked;
  final String? unlockedAt;

  const AchievementData({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.xpReward,
    required this.iconName,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory AchievementData.fromJson(Map<String, dynamic> j) => AchievementData(
    id: (j['id'] as num?)?.toInt() ?? 0,
    slug: j['slug'] as String? ?? '',
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    xpReward: (j['xpReward'] as num?)?.toInt() ?? 0,
    iconName: j['iconName'] as String? ?? 'emoji_events',
    isUnlocked: j['isUnlocked'] as bool? ?? false,
    unlockedAt: j['unlockedAt'] as String?,
  );
}

class PersonalRecordResult {
  final String exerciseNameDisplay;
  final double weightKg;
  final int reps;

  const PersonalRecordResult({
    required this.exerciseNameDisplay,
    required this.weightKg,
    required this.reps,
  });

  factory PersonalRecordResult.fromJson(Map<String, dynamic> j) =>
      PersonalRecordResult(
        exerciseNameDisplay: j['exerciseNameDisplay'] as String? ?? '',
        weightKg: (j['weightKg'] as num?)?.toDouble() ?? 0.0,
        reps: (j['reps'] as num?)?.toInt() ?? 0,
      );
}

class SessionGamificationResult {
  final int xpEarned;
  final XpBreakdown xpBreakdown;
  final int achievementXp;
  final int previousLevel;
  final int newLevel;
  final bool didLevelUp;
  final String levelLabel;
  final int currentStreak;
  final List<AchievementData> newAchievements;
  final List<PersonalRecordResult> newPrs;

  const SessionGamificationResult({
    required this.xpEarned,
    required this.xpBreakdown,
    required this.achievementXp,
    required this.previousLevel,
    required this.newLevel,
    required this.didLevelUp,
    required this.levelLabel,
    required this.currentStreak,
    required this.newAchievements,
    this.newPrs = const [],
  });

  factory SessionGamificationResult.fromJson(Map<String, dynamic> j) =>
      SessionGamificationResult(
        xpEarned: (j['xpEarned'] as num?)?.toInt() ?? 0,
        xpBreakdown: XpBreakdown.fromJson(
          j['xpBreakdown'] as Map<String, dynamic>? ?? {},
        ),
        achievementXp: (j['achievementXp'] as num?)?.toInt() ?? 0,
        previousLevel: (j['previousLevel'] as num?)?.toInt() ?? 1,
        newLevel: (j['newLevel'] as num?)?.toInt() ?? 1,
        didLevelUp: j['didLevelUp'] as bool? ?? false,
        levelLabel: j['levelLabel'] as String? ?? '',
        currentStreak: (j['currentStreak'] as num?)?.toInt() ?? 0,
        newAchievements: ((j['newAchievements'] as List?) ?? [])
            .map((e) => AchievementData.fromJson(e as Map<String, dynamic>))
            .toList(),
        newPrs: ((j['newPrs'] as List?) ?? [])
            .map((e) => PersonalRecordResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ProgressData {
  final int totalXp;
  final int currentLevel;
  final String levelLabel;
  final double levelProgressFraction;
  final int currentStreak;
  final int longestStreak;
  final int totalWorkoutsCompleted;
  final String? lastWorkoutDate;
  final List<AchievementData> recentAchievements;
  final SoloLeaderboardData? soloLeaderboard;

  const ProgressData({
    required this.totalXp,
    required this.currentLevel,
    required this.levelLabel,
    required this.levelProgressFraction,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalWorkoutsCompleted,
    this.lastWorkoutDate,
    required this.recentAchievements,
    this.soloLeaderboard,
  });

  factory ProgressData.fromJson(Map<String, dynamic> j) => ProgressData(
    totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
    currentLevel: (j['currentLevel'] as num?)?.toInt() ?? 1,
    levelLabel: j['levelLabel'] as String? ?? 'Beginner',
    levelProgressFraction:
        (j['levelProgressFraction'] as num?)?.toDouble() ?? 0.0,
    currentStreak: (j['currentStreak'] as num?)?.toInt() ?? 0,
    longestStreak: (j['longestStreak'] as num?)?.toInt() ?? 0,
    totalWorkoutsCompleted: (j['totalWorkoutsCompleted'] as num?)?.toInt() ?? 0,
    lastWorkoutDate: j['lastWorkoutDate'] as String?,
    recentAchievements: ((j['recentAchievements'] as List?) ?? [])
        .map((e) => AchievementData.fromJson(e as Map<String, dynamic>))
        .toList(),
    soloLeaderboard: j['soloLeaderboard'] is Map<String, dynamic>
        ? SoloLeaderboardData.fromJson(
            j['soloLeaderboard'] as Map<String, dynamic>,
          )
        : null,
  );
}

class SoloLeaderboardData {
  final String metricLabel;
  final String metricFormula;
  final List<WeeklyLeaderboardEntryData> topWeeks;
  final WeeklyLeaderboardCurrentData currentWeek;
  final WeeklyTrajectoryData trajectory;
  final bool challengeRewardsEnabled;
  final bool streakProtectionEnabled;
  final String generatedAt;

  const SoloLeaderboardData({
    required this.metricLabel,
    required this.metricFormula,
    required this.topWeeks,
    required this.currentWeek,
    required this.trajectory,
    required this.challengeRewardsEnabled,
    required this.streakProtectionEnabled,
    required this.generatedAt,
  });

  factory SoloLeaderboardData.fromJson(
    Map<String, dynamic> j,
  ) => SoloLeaderboardData(
    metricLabel:
        (j['metric'] as Map<String, dynamic>?)?['label'] as String? ??
        'Weekly Momentum Score',
    metricFormula:
        (j['metric'] as Map<String, dynamic>?)?['formula'] as String? ?? '',
    topWeeks: ((j['topWeeks'] as List?) ?? [])
        .map(
          (e) => WeeklyLeaderboardEntryData.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    currentWeek: WeeklyLeaderboardCurrentData.fromJson(
      j['currentWeek'] as Map<String, dynamic>? ?? const {},
    ),
    trajectory: WeeklyTrajectoryData.fromJson(
      j['trajectory'] as Map<String, dynamic>? ?? const {},
    ),
    challengeRewardsEnabled:
        (j['phase2'] as Map<String, dynamic>?)?['challengeRewardsEnabled'] ==
        true,
    streakProtectionEnabled:
        (j['phase2'] as Map<String, dynamic>?)?['streakProtectionEnabled'] ==
        true,
    generatedAt: j['generatedAt'] as String? ?? '',
  );
}

class WeeklyLeaderboardEntryData {
  final int rank;
  final String weekStart;
  final String weekEndExclusive;
  final int sessionsCompleted;
  final int totalXp;
  final int plannedWorkouts;
  final double completionFraction;
  final int score;
  final int challengeXp;
  final bool streakProtectionUsed;

  const WeeklyLeaderboardEntryData({
    required this.rank,
    required this.weekStart,
    required this.weekEndExclusive,
    required this.sessionsCompleted,
    required this.totalXp,
    required this.plannedWorkouts,
    required this.completionFraction,
    required this.score,
    required this.challengeXp,
    required this.streakProtectionUsed,
  });

  factory WeeklyLeaderboardEntryData.fromJson(Map<String, dynamic> j) =>
      WeeklyLeaderboardEntryData(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        weekStart: j['weekStart'] as String? ?? '',
        weekEndExclusive: j['weekEndExclusive'] as String? ?? '',
        sessionsCompleted: (j['sessionsCompleted'] as num?)?.toInt() ?? 0,
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
        plannedWorkouts: (j['plannedWorkouts'] as num?)?.toInt() ?? 0,
        completionFraction: ((j['completionFraction'] as num?)?.toDouble() ?? 0)
            .clamp(0.0, 1.0),
        score: (j['score'] as num?)?.toInt() ?? 0,
        challengeXp: (j['challengeXp'] as num?)?.toInt() ?? 0,
        streakProtectionUsed: j['streakProtectionUsed'] == true,
      );
}

class WeeklyLeaderboardCurrentData {
  final String weekStart;
  final String weekEndExclusive;
  final int sessionsCompleted;
  final int totalXp;
  final int plannedWorkouts;
  final double completionFraction;
  final int score;
  final int challengeXp;
  final bool streakProtectionUsed;
  final int? rank;
  final int projectedScore;
  final int projectedGapToBest;

  const WeeklyLeaderboardCurrentData({
    required this.weekStart,
    required this.weekEndExclusive,
    required this.sessionsCompleted,
    required this.totalXp,
    required this.plannedWorkouts,
    required this.completionFraction,
    required this.score,
    required this.challengeXp,
    required this.streakProtectionUsed,
    this.rank,
    required this.projectedScore,
    required this.projectedGapToBest,
  });

  factory WeeklyLeaderboardCurrentData.fromJson(Map<String, dynamic> j) =>
      WeeklyLeaderboardCurrentData(
        weekStart: j['weekStart'] as String? ?? '',
        weekEndExclusive: j['weekEndExclusive'] as String? ?? '',
        sessionsCompleted: (j['sessionsCompleted'] as num?)?.toInt() ?? 0,
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
        plannedWorkouts: (j['plannedWorkouts'] as num?)?.toInt() ?? 0,
        completionFraction: ((j['completionFraction'] as num?)?.toDouble() ?? 0)
            .clamp(0.0, 1.0),
        score: (j['score'] as num?)?.toInt() ?? 0,
        challengeXp: (j['challengeXp'] as num?)?.toInt() ?? 0,
        streakProtectionUsed: j['streakProtectionUsed'] == true,
        rank: (j['rank'] as num?)?.toInt(),
        projectedScore: (j['projectedScore'] as num?)?.toInt() ?? 0,
        projectedGapToBest: (j['projectedGapToBest'] as num?)?.toInt() ?? 0,
      );
}

class WeeklyTrajectoryData {
  final int daysElapsed;
  final int daysRemaining;
  final int currentScore;
  final int projectedScore;
  final int? currentRank;
  final int weeksTracked;

  const WeeklyTrajectoryData({
    required this.daysElapsed,
    required this.daysRemaining,
    required this.currentScore,
    required this.projectedScore,
    this.currentRank,
    required this.weeksTracked,
  });

  factory WeeklyTrajectoryData.fromJson(Map<String, dynamic> j) =>
      WeeklyTrajectoryData(
        daysElapsed: (j['daysElapsed'] as num?)?.toInt() ?? 0,
        daysRemaining: (j['daysRemaining'] as num?)?.toInt() ?? 0,
        currentScore: (j['currentScore'] as num?)?.toInt() ?? 0,
        projectedScore: (j['projectedScore'] as num?)?.toInt() ?? 0,
        currentRank: (j['currentRank'] as num?)?.toInt(),
        weeksTracked: (j['weeksTracked'] as num?)?.toInt() ?? 0,
      );
}
