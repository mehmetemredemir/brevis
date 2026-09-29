import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saf bir UI tercihi — Kotlin tarafına hiç gitmez, sadece bu cihazda
/// SharedPreferences ile saklanır. Native config'in (BrevisConfig) davranışıyla
/// hiçbir ilgisi yok, bu yüzden bilinçli olarak ConfigController'dan ayrı tutuldu.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'brevis_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
