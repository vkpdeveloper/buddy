import 'package:shared_preferences/shared_preferences.dart';

class HomeDashboardPreferences {
  static const String _showConsumedKey = 'consumed_left_behaviour';
  static const String _legacyShowConsumedKey = 'calories_show_consumed';

  static bool _showConsumed = false;

  static bool get showConsumed => _showConsumed;

  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_showConsumedKey)) {
      _showConsumed = prefs.getBool(_showConsumedKey) ?? false;
    } else {
      _showConsumed = prefs.getBool(_legacyShowConsumedKey) ?? false;
      await prefs.setBool(_showConsumedKey, _showConsumed);
      await prefs.remove(_legacyShowConsumedKey);
    }
  }

  static Future<void> setShowConsumed(bool value) async {
    _showConsumed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showConsumedKey, value);
  }
}
