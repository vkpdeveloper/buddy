import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    debugPrint('[INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[WARN] $message');
  }

  static void error(String message, [Object? error]) {
    if (error != null) {
      debugPrint('[ERROR] $message | $error');
      return;
    }
    debugPrint('[ERROR] $message');
  }
}
