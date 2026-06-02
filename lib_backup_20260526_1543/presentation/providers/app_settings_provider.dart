import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_settings_service.dart';

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AsyncValue<AppSettings>>((
  ref,
) {
  final service = ref.watch(appSettingsServiceProvider);
  return AppSettingsController(service)..load();
});

class AppSettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsController(this._service) : super(const AsyncValue.loading());

  final AppSettingsService _service;
  Future<void>? _loadFuture;

  Future<void> load() async {
    if (_loadFuture != null) {
      return _loadFuture!;
    }

    state = const AsyncValue.loading();
    _loadFuture = () async {
      state = await AsyncValue.guard(_service.load);
    }();

    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> updateThemeMode(ThemeMode themeMode) {
    return _saveWith((settings) => settings.copyWith(themeMode: themeMode));
  }

  Future<void> setNotificationsEnabled(bool enabled) {
    return _saveWith(
      (settings) => settings.copyWith(notificationsEnabled: enabled),
    );
  }

  Future<void> setAnalyticsEnabled(bool enabled) {
    return _saveWith(
      (settings) => settings.copyWith(analyticsEnabled: enabled),
    );
  }

  Future<void> setLocaleCode(String localeCode) {
    return _saveWith((settings) => settings.copyWith(localeCode: localeCode));
  }

  Future<void> acceptCurrentLegal() {
    return _saveWith(
      (settings) => settings.copyWith(
        legalAccepted: true,
        legalAcceptedVersion: AppSettings.currentLegalVersion,
        legalAcceptedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearLegalAcceptance() {
    return _saveWith(
      (settings) => settings.copyWith(
        legalAccepted: false,
        legalAcceptedVersion: '',
        legalAcceptedAt: null,
      ),
    );
  }

  Future<void> _saveWith(
    AppSettings Function(AppSettings current) update,
  ) async {
    final current = state.valueOrNull ?? const AppSettings.defaults();
    final next = update(current);
    state = AsyncValue.data(next);
    try {
      await _service.save(next);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      await load();
    }
  }
}
