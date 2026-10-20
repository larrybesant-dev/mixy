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
    // Priority:
    // 1. Dart Define (Baked in at compile-time)
    // 2. Dotenv (Loaded at runtime from assets)
    // 3. Fallback
    
    String? value;
    
    // On Web, String.fromEnvironment only works with literal keys.
    // We explicitly map our supported keys here.
    switch (key) {
      case 'AGORA_APP_ID':
        value = const String.fromEnvironment('AGORA_APP_ID');
        break;
      case 'STRIPE_PUBLISHABLE_KEY':
        value = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
        break;
      case 'GIPHY_API_KEY':
        value = const String.fromEnvironment('GIPHY_API_KEY');
        break;
    }

    if (value != null) {
      // Explicitly strip enclosing quotes, line breaks, and whitespace
      final cleaned = value
          .replaceAll(RegExp(r'[\r\n]'), '')
          .trim()
          .replaceAll(RegExp('^["\']|["\']\$'), '')
          .trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    try {
      final dotenvValue = dotenv.env[key];
      if (dotenvValue != null) {
        return dotenvValue
            .replaceAll(RegExp(r'[\r\n]'), '')
            .trim()
            .replaceAll(RegExp('^["\']|["\']\$'), '')
            .trim();
      }
      return fallback.trim();
    } catch (_) {
      return fallback.trim();
    }
  }

  // Common Keys
  static String get agoraAppId => get('AGORA_APP_ID');
  static String get stripePublishableKey => get('STRIPE_PUBLISHABLE_KEY');
  static String get giphyApiKey => get('GIPHY_API_KEY');
}



