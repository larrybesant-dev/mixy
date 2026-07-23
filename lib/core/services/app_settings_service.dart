import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String currentLegalVersion = '2026-03-29';

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool analyticsEnabled;
  final bool legalAccepted;
  final String legalAcceptedVersion;
  final DateTime? legalAcceptedAt;
  final String localeCode;

  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.analyticsEnabled,
    required this.legalAccepted,
    required this.legalAcceptedVersion,
    required this.legalAcceptedAt,
    required this.localeCode,
  });

  const AppSettings.defaults()
    : themeMode = ThemeMode.system,
      notificationsEnabled = true,
      analyticsEnabled = true,
      legalAccepted = false,
      legalAcceptedVersion = '',
      legalAcceptedAt = null,
      localeCode = 'en';

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? analyticsEnabled,
    bool? legalAccepted,
    String? legalAcceptedVersion,
    DateTime? legalAcceptedAt,
    String? localeCode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      legalAccepted: legalAccepted ?? this.legalAccepted,
      legalAcceptedVersion: legalAcceptedVersion ?? this.legalAcceptedVersion,
      legalAcceptedAt: legalAcceptedAt ?? this.legalAcceptedAt,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  bool get hasAcceptedCurrentLegal =>
      legalAccepted && legalAcceptedVersion == currentLegalVersion;
}

class AppSettingsService {
  static const _themeModeKey = 'app.theme_mode';
  static const _notificationsEnabledKey = 'app.notifications_enabled';
  static const _analyticsEnabledKey = 'app.analytics_enabled';
  static const _legalAcceptedKey = 'app.legal_accepted';
  static const _legalAcceptedVersionKey = 'app.legal_accepted_version';
  static const _legalAcceptedAtKey = 'app.legal_accepted_at';
  static const _localeCodeKey = 'app.locale_code';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: _themeModeFromString(prefs.getString(_themeModeKey)),
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      analyticsEnabled: prefs.getBool(_analyticsEnabledKey) ?? true,
      legalAccepted: prefs.getBool(_legalAcceptedKey) ?? false,
      legalAcceptedVersion: prefs.getString(_legalAcceptedVersionKey) ?? '',
      legalAcceptedAt: _parseDateTime(prefs.getString(_legalAcceptedAtKey)),
      localeCode: _normalizeLocaleCode(prefs.getString(_localeCodeKey)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setBool(
      _notificationsEnabledKey,
      settings.notificationsEnabled,
    );
    await prefs.setBool(_analyticsEnabledKey, settings.analyticsEnabled);
    await prefs.setBool(_legalAcceptedKey, settings.legalAccepted);
    await prefs.setString(
      _legalAcceptedVersionKey,
      settings.legalAcceptedVersion,
    );
    await prefs.setString(
      _localeCodeKey,
      _normalizeLocaleCode(settings.localeCode),
    );

    final acceptedAt = settings.legalAcceptedAt?.toUtc().toIso8601String();
    if (acceptedAt == null || acceptedAt.isEmpty) {
      await prefs.remove(_legalAcceptedAtKey);
    } else {
      await prefs.setString(_legalAcceptedAtKey, acceptedAt);
    }
  }

  Future<bool> hasAcceptedCurrentLegal() async {
    final settings = await load();
    return settings.hasAcceptedCurrentLegal;
  }

  ThemeMode _themeModeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  String _normalizeLocaleCode(String? value) {
    const supported = <String>{'en', 'es', 'fr'};
    final normalized = (value ?? '').trim().toLowerCase();
    if (!supported.contains(normalized)) {
      return 'en';
    }
    return normalized;
  }
}



