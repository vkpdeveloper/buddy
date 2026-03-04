import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:buddy/app_theme.dart';
import 'package:buddy/models/gamification.dart';
import 'package:buddy/providers/progress_provider.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/services/tts_service.dart';
import 'package:buddy/services/tts_cache.dart';
import 'package:buddy/services/beep_service.dart';

enum _WorkoutPhase { intro, exercise, rest, completed }

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
  int? _sessionId;
  bool _isMuted = false;

  // ── Gamification counters ────────────────────────────────────────────────
  int _completedSets = 0;
  final int _skippedExercises = 0;
  int _totalRestPeriods = 0;
  int _skippedRests = 0;

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

  int _displayXp = 0;
  Timer? _xpCountTimer;

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

    _startSession();
    _prewarmTts();
    _beginIntro();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _xpCountTimer?.cancel();
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
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      final res = await ApiClient.startSession(widget.planId, widget.dayId);
      _sessionId = res['data']?['id'];
    } catch (_) {}
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
      final duration = DateTime.now().difference(_startTime).inSeconds;
      final totalExercises = widget.exercises.length;
      final completedExercises = totalExercises - _skippedExercises;

      final res = await ApiClient.completeSessionWithGamification(
        _sessionId!,
        durationSeconds: duration,
        totalExercises: totalExercises,
        completedExercises: completedExercises,
        totalRests: _totalRestPeriods,
        skippedRests: _skippedRests,
        completedSets: _completedSets,
        dayLabel: widget.dayLabel,
      );

      final result = SessionGamificationResult.fromJson(
        res['data'] as Map<String, dynamic>,
      );
      ref.read(sessionGamificationProvider.notifier).set(result);
      ref.invalidate(progressProvider);

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
    if (result.newAchievements.isNotEmpty) await _achievementCtrl.forward();
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
      if (mounted)
        setState(() => _displayXp = (_displayXp + increment).clamp(0, target));
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
    _startExercise(0, 0);
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
      _finishWorkout();
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

    _startCountdown(60, onDone: () => _playTTS('${setText}Do $reps reps.'));
    _playTTS('$name. ${setText}Do $reps. Go!');
    _prefetchNextStepAudio(exIndex, setIndex, inRest: false);
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
          if (_restResults.isNotEmpty)
            _restResults[_restResults.length - 1] = true;
        });
        final nextSet = setIndex + 1;
        if (nextSet >= sets) {
          _startExercise(exIndex + 1, 0);
        } else {
          _startExercise(exIndex, nextSet);
        }
      },
    );
  }

  void _startCountdown(int seconds, {VoidCallback? onDone}) {
    _timer?.cancel();
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

  // DONE ✓ — exercise completed, increment set count, go to rest
  void _doneExercise() {
    _timer?.cancel();
    _ringController.stop();
    setState(() => _completedSets++);
    _startRest(_exerciseIndex, _setIndex);
  }

  // SKIP → (exercise phase) — skip set without counting, go to rest
  void _skipExerciseToRest() {
    _timer?.cancel();
    _ringController.stop();
    _startRest(_exerciseIndex, _setIndex);
  }

  // SKIP REST → (rest phase) — skip rest and go to next
  void _skipRest() {
    _timer?.cancel();
    _ringController.stop();
    setState(() {
      _skippedRests++;
      if (_restResults.isNotEmpty)
        _restResults[_restResults.length - 1] = false;
    });
    final ex = widget.exercises[_exerciseIndex];
    final sets = (ex['sets'] ?? 3) as int;
    final nextSet = _setIndex + 1;
    if (nextSet >= sets) {
      _startExercise(_exerciseIndex + 1, 0);
    } else {
      _startExercise(_exerciseIndex, nextSet);
    }
  }

  Future<void> _finishWorkout() async {
    setState(() => _phase = _WorkoutPhase.completed);
    await _playTTS(
      "Incredible work! You've completed your ${widget.dayLabel} workout. "
      "That's how champions are made. Rest up and I'll see you next time!",
    );
    await _completeSessionWithGamification();
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(progressProvider).asData?.value.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                          ? const Color(0xFF1E3A2F)
                          : _phase == _WorkoutPhase.completed
                          ? const Color(0xFF1A2E1E)
                          : const Color(0xFF1A2429))
                      .withValues(alpha: 0.8),
                  AppTheme.backgroundDark,
                ],
              ),
            ),
          ),
          _phase == _WorkoutPhase.completed
              ? _buildCompletedView()
              : _phase == _WorkoutPhase.intro
              ? _buildIntroView()
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
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.dumbbell,
                color: AppTheme.primary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.dayLabel.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DAY WORKOUT',
            style: GoogleFonts.crimsonPro(
              color: AppTheme.textCream,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.exercises.length} exercises • Let\'s make it count',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 13,
            ),
          ),
        ],
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

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, kToolbarHeight, 24, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    color: AppTheme.textSageMuted,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              if (streak >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.xpGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.xpGold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        color: AppTheme.xpGold,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.xpGold,
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
                    color: AppTheme.textSageMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _isMuted = !_isMuted);
                  if (_isMuted) TtsService.instance.stop();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Icon(
                    _isMuted ? LucideIcons.volume_x : LucideIcons.volume_2,
                    color: _isMuted ? AppTheme.textSageMuted : AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Phase indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isRest
                ? AppTheme.accent.withValues(alpha: 0.15)
                : AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isRest ? 'REST' : 'SET ${_setIndex + 1} OF $sets',
            style: GoogleFonts.plusJakartaSans(
              color: isRest ? AppTheme.accent : AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Timer ring
        SizedBox(
          width: 200,
          height: 200,
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
                              ((ex['restSeconds'] ?? ex['rest_seconds'] ?? 60)
                                  as int))
                        : null,
                    strokeWidth: 5,
                    backgroundColor: AppTheme.borderDark,
                    color: isRest ? AppTheme.accent : AppTheme.primary,
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
                      color: AppTheme.textCream,
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    'seconds',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Content
        if (!isRest) ...[
          Text(
            name,
            style: GoogleFonts.crimsonPro(
              color: AppTheme.textCream,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '$reps reps',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (muscle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Text(
                muscle.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSageMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ] else ...[
          Text(
            'Rest',
            style: GoogleFonts.crimsonPro(
              color: AppTheme.textCream,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recovery time — breathe',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSageMuted,
              fontSize: 13,
            ),
          ),
          // Discipline dots
          if (_totalRestPeriods > 0) ...[
            const SizedBox(height: 10),
            _buildDisciplineDots(),
          ],
          // Next exercise preview
          if (_exerciseIndex + 1 < widget.exercises.length) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NEXT UP',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSageMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.exercises[_exerciseIndex + 1]['name'] ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        const Spacer(),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, kToolbarHeight, 24, 32),
          child: Row(
            children: [
              if (!isRest) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: _doneExercise,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'DONE ✓',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textCream,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: isRest ? _skipRest : _skipExerciseToRest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isRest ? 'SKIP REST →' : 'SKIP →',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.backgroundDark,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
              color: AppTheme.xpGold.withValues(alpha: 0.5),
              size: 10,
            ),
          );
        }
        final color = result == true
            ? AppTheme.primary
            : AppTheme.textSageMuted.withValues(alpha: 0.3);
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
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.trophy,
                        color: AppTheme.primary,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WORKOUT COMPLETE',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.dayLabel,
                      style: GoogleFonts.crimsonPro(
                        color: AppTheme.textCream,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
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
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderDark),
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
                                color: AppTheme.textSageMuted,
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
                                color: AppTheme.xpGold,
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
                              backgroundColor: AppTheme.borderDark,
                              valueColor: const AlwaysStoppedAnimation(
                                AppTheme.xpGold,
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
                          const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.xpGold,
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

            const SizedBox(height: 32),

            // DONE button
            FadeTransition(
              opacity: _doneButtonCtrl,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'DONE',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.backgroundDark,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.trending_up,
              color: AppTheme.primary,
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
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You\'re now ${result.levelLabel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Level ${result.newLevel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSageMuted,
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.flame, color: AppTheme.xpGold, size: 20),
          const SizedBox(width: 8),
          Text(
            '$streak day streak',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.xpGold,
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
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textCream,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSageMuted,
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
                color: AppTheme.textSageMuted,
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.xpGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.xpGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.trophy,
              color: AppTheme.xpGold,
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
                    color: AppTheme.xpGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.name,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textCream,
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
              color: AppTheme.xpGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
