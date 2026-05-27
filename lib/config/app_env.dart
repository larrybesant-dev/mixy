import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration helper.
///
/// Supports both .env files (via flutter_dotenv) and compile-time variables
/// (via --dart-define or --dart-define-from-file).
/// 
/// Priority:
/// 1. Dart define (compile-time)
/// 2. Dotenv variable (runtime)
/// 3. Fallback value
class AppEnv {
  static String get(String key, {String fallback = ''}) {
    // 1. Try Dart Define
    final fromEnvironment = String.fromEnvironment(key);
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }

    // 2. Try Dotenv
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Common Keys
  static String get agoraAppId => get('AGORA_APP_ID');
  static String get stripePublishableKey => get('STRIPE_PUBLISHABLE_KEY');
  static String get meteredDomain => get('METERED_DOMAIN', fallback: 'mixvy.metered.live');
  static String get meteredSecretKey => get('METERED_SECRET_KEY');
  static String get giphyApiKey => get('GIPHY_API_KEY');
  
  /// Returns true if the environment seems to be configured.
  /// We use METERED_SECRET_KEY as a canary.
  static bool get isConfigured => get('METERED_SECRET_KEY').isNotEmpty;
}
