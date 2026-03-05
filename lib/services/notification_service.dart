import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const int _preWorkoutReminderId = 4201;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> cancelPreWorkoutReminder() async {
    await initialize();
    await _plugin.cancel(_preWorkoutReminderId);
  }

  static Future<void> scheduleDailyPreWorkoutReminder({
    required TimeOfDay workoutTime,
    required int leadMinutes,
  }) async {
    await initialize();
    await _plugin.cancel(_preWorkoutReminderId);

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      workoutTime.hour,
      workoutTime.minute,
    ).subtract(Duration(minutes: leadMinutes));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pre_workout_reminders',
        'Pre-workout reminders',
        channelDescription: 'Nutrition reminder before workout time',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    Future<void> schedule(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        _preWorkoutReminderId,
        'Pre-workout nutrition',
        'Fuel up now to stay strong in today\'s workout.',
        tz.TZDateTime.from(scheduled, tz.local),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        return;
      }
      rethrow;
    }
  }
}
