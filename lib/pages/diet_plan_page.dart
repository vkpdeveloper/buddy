import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/services/media_service.dart';
import 'package:buddy/services/notification_service.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/app_empty_state.dart';
import 'package:buddy/widgets/app_week_date_picker.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DietPlanPage extends ConsumerStatefulWidget {
  const DietPlanPage({super.key});

  @override
  ConsumerState<DietPlanPage> createState() => _DietPlanPageState();
}

class _DietPlanPageState extends ConsumerState<DietPlanPage> {
  static const Map<String, int> _weekdayNumbers = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  int? _activePlanId;
  Map<String, dynamic>? _planData;
  Map<int, bool> _todayLog = {};
  Map<int, Map<String, dynamic>> _actualLogs = {};
  bool _isLoading = true;
  int _selectedDayIndex = 0;

  bool _isPhotoLogging = false;
  List<Map<String, dynamic>> _quickLogs = [];
  List<Map<String, dynamic>> _photoAnalyses = [];
  Timer? _photoAnalysisPollTimer;
  bool _isRefreshingPhotoAnalyses = false;

  bool _reminderEnabled = false;
  int _reminderLeadMinutes = 60;
  TimeOfDay _workoutTime = const TimeOfDay(hour: 18, minute: 0);
  bool _hasSavedReminderTime = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _photoAnalysisPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    await _loadSettings();

    try {
      final res = await DietService.listDietPlans();
      final plans = (res['data'] as List?) ?? [];
      final active = plans
          .where((p) => p['isActive'] == true || p['is_active'] == 1)
          .toList();

      if (active.isNotEmpty) {
        _activePlanId = active.first['id'] as int;
      } else if (plans.isNotEmpty) {
        _activePlanId = plans.last['id'] as int;
      }

      if (_activePlanId != null) {
        await _loadPlanDetail(_activePlanId!);
      }
    } catch (_) {
      // No-op: empty/error state handled in build.
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final workoutRaw = prefs.getString('pre_workout_reminder_workout_time');

    if (!mounted) return;
    setState(() {
      _reminderEnabled = prefs.getBool('pre_workout_reminder_enabled') ?? false;
      _reminderLeadMinutes = prefs.getInt('pre_workout_reminder_lead') ?? 60;
      _hasSavedReminderTime = workoutRaw != null && workoutRaw.contains(':');
      if (workoutRaw != null && workoutRaw.contains(':')) {
        final parts = workoutRaw.split(':');
        final hour = int.tryParse(parts.first) ?? 18;
        final minute = int.tryParse(parts.last) ?? 0;
        _workoutTime = TimeOfDay(
          hour: hour.clamp(0, 23),
          minute: minute.clamp(0, 59),
        );
      }
    });
  }

