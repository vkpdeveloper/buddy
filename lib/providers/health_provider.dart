import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

final healthProvider = Provider<Health>((ref) {
  final health = Health();
  health.configure();
  return health;
});

const healthTypes = [
  HealthDataType.STEPS,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.WEIGHT,
  HealthDataType.HEIGHT,
];

const healthPermissionsList = [
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
  HealthDataAccess.READ,
];

final healthPermissionProvider = FutureProvider<bool>((ref) async {
  final health = ref.read(healthProvider);

  try {
    final has = await health.hasPermissions(
      healthTypes,
      permissions: healthPermissionsList,
    );
    return has == true;
  } catch (_) {
    return false;
  }
});

// Write-only types added to the authorization request.
const _writeTypes = [
  HealthDataType.WATER,
  HealthDataType.NUTRITION,
  HealthDataType.WORKOUT,
  HealthDataType.BODY_FAT_PERCENTAGE,
];

Future<bool> requestHealthPermissions(WidgetRef ref) async {
  final health = ref.read(healthProvider);

  try {
    // Request read permissions for existing types + write permissions for new types.
    // WEIGHT and HEIGHT get READ_WRITE so we can both read and write them.
    final allTypes = [
      ...healthTypes.where((t) => t != HealthDataType.WEIGHT && t != HealthDataType.HEIGHT),
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      ..._writeTypes,
    ];
    final allPermissions = [
      HealthDataAccess.READ, // STEPS
      HealthDataAccess.READ, // HEART_RATE
      HealthDataAccess.READ, // RESTING_HEART_RATE
      HealthDataAccess.READ, // SLEEP_SESSION
      HealthDataAccess.READ, // SLEEP_ASLEEP
      HealthDataAccess.READ, // ACTIVE_ENERGY_BURNED
      HealthDataAccess.READ, // TOTAL_CALORIES_BURNED
      HealthDataAccess.READ_WRITE, // WEIGHT
      HealthDataAccess.READ_WRITE, // HEIGHT
      HealthDataAccess.WRITE, // WATER
      HealthDataAccess.WRITE, // NUTRITION
      HealthDataAccess.WRITE, // WORKOUT
      HealthDataAccess.WRITE, // BODY_FAT_PERCENTAGE
    ];
    final granted = await health.requestAuthorization(
      allTypes,
      permissions: allPermissions,
    );
    invalidateAllHealthProviders(ref);
    return granted;
  } catch (_) {
    return false;
  }
}

void invalidateAllHealthProviders(WidgetRef ref) {
  ref.invalidate(healthPermissionProvider);
  ref.invalidate(todayStepsProvider);
  ref.invalidate(latestHeartRateProvider);
  ref.invalidate(todayActiveEnergyProvider);
  ref.invalidate(latestWeightProvider);
  ref.invalidate(latestHeightProvider);
  ref.invalidate(sleepDurationProvider);
}

final todayStepsProvider = FutureProvider<int>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return 0;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  try {
    int? steps = await health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  } catch (e) {
    return 0;
  }
});

final latestHeartRateProvider = FutureProvider<int?>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return null;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final oneWeek = now.subtract(const Duration(days: 7));
  try {
    // Prefer resting heart rate — it's the medically meaningful metric
    List<HealthDataPoint> restingData = await health.getHealthDataFromTypes(
      startTime: oneWeek,
      endTime: now,
      types: [HealthDataType.RESTING_HEART_RATE],
    );
    if (restingData.isNotEmpty) {
      restingData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final value = restingData.first.value;
      if (value is NumericHealthValue) {
        return value.numericValue.toInt();
      }
    }

    // Fall back to lowest heart rate reading today (approximates resting HR)
    final midnight = DateTime(now.year, now.month, now.day);
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.HEART_RATE],
    );
    if (data.isEmpty) return null;
    data = health.removeDuplicates(data);
    data.sort((a, b) {
      final aVal = (a.value is NumericHealthValue)
          ? (a.value as NumericHealthValue).numericValue
          : double.infinity;
      final bVal = (b.value is NumericHealthValue)
          ? (b.value as NumericHealthValue).numericValue
          : double.infinity;
      return aVal.compareTo(bVal);
    });
    final value = data.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toInt();
    }
    return null;
  } catch (e) {
    return null;
  }
});

final todayActiveEnergyProvider = FutureProvider<double>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return 0.0;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);

  try {
    // Prefer TOTAL_CALORIES_BURNED (BMR + activity) — this gives a meaningful
    // number at any time of day, not just when exercising.
    List<HealthDataPoint> totalData = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.TOTAL_CALORIES_BURNED],
    );
    totalData = health.removeDuplicates(totalData);
    double totalEnergy = 0.0;
    for (var point in totalData) {
      final value = point.value;
      if (value is NumericHealthValue) {
        totalEnergy += value.numericValue.toDouble();
      }
    }

    // Fall back to ACTIVE_ENERGY_BURNED if total is unavailable.
    // Some devices only record active (exercise) calories.
    if (totalEnergy == 0.0) {
      List<HealthDataPoint> activeData = await health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      activeData = health.removeDuplicates(activeData);
      for (var point in activeData) {
        final value = point.value;
        if (value is NumericHealthValue) {
          totalEnergy += value.numericValue.toDouble();
        }
      }
    }

    return totalEnergy;
  } catch (e) {
    return 0.0;
  }
});

final latestWeightProvider = FutureProvider<double?>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return null;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final oneYear = now.subtract(const Duration(days: 365));
  try {
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: oneYear,
      endTime: now,
      types: [HealthDataType.WEIGHT],
    );
    if (data.isEmpty) return null;
    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final value = data.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  } catch (e) {
    return null;
  }
});

