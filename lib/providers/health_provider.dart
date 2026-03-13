import 'package:buddy/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
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

const _dashboardReadTypes = [
  HealthDataType.STEPS,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
];
// Write-only types added to the authorization request.
const _writeTypes = [
  HealthDataType.WATER,
  HealthDataType.NUTRITION,
  HealthDataType.WORKOUT,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.LEAN_BODY_MASS,
];
const _permissionRefreshAttempts = 6;
const _permissionRefreshInterval = Duration(milliseconds: 350);
const _iosHealthAuthorizationRequestedKey =
    'ios_health_authorization_requested';

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

Future<bool> _hasAnyDashboardReadPermission(Health health) async {
  for (final type in _dashboardReadTypes) {
    try {
      final has = await health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
      if (has == true) return true;
    } catch (_) {
      // Keep checking other types; some permissions may be unsupported/unavailable.
    }
  }

  return false;
}

Future<bool> _hasAllHealthReadPermissions(Health health) async {
  try {
    final has = await health.hasPermissions(
      healthTypes,
      permissions: healthPermissionsList,
    );
    return has == true;
  } catch (_) {
    return false;
  }
}

Future<bool> _hasAnyWritePermission(Health health) async {
  for (final type in _writeTypes) {
    try {
      final has = await health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.WRITE],
      );
      if (has == true) return true;
    } catch (_) {
      // Keep checking other types; some permissions may be unsupported/unavailable.
    }
  }

  return false;
}

Future<bool> _getCachedIosAuthorizationRequestState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_iosHealthAuthorizationRequestedKey) ?? false;
}

Future<void> _setCachedIosAuthorizationRequestState(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_iosHealthAuthorizationRequestedKey, value);
}

Future<bool> _hasGrantedHealthAccess(Health health) async {
  if (_isIOS) {
    final hasWritePermission = await _hasAnyWritePermission(health);
    if (hasWritePermission) {
      await _setCachedIosAuthorizationRequestState(true);
      return true;
    }

    // HealthKit does not disclose read authorization state on iOS, so the
    // best available signal is whether this app has already completed an
    // authorization request for Apple Health.
    return _getCachedIosAuthorizationRequestState();
  }

  return await _hasAnyDashboardReadPermission(health) ||
      await _hasAllHealthReadPermissions(health);
}

Future<bool> _waitForGrantedHealthAccess(Health health) async {
  for (var attempt = 0; attempt < _permissionRefreshAttempts; attempt++) {
    if (await _hasGrantedHealthAccess(health)) {
      return true;
    }

    if (attempt < _permissionRefreshAttempts - 1) {
      await Future<void>.delayed(_permissionRefreshInterval);
    }
  }

  return false;
}

final healthPermissionProvider = FutureProvider<bool>((ref) async {
  final health = ref.read(healthProvider);
  return _hasGrantedHealthAccess(health);
});

Future<bool> refreshHealthPermissionState(
  WidgetRef ref, {
  bool waitForSettledState = false,
}) async {
  final health = ref.read(healthProvider);

  if (waitForSettledState) {
    await _waitForGrantedHealthAccess(health);
  }

  invalidateAllHealthProviders(ref);

  try {
    return await ref.read(healthPermissionProvider.future);
  } catch (_) {
    return false;
  }
}

Future<bool> requestHealthPermissions(WidgetRef ref) async {
  final health = ref.read(healthProvider);
  var requestCompleted = false;

  try {
    if (!_isIOS) {
      final alreadyGranted = await _hasGrantedHealthAccess(health);
      if (alreadyGranted) {
        return await refreshHealthPermissionState(ref);
      }
    }

    // Request read permissions for existing types + write permissions for new types.
    // WEIGHT and HEIGHT get READ_WRITE so we can both read and write them.
    final allTypes = [
      ...healthTypes.where(
        (t) => t != HealthDataType.WEIGHT && t != HealthDataType.HEIGHT,
      ),
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
      HealthDataAccess.WRITE, // LEAN_BODY_MASS
    ];
    requestCompleted = await health.requestAuthorization(
      allTypes,
      permissions: allPermissions,
    );

    if (_isIOS && requestCompleted) {
      await _setCachedIosAuthorizationRequestState(true);
    }
  } catch (error) {
    AppLogger.error('Health permission request failed', error);
    // Fall through to a final permission re-check below.
  }

  if (_isIOS && requestCompleted) {
    invalidateAllHealthProviders(ref);
    try {
      return await ref.read(healthPermissionProvider.future);
    } catch (error) {
      AppLogger.error('Health permission refresh failed', error);
      return true;
    }
  }

  try {
    return await refreshHealthPermissionState(ref, waitForSettledState: true);
  } catch (error) {
    AppLogger.error('Health permission state refresh failed', error);
    if (_isIOS && await _getCachedIosAuthorizationRequestState()) {
      return await refreshHealthPermissionState(ref);
    }
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
    List<HealthDataPoint> activeData = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
    );
    activeData = health.removeDuplicates(activeData);

    List<HealthDataPoint> totalData = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.TOTAL_CALORIES_BURNED],
    );
    totalData = health.removeDuplicates(totalData);

    double activeEnergy = 0.0;
    for (var point in activeData) {
      final value = point.value;
      if (value is NumericHealthValue) {
        activeEnergy += value.numericValue.toDouble();
      }
    }
    if (activeEnergy > 0) return activeEnergy;

    double totalEnergy = 0.0;
    for (var point in totalData) {
      final value = point.value;
      if (value is NumericHealthValue) {
        totalEnergy += value.numericValue.toDouble();
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

/// Weight from onboarding profile stored in SharedPreferences.
/// Available without Health Connect permission.
final profileWeightKgProvider = FutureProvider<double?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('user_weight');
});

