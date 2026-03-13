import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/services/generation_service.dart';

class GenerationJobStatus {
  final String status;
  final String stageKey;
  final String stageMessage;
  final int progressPercent;
  final String? error;

  const GenerationJobStatus({
    required this.status,
    required this.stageKey,
    required this.stageMessage,
    required this.progressPercent,
    this.error,
  });

  bool get isGenerating => status == 'pending' || status == 'generating';
  bool get isDone => status == 'done';
  bool get hasFailed => status == 'failed';

  factory GenerationJobStatus.idle(String type) => GenerationJobStatus(
    status: 'idle',
    stageKey: 'idle',
    stageMessage: type == 'diet'
        ? 'Your nutrition plan has not started yet.'
        : 'Your workout plan has not started yet.',
    progressPercent: 0,
  );

  factory GenerationJobStatus.fromJson(
    String type,
    Map<String, dynamic>? json,
  ) {
    final fallback = GenerationJobStatus.idle(type);
    return GenerationJobStatus(
      status: json?['status'] as String? ?? fallback.status,
      stageKey: json?['stageKey'] as String? ?? fallback.stageKey,
      stageMessage: json?['stageMessage'] as String? ?? fallback.stageMessage,
      progressPercent:
          (json?['progressPercent'] as num?)?.toInt() ??
          fallback.progressPercent,
      error: json?['error'] as String?,
    );
  }
}

class GenerationStatus {
  final String overallStatus;
  final int overallProgressPercent;
  final String primaryMessage;
  final GenerationJobStatus diet;
  final GenerationJobStatus workout;

  const GenerationStatus({
    required this.overallStatus,
    required this.overallProgressPercent,
    required this.primaryMessage,
    required this.diet,
    required this.workout,
  });

  bool get isGenerating =>
      overallStatus == 'generating' ||
      diet.isGenerating ||
      workout.isGenerating;

  bool get isDone => diet.isDone && workout.isDone;

  bool get hasIdle => overallStatus == 'idle';

  bool get hasFailed => diet.hasFailed || workout.hasFailed;

  factory GenerationStatus.idle() => GenerationStatus(
    overallStatus: 'idle',
    overallProgressPercent: 0,
    primaryMessage: 'Ready when you are.',
    diet: GenerationJobStatus.idle('diet'),
    workout: GenerationJobStatus.idle('workout'),
  );

  factory GenerationStatus.fromJson(Map<String, dynamic> json) {
    final jobs = (json['jobs'] as Map<String, dynamic>?) ?? const {};
    return GenerationStatus(
      overallStatus: json['overallStatus'] as String? ?? 'idle',
      overallProgressPercent:
          (json['overallProgressPercent'] as num?)?.toInt() ?? 0,
      primaryMessage:
          json['primaryMessage'] as String? ?? 'Ready when you are.',
      diet: GenerationJobStatus.fromJson(
        'diet',
        jobs['diet'] as Map<String, dynamic>?,
      ),
      workout: GenerationJobStatus.fromJson(
        'workout',
        jobs['workout'] as Map<String, dynamic>?,
      ),
    );
  }
}

class GenerationStatusNotifier extends Notifier<GenerationStatus> {
  Timer? _timer;
  Duration _pollInterval = const Duration(seconds: 5);

  @override
  GenerationStatus build() {
    ref.onDispose(() => _timer?.cancel());
    _fetch();
    return GenerationStatus.idle();
  }

  Future<void> _fetch() async {
    try {
      final res = await GenerationService.getGenerationStatus();
      final next = GenerationStatus.fromJson(
        res['data'] as Map<String, dynamic>,
      );
      state = next;

      if (next.isGenerating) {
        _scheduleNext();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    } catch (_) {
      // Keep the last known state if polling fails.
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(_pollInterval, _fetch);
  }

  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _pollInterval = interval;
    _fetch();
  }

  void refresh({Duration? interval}) {
    if (interval != null) _pollInterval = interval;
    _fetch();
  }
}

final generationStatusProvider =
    NotifierProvider<GenerationStatusNotifier, GenerationStatus>(
      GenerationStatusNotifier.new,
    );
