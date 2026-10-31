import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemePreferenceStore {
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String value);
}

class SharedPreferencesThemeStore implements ThemePreferenceStore {
  static const _key = 'appearance.theme_mode';

  @override
  Future<String?> readThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> writeThemeMode(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController._(this._store, this._mode);

  factory ThemeController.system() => ThemeController._(null, ThemeMode.system);

  static Future<ThemeController> load(ThemePreferenceStore store) async {
    ThemeMode mode = ThemeMode.system;
    try {
      final saved = await store.readThemeMode();
      mode = ThemeMode.values.firstWhere(
        (candidate) => candidate.name == saved,
        orElse: () => ThemeMode.system,
      );
    } on Object {
      // Appearance storage must never prevent the application from starting.
    }
    return ThemeController._(store, mode);
  }

  final ThemePreferenceStore? _store;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _store?.writeThemeMode(mode.name);
    } on Object {
      // The selected mode still applies for this session if persistence fails.
    }
  }
}
