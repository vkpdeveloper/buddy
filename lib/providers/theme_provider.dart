import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme_mode';
  static const _defaultMode = ThemeMode.light;

  @override
  ThemeMode build() {
    _load();
    return _defaultMode;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = switch (prefs.getString(_key)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => _defaultMode,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'system',
    });
  }
}
