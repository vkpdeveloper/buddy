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
  HealthDataType.SLEEP_SESSION,
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
  final midnight = DateTime(now.year, now.month, now.day);
  try {
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.HEART_RATE],
    );
    if (data.isEmpty) return null;
    data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final value = data.first.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toInt();
    }
    return 0;
  } catch (e) {
    return 0;
  }
});

final todayActiveEnergyProvider = FutureProvider<double>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return 0.0;

  final health = ref.read(healthProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);

  try {
    // Try ACTIVE_ENERGY_BURNED first (exercise-only calories)
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: midnight,
      endTime: now,
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
    );
    double totalEnergy = 0.0;
    for (var point in data) {
      final value = point.value;
      if (value is NumericHealthValue) {
        totalEnergy += value.numericValue.toDouble();
      }
    }

    // Fall back to TOTAL_CALORIES_BURNED if active energy is unavailable.
    // Google Fit stores calories as total (active + BMR), so this ensures
    // data synced from Google Fit is picked up.
    if (totalEnergy == 0.0) {
      final totalData = await health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
      );
      for (var point in totalData) {
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
  // Extend window to catch sleep sessions that start yesterday evening and end today morning
  final sleepStart = DateTime(
    now.year,
    now.month,
    now.day - 1,
    20,
    0,
  ); // yesterday 8pm
  final sleepEnd = DateTime(now.year, now.month, now.day, 14, 0); // today 2pm

  try {
    List<HealthDataPoint> data = await health.getHealthDataFromTypes(
      startTime: sleepStart,
      endTime: sleepEnd,
      types: [HealthDataType.SLEEP_SESSION],
    );

    Duration totalSleep = Duration.zero;
    for (var point in data) {
      totalSleep += point.dateTo.difference(point.dateFrom);
    }
    return totalSleep;
  } catch (e) {
    return Duration.zero;
  }
});
