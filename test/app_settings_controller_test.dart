import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/services/app_settings_service.dart';
import 'package:mixvy/presentation/providers/app_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads defaults when no preferences are stored', () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(AppSettingsService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsControllerProvider.notifier).load();
      final settings = container
          .read(appSettingsControllerProvider)
          .valueOrNull;

      expect(settings, isNotNull);
      expect(settings!.themeMode, ThemeMode.system);
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.analyticsEnabled, isTrue);
    });

    test('persists theme and toggle updates', () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(AppSettingsService()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.load();
      await controller.updateThemeMode(ThemeMode.dark);
      await controller.setNotificationsEnabled(false);
      await controller.setAnalyticsEnabled(false);
      await controller.setLocaleCode('fr');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app.theme_mode'), 'dark');
      expect(prefs.getBool('app.notifications_enabled'), isFalse);
      expect(prefs.getBool('app.analytics_enabled'), isFalse);
      expect(prefs.getString('app.locale_code'), 'fr');
    });

    test('persists legal acceptance metadata', () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(AppSettingsService()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.load();
      await controller.acceptCurrentLegal();

      final settings = container
          .read(appSettingsControllerProvider)
          .valueOrNull;
      final prefs = await SharedPreferences.getInstance();

      expect(settings, isNotNull);
      expect(settings!.hasAcceptedCurrentLegal, isTrue);
      expect(prefs.getBool('app.legal_accepted'), isTrue);
      expect(
        prefs.getString('app.legal_accepted_version'),
        AppSettings.currentLegalVersion,
      );
      expect(prefs.getString('app.legal_accepted_at'), isNotEmpty);
    });
  });
}
