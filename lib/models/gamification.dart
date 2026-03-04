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
  });

  factory SessionGamificationResult.fromJson(Map<String, dynamic> j) =>
      SessionGamificationResult(
        xpEarned: (j['xpEarned'] as num?)?.toInt() ?? 0,
        xpBreakdown: XpBreakdown.fromJson(j['xpBreakdown'] as Map<String, dynamic>? ?? {}),
        achievementXp: (j['achievementXp'] as num?)?.toInt() ?? 0,
        previousLevel: (j['previousLevel'] as num?)?.toInt() ?? 1,
        newLevel: (j['newLevel'] as num?)?.toInt() ?? 1,
        didLevelUp: j['didLevelUp'] as bool? ?? false,
        levelLabel: j['levelLabel'] as String? ?? '',
        currentStreak: (j['currentStreak'] as num?)?.toInt() ?? 0,
        newAchievements: ((j['newAchievements'] as List?) ?? [])
            .map((e) => AchievementData.fromJson(e as Map<String, dynamic>))
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
  });

  factory ProgressData.fromJson(Map<String, dynamic> j) => ProgressData(
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
        currentLevel: (j['currentLevel'] as num?)?.toInt() ?? 1,
        levelLabel: j['levelLabel'] as String? ?? 'Beginner',
        levelProgressFraction: (j['levelProgressFraction'] as num?)?.toDouble() ?? 0.0,
        currentStreak: (j['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (j['longestStreak'] as num?)?.toInt() ?? 0,
        totalWorkoutsCompleted: (j['totalWorkoutsCompleted'] as num?)?.toInt() ?? 0,
        lastWorkoutDate: j['lastWorkoutDate'] as String?,
        recentAchievements: ((j['recentAchievements'] as List?) ?? [])
            .map((e) => AchievementData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
