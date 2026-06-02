import 'package:shared_preferences/shared_preferences.dart';

class FirstRunService {
  static const _seenOnboardingKey = 'has_seen_onboarding';
  static bool? _cachedIsFirstRun;

  static Future<bool> isFirstRun() async {
    if (_cachedIsFirstRun != null) return _cachedIsFirstRun ?? true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(_seenOnboardingKey) ?? false;
    _cachedIsFirstRun = !hasSeenOnboarding;
    return _cachedIsFirstRun ?? true;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
    _cachedIsFirstRun = false;
  }
}