final latestHeightProvider = FutureProvider<double?>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return null;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final oneYear = now.subtract(const Duration(days: 365));
  try {
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: oneYear,
      endTime: now,
      types: [HealthDataType.HEIGHT],
    );
    if (data.isEmpty) return null;
    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final value = data.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble() * 100;
    }
    return null;
  } catch (e) {
    return null;
  }
});

final sleepDurationProvider = FutureProvider<Duration>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return Duration.zero;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  // Use subtraction to safely get yesterday evening regardless of month boundaries
  final sleepStart = now.subtract(const Duration(hours: 18)); // ~yesterday 8pm
  final sleepEnd = DateTime(now.year, now.month, now.day, 14, 0); // today 2pm

  try {
    // Try SLEEP_SESSION first (parent record, most common)
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: sleepStart,
      endTime: sleepEnd,
      types: [HealthDataType.SLEEP_SESSION],
    );
    data = health.removeDuplicates(data);

    Duration totalSleep = Duration.zero;
    for (var point in data) {
      totalSleep += point.dateTo.difference(point.dateFrom);
    }

    if (totalSleep > Duration.zero) return totalSleep;

    // Fall back to SLEEP_ASLEEP sub-stage records (Samsung, Garmin, etc.)
    List<HealthDataPoint> stageData = await health.getHealthDataFromTypes(
      startTime: sleepStart,
      endTime: sleepEnd,
      types: [HealthDataType.SLEEP_ASLEEP],
    );
    stageData = health.removeDuplicates(stageData);
    for (var point in stageData) {
      totalSleep += point.dateTo.difference(point.dateFrom);
    }
    return totalSleep;
  } catch (e) {
    return Duration.zero;
  }
});

// ── Health Connect write helpers ─────────────────────────────────────────────
// All helpers are fire-and-forget: they silently swallow errors so a missing
// permission or unavailable HC installation never interrupts the main flow.

Future<void> writeHydrationToHC({double ml = 250}) async {
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: ml,
      type: HealthDataType.WATER,
      startTime: now,
      unit: HealthDataUnit.MILLILITER,
    );
  } catch (_) {}
}

Future<void> writeNutritionToHC({
  required double calories,
  required double proteinG,
  required double carbsG,
  required double fatG,
  String name = 'Meal',
}) async {
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeMeal(
      mealType: MealType.UNKNOWN,
      startTime: now,
      endTime: now,
      caloriesConsumed: calories,
      carbohydrates: carbsG,
      protein: proteinG,
      fatTotal: fatG,
      name: name,
    );
  } catch (_) {}
}

Future<void> writeWorkoutToHC({
  required DateTime start,
  required DateTime end,
  required String dayLabel,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final weightKg = prefs.getDouble('user_weight') ?? 70.0;
    final health = Health();
    final activityType = _activityTypeFromLabel(dayLabel);
    final durationSeconds = end.difference(start).inSeconds;
    final kcal = _estimateWorkoutCalories(activityType, durationSeconds, weightKg);
    await health.writeWorkoutData(
      activityType: activityType,
      start: start,
      end: end,
      totalEnergyBurned: kcal,
      title: dayLabel,
    );
  } catch (_) {}
}

Future<void> writeWeightToHC(double kg) async {
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: kg,
      type: HealthDataType.WEIGHT,
      startTime: now,
      unit: HealthDataUnit.KILOGRAM,
    );
  } catch (_) {}
}

Future<void> writeBodyFatToHC(double percent) async {
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: percent,
      type: HealthDataType.BODY_FAT_PERCENTAGE,
      startTime: now,
      unit: HealthDataUnit.PERCENT,
    );
  } catch (_) {}
}

Future<void> writeHeightToHC(double cm) async {
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: cm / 100.0,
      type: HealthDataType.HEIGHT,
      startTime: now,
      unit: HealthDataUnit.METER,
    );
  } catch (_) {}
}

HealthWorkoutActivityType _activityTypeFromLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('run') || l.contains('jog')) {
    return HealthWorkoutActivityType.RUNNING;
  }
  if (l.contains('yoga') || l.contains('stretch') || l.contains('flexibility')) {
    return HealthWorkoutActivityType.YOGA;
  }
  if (l.contains('hiit') || l.contains('circuit')) {
    return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
  }
  if (l.contains('cycling') || l.contains('bike') || l.contains('spin')) {
    return HealthWorkoutActivityType.BIKING;
  }
  if (l.contains('swim')) {
    return HealthWorkoutActivityType.SWIMMING;
  }
  if (l.contains('walk') || l.contains('hike')) {
    return HealthWorkoutActivityType.WALKING;
  }
  return HealthWorkoutActivityType.STRENGTH_TRAINING;
}

int _estimateWorkoutCalories(
  HealthWorkoutActivityType type,
  int durationSeconds,
  double weightKg,
) {
  double met = 5.0;
  if (type == HealthWorkoutActivityType.RUNNING) {
    met = 9.0;
  } else if (type == HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING) {
    met = 8.0;
  } else if (type == HealthWorkoutActivityType.BIKING) {
    met = 7.0;
  } else if (type == HealthWorkoutActivityType.SWIMMING) {
    met = 6.0;
  } else if (type == HealthWorkoutActivityType.WALKING) {
    met = 3.5;
  } else if (type == HealthWorkoutActivityType.YOGA) {
    met = 2.5;
  }
  return (met * weightKg * (durationSeconds / 3600)).round();
}
