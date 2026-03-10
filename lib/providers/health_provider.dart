import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

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

Future<bool> requestHealthPermissions(WidgetRef ref) async {
  final health = ref.read(healthProvider);

  try {
    final granted = await health.requestAuthorization(
      healthTypes,
      permissions: healthPermissionsList,
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
