import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buddy/services/api_client.dart';
import 'package:buddy/models/gamification.dart';

/// FutureProvider that fetches /api/progress — used by home page and workout page.
final progressProvider = FutureProvider<ProgressData>((ref) async {
  final json = await ApiClient.getProgress();
  return ProgressData.fromJson(json['data'] as Map<String, dynamic>);
});

/// Notifier that holds the gamification result from the most recent session.
class _SessionGamificationNotifier extends Notifier<SessionGamificationResult?> {
  @override
  SessionGamificationResult? build() => null;

  void set(SessionGamificationResult? value) => state = value;
}

final sessionGamificationProvider =
    NotifierProvider<_SessionGamificationNotifier, SessionGamificationResult?>(
  _SessionGamificationNotifier.new,
);