  Future<void> _loadPlanDetail(int id) async {
    try {
      final results = await Future.wait([
        DietService.getDietPlan(id),
        DietService.getDietLog(_todayDate),
      ]);

      final planRes = results[0]['data'] as Map<String, dynamic>;
      final logRes = (results[1]['data'] as Map<String, dynamic>?) ?? {};

      final dynamic completionRaw = logRes['completionMap'] ?? logRes;
      final completionMap = <int, bool>{};
      if (completionRaw is Map) {
        completionRaw.forEach((key, value) {
          final id = int.tryParse(key.toString());
          if (id != null) completionMap[id] = value == true;
        });
      }

      final actualLogsRaw = (logRes['actualLogs'] as Map?) ?? {};
      final actualMap = <int, Map<String, dynamic>>{};
      actualLogsRaw.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null && value is Map) {
          actualMap[id] = Map<String, dynamic>.from(value);
        }
      });

      final nowDayIndex = DateTime.now().weekday - 1;
      final days = (planRes['days'] as List?) ?? [];
      final inferredWorkoutTime = _inferWorkoutTime(
        days,
        _reminderLeadMinutes,
        nowDayIndex,
      );

      final quickLogsRaw = (logRes['quickLogs'] as List?) ?? [];
      final quickLogs = quickLogsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      List<Map<String, dynamic>> recentAnalyses = _photoAnalyses;
      try {
        final analysesRes = await MediaService.listRecentMealAnalyses();
        recentAnalyses = ((analysesRes['data'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        // Keep the last known photo analysis state on transient failures.
      }

      if (!mounted) return;
      setState(() {
        _planData = planRes;
        _activePlanId = id;
        _todayLog = completionMap;
        _actualLogs = actualMap;
        _quickLogs = quickLogs;
        _photoAnalyses = recentAnalyses;
        _selectedDayIndex = days.isEmpty
            ? 0
            : nowDayIndex.clamp(0, days.length - 1);

        if (!_hasSavedReminderTime) {
          _workoutTime = inferredWorkoutTime;
        }
      });
      _syncPhotoAnalysisPolling();
    } catch (_) {
      // Keep existing state on transient API failures.
    }
  }

  List<Map<String, dynamic>> get _visiblePhotoAnalyses {
    final loggedAttachmentIds = <int>{};

    for (final quickLog in _quickLogs) {
      final attachmentId = (quickLog['attachmentId'] as num?)?.toInt();
      if (attachmentId != null) {
        loggedAttachmentIds.add(attachmentId);
      }
    }

    for (final actualLog in _actualLogs.values) {
      final rawPayload = actualLog['rawPayload'];
      if (rawPayload is Map) {
        final attachmentId = (rawPayload['attachmentId'] as num?)?.toInt();
        if (attachmentId != null) {
          loggedAttachmentIds.add(attachmentId);
        }
      }
    }

    final visible = _photoAnalyses.where((analysis) {
      final attachmentId = (analysis['id'] as num?)?.toInt();
      return attachmentId == null ||
          !loggedAttachmentIds.contains(attachmentId);
    }).toList();

    visible.sort((a, b) {
      final aCreatedAt =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return visible;
  }

  bool get _hasPendingPhotoAnalyses => _visiblePhotoAnalyses.any((analysis) {
    final status = analysis['aiAnalysisStatus']?.toString() ?? '';
    return status == 'pending' || status == 'analyzing';
  });

  void _syncPhotoAnalysisPolling() {
    if (_hasPendingPhotoAnalyses) {
      _photoAnalysisPollTimer ??= Timer.periodic(
        const Duration(seconds: 4),
        (_) => _refreshRecentPhotoAnalyses(silent: true),
      );
      return;
    }

    _photoAnalysisPollTimer?.cancel();
    _photoAnalysisPollTimer = null;
  }

  Future<void> _refreshRecentPhotoAnalyses({bool silent = false}) async {
    if (_isRefreshingPhotoAnalyses) return;
    _isRefreshingPhotoAnalyses = true;

    try {
      final res = await MediaService.listRecentMealAnalyses();
      final analyses = ((res['data'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() => _photoAnalyses = analyses);
    } catch (_) {
      if (!silent && mounted) {
        AppSnackbar.error(context, 'Could not refresh photo analysis status.');
      }
    } finally {
      _isRefreshingPhotoAnalyses = false;
      if (mounted) {
        _syncPhotoAnalysisPolling();
      }
    }
  }

  void _upsertPhotoAnalysis(Map<String, dynamic> analysis) {
    if (!mounted) return;

    setState(() {
      _photoAnalyses = [
        analysis,
        ..._photoAnalyses.where((item) => item['id'] != analysis['id']),
      ];
    });
    _syncPhotoAnalysisPolling();
  }

  void _openCompletedPhotoAnalysis(Map<String, dynamic> analysis) {
    final result = analysis['analysisResult'];
    if (result is! Map) return;

    _showPhotoResultSheet(
      attachmentId: (analysis['id'] as num).toInt(),
      result: Map<String, dynamic>.from(result),
      signedUrl: analysis['signedUrl'] as String?,
    );
  }

  TimeOfDay _inferWorkoutTime(List days, int leadMinutes, int dayIndex) {
    if (days.isEmpty) {
      return const TimeOfDay(hour: 18, minute: 0);
    }
    final safeIndex = dayIndex.clamp(0, days.length - 1);
    final day = days[safeIndex] as Map<String, dynamic>;
    final meals = ((day['meals'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final pre = meals.cast<Map<String, dynamic>?>().firstWhere(
      (m) => (m?['mealType'] ?? m?['meal_type']) == 'pre_workout',
      orElse: () => null,
    );
    if (pre == null) return const TimeOfDay(hour: 18, minute: 0);

    final mealTime = (pre['mealTime'] ?? pre['meal_time'] ?? '').toString();
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(mealTime)) {
      return const TimeOfDay(hour: 18, minute: 0);
    }

    final parts = mealTime.split(':');
    final hh = int.tryParse(parts[0]) ?? 17;
    final mm = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2026, 1, 1, hh, mm).add(Duration(minutes: leadMinutes));
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  Future<void> _toggleMealCompletion(int mealId, bool isCompleted) async {
    await DietService.logMealCompletion(_todayDate, mealId, isCompleted);
    if (!mounted) return;
    setState(() => _todayLog[mealId] = isCompleted);
    ref.invalidate(todayNutritionSummaryProvider(_todayDate));
  }

  Future<void> _logActualMeal(int mealId, Map<String, dynamic> payload) async {
    await DietService.logActualMeal(_todayDate, {'mealId': mealId, ...payload});
    await _loadPlanDetail(_activePlanId!);
    if (mounted) ref.invalidate(todayNutritionSummaryProvider(_todayDate));
    // Write nutrition to Health Connect (fire-and-forget)
    final calories = (payload['calories'] as num?)?.toDouble() ?? 0;
    final proteinG = (payload['proteinG'] as num?)?.toDouble() ?? 0;
    final carbsG = (payload['carbsG'] as num?)?.toDouble() ?? 0;
    final fatG = (payload['fatG'] as num?)?.toDouble() ?? 0;
    if (calories > 0) {
      writeNutritionToHC(
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        name: payload['name'] as String? ?? 'Meal',
      );
    }
  }

  Future<void> _quickPhotoLog() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;

    setState(() => _isPhotoLogging = true);

    try {
      final file = File(picked.path);
      final ext = picked.path.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

      // Upload
      final uploadRes = await MediaService.uploadMealPhoto(file, mime);
      final uploadData = uploadRes['data'] as Map<String, dynamic>;
      final attachmentId = uploadData['id'] as int;
      final signedUrl = uploadData['signedUrl'] as String?;

      final analyzeRes = await MediaService.analyzeMealPhoto(attachmentId);
      final analyzeData = analyzeRes['data'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() => _isPhotoLogging = false);
      _upsertPhotoAnalysis({
        'id': attachmentId,
        'signedUrl': signedUrl,
        'analysisResult': analyzeData['analysisResult'],
        'aiAnalysisStatus': analyzeData['status'] ?? 'analyzing',
        'createdAt': DateTime.now().toIso8601String(),
      });
      AppSnackbar.info(
        context,
        'Meal uploaded. Analysis is running in the background.',
      );
      unawaited(_refreshRecentPhotoAnalyses(silent: true));
    } catch (e) {
      if (mounted) {
        setState(() => _isPhotoLogging = false);
        AppSnackbar.error(context, 'Could not start meal analysis.');
      }
    }
  }

  void _showPhotoResultSheet({
    required int attachmentId,
    required Map<String, dynamic> result,
    String? signedUrl,
    File? file,
  }) {
    final colors = context.colors;
    final macros = result['macros'] as Map<String, dynamic>;
    final ingredients =
        (result['ingredients'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final calories = (macros['calories'] as num?)?.toInt() ?? 0;
    final protein = (macros['proteinG'] as num?)?.toDouble() ?? 0;
    final carbs = (macros['carbsG'] as num?)?.toDouble() ?? 0;
    final fat = (macros['fatG'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.85,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            // Header
            Row(
              children: [
                Text(
                  'PHOTO ANALYSIS',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 11,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(confidence * 100).toStringAsFixed(0)}% confident',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: file != null
                  ? Image.file(
                      file,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : signedUrl != null
                  ? Image.network(
                      signedUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 180,
                      color: colors.primary.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.camera,
                        color: colors.primary,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(height: 20),

            // Macro row
            Row(
              children: [
                _MacroPill(
                  label: 'CAL',
                  value: '$calories',
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'PROTEIN',
                  value: '${protein.toStringAsFixed(1)}g',
                  color: colors.info,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'CARBS',
                  value: '${carbs.toStringAsFixed(1)}g',
                  color: colors.warning,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'FAT',
                  value: '${fat.toStringAsFixed(1)}g',
                  color: colors.muscleArms,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ingredients
            if (ingredients.isNotEmpty) ...[
              Text(
                'DETECTED ITEMS',
                style: GoogleFonts.plusJakartaSans(
                  color: colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              ...ingredients.map(
                (ing) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circle_dot,
                        size: 10,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ing['name']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        ing['quantity']?.toString() ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Log button
            Semantics(
              label: 'Log this meal',
              button: true,
              child: GestureDetector(
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await MediaService.logQuickMeal(_todayDate, {
                      'mealName':
                          (result['ingredients'] as List?)
                              ?.map((e) => (e as Map)['name'])
                              .take(2)
                              .join(', ') ??
                          'Photo meal',
                      'calories': calories,
                      'proteinG': protein,
                      'carbsG': carbs,
                      'fatG': fat,
                      'attachmentId': attachmentId,
                    });
                    if (_activePlanId != null) {
                      await _loadPlanDetail(_activePlanId!);
                    }
                    if (mounted) {
                      ref.invalidate(todayNutritionSummaryProvider(_todayDate));
                    }
                  } catch (_) {}
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.actionSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LOG THIS MEAL',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.actionForeground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReminder({
    bool? enabled,
    int? leadMinutes,
    TimeOfDay? workoutTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled != null) {
      _reminderEnabled = enabled;
      await prefs.setBool('pre_workout_reminder_enabled', enabled);
    }
    if (leadMinutes != null) {
      _reminderLeadMinutes = leadMinutes;
      await prefs.setInt('pre_workout_reminder_lead', leadMinutes);
    }
    if (workoutTime != null) {
      _workoutTime = workoutTime;
      _hasSavedReminderTime = true;
      final hh = workoutTime.hour.toString().padLeft(2, '0');
      final mm = workoutTime.minute.toString().padLeft(2, '0');
      await prefs.setString('pre_workout_reminder_workout_time', '$hh:$mm');
    }

    if (_reminderEnabled) {
      final granted = await NotificationService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _reminderEnabled = false;
        await SharedPreferences.getInstance().then(
          (p) => p.setBool('pre_workout_reminder_enabled', false),
        );
        if (!mounted) return;
        AppSnackbar.error(context, 'Notification permission denied.');
        setState(() {});
        return;
      }
      try {
        await NotificationService.scheduleDailyPreWorkoutReminder(
          workoutTime: _workoutTime,
          leadMinutes: _reminderLeadMinutes,
        );
      } catch (_) {
        if (!mounted) return;
        AppSnackbar.error(context, 'Could not schedule reminder right now.');
      }
    } else {
      await NotificationService.cancelPreWorkoutReminder();
    }

    if (mounted) setState(() {});
  }

  Future<void> _reorderMeals(
    Map<String, dynamic> day,
    List<dynamic> meals,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final reordered = List<Map<String, dynamic>>.from(
      meals.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final mealIds = reordered
        .map((m) => (m['id'] as num?)?.toInt())
        .whereType<int>()
        .toList();

    final dayId = (day['id'] as num).toInt();
    final days = List<Map<String, dynamic>>.from(
      ((_planData?['days'] as List?) ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    days[_selectedDayIndex]['meals'] = reordered;
    setState(() => _planData = {...?_planData, 'days': days});

    try {
      await DietService.reorderDietMeals(dayId, mealIds);
    } catch (_) {
      if (_activePlanId != null) await _loadPlanDetail(_activePlanId!);
    }
  }

  Future<void> _openReminderSettingsSheet() async {
    final colors = context.colors;
    var localReminderEnabled = _reminderEnabled;
    var localLeadMinutes = _reminderLeadMinutes;
    var localWorkoutTime = _workoutTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REMINDER SETTINGS',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pre-workout reminder',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: localReminderEnabled,
                      activeThumbColor: colors.primary,
                      onChanged: (v) async {
                        setSheetState(() => localReminderEnabled = v);
                        await _updateReminder(enabled: v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SettingRow(
                  title: 'Workout time',
                  value: localWorkoutTime.format(sheetContext),
                  icon: LucideIcons.alarm_clock,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: sheetContext,
                      initialTime: localWorkoutTime,
                    );
                    if (picked != null) {
                      setSheetState(() => localWorkoutTime = picked);
                      await _updateReminder(workoutTime: picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _SettingRow(
                  title: 'Reminder lead',
                  value: '$localLeadMinutes min before',
                  icon: LucideIcons.clock_3,
                  onTap: () async {
                    final lead = await showModalBottomSheet<int>(
                      context: sheetContext,
                      backgroundColor: colors.card,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [30, 45, 60, 90]
                              .map(
                                (m) => ListTile(
                                  title: Text(
                                    '$m min before',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: m == localLeadMinutes
                                      ? Icon(
                                          LucideIcons.check,
                                          color: colors.primary,
                                          size: 16,
                                        )
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(m),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                    if (lead != null) {
                      setSheetState(() => localLeadMinutes = lead);
                      await _updateReminder(leadMinutes: lead);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _dietDayNumber(Map<String, dynamic> day, {required int fallbackIndex}) {
    final dayName = (day['dayName'] ?? day['day_name'])?.toString();
    final parsed = _weekdayNumbers[dayName?.trim().toLowerCase()];
    if (parsed != null) return parsed;

    final fallbackDayNumber = fallbackIndex + 1;
    return fallbackDayNumber < 1
        ? 1
        : fallbackDayNumber > 7
        ? 7
        : fallbackDayNumber;
  }

  int _findDietDayIndexForWeekday(List<dynamic> days, int weekday) {
    for (var index = 0; index < days.length; index++) {
      final day = Map<String, dynamic>.from(days[index] as Map);
      if (_dietDayNumber(day, fallbackIndex: index) == weekday) {
        return index;
      }
    }

    return -1;
  }

  DateTime _selectedWeekDateForDietDays(List<dynamic> days) {
    if (days.isEmpty) {
      return normalizeCalendarDate(DateTime.now());
    }

    final selectedIndex = _selectedDayIndex.clamp(0, days.length - 1).toInt();
    final day = Map<String, dynamic>.from(days[selectedIndex] as Map);
    final dayNumber = _dietDayNumber(day, fallbackIndex: selectedIndex);
    return currentWeekDateForDayNumber(dayNumber);
  }

  void _selectDietDayForDate(DateTime date, List<dynamic> days) {
    final index = _findDietDayIndexForWeekday(days, date.weekday);
    if (index == -1 || index == _selectedDayIndex) return;
    setState(() => _selectedDayIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (!(prev?.diet.isDone ?? false) && next.diet.isDone) {
        _loadPlans();
      }
    });

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Nav bar is 76 + bottomInset tall, positioned absolutely at bottom: 0
    final fabBottom = 76.0 + bottomInset + 16.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              const GeneratingBanner(watchType: 'diet'),
              if (_isLoading)
                Expanded(child: _buildSkeleton())
              else if (_planData == null)
                _buildEmptyState()
              else
                Expanded(child: _buildPlanContent()),
            ],
          ),
          if (_planData != null)
            Positioned(
              right: 20,
              bottom: fabBottom,
              child: Tooltip(
                message: _isPhotoLogging
                    ? 'Logging meal photo…'
                    : 'Log meal with photo',
                child: Semantics(
                  label: _isPhotoLogging
                      ? 'Logging meal photo, please wait'
                      : 'Log meal with photo',
                  button: true,
                  enabled: !_isPhotoLogging,
                  child: GestureDetector(
                    onTap: _isPhotoLogging ? null : _quickPhotoLog,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.actionSurface,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: _isPhotoLogging
                            ? Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colors.actionForeground,
                                  ),
                                ),
                              )
                            : Icon(
                                LucideIcons.scan_line,
                                color: colors.actionForeground,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.paddingOf(context).bottom + 92,
      ),
      children: [
        _buildMacroProgressSkeletonCard(),
        const SizedBox(height: 14),
        IgnorePointer(
          child: AppWeekDatePicker(
            selected: normalizeCalendarDate(DateTime.now()),
            onDateSelected: (_) {},
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 4; index++) _buildMealSkeletonCard(index),
      ],
    );
  }

  Widget _buildMacroProgressSkeletonCard() {
    return SkeletonCardShell(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ShimmerBox(width: 178, height: 16, borderRadius: 6),
                ),
              ),
              ShimmerBox(width: 88, height: 14, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 8),
          const ShimmerBox(width: double.infinity, height: 9, borderRadius: 8),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _MacroProgressSkeleton(
                  labelWidth: 92,
                  progressWidth: double.infinity,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MacroProgressSkeleton(
                  labelWidth: 88,
                  progressWidth: double.infinity,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MacroProgressSkeleton(
                  labelWidth: 72,
                  progressWidth: double.infinity,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealSkeletonCard(int index) {
    const titleFactors = [0.74, 0.88, 0.82, 0.7];
    const detailFactors = [0.62, 0.56, 0.66, 0.6];
    const ctaWidths = [82.0, 88.0, 84.0, 90.0];

    return SkeletonCardShell(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(width: 28, height: 28, borderRadius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 132, height: 20, borderRadius: 6),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: titleFactors[index],
                      alignment: Alignment.centerLeft,
                      child: const ShimmerBox(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: ShimmerBox(width: 14, height: 18, borderRadius: 6),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FractionallySizedBox(
                  widthFactor: detailFactors[index],
                  alignment: Alignment.centerLeft,
                  child: const ShimmerBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const ShimmerBox(width: 14, height: 14, borderRadius: 6),
                  const SizedBox(width: 8),
                  ShimmerBox(
                    width: ctaWidths[index],
                    height: 14,
                    borderRadius: 6,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 16,
        16,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NUTRITION',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Diet Plan',
                  style: GoogleFonts.sora(
                    color: colors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Reminder settings',
            child: IconButton(
              onPressed: _openReminderSettingsSheet,
              icon: Icon(
                _reminderEnabled ? LucideIcons.bell_ring : LucideIcons.bell,
                color: _reminderEnabled ? colors.primary : colors.textMuted,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final genStatus = ref.watch(generationStatusProvider);
    final isGenerating = genStatus.diet.isGenerating;

    return Expanded(
      child: AppEmptyState(
        icon: LucideIcons.utensils,
        title: isGenerating ? 'Building your plan…' : 'No diet plan yet',
        subtitle: isGenerating
            ? 'Creating a measurable macro-first plan for your goals.'
            : 'Generate a plan to unlock meal timing, macro tracking, and actual logging.',
      ),
    );
  }

  Widget _buildPlanContent() {
    final colors = context.colors;
    final days = (_planData?['days'] as List?) ?? [];
    if (days.isEmpty) return _buildEmptyState();

    final day = Map<String, dynamic>.from(days[_selectedDayIndex] as Map);
    final meals = ((day['meals'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final consumed = _consumedForDay(day);

    final targetCalories = (day['totalCalories'] ?? day['total_calories'] ?? 0)
        .toDouble();
    final targetProtein = (day['proteinG'] ?? day['protein_g'] ?? 0).toDouble();
    final targetCarbs = (day['carbsG'] ?? day['carbs_g'] ?? 0).toDouble();
    final targetFat = (day['fatG'] ?? day['fat_g'] ?? 0).toDouble();
    final photoAnalyses = _visiblePhotoAnalyses;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _MacroProgressCard(
            consumedCalories: consumed['calories']!,
            consumedProtein: consumed['proteinG']!,
            consumedCarbs: consumed['carbsG']!,
            consumedFat: consumed['fatG']!,
            targetCalories: targetCalories,
            targetProtein: targetProtein,
            targetCarbs: targetCarbs,
            targetFat: targetFat,
          ),
        ),
        const SizedBox(height: 14),
        AppWeekDatePicker(
          selected: _selectedWeekDateForDietDays(days),
          onDateSelected: (date) => _selectDietDayForDate(date, days),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.paddingOf(context).bottom + 92,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: meals.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorderMeals(day, meals, oldIndex, newIndex),
                  itemBuilder: (ctx, i) {
                    final meal = meals[i];
                    final mealId = (meal['id'] as num).toInt();
                    return _MealCard(
                      key: ValueKey(mealId),
                      index: i,
                      meal: meal,
                      isCompletedToday: _todayLog[mealId] ?? false,
                      actualLog: _actualLogs[mealId],
                      onToggle: (completed) =>
                          _toggleMealCompletion(mealId, completed),
                      onLogActual: (payload) => _logActualMeal(mealId, payload),
                    );
                  },
                ),
                if (photoAnalyses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'PHOTO ANALYSIS',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...photoAnalyses.map(
                    (analysis) => _PhotoAnalysisCard(
                      analysis: analysis,
                      onTap: () => _openCompletedPhotoAnalysis(analysis),
                      onRetry: () async {
                        final attachmentId = (analysis['id'] as num?)?.toInt();
                        if (attachmentId == null) return;

                        try {
                          await MediaService.analyzeMealPhoto(attachmentId);
                          if (!mounted) return;
                          _upsertPhotoAnalysis({
                            ...analysis,
                            'aiAnalysisStatus': 'analyzing',
                          });
                          AppSnackbar.info(
                            context,
                            'Meal analysis restarted in the background.',
                          );
                          unawaited(_refreshRecentPhotoAnalyses(silent: true));
                        } catch (_) {
                          if (!mounted) return;
                          AppSnackbar.error(
                            context,
                            'Could not restart photo analysis.',
                          );
                        }
                      },
                    ),
                  ),
                ],
                if (_quickLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'CAPTURED MEALS',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._quickLogs.map((q) => _QuickLogCard(log: q)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, double> _consumedForDay(Map<String, dynamic> day) {
    final meals = ((day['meals'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    double calories = 0;
    double proteinG = 0;
    double carbsG = 0;
    double fatG = 0;

    for (final meal in meals) {
      final mealId = (meal['id'] as num?)?.toInt();
      if (mealId == null) continue;

      final actual = _actualLogs[mealId];
      if (actual != null) {
        calories += (actual['calories'] as num?)?.toDouble() ?? 0;
        proteinG += (actual['proteinG'] as num?)?.toDouble() ?? 0;
        carbsG += (actual['carbsG'] as num?)?.toDouble() ?? 0;
        fatG += (actual['fatG'] as num?)?.toDouble() ?? 0;
        continue;
      }

      if (_todayLog[mealId] == true) {
        calories += (meal['calories'] as num?)?.toDouble() ?? 0;
        proteinG +=
            ((meal['proteinG'] ?? meal['protein_g']) as num?)?.toDouble() ?? 0;
        carbsG +=
            ((meal['carbsG'] ?? meal['carbs_g']) as num?)?.toDouble() ?? 0;
        fatG += ((meal['fatG'] ?? meal['fat_g']) as num?)?.toDouble() ?? 0;
      }
    }

    // Add standalone photo-captured quick logs
    for (final q in _quickLogs) {
      calories += (q['calories'] as num?)?.toDouble() ?? 0;
      proteinG += (q['proteinG'] as num?)?.toDouble() ?? 0;
      carbsG += (q['carbsG'] as num?)?.toDouble() ?? 0;
      fatG += (q['fatG'] as num?)?.toDouble() ?? 0;
    }

    return {
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
    };
  }
}

class _MacroProgressCard extends StatelessWidget {
  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;

  const _MacroProgressCard({
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final calProgress = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.95)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.cardGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Macro Progress',
                style: GoogleFonts.plusJakartaSans(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${consumedCalories.toInt()} / ${targetCalories.toInt()} cal',
                style: GoogleFonts.plusJakartaSans(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: calProgress,
              minHeight: 9,
              backgroundColor: colors.border,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MacroMiniProgress(
                  label: 'Protein',
                  value: consumedProtein,
                  target: targetProtein,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniProgress(
                  label: 'Carbs',
                  value: consumedCarbs,
                  target: targetCarbs,
                  color: colors.macroCarbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniProgress(
                  label: 'Fat',
                  value: consumedFat,
                  target: targetFat,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroMiniProgress extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MacroMiniProgress({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toInt()}g/${target.toInt()}g',
          style: GoogleFonts.plusJakartaSans(
            color: colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: colors.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MacroProgressSkeleton extends StatelessWidget {
  final double labelWidth;
  final double progressWidth;

  const _MacroProgressSkeleton({
    required this.labelWidth,
    required this.progressWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: labelWidth, height: 10, borderRadius: 4),
        const SizedBox(height: 4),
        ShimmerBox(width: progressWidth, height: 6, borderRadius: 8),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$title: $value',
      button: true,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(icon, color: colors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevron_right,
                    color: colors.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> meal;
  final bool isCompletedToday;
  final Map<String, dynamic>? actualLog;
  final Future<void> Function(bool) onToggle;
  final Future<void> Function(Map<String, dynamic>) onLogActual;

  const _MealCard({
    super.key,
    required this.index,
    required this.meal,
    required this.isCompletedToday,
    required this.actualLog,
    required this.onToggle,
    required this.onLogActual,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  late bool _isCompleted;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.isCompletedToday;
  }

  @override
  void didUpdateWidget(covariant _MealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompletedToday != widget.isCompletedToday) {
      _isCompleted = widget.isCompletedToday;
    }
  }

  Future<void> _toggleDone() async {
    final newValue = !_isCompleted;
    setState(() => _isCompleted = newValue);
    await widget.onToggle(newValue);
    if (newValue) {
      final meal = widget.meal;
      final calories = (meal['calories'] as num?)?.toDouble() ?? 0;
      final proteinG =
          ((meal['proteinG'] ?? meal['protein_g']) as num?)?.toDouble() ?? 0;
      final carbsG =
          ((meal['carbsG'] ?? meal['carbs_g']) as num?)?.toDouble() ?? 0;
      final fatG = ((meal['fatG'] ?? meal['fat_g']) as num?)?.toDouble() ?? 0;
      final name = (meal['mealName'] ?? meal['meal_name'] ?? 'Meal').toString();
      if (calories > 0) {
        writeNutritionToHC(
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          name: name,
        );
      }
    }
  }

  void _showLogActualSheet() {
    final colors = context.colors;
    final meal = widget.meal;
    final mealNameCtrl = TextEditingController(
      text:
          (widget.actualLog?['mealName'] ??
                  meal['mealName'] ??
                  meal['meal_name'] ??
                  'Meal')
              .toString(),
    );
    final calCtrl = TextEditingController(
      text: (widget.actualLog?['calories'] ?? meal['calories'] ?? 0).toString(),
    );
    final protCtrl = TextEditingController(
      text:
          (widget.actualLog?['proteinG'] ??
                  meal['proteinG'] ??
                  meal['protein_g'] ??
                  0)
              .toString(),
    );
    final carbsCtrl = TextEditingController(
      text:
          (widget.actualLog?['carbsG'] ??
                  meal['carbsG'] ??
                  meal['carbs_g'] ??
                  0)
              .toString(),
    );
    final fatCtrl = TextEditingController(
      text: (widget.actualLog?['fatG'] ?? meal['fatG'] ?? meal['fat_g'] ?? 0)
          .toString(),
    );
    final notesCtrl = TextEditingController(
      text: (widget.actualLog?['notes'] ?? '').toString(),
    );

    File? selectedPhoto;
    int? attachmentId;
    bool isUploading = false;
    bool isAnalyzing = false;
    double? aiConfidence;
    String? uploadError;
    String? analysisStatus;
    Timer? analysisPollTimer;

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void applyAnalysisResult(Map<String, dynamic> result) {
            final macros = result['macros'] as Map<String, dynamic>;
            setSheetState(() {
              calCtrl.text = (macros['calories'] as num).toInt().toString();
              protCtrl.text = (macros['proteinG'] as num).toStringAsFixed(1);
              carbsCtrl.text = (macros['carbsG'] as num).toStringAsFixed(1);
              fatCtrl.text = (macros['fatG'] as num).toStringAsFixed(1);
              aiConfidence = (result['confidence'] as num?)?.toDouble();
              isAnalyzing = false;
              analysisStatus = 'completed';
            });
          }

          Future<void> pollAnalysisStatus() async {
            if (attachmentId == null) return;

            try {
              final res = await MediaService.getMealAttachment(attachmentId!);
              final data = res['data'] as Map<String, dynamic>;
              final status = data['aiAnalysisStatus']?.toString() ?? '';

              if (!ctx.mounted) return;

              if (status == 'completed' && data['analysisResult'] is Map) {
                analysisPollTimer?.cancel();
                analysisPollTimer = null;
                applyAnalysisResult(
                  Map<String, dynamic>.from(data['analysisResult'] as Map),
                );
                return;
              }

              if (status == 'failed') {
                analysisPollTimer?.cancel();
                analysisPollTimer = null;
                setSheetState(() {
                  isAnalyzing = false;
                  analysisStatus = 'failed';
                });
              }
            } catch (_) {
              // Keep polling on transient failures.
            }
          }

          late Future<void> Function() runAnalysis;

          Future<void> pickAndUpload(ImageSource source) async {
            final picked = await picker.pickImage(
              source: source,
              imageQuality: 85,
              maxWidth: 1280,
            );
            if (picked == null) return;
            final file = File(picked.path);
            final ext = picked.path.split('.').last.toLowerCase();
            final mime = ext == 'png'
                ? 'image/png'
                : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg';

            setSheetState(() {
              selectedPhoto = file;
              isUploading = true;
              uploadError = null;
              attachmentId = null;
              aiConfidence = null;
              analysisStatus = null;
            });
            analysisPollTimer?.cancel();
            analysisPollTimer = null;

            try {
              final res = await MediaService.uploadMealPhoto(file, mime);
              final data = res['data'] as Map<String, dynamic>;
              setSheetState(() {
                attachmentId = data['id'] as int;
                isUploading = false;
              });
              unawaited(runAnalysis());
            } catch (e) {
              setSheetState(() {
                isUploading = false;
                uploadError = 'Upload failed';
              });
            }
          }

          runAnalysis = () async {
            if (attachmentId == null) return;
            setSheetState(() {
              isAnalyzing = true;
              analysisStatus = 'analyzing';
            });
            try {
              final res = await MediaService.analyzeMealPhoto(attachmentId!);
              final data = res['data'] as Map<String, dynamic>;
              if (data['status'] == 'completed' &&
                  data['analysisResult'] is Map) {
                applyAnalysisResult(
                  Map<String, dynamic>.from(data['analysisResult'] as Map),
                );
                return;
              }

              analysisPollTimer?.cancel();
              analysisPollTimer = Timer.periodic(
                const Duration(seconds: 4),
                (_) => pollAnalysisStatus(),
              );
              unawaited(pollAnalysisStatus());
            } catch (e) {
              setSheetState(() {
                isAnalyzing = false;
                analysisStatus = 'failed';
              });
            }
          };

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOG ACTUAL',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),

                // Photo row
                Row(
                  children: [
                    if (selectedPhoto != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          selectedPhoto!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final choice =
                                    await showModalBottomSheet<ImageSource>(
                                      context: context,
                                      backgroundColor: colors.card,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (pickerCtx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: Icon(
                                                LucideIcons.camera,
                                                color: colors.primary,
                                              ),
                                              title: Text(
                                                'Camera',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: colors.textPrimary,
                                                    ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                pickerCtx,
                                                ImageSource.camera,
                                              ),
                                            ),
                                            ListTile(
                                              leading: Icon(
                                                LucideIcons.image,
                                                color: colors.primary,
                                              ),
                                              title: Text(
                                                'Gallery',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: colors.textPrimary,
                                                    ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                pickerCtx,
                                                ImageSource.gallery,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                if (choice != null) await pickAndUpload(choice);
                              },
                        icon: isUploading
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              )
                            : Icon(
                                LucideIcons.camera,
                                color: colors.primary,
                                size: 14,
                              ),
                        label: Text(
                          isUploading
                              ? 'Uploading…'
                              : selectedPhoto == null
                              ? 'Add Photo'
                              : 'Change Photo',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    if (attachmentId != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isAnalyzing ? null : runAnalysis,
                        icon: isAnalyzing
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.actionForeground,
                                ),
                              )
                            : Icon(
                                LucideIcons.sparkles,
                                size: 14,
                                color: colors.actionForeground,
                              ),
                        label: Text(
                          isAnalyzing ? 'Queued…' : 'Analyze',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.actionForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.actionSurface,
                          foregroundColor: colors.actionForeground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ],
                ),

                if (uploadError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    uploadError!,
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ],

                if (analysisStatus == 'analyzing') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'AI analysis is running in the background. You can keep editing or close this sheet.',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (analysisStatus == 'failed') ...[
                  const SizedBox(height: 6),
                  Text(
                    'AI analysis failed. You can retry or log the meal manually.',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ],

                if (aiConfidence != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 12,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI estimate — ${(aiConfidence! * 100).toStringAsFixed(0)}% confident',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                AppTextField(controller: mealNameCtrl, label: 'What you ate'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: calCtrl,
                        label: 'Calories',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: protCtrl,
                        label: 'Protein (g)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: carbsCtrl,
                        label: 'Carbs (g)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: fatCtrl,
                        label: 'Fat (g)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: notesCtrl,
                  label: 'Notes',
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: 'Save actual meal log',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      await widget.onLogActual({
                        'mealName': mealNameCtrl.text.trim().isEmpty
                            ? 'Meal'
                            : mealNameCtrl.text.trim(),
                        'calories': int.tryParse(calCtrl.text) ?? 0,
                        'proteinG': double.tryParse(protCtrl.text) ?? 0,
                        'carbsG': double.tryParse(carbsCtrl.text) ?? 0,
                        'fatG': double.tryParse(fatCtrl.text) ?? 0,
                        'notes': notesCtrl.text.trim(),
                        'attachmentId': attachmentId,
                        'rawPayload': {
                          'plannedMeal': meal,
                          'source': attachmentId != null
                              ? 'ai_photo_analysis'
                              : 'diet_log_actual',
                          'aiConfidence': aiConfidence,
                        },
                      });
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.actionSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'SAVE ACTUAL LOG',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.actionForeground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      analysisPollTimer?.cancel();
      analysisPollTimer = null;
    });
  }

  void _showDetailSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MealDetailSheet(
        meal: widget.meal,
        actualLog: widget.actualLog,
        onLogActual: () {
          Navigator.of(context).pop();
          _showLogActualSheet();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final meal = widget.meal;
    final mealType = (meal['mealType'] ?? meal['meal_type'] ?? '')
        .toString()
        .replaceAll('_', ' ')
        .toUpperCase();
    final mealTime = (meal['mealTime'] ?? meal['meal_time'] ?? '--:--')
        .toString();
    final name = meal['mealName'] ?? meal['meal_name'] ?? 'Meal';
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final protein =
        ((meal['proteinG'] ?? meal['protein_g']) as num?)?.toDouble() ?? 0;

    final hasActual = widget.actualLog != null;
    final rawPayload = widget.actualLog?['rawPayload'];
    final hasPhoto = rawPayload is Map && rawPayload['attachmentId'] != null;

    return Container(
      key: widget.key,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasActual
              ? colors.primary.withValues(alpha: 0.5)
              : _isCompleted
              ? colors.primary.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.95),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.cardGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Semantics(
        label:
            '$name, $mealType, $mealTime, $calories kcal. ${_isCompleted ? 'Completed' : 'Not completed'}. Double tap to view details.',
        button: true,
        child: Material(
          color: AppTheme.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _showDetailSheet,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Semantics(
                        label: _isCompleted
                            ? 'Mark meal as not done'
                            : 'Mark meal as done',
                        button: true,
                        checked: _isCompleted,
                        child: SizedBox(
                          width: AppTheme.minimumTouchTarget,
                          height: AppTheme.minimumTouchTarget,
                          child: GestureDetector(
                            onTap: _toggleDone,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _isCompleted
                                      ? colors.primary
                                      : colors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isCompleted
                                        ? colors.primary
                                        : colors.border,
                                  ),
                                ),
                                child: _isCompleted
                                    ? ExcludeSemantics(
                                        child: Icon(
                                          LucideIcons.check,
                                          color: colors.background,
                                          size: 16,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$mealTime • $mealType',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: colors.primary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                if (hasActual) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.accent.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ACTUAL',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: colors.textPrimary,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  if (hasPhoto) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      LucideIcons.camera,
                                      size: 11,
                                      color: colors.primary,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                color: _isCompleted
                                    ? colors.textMuted
                                    : colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Drag to reorder',
                        child: Semantics(
                          label: 'Drag to reorder meal',
                          child: ReorderableDragStartListener(
                            index: widget.index,
                            child: ExcludeSemantics(
                              child: Icon(
                                LucideIcons.grip_vertical,
                                color: colors.textMuted,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$calories kcal • ${protein.toInt()}g protein',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showLogActualSheet,
                        icon: Icon(
                          LucideIcons.pencil_line,
                          color: colors.primary,
                          size: 14,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(
                            0,
                            AppTheme.minimumTouchTarget,
                          ),
                        ),
                        label: Text(
                          hasActual ? 'Update Actual' : 'Log Actual',
                          style: GoogleFonts.plusJakartaSans(
                            color: colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MealDetailSheet extends StatelessWidget {
  static const String _rawMeasurementsNote =
      'All measurements are in raw/uncooked quantities';

  final Map<String, dynamic> meal;
  final Map<String, dynamic>? actualLog;
  final VoidCallback onLogActual;

  const _MealDetailSheet({
    required this.meal,
    this.actualLog,
    required this.onLogActual,
  });

  List<Map<String, String>> _parseIngredients(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> list = raw is String ? jsonDecode(raw) : raw as List;
      return list
          .map(
            (e) => {
              'name': (e['name'] ?? '').toString(),
              'quantity': (e['quantity'] ?? '').toString(),
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = (meal['mealName'] ?? meal['meal_name'] ?? 'Meal').toString();
    final mealType = (meal['mealType'] ?? meal['meal_type'] ?? '')
        .toString()
        .replaceAll('_', ' ')
        .toUpperCase();
    final mealTime = (meal['mealTime'] ?? meal['meal_time'] ?? '--:--')
        .toString();
    final recipe = (meal['recipe'] ?? '').toString();
    final ingredients = _parseIngredients(meal['ingredients']);
    final calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final protein =
        ((meal['proteinG'] ?? meal['protein_g']) as num?)?.toDouble() ?? 0;
    final carbs =
        ((meal['carbsG'] ?? meal['carbs_g']) as num?)?.toDouble() ?? 0;
    final fat = ((meal['fatG'] ?? meal['fat_g']) as num?)?.toDouble() ?? 0;
    final hasActual = actualLog != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Meal type + time badge
          if (mealType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$mealTime • $mealType',
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Hero meal name
          Text(
            name,
            style: GoogleFonts.sora(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Macro pills
          Row(
            children: [
              _MacroPill(
                label: 'CAL',
                value: '$calories',
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              _MacroPill(
                label: 'PROTEIN',
                value: '${protein.toStringAsFixed(1)}g',
                color: colors.info,
              ),
              const SizedBox(width: 8),
              _MacroPill(
                label: 'CARBS',
                value: '${carbs.toStringAsFixed(1)}g',
                color: colors.warning,
              ),
              const SizedBox(width: 8),
              _MacroPill(
                label: 'FAT',
                value: '${fat.toStringAsFixed(1)}g',
                color: colors.muscleArms,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Ingredients section
          Text(
            'INGREDIENTS',
            style: GoogleFonts.plusJakartaSans(
              color: colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.scale, size: 14, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rawMeasurementsNote,
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (ingredients.isEmpty)
            Text(
              'No ingredient details available.',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textMuted,
                fontSize: 13,
              ),
            )
          else
            ...ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        LucideIcons.circle_dot,
                        size: 10,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ing['name'] ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ing['quantity'] ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recipe section
          if (recipe.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'HOW TO MAKE',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: recipe,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.plusJakartaSans(
                  color: colors.textMuted,
                  fontSize: 13,
                  height: 1.6,
                ),
                listBullet: GoogleFonts.plusJakartaSans(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          // Log Actual CTA
          const SizedBox(height: 24),
          Semantics(
            label: hasActual ? 'Update actual meal log' : 'Log actual meal',
            button: true,
            child: GestureDetector(
              onTap: onLogActual,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.actionSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasActual ? 'UPDATE ACTUAL LOG' : 'LOG ACTUAL',
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.actionForeground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  const _PhotoAnalysisCard({
    required this.analysis,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final signedUrl = analysis['signedUrl'] as String?;
    final status = analysis['aiAnalysisStatus']?.toString() ?? 'pending';
    final result = analysis['analysisResult'] is Map
        ? Map<String, dynamic>.from(analysis['analysisResult'] as Map)
        : null;
    final macros = result?['macros'] is Map
        ? Map<String, dynamic>.from(result!['macros'] as Map)
        : null;
    final calories = (macros?['calories'] as num?)?.toInt();
    final protein = (macros?['proteinG'] as num?)?.toDouble();
    final carbs = (macros?['carbsG'] as num?)?.toDouble();
    final fat = (macros?['fatG'] as num?)?.toDouble();
    final confidence = (result?['confidence'] as num?)?.toDouble();

    final isReady = status == 'completed' && result != null;
    final isFailed = status == 'failed';

    final (badgeLabel, badgeColor, message) = switch (status) {
      'completed' => (
        'READY',
        colors.success,
        confidence == null
            ? 'Tap to review this meal.'
            : 'Tap to review. ${(confidence * 100).toStringAsFixed(0)}% confident.',
      ),
      'failed' => (
        'FAILED',
        colors.error,
        'Analysis failed. Retry when you are ready.',
      ),
      _ => (
        'ANALYZING',
        colors.primary,
        'Processing in the background. You can keep using the app.',
      ),
    };

    return GestureDetector(
      onTap: isReady ? onTap : null,
      child: Opacity(
        opacity: isReady || isFailed ? 1 : 0.96,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.cardGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (signedUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  child: Image.network(
                    signedUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 160,
                            color: badgeColor.withValues(alpha: 0.06),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ),
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: GoogleFonts.plusJakartaSans(
                              color: badgeColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isReady
                                ? 'Photo analysis complete'
                                : isFailed
                                ? 'Photo analysis failed'
                                : 'Photo analysis in progress',
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isFailed && !isReady)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (isReady &&
                        calories != null &&
                        protein != null &&
                        carbs != null &&
                        fat != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '$calories kcal  •  ${protein.toStringAsFixed(1)}g protein  •  ${carbs.toStringAsFixed(1)}g carbs  •  ${fat.toStringAsFixed(1)}g fat',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (isFailed) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: Icon(
                            LucideIcons.rotate_cw,
                            color: colors.error,
                            size: 14,
                          ),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.plusJakartaSans(
                              color: colors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.error),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _QuickLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = log['mealName']?.toString() ?? 'Meal';
    final calories = (log['calories'] as num?)?.toInt() ?? 0;
    final protein = (log['proteinG'] as num?)?.toDouble() ?? 0;
    final carbs = (log['carbsG'] as num?)?.toDouble() ?? 0;
    final fat = (log['fatG'] as num?)?.toDouble() ?? 0;
    final signedUrl = log['signedUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.cardGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signedUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: Image.network(
                signedUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 160,
                        color: colors.primary.withValues(alpha: 0.06),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.camera, size: 9, color: colors.primary),
                      const SizedBox(width: 3),
                      Text(
                        'PHOTO LOG',
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              '$calories kcal  •  ${protein.toStringAsFixed(1)}g protein  •  ${carbs.toStringAsFixed(1)}g carbs  •  ${fat.toStringAsFixed(1)}g fat',
              style: GoogleFonts.plusJakartaSans(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: color.withValues(alpha: 0.8),
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
