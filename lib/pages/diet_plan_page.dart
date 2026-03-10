import 'dart:convert';
import 'dart:io';

import 'package:buddy/app_theme.dart';
import 'package:buddy/providers/generation_provider.dart';
import 'package:buddy/services/diet_service.dart';
import 'package:buddy/services/media_service.dart';
import 'package:buddy/services/notification_service.dart';
import 'package:buddy/widgets/generating_banner.dart';
import 'package:buddy/widgets/shimmer_loading.dart';
import 'package:buddy/widgets/app_empty_state.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/widgets/app_snackbar.dart';
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
  int? _activePlanId;
  Map<String, dynamic>? _planData;
  Map<int, bool> _todayLog = {};
  Map<int, Map<String, dynamic>> _actualLogs = {};
  bool _isLoading = true;
  int _selectedDayIndex = 0;

  bool _isPhotoLogging = false;
  List<Map<String, dynamic>> _quickLogs = [];

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

      if (!mounted) return;
      setState(() {
        _planData = planRes;
        _activePlanId = id;
        _todayLog = completionMap;
        _actualLogs = actualMap;
        _quickLogs = quickLogs;
        _selectedDayIndex = days.isEmpty
            ? 0
            : nowDayIndex.clamp(0, days.length - 1);

        if (!_hasSavedReminderTime) {
          _workoutTime = inferredWorkoutTime;
        }
      });
    } catch (_) {
      // Keep existing state on transient API failures.
    }
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
  }

  Future<void> _logActualMeal(int mealId, Map<String, dynamic> payload) async {
    await DietService.logActualMeal(_todayDate, {'mealId': mealId, ...payload});
    await _loadPlanDetail(_activePlanId!);
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
      final attachmentId =
          (uploadRes['data'] as Map<String, dynamic>)['id'] as int;

      // Analyze
      final analyzeRes = await MediaService.analyzeMealPhoto(attachmentId);
      final result =
          (analyzeRes['data'] as Map<String, dynamic>)['analysisResult']
              as Map<String, dynamic>;

      if (!mounted) return;
      setState(() => _isPhotoLogging = false);
      _showPhotoResultSheet(
        file: file,
        attachmentId: attachmentId,
        result: result,
      );
    } catch (e) {
      if (mounted) setState(() => _isPhotoLogging = false);
    }
  }

  void _showPhotoResultSheet({
    required File file,
    required int attachmentId,
    required Map<String, dynamic> result,
  }) {
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
      backgroundColor: AppTheme.cardDark,
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
                    color: AppTheme.primary,
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
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 11,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(confidence * 100).toStringAsFixed(0)}% confident',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
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
              child: Image.file(
                file,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),

            // Macro row
            Row(
              children: [
                _MacroPill(
                  label: 'CAL',
                  value: '$calories',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'PROTEIN',
                  value: '${protein.toStringAsFixed(1)}g',
                  color: AppTheme.info,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'CARBS',
                  value: '${carbs.toStringAsFixed(1)}g',
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _MacroPill(
                  label: 'FAT',
                  value: '${fat.toStringAsFixed(1)}g',
                  color: AppTheme.muscleArms,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ingredients
            if (ingredients.isNotEmpty) ...[
              Text(
                'DETECTED ITEMS',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
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
                      const Icon(
                        LucideIcons.circle_dot,
                        size: 10,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ing['name']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        ing['quantity']?.toString() ?? '',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textSageMuted,
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
                  } catch (_) {}
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.actionSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LOG THIS MEAL',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.actionForeground,
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
    var localReminderEnabled = _reminderEnabled;
    var localLeadMinutes = _reminderLeadMinutes;
    var localWorkoutTime = _workoutTime;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
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
                    color: AppTheme.primary,
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
                          color: AppTheme.textCream,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: localReminderEnabled,
                      activeThumbColor: AppTheme.primary,
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
                      backgroundColor: AppTheme.cardDark,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [30, 45, 60, 90]
                              .map(
                                (m) => ListTile(
                                  title: Text(
                                    '$m min before',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.textCream,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: m == localLeadMinutes
                                      ? const Icon(
                                          LucideIcons.check,
                                          color: AppTheme.primary,
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

  @override
  Widget build(BuildContext context) {
    ref.listen<GenerationStatus>(generationStatusProvider, (prev, next) {
      if (prev?.diet != 'done' && next.diet == 'done') {
        _loadPlans();
      }
    });

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Nav bar is 76 + bottomInset tall, positioned absolutely at bottom: 0
    final fabBottom = 76.0 + bottomInset + 16.0;

    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
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
                        color: AppTheme.actionSurface,
                        shape: BoxShape.circle,
                      ),
                      child: ExcludeSemantics(
                        child: _isPhotoLogging
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.actionForeground,
                                  ),
                                ),
                              )
                            : const Icon(
                                LucideIcons.scan_line,
                                color: AppTheme.actionForeground,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderDark),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                7,
                (_) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShimmerBox(width: 44, height: 36, borderRadius: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const ShimmerBox(
            width: double.infinity,
            height: 58,
            borderRadius: 14,
          ),
          const SizedBox(height: 12),
          const ShimmerBox(
            width: double.infinity,
            height: 74,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Diet Plan',
                  style: GoogleFonts.sora(
                    color: AppTheme.textCream,
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
                color: _reminderEnabled
                    ? AppTheme.primary
                    : AppTheme.textSageMuted,
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
    final isGenerating =
        genStatus.diet == 'pending' || genStatus.diet == 'generating';

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
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: days.length,
            itemBuilder: (ctx, i) {
              final d = Map<String, dynamic>.from(days[i] as Map);
              final dayName =
                  (d['dayName'] ?? d['day_name'] ?? 'Day ${i + 1}') as String;
              final isSelected = _selectedDayIndex == i;
              return Semantics(
                label: dayName,
                button: true,
                selected: isSelected,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    width: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderDark,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        dayName.substring(0, 3).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected
                              ? AppTheme.oledBlack
                              : AppTheme.textSageMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
                if (_quickLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'CAPTURED MEALS',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
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
    final calProgress = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
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
                  color: AppTheme.textCream,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${consumedCalories.toInt()} / ${targetCalories.toInt()} cal',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary,
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
              backgroundColor: AppTheme.borderDark,
              color: AppTheme.primary,
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
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniProgress(
                  label: 'Carbs',
                  value: consumedCarbs,
                  target: targetCarbs,
                  color: AppTheme.macroCarbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniProgress(
                  label: 'Fat',
                  value: consumedFat,
                  target: targetFat,
                  color: AppTheme.textSageMuted,
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
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toInt()}g/${target.toInt()}g',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textSageMuted,
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
            backgroundColor: AppTheme.borderDark,
            color: color,
          ),
        ),
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
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textCream,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textSageMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevron_right,
                    color: AppTheme.textSageMuted,
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
      final fatG =
          ((meal['fatG'] ?? meal['fat_g']) as num?)?.toDouble() ?? 0;
      final name =
          (meal['mealName'] ?? meal['meal_name'] ?? 'Meal').toString();
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

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
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
            });

            try {
              final res = await MediaService.uploadMealPhoto(file, mime);
              final data = res['data'] as Map<String, dynamic>;
              setSheetState(() {
                attachmentId = data['id'] as int;
                isUploading = false;
              });
            } catch (e) {
              setSheetState(() {
                isUploading = false;
                uploadError = 'Upload failed';
              });
            }
          }

          Future<void> runAnalysis() async {
            if (attachmentId == null) return;
            setSheetState(() => isAnalyzing = true);
            try {
              final res = await MediaService.analyzeMealPhoto(attachmentId!);
              final result =
                  (res['data'] as Map<String, dynamic>)['analysisResult']
                      as Map<String, dynamic>;
              final macros = result['macros'] as Map<String, dynamic>;
              setSheetState(() {
                calCtrl.text = (macros['calories'] as num).toInt().toString();
                protCtrl.text = (macros['proteinG'] as num).toStringAsFixed(1);
                carbsCtrl.text = (macros['carbsG'] as num).toStringAsFixed(1);
                fatCtrl.text = (macros['fatG'] as num).toStringAsFixed(1);
                aiConfidence = (result['confidence'] as num).toDouble();
                isAnalyzing = false;
              });
            } catch (e) {
              setSheetState(() => isAnalyzing = false);
            }
          }

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
                    color: AppTheme.primary,
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
                                      backgroundColor: AppTheme.cardDark,
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
                                              leading: const Icon(
                                                LucideIcons.camera,
                                                color: AppTheme.primary,
                                              ),
                                              title: Text(
                                                'Camera',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: AppTheme.textCream,
                                                    ),
                                              ),
                                              onTap: () => Navigator.pop(
                                                pickerCtx,
                                                ImageSource.camera,
                                              ),
                                            ),
                                            ListTile(
                                              leading: const Icon(
                                                LucideIcons.image,
                                                color: AppTheme.primary,
                                              ),
                                              title: Text(
                                                'Gallery',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: AppTheme.textCream,
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
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              )
                            : const Icon(
                                LucideIcons.camera,
                                color: AppTheme.primary,
                                size: 14,
                              ),
                        label: Text(
                          isUploading
                              ? 'Uploading…'
                              : selectedPhoto == null
                              ? 'Add Photo'
                              : 'Change Photo',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
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
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.actionForeground,
                                ),
                              )
                            : const Icon(
                                LucideIcons.sparkles,
                                size: 14,
                                color: AppTheme.actionForeground,
                              ),
                        label: Text(
                          isAnalyzing ? 'Analyzing…' : 'Analyze',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.actionForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.actionSurface,
                          foregroundColor: AppTheme.actionForeground,
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
                      color: AppTheme.error,
                      fontSize: 11,
                    ),
                  ),
                ],

                if (aiConfidence != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI estimate — ${(aiConfidence! * 100).toStringAsFixed(0)}% confident',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                _EditField(controller: mealNameCtrl, label: 'What you ate'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _EditField(
                        controller: calCtrl,
                        label: 'Calories',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _EditField(
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
                      child: _EditField(
                        controller: carbsCtrl,
                        label: 'Carbs (g)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _EditField(
                        controller: fatCtrl,
                        label: 'Fat (g)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _EditField(controller: notesCtrl, label: 'Notes', maxLines: 2),
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
                        color: AppTheme.actionSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'SAVE ACTUAL LOG',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.actionForeground,
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
    );
  }

  void _showDetailSheet() {
    final meal = widget.meal;
    final name = meal['mealName'] ?? meal['meal_name'] ?? 'Meal';
    final recipe = (meal['recipe'] ?? '').toString();
    final ingredients = _parseIngredients(meal['ingredients']);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'INGREDIENTS',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            if (ingredients.isEmpty)
              Text(
                'No ingredient details available.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 13,
                ),
              )
            else
              ...ingredients.map(
                (ing) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${ing['name']} — ${ing['quantity']}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            if (recipe.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'HOW TO MAKE',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
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
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  listBullet: GoogleFonts.plusJakartaSans(
                    color: AppTheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        color: _isCompleted
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasActual
              ? AppTheme.primary.withValues(alpha: 0.5)
              : (_isCompleted
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : AppTheme.borderDark),
        ),
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
                        child: GestureDetector(
                          onTap: _toggleDone,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _isCompleted
                                  ? AppTheme.primary
                                  : AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isCompleted
                                    ? AppTheme.primary
                                    : AppTheme.borderDark,
                              ),
                            ),
                            child: _isCompleted
                                ? const ExcludeSemantics(
                                    child: Icon(
                                      LucideIcons.check,
                                      color: AppTheme.oledBlack,
                                      size: 16,
                                    ),
                                  )
                                : null,
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
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$mealTime • $mealType',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.primary,
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
                                      color: AppTheme.accent.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ACTUAL',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textCream,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  if (hasPhoto) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      LucideIcons.camera,
                                      size: 11,
                                      color: AppTheme.primary,
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
                                    ? AppTheme.textSageMuted
                                    : AppTheme.textCream,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                            child: const ExcludeSemantics(
                              child: Icon(
                                LucideIcons.grip_vertical,
                                color: AppTheme.textSageMuted,
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
                          color: AppTheme.textSageMuted,
                          fontSize: 11,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showLogActualSheet,
                        icon: const Icon(
                          LucideIcons.pencil_line,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        label: Text(
                          hasActual ? 'Update Actual' : 'Log Actual',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
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

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textCream,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.textSageMuted,
          fontSize: 12,
        ),
        filled: true,
        fillColor: AppTheme.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
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
    final name = log['mealName']?.toString() ?? 'Meal';
    final calories = (log['calories'] as num?)?.toInt() ?? 0;
    final protein = (log['proteinG'] as num?)?.toDouble() ?? 0;
    final carbs = (log['carbsG'] as num?)?.toDouble() ?? 0;
    final fat = (log['fatG'] as num?)?.toDouble() ?? 0;
    final signedUrl = log['signedUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (signedUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
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
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
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
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.camera,
                        size: 9,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PHOTO LOG',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primary,
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
                      color: AppTheme.textCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
                color: AppTheme.textSageMuted,
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
