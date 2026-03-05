import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/services/api_client.dart';

class GenerationStatus {
  final String diet;
  final String workout;

  const GenerationStatus({required this.diet, required this.workout});

  bool get isGenerating =>
      diet == 'pending' ||
      diet == 'generating' ||
      workout == 'pending' ||
      workout == 'generating';

  bool get isDone => diet == 'done' && workout == 'done';

  bool get hasIdle => diet == 'idle' && workout == 'idle';

  factory GenerationStatus.idle() =>
      const GenerationStatus(diet: 'idle', workout: 'idle');

  factory GenerationStatus.fromJson(Map<String, dynamic> json) =>
      GenerationStatus(
        diet: json['diet'] as String? ?? 'idle',
        workout: json['workout'] as String? ?? 'idle',
      );
}

class GenerationStatusNotifier extends Notifier<GenerationStatus> {
  Timer? _timer;

  @override
  GenerationStatus build() {
    ref.onDispose(() => _timer?.cancel());
    _fetch();
    return GenerationStatus.idle();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient.getGenerationStatus();
      final next =
          GenerationStatus.fromJson(res['data'] as Map<String, dynamic>);
      state = next;

      if (next.isGenerating) {
        _scheduleNext();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    } catch (_) {
      // Silently ignore network errors; keep last state.
    }
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), _fetch);
  }

  /// Call this after triggering generation so polling starts immediately.
  void startPolling() {
    _fetch();
  }

  /// Call this to force a status refresh (e.g. after manual regeneration).
  void refresh() {
    _fetch();
  }
}

final generationStatusProvider =
    NotifierProvider<GenerationStatusNotifier, GenerationStatus>(
  GenerationStatusNotifier.new,
);
