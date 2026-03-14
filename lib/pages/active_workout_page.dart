import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/app_color_scheme.dart';
import 'package:buddy/widgets/app_buttons.dart';
import 'package:buddy/models/gamification.dart';
import 'package:buddy/models/pr.dart';
import 'package:buddy/providers/health_provider.dart';
import 'package:buddy/providers/pr_provider.dart';
import 'package:buddy/providers/home_dashboard_provider.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/workout_service.dart';
import 'package:buddy/services/tts_service.dart';
import 'package:buddy/services/tts_cache.dart';
import 'package:buddy/services/beep_service.dart';
import 'package:buddy/services/progress_share_service.dart';
import 'package:buddy/widgets/app_snackbar.dart';
import 'package:buddy/widgets/progress_share_cards.dart';

enum _WorkoutPhase {
  intro,
  warmup,
  exercise,
  rest,
  paused,
  cooldown,
  completed,
}

enum _SetStatus { pending, completed, skipped }

class _SessionSetLog {
  _SessionSetLog({
    required this.exerciseIndex,
    required this.exerciseName,
    required this.setNumber,
    required this.status,
    this.weightKg,
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  final int exerciseIndex;
  final String exerciseName;
  final int setNumber;
  _SetStatus status;
  double? weightKg;
  DateTime loggedAt;

  Map<String, dynamic> toJson() => {
    'exerciseIndex': exerciseIndex,
    'exerciseName': exerciseName,
    'setNumber': setNumber,
    'status': status.name,
    'weightKg': weightKg,
    'loggedAt': loggedAt.toIso8601String(),
  };
}

class ActiveWorkoutPage extends ConsumerStatefulWidget {
  final String dayLabel;
  final List<dynamic> exercises;
  final int planId;
  final int dayId;

  const ActiveWorkoutPage({
    super.key,
    required this.dayLabel,
    required this.exercises,
    required this.planId,
    required this.dayId,
  });

  @override
  ConsumerState<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends ConsumerState<ActiveWorkoutPage>
    with TickerProviderStateMixin {
  _WorkoutPhase _phase = _WorkoutPhase.intro;
  int _exerciseIndex = 0;
  int _setIndex = 0;
  int _timerSeconds = 0;
  Timer? _timer;
  VoidCallback? _countdownOnDone;
  int _countdownTotalSeconds = 0;
  int? _sessionId;
  bool _isMuted = false;
  _WorkoutPhase? _pausedFromPhase;
  DateTime? _pausedAt;
  int _pausedDurationSeconds = 0;

  // ── Gamification counters ────────────────────────────────────────────────
  int _completedSets = 0;
  int _skippedExercises = 0;
  int _totalRestPeriods = 0;
  int _skippedRests = 0;
  final List<_SessionSetLog> _setLogs = [];
  final List<Map<String, dynamic>> _sessionNotes = [];
  final List<Map<String, dynamic>> _hrSnapshots = [];
  DateTime? _lastSessionSyncAt;

  late final List<String> _warmupChecklist;
  late final List<bool> _warmupCompleted;
  late final List<String> _cooldownChecklist;
  late final List<bool> _cooldownCompleted;
  DateTime? _warmupCompletedAt;
  DateTime? _cooldownCompletedAt;

  final Map<int, TextEditingController> _weightControllers = {};
  int? _heartRateBpm;
  int? _previousHeartRateBpm;
  String _heartRateZone = 'No data';
  Timer? _heartRateTimer;

  // Per-rest discipline tracking (for dots UI): true=honored, false=skipped, null=current
  final List<bool?> _restResults = [];

  // Beep milestone flags — reset each time a new rest countdown starts.
  bool _beep30Fired = false;
  bool _beep10Fired = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _ringController;
  final DateTime _startTime = DateTime.now();

  // ── Completion animation controllers ─────────────────────────────────────
  late AnimationController _completionFadeCtrl;
  late AnimationController _headerSlideCtrl;
  late AnimationController _statsCtrl;
  late AnimationController _xpBarCtrl;
  late AnimationController _levelPanelCtrl;
  late AnimationController _achievementCtrl;
  late AnimationController _doneButtonCtrl;

  bool _gamificationLoaded = false;
  SessionGamificationResult? _gamResult;

  bool _inSupersetSecondHalf = false;
  Map<String, PersonalRecord> _prMap = {};

  int _displayXp = 0;
  Timer? _xpCountTimer;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _completionFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _headerSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _statsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _xpBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _levelPanelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _achievementCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _doneButtonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _warmupChecklist = _buildWarmupChecklist();
    _warmupCompleted = List<bool>.filled(_warmupChecklist.length, false);
    _cooldownChecklist = _buildCooldownChecklist();
    _cooldownCompleted = List<bool>.filled(_cooldownChecklist.length, false);
    for (var i = 0; i < widget.exercises.length; i++) {
      _weightControllers[i] = TextEditingController();
    }

    _initializeSession();
    _startHeartRateSamplingLoop();
    _prewarmTts();
    _loadPrMap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartRateTimer?.cancel();
    _xpCountTimer?.cancel();
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    _pulseController.dispose();
    _ringController.dispose();
    _completionFadeCtrl.dispose();
    _headerSlideCtrl.dispose();
    _statsCtrl.dispose();
    _xpBarCtrl.dispose();
    _levelPanelCtrl.dispose();
    _achievementCtrl.dispose();
    _doneButtonCtrl.dispose();
    TtsService.instance.stop();
    TtsCache.instance.dispose();
    BeepService.instance.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppTheme.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  Future<void> _initializeSession() async {
    await _startSession();
    if (!mounted || _phase == _WorkoutPhase.completed) return;
    if (_phase == _WorkoutPhase.intro) {
      await _beginIntro();
    } else if (_phase == _WorkoutPhase.exercise ||
        _phase == _WorkoutPhase.rest) {
      _resumeCountdown();
      _announceResume();
    } else if (_phase == _WorkoutPhase.paused) {
      _announceResume(paused: true);
    }
  }

  Future<void> _startSession() async {
    try {
      final res = await WorkoutService.startSession(
        widget.planId,
        widget.dayId,
        date: _todayDate,
      );
      final data = res['data'];
      if (data is! Map<String, dynamic>) return;
      _sessionId = (data['id'] as num?)?.toInt();
      _hydrateFromSession(data);
    } catch (_) {}
  }

  void _hydrateFromSession(Map<String, dynamic> session) {
    if (!mounted) return;

    final setLogsRaw = (session['setLogs'] as List?) ?? const [];
    _setLogs
      ..clear()
      ..addAll(
        setLogsRaw.whereType<Map>().map((raw) {
          final map = raw.map((key, value) => MapEntry(key.toString(), value));
          final statusName = (map['status'] ?? 'pending').toString();
          final status = _SetStatus.values.firstWhere(
            (value) => value.name == statusName,
            orElse: () => _SetStatus.pending,
          );
          final loggedAtRaw = map['loggedAt']?.toString();
          return _SessionSetLog(
            exerciseIndex: (map['exerciseIndex'] as num?)?.toInt() ?? 0,
            exerciseName: (map['exerciseName'] ?? 'Exercise').toString(),
            setNumber: (map['setNumber'] as num?)?.toInt() ?? 1,
            status: status,
            weightKg: (map['weightKg'] as num?)?.toDouble(),
            loggedAt: DateTime.tryParse(loggedAtRaw ?? '') ?? DateTime.now(),
          );
        }).toList(),
      );

    final warmupData =
        (session['warmupData'] as Map?)?.cast<String, dynamic>() ?? {};
    final cooldownData =
        (session['cooldownData'] as Map?)?.cast<String, dynamic>() ?? {};

    final warmupChecks = (warmupData['completed'] as List?) ?? const [];
    for (var i = 0; i < _warmupCompleted.length; i++) {
      _warmupCompleted[i] =
          i < warmupChecks.length &&
          (warmupChecks[i] == true || warmupChecks[i] == 1);
    }

    final cooldownChecks = (cooldownData['completed'] as List?) ?? const [];
    for (var i = 0; i < _cooldownCompleted.length; i++) {
      _cooldownCompleted[i] =
          i < cooldownChecks.length &&
          (cooldownChecks[i] == true || cooldownChecks[i] == 1);
    }

    _warmupCompletedAt = DateTime.tryParse(
      (warmupData['completedAt'] ?? '').toString(),
    );
    _cooldownCompletedAt = DateTime.tryParse(
      (cooldownData['completedAt'] ?? '').toString(),
    );

    final notesRaw = (session['sessionNotes'] as List?) ?? const [];
    _sessionNotes
      ..clear()
      ..addAll(
        notesRaw
            .whereType<Map>()
            .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
            .toList(),
      );

    final hrRaw = (session['hrSnapshots'] as List?) ?? const [];
    _hrSnapshots
      ..clear()
      ..addAll(
        hrRaw
            .whereType<Map>()
            .map((raw) => raw.map((k, v) => MapEntry(k.toString(), v)))
            .toList(),
      );

    _pausedDurationSeconds =
        (session['pausedDurationSeconds'] as num?)?.toInt() ?? 0;
    _completedSets = _setLogs
        .where((log) => log.status == _SetStatus.completed)
        .length;
    _skippedExercises = _computeSkippedExercises();

    final runtime =
        (warmupData['_runtime'] as Map?)?.cast<String, dynamic>() ?? {};
    final completedAt = session['completedAt'];
    if (completedAt != null && completedAt.toString().isNotEmpty) {
      setState(() {
        _phase = _WorkoutPhase.completed;
        _gamificationLoaded = true;
      });
      _completionFadeCtrl.value = 1.0;
      _headerSlideCtrl.value = 1.0;
      _statsCtrl.value = 1.0;
      _xpBarCtrl.value = 1.0;
      _levelPanelCtrl.value = 1.0;
      _achievementCtrl.value = 1.0;
      _doneButtonCtrl.value = 1.0;
      return;
    }

    if (runtime.isNotEmpty && _restoreRuntime(runtime)) {
      setState(() {});
      return;
    }

    _restoreFallbackFromSetLogs();
    setState(() {});
  }

  Future<void> _loadPrMap() async {
    try {
      final map = await WorkoutService.getPersonalRecords();
      if (mounted) setState(() => _prMap = map);
    } catch (_) {}
  }

  int? _supersetPartnerIndex(int exIndex) {
    if (exIndex < 0 || exIndex >= widget.exercises.length) return null;
    final groupId = widget.exercises[exIndex]['supersetGroupId'];
    if (groupId == null) return null;
    for (var i = 0; i < widget.exercises.length; i++) {
      if (i == exIndex) continue;
      if (widget.exercises[i]['supersetGroupId'] == groupId) return i;
    }
    return null;
  }

  int _computeSkippedExercises() {
    var skipped = 0;
    for (var exIndex = 0; exIndex < widget.exercises.length; exIndex++) {
      final sets = (widget.exercises[exIndex]['sets'] ?? 3) as int;
      final allSkipped = List.generate(sets, (i) => i + 1).every((setNumber) {
        final log = _setLogs.where(
          (entry) =>
              entry.exerciseIndex == exIndex && entry.setNumber == setNumber,
        );
        return log.isNotEmpty && log.first.status == _SetStatus.skipped;
      });
      if (allSkipped) skipped++;
    }
    return skipped;
  }

  bool _restoreRuntime(Map<String, dynamic> runtime) {
    final phaseName = runtime['phase']?.toString();
    final restoredPhase = _WorkoutPhase.values.where(
      (p) => p.name == phaseName,
    );
    if (restoredPhase.isEmpty) return false;

    final exIndex = (runtime['exerciseIndex'] as num?)?.toInt() ?? 0;
    final setIndex = (runtime['setIndex'] as num?)?.toInt() ?? 0;
    if (widget.exercises.isNotEmpty &&
        (exIndex < 0 || exIndex >= widget.exercises.length)) {
      return false;
    }

    _phase = restoredPhase.first;
    _exerciseIndex = exIndex
        .clamp(0, max(0, widget.exercises.length - 1))
        .toInt();
    final setsForExercise = widget.exercises.isEmpty
        ? 1
        : ((widget.exercises[_exerciseIndex]['sets'] ?? 3) as int);
    _setIndex = setIndex.clamp(0, max(0, setsForExercise - 1)).toInt();
    _timerSeconds = ((runtime['timerSeconds'] as num?)?.toInt() ?? 0)
        .clamp(0, 3600)
        .toInt();
    _countdownTotalSeconds =
        ((runtime['countdownTotalSeconds'] as num?)?.toInt() ?? _timerSeconds)
            .clamp(0, 3600)
            .toInt();
    _totalRestPeriods =
        (runtime['totalRests'] as num?)?.toInt() ?? _totalRestPeriods;
    _skippedRests = (runtime['skippedRests'] as num?)?.toInt() ?? _skippedRests;

    final pausedFrom = runtime['pausedFromPhase']?.toString();
    _pausedFromPhase =
        _WorkoutPhase.values
            .where((value) => value.name == pausedFrom)
            .isNotEmpty
        ? _WorkoutPhase.values.firstWhere((value) => value.name == pausedFrom)
        : null;
    final pausedAtRaw = runtime['pausedAt']?.toString();
    _pausedAt = pausedAtRaw == null ? null : DateTime.tryParse(pausedAtRaw);

    final rests = (runtime['restResults'] as List?) ?? const [];
    _restResults
      ..clear()
      ..addAll(
        rests.map((value) {
          if (value == true) return true;
          if (value == false) return false;
          return null;
        }),
      );

    _countdownOnDone = _buildCountdownOnDoneForCurrentState();
    return true;
  }

  void _restoreFallbackFromSetLogs() {
    if (_warmupCompletedAt == null ||
        _warmupCompleted.where((value) => value).length <
            _warmupCompleted.length) {
      _phase = _WorkoutPhase.warmup;
      return;
    }

    for (var exIndex = 0; exIndex < widget.exercises.length; exIndex++) {
      final sets = (widget.exercises[exIndex]['sets'] ?? 3) as int;
      for (var setNum = 1; setNum <= sets; setNum++) {
        final hasLogged = _setLogs.any(
          (entry) =>
              entry.exerciseIndex == exIndex && entry.setNumber == setNum,
        );
        if (!hasLogged) {
          _phase = _WorkoutPhase.exercise;
          _exerciseIndex = exIndex;
          _setIndex = setNum - 1;
          _timerSeconds = 60;
          _countdownTotalSeconds = 60;
          _countdownOnDone = _buildCountdownOnDoneForCurrentState();
          return;
        }
      }
    }

    _phase = _cooldownCompletedAt != null
        ? _WorkoutPhase.completed
        : _WorkoutPhase.cooldown;
  }

  VoidCallback? _buildCountdownOnDoneForCurrentState() {
    if (_phase == _WorkoutPhase.exercise) {
      final ex = widget.exercises[_exerciseIndex];
      final sets = (ex['sets'] ?? 3) as int;
      final reps = ex['repsOrTime'] ?? ex['reps_or_time'] ?? '10';
      final isLastSet = _setIndex >= sets - 1;
      final setText = isLastSet
          ? 'Last set! '
          : 'Set ${_setIndex + 1} of $sets. ';
      return () => _playTTS('${setText}Do $reps reps.');
    }

    if (_phase == _WorkoutPhase.rest) {
      return () {
        setState(() {
          if (_restResults.isNotEmpty) {
            _restResults[_restResults.length - 1] = true;
          }
        });
        final ex = widget.exercises[_exerciseIndex];
        final sets = (ex['sets'] ?? 3) as int;
        final nextSet = _setIndex + 1;
        if (nextSet >= sets) {
          _startExercise(_exerciseIndex + 1, 0);
        } else {
          _startExercise(_exerciseIndex, nextSet);
        }
      };
    }

    return null;
  }

  void _announceResume({bool paused = false}) {
    if (widget.exercises.isEmpty) return;
    if (_phase == _WorkoutPhase.warmup) {
      _playTTS(
        'Welcome back. Continue your warmup and then start the session.',
      );
      return;
    }
    if (_phase == _WorkoutPhase.cooldown) {
      _playTTS(
        'Welcome back. You are in cooldown. Finish your recovery steps.',
      );
      return;
    }

    final ex = widget.exercises[_exerciseIndex];
    final name = (ex['name'] ?? 'Exercise').toString();
    final sets = (ex['sets'] ?? 3) as int;
    final prefix = paused ? 'Session paused.' : 'Resuming session.';
    _playTTS('$prefix $name, set ${_setIndex + 1} of $sets.');
  }

  List<String> _muscleGroupsForDay() {
    final muscles = <String>{};
    for (final ex in widget.exercises) {
      final raw = (ex['muscleGroup'] ?? ex['muscle_group'] ?? '')
          .toString()
          .trim();
      if (raw.isNotEmpty) muscles.add(raw);
    }
    return muscles.toList();
  }

  List<String> _buildWarmupChecklist() {
    final muscles = _muscleGroupsForDay();
    final hasLower = muscles.any(
      (m) =>
          m.toLowerCase().contains('leg') || m.toLowerCase().contains('glute'),
    );
    final hasUpper = muscles.any(
      (m) =>
          m.toLowerCase().contains('chest') ||
          m.toLowerCase().contains('back') ||
          m.toLowerCase().contains('shoulder'),
    );

    final items = <String>[
      '3 min brisk walk or march in place',
      '2 rounds of light mobility flow',
    ];
    if (hasUpper) {
      items.add('Band pull-aparts + shoulder circles (2 min)');
    }
    if (hasLower) {
      items.add('Hip openers + bodyweight squats (2 min)');
    }
    items.add('2 ramp-up sets for your first movement');
    return items;
  }

  List<String> _buildCooldownChecklist() {
    final muscles = _muscleGroupsForDay();
    final target = 10 + Random().nextInt(11);
    return [
      '$target minute cooldown walk and nasal breathing',
      'Light stretch: ${muscles.isEmpty ? 'full body' : muscles.join(', ')}',
      'Hydrate and log recovery note',
    ];
  }

  Map<String, dynamic> _warmupPayload() => {
    'items': _warmupChecklist,
    'completed': _warmupCompleted,
    'completedAt': _warmupCompletedAt?.toIso8601String(),
    '_runtime': _runtimePayload(),
  };

  Map<String, dynamic> _cooldownPayload() => {
    'items': _cooldownChecklist,
    'completed': _cooldownCompleted,
    'completedAt': _cooldownCompletedAt?.toIso8601String(),
  };

  List<Map<String, dynamic>> _setLogsPayload() =>
      _setLogs.map((log) => log.toJson()).toList();

  Map<String, dynamic> _runtimePayload() => {
    'phase': _phase.name,
    'exerciseIndex': _exerciseIndex,
    'setIndex': _setIndex,
    'timerSeconds': _timerSeconds,
    'countdownTotalSeconds': _countdownTotalSeconds,
    'totalRests': _totalRestPeriods,
    'skippedRests': _skippedRests,
    'restResults': _restResults,
    'pausedFromPhase': _pausedFromPhase?.name,
    'pausedAt': _pausedAt?.toIso8601String(),
  };

  Future<void> _syncSessionLog({bool force = false}) async {
    if (_sessionId == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastSessionSyncAt != null &&
        now.difference(_lastSessionSyncAt!).inSeconds < 5) {
      return;
    }
    _lastSessionSyncAt = now;
    try {
      await WorkoutService.logWorkoutSession(_sessionId!, {
        'pausedDurationSeconds': _pausedDurationSeconds,
        'warmupData': _warmupPayload(),
        'cooldownData': _cooldownPayload(),
        'setLogs': _setLogsPayload(),
        'sessionNotes': _sessionNotes,
        'hrSnapshots': _hrSnapshots,
      });
    } catch (_) {}
  }

  String _currentPhaseName() {
    switch (_phase) {
      case _WorkoutPhase.intro:
        return 'intro';
      case _WorkoutPhase.warmup:
        return 'warmup';
      case _WorkoutPhase.exercise:
        return 'exercise';
      case _WorkoutPhase.rest:
        return 'rest';
      case _WorkoutPhase.paused:
        return 'paused';
      case _WorkoutPhase.cooldown:
        return 'cooldown';
      case _WorkoutPhase.completed:
        return 'completed';
    }
  }

  String _resolveHrZone(int bpm) {
    const max = 190;
    final pct = bpm / max;
    if (pct < 0.6) return 'Recovery';
    if (pct < 0.7) return 'Fat Burn';
    if (pct < 0.8) return 'Aerobic';
    if (pct < 0.9) return 'Threshold';
    return 'Peak';
  }

  Future<void> _sampleHeartRate() async {
    try {
      final hasPermission = await ref.read(healthPermissionProvider.future);
      if (!hasPermission || !mounted || _phase == _WorkoutPhase.completed) {
        return;
      }
      final health = ref.read(healthProvider);
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 5));
      final data = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      if (data.isEmpty) return;
      data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final value = data.first.value;
      if (value is! NumericHealthValue) return;
      final bpm = value.numericValue.toInt();
      final zone = _resolveHrZone(bpm);
      if (!mounted) return;
      setState(() {
        _previousHeartRateBpm = _heartRateBpm;
        _heartRateBpm = bpm;
        _heartRateZone = zone;
      });
      _hrSnapshots.add({
        'bpm': bpm,
        'zone': zone,
        'capturedAt': now.toIso8601String(),
        'phase': _currentPhaseName(),
      });
      _syncSessionLog();
    } catch (_) {}
  }

  void _scheduleNextHeartRateSample() {
    _heartRateTimer?.cancel();
    final seconds = 30 + Random().nextInt(16);
    _heartRateTimer = Timer(Duration(seconds: seconds), () async {
      if (!mounted) return;
      await _sampleHeartRate();
      _scheduleNextHeartRateSample();
    });
  }

  void _startHeartRateSamplingLoop() {
    _scheduleNextHeartRateSample();
  }

  void _prewarmTts() {
    final exs = widget.exercises;
    final scripts = <String>[];

    if (exs.isNotEmpty) {
      final firstName = exs[0]['name'] ?? 'the first exercise';
      scripts.add(
        "Let's get it! Starting your ${widget.dayLabel} workout. "
        "Today we have ${exs.length} exercises. "
        "We'll begin with $firstName. Get ready!",
      );
    }

    for (var i = 0; i < exs.length; i++) {
      final ex = exs[i];
      final name = ex['name'] ?? 'Exercise';
      final sets = (ex['sets'] ?? 3) as int;
      final reps = ex['repsOrTime'] ?? ex['reps_or_time'] ?? '10';
      final rest = (ex['restSeconds'] ?? ex['rest_seconds'] ?? 60) as int;
      final restText = _formatDurationForSpeech(rest);

      for (var s = 0; s < sets; s++) {
        final isLastSet = s >= sets - 1;
        final setText = isLastSet ? 'Last set! ' : 'Set ${s + 1} of $sets. ';
        scripts.add('$name. ${setText}Do $reps. Go!');
        scripts.add('${setText}Do $reps reps.');
        final nextText = isLastSet
            ? (i + 1 < exs.length
                  ? 'Next up: ${exs[i + 1]['name']}'
                  : 'This is the last exercise!')
            : '${ex['name']}, set ${s + 2}';
        scripts.add('Great work! Rest for $restText. $nextText coming up.');
      }
    }

    scripts.add(
      "Incredible work! You've completed your ${widget.dayLabel} workout. "
      "That's how champions are made. Rest up and I'll see you next time!",
    );

    TtsCache.instance.prefetch(scripts);
  }

  Future<void> _completeSessionWithGamification() async {
    if (_sessionId == null) return;
    try {
      final workoutEnd = DateTime.now();
      final duration = workoutEnd.difference(_startTime).inSeconds;
      final totalExercises = widget.exercises.length;
      final completedExercises = totalExercises - _skippedExercises;

      final res = await WorkoutService.completeSessionWithGamification(
        _sessionId!,
        durationSeconds: duration,
        totalExercises: totalExercises,
        completedExercises: completedExercises,
        totalRests: _totalRestPeriods,
        skippedRests: _skippedRests,
        completedSets: _completedSets,
        pausedDurationSeconds: _pausedDurationSeconds,
        warmupData: _warmupPayload(),
        cooldownData: _cooldownPayload(),
        setLogs: _setLogsPayload(),
        sessionNotes: _sessionNotes,
        hrSnapshots: _hrSnapshots,
        dayLabel: widget.dayLabel,
      );

      final result = SessionGamificationResult.fromJson(
        res['data'] as Map<String, dynamic>,
      );
      ref.read(sessionGamificationProvider.notifier).set(result);
      ref.invalidate(progressProvider);
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(weeklyWorkoutSummaryProvider);
      ref.invalidate(prMapProvider);
      writeWorkoutToHC(start: _startTime, end: workoutEnd, dayLabel: widget.dayLabel);

      if (mounted) {
        setState(() {
          _gamResult = result;
          _gamificationLoaded = true;
        });
        _playCompletionAnimation(result);
      }
    } catch (e) {
      debugPrint('Gamification error: $e');
      if (mounted) setState(() => _gamificationLoaded = true);
    }
  }

  Future<void> _openWorkoutSharePreview() async {
    final captureKey = GlobalKey();
    final duration = DateTime.now().difference(_startTime);
    final completedExercises = widget.exercises.length - _skippedExercises;
    final totalXp = _gamResult == null
        ? 0
        : _gamResult!.xpEarned + _gamResult!.achievementXp;
    final achievements =
        _gamResult?.newAchievements
            .map((achievement) => achievement.name)
            .toList() ??
        const <String>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var sharing = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: captureKey,
                      child: WorkoutShareCard(
                        dayLabel: widget.dayLabel,
                        durationMinutes: duration.inMinutes,
                        completedExercises: completedExercises,
                        totalExercises: widget.exercises.length,
                        xpEarned: totalXp,
                        currentStreak: _gamResult?.currentStreak ?? 0,
                        newLevel: _gamResult?.newLevel ?? 1,
                        levelLabel: _gamResult?.levelLabel ?? 'Beginner',
                        unlockedAchievements: achievements,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Preview your workout card before sharing.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: sharing
                                ? null
                                : () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: context.colors.border,
                              ),
                              foregroundColor: context.colors.textMuted,
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: sharing
                                ? null
                                : () async {
                                    setModalState(() => sharing = true);
                                    try {
                                      final bytes =
                                          await ProgressShareService.captureBoundaryPng(
                                            captureKey,
                                          );
                                      await ProgressShareService.sharePngBytes(
                                        pngBytes: bytes,
                                        fileStem:
                                            'workout_completion_${DateTime.now().millisecondsSinceEpoch}',
                                        text:
                                            'Workout complete with Buddy. #fitness',
                                        subject: 'My workout result',
                                      );
                                    } catch (e) {
                                      if (sheetContext.mounted) {
                                        AppSnackbar.error(
                                          sheetContext,
                                          'Could not share workout card: $e',
                                        );
                                      }
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setModalState(() => sharing = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.actionSurface,
                              foregroundColor: context.colors.actionForeground,
                            ),
                            icon: sharing
                                ?       SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.actionForeground,
                                    ),
                                  )
                                : const Icon(LucideIcons.send, size: 16),
                            label: Text(sharing ? 'Sharing...' : 'Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _playCompletionAnimation(SessionGamificationResult result) async {
    await _completionFadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    await _headerSlideCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    await _statsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _startXpCountUp(result.xpEarned + result.achievementXp);
    await _xpBarCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    await _levelPanelCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (result.newAchievements.isNotEmpty) {
      HapticFeedback.mediumImpact();
      await _achievementCtrl.forward();
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) await _doneButtonCtrl.forward();
  }

  void _startXpCountUp(int target) {
    _displayXp = 0;
    final steps = 30;
    final increment = (target / steps).ceil().clamp(1, 9999);
    int count = 0;
    _xpCountTimer?.cancel();
    _xpCountTimer = Timer.periodic(const Duration(milliseconds: 23), (t) {
      count++;
      if (mounted) {
        setState(() => _displayXp = (_displayXp + increment).clamp(0, target));
      }
      if (count >= steps || _displayXp >= target) {
        t.cancel();
        if (mounted) setState(() => _displayXp = target);
      }
    });
  }

  Future<void> _playTTS(String text) async {
    if (_isMuted) return;
    try {
      await TtsService.instance.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> _beginIntro() async {
    setState(() => _phase = _WorkoutPhase.intro);
    _syncSessionLog(force: true);

    if (widget.exercises.isEmpty) {
      _finishWorkout();
      return;
    }

    final firstEx = widget.exercises[0];
    final firstName = firstEx['name'] ?? 'the first exercise';
    await _playTTS(
      "Let's get it! Starting your ${widget.dayLabel} workout. "
      "Today we have ${widget.exercises.length} exercises. "
      "We'll begin with $firstName. Get ready!",
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _phase = _WorkoutPhase.warmup);
    _syncSessionLog(force: true);
  }

  String _formatDurationForSpeech(int totalSeconds) {
    if (totalSeconds <= 0) return '0 seconds';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minuteText = minutes == 1 ? '1 minute' : '$minutes minutes';
    final secondText = seconds == 1 ? '1 second' : '$seconds seconds';
    if (minutes == 0) return secondText;
    if (seconds == 0) return minuteText;
    return '$minuteText $secondText';
  }

  void _prefetchNextStepAudio(
    int exIndex,
    int setIndex, {
    required bool inRest,
  }) {
    final exs = widget.exercises;
    if (exs.isEmpty) return;

    final ex = exs[exIndex];
    final sets = (ex['sets'] ?? 3) as int;
    final reps = ex['repsOrTime'] ?? ex['reps_or_time'] ?? '10';
    final rest = (ex['restSeconds'] ?? ex['rest_seconds'] ?? 60) as int;
    final restText = _formatDurationForSpeech(rest);
    final name = ex['name'] ?? 'Exercise';
    final texts = <String>[];

    if (!inRest) {
      final isLastSet = setIndex >= sets - 1;
      final nextText = isLastSet
          ? (exIndex + 1 < exs.length
                ? 'Next up: ${exs[exIndex + 1]['name']}'
                : 'This is the last exercise!')
          : '$name, set ${setIndex + 2}';
      texts.add('Great work! Rest for $restText. $nextText coming up.');
      final nextSet = setIndex + 1;
      if (nextSet >= sets) {
        if (exIndex + 1 < exs.length) {
          final nx = exs[exIndex + 1];
          texts.add(
            '${nx['name'] ?? 'Exercise'}. Set 1 of ${(nx['sets'] ?? 3) as int}. Do ${nx['repsOrTime'] ?? nx['reps_or_time'] ?? '10'}. Go!',
          );
        }
      } else {
        final isNextLast = nextSet >= sets - 1;
        texts.add(
          '$name. ${isNextLast ? 'Last set! ' : 'Set ${nextSet + 1} of $sets. '}Do $reps. Go!',
        );
      }
    } else {
      final nextSet = setIndex + 1;
      if (nextSet >= sets) {
        if (exIndex + 1 < exs.length) {
          final nx = exs[exIndex + 1];
          texts.add(
            '${nx['name'] ?? 'Exercise'}. Set 1 of ${(nx['sets'] ?? 3) as int}. Do ${nx['repsOrTime'] ?? nx['reps_or_time'] ?? '10'}. Go!',
          );
        }
      } else {
        final isNextLast = nextSet >= sets - 1;
        texts.add(
          '$name. ${isNextLast ? 'Last set! ' : 'Set ${nextSet + 1} of $sets. '}Do $reps. Go!',
        );
      }
    }

    TtsCache.instance.ensureReady(texts);
  }

  void _startExercise(int exIndex, int setIndex) {
    if (exIndex >= widget.exercises.length) {
      _startCooldown();
      return;
    }

    final ex = widget.exercises[exIndex];
    final name = ex['name'] ?? 'Exercise';
    final sets = (ex['sets'] ?? 3) as int;
    final reps = ex['repsOrTime'] ?? ex['reps_or_time'] ?? '10';
    final isLastSet = setIndex >= sets - 1;
    final setText = isLastSet ? 'Last set! ' : 'Set ${setIndex + 1} of $sets. ';

    setState(() {
      _phase = _WorkoutPhase.exercise;
      _exerciseIndex = exIndex;
      _setIndex = setIndex;
      _timerSeconds = 60;
    });

    final controller = _weightControllers[exIndex];
    final previousCompletedSet = _setLogs
        .where(
          (log) =>
              log.exerciseIndex == exIndex &&
              log.status == _SetStatus.completed &&
              log.weightKg != null,
        )
        .toList();
    if (controller != null &&
        controller.text.trim().isEmpty &&
        previousCompletedSet.isNotEmpty) {
      controller.text = previousCompletedSet.last.weightKg!.toStringAsFixed(1);
    }

    _startCountdown(60, onDone: () => _playTTS('${setText}Do $reps reps.'));
    _playTTS('$name. ${setText}Do $reps. Go!');
    _prefetchNextStepAudio(exIndex, setIndex, inRest: false);
    _syncSessionLog(force: true);
  }

  void _startRest(int exIndex, int setIndex) {
    final ex = widget.exercises[exIndex];
    final rest = (ex['restSeconds'] ?? ex['rest_seconds'] ?? 60) as int;
    final sets = (ex['sets'] ?? 3) as int;

    _beep30Fired = false;
    _beep10Fired = false;
    BeepService.instance.preload();

    setState(() {
      _phase = _WorkoutPhase.rest;
      _exerciseIndex = exIndex;
      _setIndex = setIndex;
      _timerSeconds = rest;
      _totalRestPeriods++;
      _restResults.add(null);
    });

    final isLastSet = setIndex >= sets - 1;
    final nextText = isLastSet
        ? (exIndex + 1 < widget.exercises.length
              ? 'Next up: ${widget.exercises[exIndex + 1]['name']}'
              : 'This is the last exercise!')
        : '${ex['name']}, set ${setIndex + 2}';

    _playTTS(
      'Great work! Rest for ${_formatDurationForSpeech(rest)}. $nextText coming up.',
    );
    _prefetchNextStepAudio(exIndex, setIndex, inRest: true);

    _startCountdown(
      rest,
      onDone: () {
        setState(() {
          if (_restResults.isNotEmpty) {
            _restResults[_restResults.length - 1] = true;
          }
        });
        final nextSet = setIndex + 1;
        if (nextSet >= sets) {
          _startExercise(exIndex + 1, 0);
        } else {
          _startExercise(exIndex, nextSet);
        }
      },
    );
    _syncSessionLog(force: true);
  }

  void _startCountdown(int seconds, {VoidCallback? onDone}) {
    _timer?.cancel();
    _countdownOnDone = onDone;
    _countdownTotalSeconds = seconds;
    _timerSeconds = seconds;
    _ringController.reset();
    _ringController.animateTo(1.0, duration: Duration(seconds: seconds));

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timerSeconds--);

      if (_phase == _WorkoutPhase.rest) {
        if (!_beep30Fired && _timerSeconds <= 50 && _timerSeconds > 20) {
          _beep30Fired = true;
          HapticFeedback.mediumImpact();
          BeepService.instance.playWarningBeep();
        } else if (!_beep10Fired && _timerSeconds <= 20 && _timerSeconds > 0) {
          _beep10Fired = true;
          HapticFeedback.heavyImpact();
          BeepService.instance.playUrgentBeep();
        }
      }

      if (_timerSeconds <= 0) {
        t.cancel();
        onDone?.call();
      }
    });
  }

  void _resumeCountdown() {
    final remaining = _timerSeconds;
    if (remaining <= 0) {
      _countdownOnDone?.call();
      return;
    }
    _timer?.cancel();
    final base = _countdownTotalSeconds > 0
        ? _countdownTotalSeconds
        : remaining;
    final elapsed = (base - remaining).clamp(0, base);
    _ringController.value = base == 0 ? 0 : elapsed / base;
    _ringController.animateTo(1.0, duration: Duration(seconds: remaining));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timerSeconds--);
      if (_phase == _WorkoutPhase.rest) {
        if (!_beep30Fired && _timerSeconds <= 50 && _timerSeconds > 20) {
          _beep30Fired = true;
          HapticFeedback.mediumImpact();
          BeepService.instance.playWarningBeep();
        } else if (!_beep10Fired && _timerSeconds <= 20 && _timerSeconds > 0) {
          _beep10Fired = true;
          HapticFeedback.heavyImpact();
          BeepService.instance.playUrgentBeep();
        }
      }
      if (_timerSeconds <= 0) {
        t.cancel();
        _countdownOnDone?.call();
      }
    });
  }

  void _pauseSession() {
    if (_phase != _WorkoutPhase.exercise && _phase != _WorkoutPhase.rest) {
      return;
    }
    _timer?.cancel();
    _ringController.stop();
    _pausedAt = DateTime.now();
    _pausedFromPhase = _phase;
    setState(() => _phase = _WorkoutPhase.paused);
    _syncSessionLog(force: true);
  }

  void _resumeSession() {
    final pausedFrom = _pausedFromPhase;
    if (pausedFrom == null) return;
    if (_pausedAt != null) {
      _pausedDurationSeconds += DateTime.now().difference(_pausedAt!).inSeconds;
    }
    _pausedAt = null;
    setState(() => _phase = pausedFrom);
    _resumeCountdown();
    _syncSessionLog(force: true);
  }

  void _updateSetLog(_SetStatus status, {double? weightKg}) {
    final ex = widget.exercises[_exerciseIndex];
    final existingIndex = _setLogs.indexWhere(
      (log) =>
          log.exerciseIndex == _exerciseIndex && log.setNumber == _setIndex + 1,
    );
    if (existingIndex >= 0) {
      _setLogs[existingIndex]
        ..status = status
        ..weightKg = weightKg
        ..loggedAt = DateTime.now();
    } else {
      _setLogs.add(
        _SessionSetLog(
          exerciseIndex: _exerciseIndex,
          exerciseName: (ex['name'] ?? 'Exercise').toString(),
          setNumber: _setIndex + 1,
          status: status,
          weightKg: weightKg,
        ),
      );
    }
  }

  double? _currentWeightInput() {
    final text = _weightControllers[_exerciseIndex]?.text.trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  // DONE ✓ — exercise completed, increment set count, go to rest (or superset B)
  void _doneExercise() {
    _timer?.cancel();
    _ringController.stop();
    HapticFeedback.lightImpact();
    _updateSetLog(_SetStatus.completed, weightKg: _currentWeightInput());

    final currentExIdx = _exerciseIndex;
    final partnerIdx = _supersetPartnerIndex(currentExIdx);

    if (partnerIdx != null && !_inSupersetSecondHalf) {
      // A done → jump immediately to B (no rest)
      setState(() {
        _completedSets++;
        _exerciseIndex = partnerIdx;
        _inSupersetSecondHalf = true;
        _phase = _WorkoutPhase.exercise;
        _timerSeconds = 60;
      });
      // Prefill B's weight from previous completed set
      final controller = _weightControllers[partnerIdx];
      final prevB = _setLogs
          .where(
            (log) =>
                log.exerciseIndex == partnerIdx &&
                log.status == _SetStatus.completed &&
                log.weightKg != null,
          )
          .toList();
      if (controller != null &&
          controller.text.trim().isEmpty &&
          prevB.isNotEmpty) {
        controller.text = prevB.last.weightKg!.toStringAsFixed(1);
      }
      final partnerEx = widget.exercises[partnerIdx];
      final name = (partnerEx['name'] ?? 'Exercise').toString();
      final sets = (partnerEx['sets'] ?? 3) as int;
      final reps = partnerEx['repsOrTime'] ?? partnerEx['reps_or_time'] ?? '10';
      final isLastSet = _setIndex >= sets - 1;
      final setText = isLastSet
          ? 'Last set! '
          : 'Set ${_setIndex + 1} of $sets. ';
      _startCountdown(60, onDone: () => _playTTS('${setText}Do $reps reps.'));
      _playTTS('Now: $name. ${setText}Do $reps. Go!');
    } else if (_inSupersetSecondHalf) {
      // B done → reset superset state and go to rest from A's perspective
      setState(() {
        _completedSets++;
        _inSupersetSecondHalf = false;
      });
      final aIdx = _supersetPartnerIndex(currentExIdx) ?? currentExIdx;
      _startRest(aIdx, _setIndex);
    } else {
      // Normal (no superset)
      setState(() => _completedSets++);
      _startRest(currentExIdx, _setIndex);
    }
    _syncSessionLog(force: true);
  }

  // SKIP → (exercise phase) — skip set without counting, go to rest
  void _skipExerciseToRest() {
    _timer?.cancel();
    _ringController.stop();
    _updateSetLog(_SetStatus.skipped, weightKg: _currentWeightInput());
    final currentExIdx = _exerciseIndex;
    if (_inSupersetSecondHalf) {
      setState(() => _inSupersetSecondHalf = false);
      final aIdx = _supersetPartnerIndex(currentExIdx) ?? currentExIdx;
      _startRest(aIdx, _setIndex);
    } else {
      _startRest(currentExIdx, _setIndex);
    }
    _syncSessionLog(force: true);
  }

  // SKIP REST → (rest phase) — skip rest and go to next
  void _skipRest() {
    _timer?.cancel();
    _ringController.stop();
    setState(() {
      _skippedRests++;
      if (_restResults.isNotEmpty) {
        _restResults[_restResults.length - 1] = false;
      }
    });
    final ex = widget.exercises[_exerciseIndex];
    final sets = (ex['sets'] ?? 3) as int;
    final nextSet = _setIndex + 1;
    if (nextSet >= sets) {
      _startExercise(_exerciseIndex + 1, 0);
    } else {
      _startExercise(_exerciseIndex, nextSet);
    }
    _syncSessionLog(force: true);
  }

  Future<void> _skipCurrentExerciseCompletely() async {
    final shouldSkip = await _confirmAction(
      title: 'Skip exercise?',
      body: 'Skip all remaining sets for this exercise.',
      actionLabel: 'Skip Exercise',
    );
    if (!shouldSkip) return;

    _timer?.cancel();
    _ringController.stop();
    final ex = widget.exercises[_exerciseIndex];
    final sets = (ex['sets'] ?? 3) as int;
    for (var i = _setIndex; i < sets; i++) {
      final existing = _setLogs.any(
        (log) => log.exerciseIndex == _exerciseIndex && log.setNumber == i + 1,
      );
      if (!existing) {
        _setLogs.add(
          _SessionSetLog(
            exerciseIndex: _exerciseIndex,
            exerciseName: (ex['name'] ?? 'Exercise').toString(),
            setNumber: i + 1,
            status: _SetStatus.skipped,
            weightKg: _currentWeightInput(),
          ),
        );
      }
    }
    setState(() => _skippedExercises++);
    _syncSessionLog(force: true);
    _startExercise(_exerciseIndex + 1, 0);
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _phase = _WorkoutPhase.cooldown);
    _syncSessionLog(force: true);
  }

  Future<bool> _confirmAction({
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          body,
          style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              actionLabel,
              style: GoogleFonts.plusJakartaSans(color: context.colors.accent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openNotesSheet() async {
    var noteText = '';
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session note',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                autofocus: true,
                onChanged: (value) => noteText = value,
                style: GoogleFonts.plusJakartaSans(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'How does this session feel?',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: context.colors.textMuted,
                  ),
                  filled: true,
                  fillColor: context.colors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (noteText.trim().isEmpty) {
                      Navigator.pop(context, false);
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.actionSurface,
                    foregroundColor: context.colors.actionForeground,
                  ),
                  child: const Text('Save note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (added == true && noteText.trim().isNotEmpty) {
      _sessionNotes.add({
        'text': noteText.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'phase': _currentPhaseName(),
        'exerciseIndex': _exerciseIndex,
        'setIndex': _setIndex,
      });
      if (mounted) setState(() {});
      _syncSessionLog(force: true);
    }
  }

  Future<void> _finishWorkout() async {
    setState(() => _phase = _WorkoutPhase.completed);
    _heartRateTimer?.cancel();
    await _syncSessionLog(force: true);
    await _playTTS(
      "Incredible work! You've completed your ${widget.dayLabel} workout. "
      "That's how champions are made. Rest up and I'll see you next time!",
    );
    await _completeSessionWithGamification();
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(weeklyWorkoutSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(progressProvider).asData?.value.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  (_phase == _WorkoutPhase.rest
                          ? context.colors.phaseRest
                          : _phase == _WorkoutPhase.completed
                          ? context.colors.phaseCompleted
                          : context.colors.phaseExercise)
                      .withValues(alpha: 0.8),
                  context.colors.background,
                ],
              ),
            ),
          ),
          _phase == _WorkoutPhase.completed
              ? _buildCompletedView()
              : _phase == _WorkoutPhase.intro
              ? _buildIntroView()
              : _phase == _WorkoutPhase.warmup
              ? _buildChecklistPhase(
                  title: 'Warmup',
                  subtitle: 'Prep muscles and raise core temperature',
                  items: _warmupChecklist,
                  checks: _warmupCompleted,
                  cta: 'Start Workout',
                  onDone: () {
                    _warmupCompletedAt = DateTime.now();
                    _syncSessionLog(force: true);
                    _startExercise(0, 0);
                  },
                )
              : _phase == _WorkoutPhase.cooldown
              ? _buildChecklistPhase(
                  title: 'Cooldown',
                  subtitle: 'Bring heart rate down and recover',
                  items: _cooldownChecklist,
                  checks: _cooldownCompleted,
                  cta: 'Finish Session',
                  onDone: () {
                    _cooldownCompletedAt = DateTime.now();
                    _syncSessionLog(force: true);
                    _finishWorkout();
                  },
                )
              : _phase == _WorkoutPhase.paused
              ? _buildPausedView()
              : _buildActiveView(streak),
        ],
      ),
    );
  }

  Widget _buildIntroView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child:       Icon(
                LucideIcons.dumbbell,
                color: context.colors.primary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.dayLabel.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Today\'s Session',
            style: GoogleFonts.sora(
              color: context.colors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.exercises.length} exercises — let\'s make it count',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistPhase({
    required String title,
    required String subtitle,
    required List<String> items,
    required List<bool> checks,
    required String cta,
    required VoidCallback onDone,
  }) {
    final completed = checks.where((v) => v).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.sora(
              color: context.colors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed/${items.length} blocks complete',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => Semantics(
                label: items[i],
                checked: checks[i],
                button: true,
                child: InkWell(
                  onTap: () {
                    setState(() => checks[i] = !checks[i]);
                    _syncSessionLog(force: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: checks[i]
                            ? context.colors.primary
                            : context.colors.border,
                      ),
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          Icon(
                            checks[i] ? LucideIcons.check : LucideIcons.circle,
                            color: checks[i]
                                ? context.colors.primary
                                : context.colors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              items[i],
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: context.colors.actionSurface,
                foregroundColor: context.colors.actionForeground,
              ),
              child: Text(
                cta,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedView() {
    final ex = widget.exercises[_exerciseIndex];
    final name = (ex['name'] ?? 'Exercise').toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                    Icon(LucideIcons.pause, color: context.colors.accent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Workout Paused',
                style: GoogleFonts.sora(
                  color: context.colors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$name • set ${_setIndex + 1}',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _resumeSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.actionSurface,
                    foregroundColor: context.colors.actionForeground,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Resume Session',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView(int streak) {
    if (widget.exercises.isEmpty) return const SizedBox();

    final ex = widget.exercises[_exerciseIndex];
    final name = ex['name'] ?? 'Exercise';
    final muscle = (ex['muscleGroup'] ?? ex['muscle_group'] ?? '') as String;
    final sets = (ex['sets'] ?? 3) as int;
    final reps = ex['repsOrTime'] ?? ex['reps_or_time'] ?? '10';
    final isRest = _phase == _WorkoutPhase.rest;
    final completedForExercise = _setLogs
        .where(
          (log) =>
              log.exerciseIndex == _exerciseIndex &&
              log.status == _SetStatus.completed,
        )
        .length;
    final hrTrendIcon = _heartRateBpm == null || _previousHeartRateBpm == null
        ? LucideIcons.minus
        : _heartRateBpm! > _previousHeartRateBpm!
        ? LucideIcons.trending_up
        : _heartRateBpm! < _previousHeartRateBpm!
        ? LucideIcons.trending_down
        : LucideIcons.minus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        kToolbarHeight,
                        24,
                        0,
                      ),
                      child: Row(
                        children: [
                          AppBackButton(
                            icon: LucideIcons.x,
                            onPressed: () => Navigator.pop(context),
                            iconSize: 20,
                            color: context.colors.textMuted,
                          ),
                          const Spacer(),
                          if (streak >= 3)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.xpGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.colors.xpGold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                        Icon(
                                    LucideIcons.flame,
                                    color: context.colors.xpGold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$streak',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.colors.xpGold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              '${_exerciseIndex + 1} / ${widget.exercises.length}',
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Spacer(),
                          Semantics(
                            label: _isMuted
                                ? 'Voice muted, tap to unmute'
                                : 'Voice on, tap to mute',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _isMuted = !_isMuted);
                                if (_isMuted) TtsService.instance.stop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.card,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _isMuted
                                        ? context.colors.border
                                        : context.colors.primary,
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isMuted
                                            ? LucideIcons.volume_x
                                            : LucideIcons.volume_2,
                                        color: _isMuted
                                            ? context.colors.textMuted
                                            : context.colors.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isMuted ? 'Muted' : 'Voice On',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: _isMuted
                                              ? context.colors.textMuted
                                              : context.colors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: 'Pause workout',
                              button: true,
                              child: GestureDetector(
                                onTap: _pauseSession,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                            Icon(
                                        LucideIcons.pause,
                                        color: context.colors.textPrimary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Pause',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: context.colors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              label: _heartRateBpm == null
                                  ? 'Heart rate unavailable'
                                  : 'Heart rate: $_heartRateBpm bpm, $_heartRateZone zone',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.colors.border,
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        hrTrendIcon,
                                        color: context.colors.accent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _heartRateBpm == null
                                              ? 'HR unavailable'
                                              : '$_heartRateBpm bpm • $_heartRateZone',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: context.colors.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Semantics(
                            label: _sessionNotes.isEmpty
                                ? 'Add workout notes'
                                : 'Workout notes, ${_sessionNotes.length} note${_sessionNotes.length == 1 ? '' : 's'}',
                            button: true,
                            child: GestureDetector(
                              onTap: _openNotesSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.colors.border,
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                            Icon(
                                        LucideIcons.notebook_pen,
                                        color: context.colors.textPrimary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _sessionNotes.isEmpty
                                            ? 'Notes'
                                            : 'Notes ${_sessionNotes.length}',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: context.colors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRest) ...[
                      Builder(
                        builder: (context) {
                          final partnerIdx = _supersetPartnerIndex(
                            _exerciseIndex,
                          );
                          if (partnerIdx == null) {
                            return const SizedBox.shrink();
                          }
                          final partnerEx = widget.exercises[partnerIdx];
                          final label = _inSupersetSecondHalf
                              ? 'SUPERSET · Set ${_setIndex + 1}/$sets · Now: ${ex['name']}'
                              : 'SUPERSET · Set ${_setIndex + 1}/$sets · Next: ${partnerEx['name']}';
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.colors.accent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                        Icon(
                                    LucideIcons.link_2,
                                    color: context.colors.accent,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: context.colors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isRest
                            ? context.colors.accent.withValues(alpha: 0.15)
                            : context.colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isRest ? 'REST' : 'SET ${_setIndex + 1} OF $sets',
                        style: GoogleFonts.plusJakartaSans(
                          color: isRest ? context.colors.accent : context.colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: isRest
                          ? 'Rest timer: $_timerSeconds seconds remaining'
                          : 'Exercise timer: $_timerSeconds seconds',
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: ExcludeSemantics(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _ringController,
                                builder: (_, _) => SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: CircularProgressIndicator(
                                    value: isRest
                                        ? (_timerSeconds /
                                              ((ex['restSeconds'] ??
                                                      ex['rest_seconds'] ??
                                                      60)
                                                  as int))
                                        : null,
                                    strokeWidth: 5,
                                    backgroundColor: context.colors.border,
                                    color: isRest
                                        ? context.colors.accent
                                        : context.colors.primary,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _timerSeconds > 0 ? '$_timerSeconds' : '0',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.colors.textPrimary,
                                      fontSize: 64,
                                      fontWeight: FontWeight.w200,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  Text(
                                    'seconds',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.colors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (!isRest) ...[
                      Semantics(
                        label:
                            '$name, $reps reps${muscle.isNotEmpty ? ', $muscle' : ''}. Set ${_setIndex + 1} of $sets.',
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  color: context.colors.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$reps reps',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.colors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (muscle.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.card,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Text(
                                    muscle.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: context.colors.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSetProgressDots(sets),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _weightControllers[_exerciseIndex],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _syncSessionLog(force: true),
                          style: GoogleFonts.plusJakartaSans(
                            color: context.colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Set weight (kg)',
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: context.colors.textMuted,
                            ),
                            prefixIcon:       Icon(
                              LucideIcons.dumbbell,
                              color: context.colors.textMuted,
                              size: 16,
                            ),
                            filled: true,
                            fillColor: context.colors.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: context.colors.border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final normalized = (ex['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .replaceAll(RegExp(r'[^a-z0-9]'), '');
                          final pr = _prMap[normalized];
                          return Text(
                            pr != null
                                ? 'PR: ${pr.weightKg % 1 == 0 ? pr.weightKg.toInt() : pr.weightKg}kg × ${pr.reps} reps'
                                : 'No PR yet',
                            style: GoogleFonts.plusJakartaSans(
                              color: pr != null
                                  ? context.colors.primary.withValues(alpha: 0.8)
                                  : context.colors.textMuted.withValues(
                                      alpha: 0.5,
                                    ),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'Rest',
                        style: GoogleFonts.sora(
                          color: context.colors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Recovery time — breathe',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (_totalRestPeriods > 0) ...[
                        const SizedBox(height: 10),
                        _buildDisciplineDots(),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Completed $completedForExercise/$sets sets',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (_exerciseIndex + 1 < widget.exercises.length) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'NEXT UP',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.colors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.exercises[_exerciseIndex + 1]['name'] ??
                                    '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        kToolbarHeight,
                        24,
                        24,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.card.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 52,
                              child: Row(
                                children: [
                                  if (!isRest) ...[
                                    Expanded(
                                      child: Semantics(
                                        label: 'Mark set as done',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: _doneExercise,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: context.colors.backgroundSecondary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: context.colors.border,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'DONE ✓',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: context.colors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Semantics(
                                      label: isRest
                                          ? 'Skip rest period'
                                          : 'Skip this set',
                                      button: true,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final confirmed = await _confirmAction(
                                            title: isRest
                                                ? 'Skip rest?'
                                                : 'Skip this set?',
                                            body: isRest
                                                ? 'Jump immediately to the next set.'
                                                : 'This set will be logged as skipped.',
                                            actionLabel: isRest
                                                ? 'Skip Rest'
                                                : 'Skip Set',
                                          );
                                          if (!confirmed) return;
                                          isRest
                                              ? _skipRest()
                                              : _skipExerciseToRest();
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: context.colors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: context.colors.primary
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            isRest
                                                ? 'SKIP REST →'
                                                : 'SKIP SET →',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: context.colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton(
                                onPressed: _skipCurrentExerciseCompletely,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: context.colors.accent.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  backgroundColor: context.colors.background,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'SKIP EXERCISE',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: context.colors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetProgressDots(int sets) {
    return Semantics(
      label: 'Set progress: set ${_setIndex + 1} of $sets',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(sets, (i) {
            final log = _setLogs.where(
              (entry) =>
                  entry.exerciseIndex == _exerciseIndex &&
                  entry.setNumber == i + 1,
            );
            final status = log.isEmpty ? _SetStatus.pending : log.first.status;
            final isCurrent =
                i == _setIndex && _phase == _WorkoutPhase.exercise;
            final icon = switch (status) {
              _SetStatus.completed => LucideIcons.check,
              _SetStatus.skipped => LucideIcons.x,
              _SetStatus.pending => LucideIcons.circle,
            };
            final color = switch (status) {
              _SetStatus.completed => context.colors.primary,
              _SetStatus.skipped => context.colors.accent,
              _SetStatus.pending =>
                isCurrent
                    ? context.colors.textPrimary
                    : context.colors.textMuted,
            };
            return Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: context.colors.card,
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.9)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 14),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDisciplineDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalRestPeriods, (i) {
        final result = i < _restResults.length ? _restResults[i] : null;
        if (result == false) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              LucideIcons.x,
              color: context.colors.xpGold.withValues(alpha: 0.5),
              size: 10,
            ),
          );
        }
        final color = result == true
            ? context.colors.primary
            : context.colors.textMuted;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      }),
    );
  }

  Widget _buildCompletedView() {
    final duration = DateTime.now().difference(_startTime);
    final minutes = duration.inMinutes;
    final completedExercises = widget.exercises.length - _skippedExercises;
    final restsHonored = _totalRestPeriods - _skippedRests;

    return FadeTransition(
      opacity: _completionFadeCtrl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, kToolbarHeight + 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _headerSlideCtrl,
                      curve: Curves.easeOut,
                    ),
                  ),
              child: FadeTransition(
                opacity: _headerSlideCtrl,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:       Icon(
                        LucideIcons.trophy,
                        color: context.colors.primary,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WORKOUT COMPLETE',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.dayLabel,
                      style: GoogleFonts.sora(
                        color: context.colors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Stat cards
            FadeTransition(
              opacity: _statsCtrl,
              child: Row(
                children: [
                  _StatCard(label: 'Duration', value: '${minutes}m'),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Exercises', value: '$completedExercises'),
                  const SizedBox(width: 10),
                  _StatCard(
                    label: 'Rests Honored',
                    value: _totalRestPeriods > 0
                        ? '$restsHonored/$_totalRestPeriods'
                        : '—',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // XP bar
            AnimatedBuilder(
              animation: _xpBarCtrl,
              builder: (_, _) {
                final targetXp = _gamResult != null
                    ? _gamResult!.xpEarned + _gamResult!.achievementXp
                    : 0;
                return FadeTransition(
                  opacity: _xpBarCtrl,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'XP EARNED',
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              !_gamificationLoaded
                                  ? 'Calculating...'
                                  : '+$_displayXp XP',
                              style: GoogleFonts.plusJakartaSans(
                                color: context.colors.xpGold,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (_gamificationLoaded && targetXp > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _xpBarCtrl.value.clamp(0.0, 1.0),
                              backgroundColor: context.colors.border,
                              valueColor:       AlwaysStoppedAnimation(
                                context.colors.xpGold,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          if (_gamResult != null) ...[
                            const SizedBox(height: 8),
                            _XpBreakdownRow(breakdown: _gamResult!.xpBreakdown),
                          ],
                        ] else if (!_gamificationLoaded) ...[
                          const SizedBox(height: 10),
                                Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.xpGold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Level-up panel or streak
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _levelPanelCtrl,
                      curve: Curves.easeOut,
                    ),
                  ),
              child: FadeTransition(
                opacity: _levelPanelCtrl,
                child: _gamResult != null
                    ? (_gamResult!.didLevelUp
                          ? _buildLevelUpPanel(_gamResult!)
                          : _buildStreakIndicator(_gamResult!.currentStreak))
                    : const SizedBox.shrink(),
              ),
            ),

            // Achievements
            if (_gamResult != null &&
                _gamResult!.newAchievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _achievementCtrl,
                child: Column(
                  children: _gamResult!.newAchievements.asMap().entries.map((
                    entry,
                  ) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            entry.key < _gamResult!.newAchievements.length - 1
                            ? 10
                            : 0,
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(0, 0.3 + entry.key * 0.1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _achievementCtrl,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: _AchievementCard(achievement: entry.value),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // New PRs
            if (_gamResult != null && _gamResult!.newPrs.isNotEmpty) ...[
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _achievementCtrl,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.xpGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                                Icon(
                            LucideIcons.trophy,
                            color: context.colors.xpGold,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'NEW PERSONAL RECORDS',
                            style: GoogleFonts.plusJakartaSans(
                              color: context.colors.xpGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._gamResult!.newPrs.map(
                        (pr) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pr.exerciseNameDisplay,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: context.colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pr.weightKg % 1 == 0 ? pr.weightKg.toInt() : pr.weightKg}kg × ${pr.reps}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.colors.xpGold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            FadeTransition(
              opacity: _doneButtonCtrl,
              child: Semantics(
                label: 'Share progress',
                button: true,
                child: GestureDetector(
                  onTap: _openWorkoutSharePreview,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                Icon(
                            LucideIcons.share_2,
                            size: 16,
                            color: context.colors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SHARE PROGRESS',
                            style: GoogleFonts.plusJakartaSans(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // DONE button
            FadeTransition(
              opacity: _doneButtonCtrl,
              child: Semantics(
                label: 'Done, close workout summary',
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: context.colors.actionSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        'DONE',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.colors.actionForeground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
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

  Widget _buildLevelUpPanel(SessionGamificationResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child:       Icon(
              LucideIcons.trending_up,
              color: context.colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL UP',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You\'re now ${result.levelLabel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Level ${result.newLevel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakIndicator(int streak) {
    if (streak < 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                Icon(LucideIcons.flame, color: context.colors.xpGold, size: 20),
          const SizedBox(width: 8),
          Text(
            '$streak day streak',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.xpGold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _XpBreakdownRow extends StatelessWidget {
  final XpBreakdown breakdown;

  const _XpBreakdownRow({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final parts = <(String, int)>[];

    if (breakdown.fromExercises > 0) {
      parts.add(('Sets', breakdown.fromExercises));
    }

    if (breakdown.disciplineBonus > 0) {
      parts.add(('Rest', breakdown.disciplineBonus));
    }

    if (breakdown.completionBonus > 0) {
      parts.add(('Completion', breakdown.completionBonus));
    }

    if (breakdown.durationBonus > 0) {
      parts.add(('Duration', breakdown.durationBonus));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: parts
          .map(
            (p) => Text(
              '${p.$1} +${p.$2}',
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textMuted,
                fontSize: 11,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementData achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.xpGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.xpGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child:       Icon(
              LucideIcons.trophy,
              color: context.colors.xpGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.xpGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${achievement.xpReward} XP',
            style: GoogleFonts.plusJakartaSans(
              color: context.colors.xpGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
