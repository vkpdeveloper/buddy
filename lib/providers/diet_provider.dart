import 'package:flutter_riverpod/flutter_riverpod.dart';

class _DietPlanRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Incrementing counter that signals the diet plan page to reload its data.
/// Increment this when Buddy modifies or logs diet-related data.
final dietPlanRefreshProvider =
    NotifierProvider<_DietPlanRefreshNotifier, int>(
      _DietPlanRefreshNotifier.new,
    );
