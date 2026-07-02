import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsState {
  final bool notificationsEnabled;
  final ThemeMode themeMode;
  final bool isInitialized;

  const SettingsState({
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.light,
    this.isInitialized = false,
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    bool? isInitialized,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final _storage = const FlutterSecureStorage();

  SettingsNotifier() : super(const SettingsState()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final notifStr = await _storage.read(key: 'settings_notifications_enabled');
      final themeStr = await _storage.read(key: 'settings_theme_mode');

      final notificationsEnabled = notifStr != 'false'; // defaults to true
      final themeMode = themeStr == 'dark'
          ? ThemeMode.dark
          : (themeStr == 'light' ? ThemeMode.light : ThemeMode.system);

      state = SettingsState(
        notificationsEnabled: notificationsEnabled,
        themeMode: themeMode,
        isInitialized: true,
      );
    } catch (_) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _storage.write(
      key: 'settings_notifications_enabled',
      value: value.toString(),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String modeStr = 'light';
    if (mode == ThemeMode.dark) {
      modeStr = 'dark';
    } else if (mode == ThemeMode.system) {
      modeStr = 'system';
    }
    await _storage.write(key: 'settings_theme_mode', value: modeStr);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// Bridge to update the global themeModeProvider when settings change
final persistedThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.themeMode;
});
