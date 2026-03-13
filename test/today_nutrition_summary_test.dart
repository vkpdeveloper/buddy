import 'package:buddy/models/home_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TodayNutritionSummary.withMealCompletion', () {
    const breakfast = TodayMealItem(
      id: 1,
      type: 'breakfast',
      label: '08:00 • BREAKFAST',
      name: 'Eggs and toast',
      calories: 420,
      proteinG: 28,
      carbsG: 34,
      fatsG: 18,
      isCompleted: false,
    );
    const lunch = TodayMealItem(
      id: 2,
      type: 'lunch',
      label: '13:00 • LUNCH',
      name: 'Chicken bowl',
      calories: 560,
      proteinG: 42,
      carbsG: 51,
      fatsG: 20,
      isCompleted: true,
    );

    const summary = TodayNutritionSummary(
      caloriesTarget: 2200,
      caloriesConsumed: 560,
      proteinTargetG: 160,
      proteinConsumedG: 42,
      carbsTargetG: 220,
      carbsConsumedG: 51,
      fatsTargetG: 70,
      fatsConsumedG: 20,
      meals: [breakfast, lunch],
    );

    test('marks a meal complete and updates consumed totals immediately', () {
      final next = summary.withMealCompletion(1, isCompleted: true);

      expect(next.caloriesConsumed, 980);
      expect(next.proteinConsumedG, 70);
      expect(next.carbsConsumedG, 85);
      expect(next.fatsConsumedG, 38);
      expect(next.meals.first.isCompleted, isTrue);
    });

    test('unchecking a completed meal subtracts its nutrition totals', () {
      final next = summary.withMealCompletion(2, isCompleted: false);

      expect(next.caloriesConsumed, 0);
      expect(next.proteinConsumedG, 0);
      expect(next.carbsConsumedG, 0);
      expect(next.fatsConsumedG, 0);
      expect(next.meals[1].isCompleted, isFalse);
    });
  });
}
