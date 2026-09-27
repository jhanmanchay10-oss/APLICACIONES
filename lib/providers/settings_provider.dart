import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/text_utils.dart';
import 'core_providers.dart';

class AppSettings {
  const AppSettings({
    this.userName = '',
    this.avatarPath,
    this.showCalories = true,
    this.themeMode = ThemeMode.system,
    this.onboardingDone = false,
  });

  final String userName;
  final String? avatarPath;

  /// Permite ocultar las calorías para centrarse en la calidad nutricional.
  final bool showCalories;
  final ThemeMode themeMode;
  final bool onboardingDone;

  AppSettings copyWith({
    String? userName,
    String? avatarPath,
    bool clearAvatar = false,
    bool? showCalories,
    ThemeMode? themeMode,
    bool? onboardingDone,
  }) =>
      AppSettings(
        userName: userName ?? this.userName,
        avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
        showCalories: showCalories ?? this.showCalories,
        themeMode: themeMode ?? this.themeMode,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _name = 'user_name';
  static const _avatar = 'avatar_path';
  static const _calories = 'show_calories';
  static const _theme = 'theme_mode';
  static const _onboarding = 'onboarding_done';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      userName: prefs.getString(_name) ?? '',
      avatarPath: prefs.getString(_avatar),
      showCalories: prefs.getBool(_calories) ?? true,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == prefs.getString(_theme),
        orElse: () => ThemeMode.system,
      ),
      onboardingDone: prefs.getBool(_onboarding) ?? false,
    );
  }

  Future<void> completeOnboarding(String name) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final clean = TextUtils.sanitize(name, maxLength: 30);
    await prefs.setString(_name, clean);
    await prefs.setBool(_onboarding, true);
    state = state.copyWith(userName: clean, onboardingDone: true);
  }

  Future<void> setName(String name) async {
    final clean = TextUtils.sanitize(name, maxLength: 30);
    await ref.read(sharedPreferencesProvider).setString(_name, clean);
    state = state.copyWith(userName: clean);
  }

  Future<void> setAvatar(String? path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final previous = state.avatarPath;
    if (path == null) {
      await prefs.remove(_avatar);
    } else {
      await prefs.setString(_avatar, path);
    }
    state = path == null ? state.copyWith(clearAvatar: true) : state.copyWith(avatarPath: path);
    if (previous != null && previous != path) await ref.read(photoStorageProvider).delete(previous);
  }

  Future<void> setShowCalories(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_calories, value);
    state = state.copyWith(showCalories: value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_theme, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).clear();
    state = const AppSettings();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
