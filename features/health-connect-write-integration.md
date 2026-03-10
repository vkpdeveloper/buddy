# Health Connect Write Integration

Everything we can write from Buddy into Health Connect, organized by category and priority.

---

## Why Write to Health Connect?

Writing data into Health Connect makes Buddy a first-class health citizen on Android:
- Data logged in Buddy (food, water, workouts) appears in Google Fit, Samsung Health, etc.
- Other apps that read from Health Connect (e.g., Withings, Garmin Connect) pick up our data automatically.
- Users get a unified health history even if they switch apps.

---

## Category 1 — Nutrition (Highest Priority)

### 1.1 Hydration
**HC Type:** `HydrationRecord`
**Unit:** millilitres (ml)
**What we log:** Buddy already shows a hydration target. We can write each water intake event as a `HydrationRecord`.

**Data shape:**
```
startTime / endTime: timestamp of the drink
volume: WaterMass in litres (e.g., 250ml glass → 0.25)
```

**Trigger:** When user logs water intake (manual entry or quick-add button on dashboard).

---

### 1.2 Nutrition (Meals / Macro Tracking)
**HC Type:** `NutritionRecord`
**Unit:** various (grams, kcal)
**What we log:** Every meal logged in Buddy's diet tracker has macros (calories, protein, carbs, fat). We can write these directly.

**Data shape:**
```
startTime / endTime: meal time
energy: Energy in kcal
totalCarbohydrate: Mass in grams
protein: Mass in grams
totalFat: Mass in grams
dietaryFiber: Mass in grams (if available)
sugar: Mass in grams (if available)
sodium: Mass in milligrams (if available)
name: meal name (e.g., "Breakfast — Oats & Banana")
```

**Trigger:** When user saves a meal log entry.

---

## Category 2 — Activity (High Priority)

### 2.1 Exercise Sessions
**HC Type:** `ExerciseSessionRecord`
**Unit:** n/a (structured record)
**What we log:** Every completed workout session in Buddy — type, duration, sets/reps.

**Data shape:**
```
startTime / endTime: session start and end
exerciseType: maps from our discipline (e.g., STRENGTH_TRAINING, RUNNING, YOGA, HIKING)
title: workout plan name
notes: optional summary
```

**Supporting records to write alongside:**
- `ActiveCaloriesBurnedRecord` — XP-estimated or MET-estimated kcal burned
- `ExerciseLapRecord` — one lap per exercise set (optional, advanced)

**Trigger:** When `PUT /sessions/:id/complete` is called (workout done).

---

### 2.2 Active Calories Burned
**HC Type:** `ActiveCaloriesBurnedRecord`
**Unit:** kcal
**What we log:** Calories burned during a workout (estimated from MET values or our XP system).

**Data shape:**
```
startTime / endTime: workout window
energy: Energy in kcal
```

**Trigger:** Written automatically when completing an exercise session (see 2.1).

---

## Category 3 — Body Measurements (Medium Priority)

### 3.1 Weight
**HC Type:** `WeightRecord`
**Unit:** kilograms
**What we log:** Buddy's Growth tab allows body weight logging. We should write these to HC.

**Data shape:**
```
time: measurement timestamp
weight: Mass in kg
```

**Trigger:** When user saves a body measurement entry (weight field).

---

### 3.2 Body Fat Percentage
**HC Type:** `BodyFatRecord`
**Unit:** percentage (0.0–1.0)
**What we log:** If user enters body fat % in their profile or measurement log.

**Data shape:**
```
time: measurement timestamp
percentage: Percentage (e.g., 0.18 for 18%)
```

**Trigger:** When user saves body fat entry in measurements.

---

### 3.3 Height
**HC Type:** `HeightRecord`
**Unit:** metres
**What we log:** Set once during onboarding or profile update. No need to write repeatedly.

**Data shape:**
```
time: profile update timestamp
height: Length in metres (e.g., 1.75)
```

**Trigger:** On onboarding completion or profile height update.

---

### 3.4 Lean Body Mass
**HC Type:** `LeanBodyMassRecord`
**Unit:** kilograms
**What we log:** Can be derived from weight + body fat %. Write when both are available.

**Data shape:**
```
time: measurement timestamp
mass: Mass in kg (weight × (1 - bodyFatFraction))
```

**Trigger:** Computed and written when both weight and body fat are logged.

---

## Category 4 — Vitals (Lower Priority / Future)

### 4.1 Resting Heart Rate
**HC Type:** `RestingHeartRateRecord`
**Unit:** beats per minute
**What we log:** If we ever add a manual resting HR entry or integrate with a connected device.

---

### 4.2 Blood Pressure
**HC Type:** `BloodPressureRecord`
**Unit:** mmHg (systolic / diastolic)
**What we log:** Manual entry if user wants to track cardiovascular health alongside fitness.

---

### 4.3 Blood Glucose
**HC Type:** `BloodGlucoseRecord`
**Unit:** mmol/L
**What we log:** For users managing diabetes who track alongside diet.

---

## Implementation Notes

### Permissions Required (AndroidManifest.xml)
```xml
<!-- Nutrition -->
<uses-permission android:name="android.permission.health.WRITE_HYDRATION"/>
<uses-permission android:name="android.permission.health.WRITE_NUTRITION"/>

<!-- Activity -->
<uses-permission android:name="android.permission.health.WRITE_EXERCISE"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>

<!-- Body Measurements -->
<uses-permission android:name="android.permission.health.WRITE_WEIGHT"/>
<uses-permission android:name="android.permission.health.WRITE_HEIGHT"/>
<uses-permission android:name="android.permission.health.WRITE_BODY_FAT"/>
<uses-permission android:name="android.permission.health.WRITE_LEAN_BODY_MASS"/>
```

### Flutter health package — write API
```dart
// Example: write hydration
await health.writeHealthData(
  value: 250.0,        // ml
  type: HealthDataType.WATER,
  startTime: DateTime.now(),
  endTime: DateTime.now(),
  unit: HealthDataUnit.MILLILITER,
);

// Example: write exercise session
await health.writeWorkoutData(
  activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
  start: sessionStart,
  end: sessionEnd,
  totalEnergyBurned: estimatedKcal,
  totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
);
```

### Idempotency
Health Connect does not deduplicate writes automatically. Before writing, check if a record for the same time window already exists to avoid duplicate entries (e.g., if the user re-completes or re-syncs a workout).

### User Consent
Write permissions are separate from read permissions. The Health Connect permissions dialog will show both. Users must explicitly grant write access. Add a toggle in Profile → Health Connect to let users opt out of writes without losing read access.

---

## Priority Roadmap

| Priority | Data Type | Trigger |
|----------|-----------|---------|
| P0 | Hydration | Water intake log |
| P0 | Nutrition (meal macros) | Meal log save |
| P0 | Exercise Session + Active Calories | Workout complete |
| P1 | Weight | Body measurement save |
| P1 | Body Fat % | Body measurement save |
| P2 | Height | Onboarding / profile update |
| P2 | Lean Body Mass | Derived from weight + fat |
| P3 | Resting HR, Blood Pressure, Blood Glucose | Manual entry (future) |