/// Height (cm) from onboarding profile stored in SharedPreferences.
/// Available without Health Connect permission.
final profileHeightCmProvider = FutureProvider<double?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('user_height');
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

Future<void> writeHydrationToHC({required double ml}) async {
  // Health Connect stores HydrationRecord in liters (Volume.liters(value)).
  // Pass the value in liters; no chunking needed since 0.25 L << 100 L limit.
  AppLogger.info('[HC] writeHydrationToHC: ${ml}ml (${ml / 1000.0}L)');
  try {
    final health = Health();
    final now = DateTime.now();
    final start = now.subtract(const Duration(seconds: 2));
    await health.writeHealthData(
      value: ml / 1000.0,
      type: HealthDataType.WATER,
      startTime: start,
      endTime: start.add(const Duration(seconds: 1)),
      unit: HealthDataUnit.LITER,
    );
    AppLogger.info('[HC] writeHydrationToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeHydrationToHC failed', e);
  }
}

Future<void> writeNutritionToHC({
  required double calories,
  required double proteinG,
  required double carbsG,
  required double fatG,
  String name = 'Meal',
}) async {
  AppLogger.info(
    '[HC] writeNutritionToHC: $name — ${calories}kcal, protein=${proteinG}g, carbs=${carbsG}g, fat=${fatG}g',
  );
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeMeal(
      mealType: MealType.UNKNOWN,
      startTime: now,
      endTime: now.add(const Duration(seconds: 1)),
      caloriesConsumed: calories,
      carbohydrates: carbsG,
      protein: proteinG,
      fatTotal: fatG,
      name: name,
    );
    AppLogger.info('[HC] writeNutritionToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeNutritionToHC failed', e);
  }
}

Future<void> writeWorkoutToHC({
  required DateTime start,
  required DateTime end,
  required String dayLabel,
}) async {
  AppLogger.info('[HC] writeWorkoutToHC: "$dayLabel" from $start to $end');
  try {
    final prefs = await SharedPreferences.getInstance();
    final weightKg = prefs.getDouble('user_weight') ?? 70.0;
    final health = Health();
    final activityType = _activityTypeFromLabel(dayLabel);
    final durationSeconds = end.difference(start).inSeconds;
    final kcal = _estimateWorkoutCalories(
      activityType,
      durationSeconds,
      weightKg,
    );
    AppLogger.info(
      '[HC] writeWorkoutToHC: activityType=$activityType, duration=${durationSeconds}s, weightKg=$weightKg, kcal=$kcal',
    );
    await health.writeWorkoutData(
      activityType: activityType,
      start: start,
      end: end,
      totalEnergyBurned: kcal,
      title: dayLabel,
    );
    AppLogger.info('[HC] writeWorkoutToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeWorkoutToHC failed', e);
  }
}

Future<void> writeWeightToHC(double kg) async {
  AppLogger.info('[HC] writeWeightToHC: ${kg}kg');
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: kg,
      type: HealthDataType.WEIGHT,
      startTime: now,
      unit: HealthDataUnit.KILOGRAM,
    );
    AppLogger.info('[HC] writeWeightToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeWeightToHC failed', e);
  }
}

Future<void> writeBodyFatToHC(double percent) async {
  AppLogger.info('[HC] writeBodyFatToHC: $percent%');
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: percent,
      type: HealthDataType.BODY_FAT_PERCENTAGE,
      startTime: now,
      unit: HealthDataUnit.PERCENT,
    );
    AppLogger.info('[HC] writeBodyFatToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeBodyFatToHC failed', e);
  }
}

Future<void> writeLeanBodyMassToHC({
  required double weightKg,
  required double bodyFatPercent,
}) async {
  final leanKg = weightKg * (1 - bodyFatPercent / 100);
  AppLogger.info(
    '[HC] writeLeanBodyMassToHC: weightKg=$weightKg, bodyFat=$bodyFatPercent% → leanKg=${leanKg.toStringAsFixed(2)}',
  );
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: leanKg,
      type: HealthDataType.LEAN_BODY_MASS,
      startTime: now,
      unit: HealthDataUnit.KILOGRAM,
    );
    AppLogger.info('[HC] writeLeanBodyMassToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeLeanBodyMassToHC failed', e);
  }
}

Future<void> writeHeightToHC(double cm) async {
  AppLogger.info('[HC] writeHeightToHC: ${cm}cm (${cm / 100.0}m)');
  try {
    final health = Health();
    final now = DateTime.now();
    await health.writeHealthData(
      value: cm / 100.0,
      type: HealthDataType.HEIGHT,
      startTime: now,
      unit: HealthDataUnit.METER,
    );
    AppLogger.info('[HC] writeHeightToHC: success');
  } catch (e) {
    AppLogger.error('[HC] writeHeightToHC failed', e);
  }
}

HealthWorkoutActivityType _activityTypeFromLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('run') || l.contains('jog')) {
    return HealthWorkoutActivityType.RUNNING;
  }
  if (l.contains('yoga') ||
      l.contains('stretch') ||
      l.contains('flexibility')) {
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
  } else if (type ==
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING) {
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
