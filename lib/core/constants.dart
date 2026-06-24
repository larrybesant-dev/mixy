// App-wide constants for Mix & Mingle
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // App info
  static const String appName = 'Mix & Mingle';
  static const String appVersion = '1.0.0';

  // Agora configuration - loaded from .env file
  // NEVER commit actual credentials to the repository
  // Copy .env.example to .env and add your credentials
  static String get agoraAppId => dotenv.get('AGORA_APP_ID', fallback: '');
  static String get agoraAppCertificate =>
      dotenv.get('AGORA_APP_CERTIFICATE', fallback: '');

  // Firebase collections
  static const String usersCollection = 'users';
  static const String roomsCollection = 'rooms';
  static const String messagesCollection = 'messages';

  // UI constants
  static const double borderRadius = 12.0;
  static const double glowRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Room settings
  static const int maxRoomNameLength = 50;
  static const int maxRoomDescriptionLength = 200;
  static const int maxUsernameLength = 20;

  // Video settings
  static const int defaultVideoWidth = 640;
  static const int defaultVideoHeight = 360;
  static const int defaultFrameRate = 15;

  // Chat settings
  static const int maxMessageLength = 500;
  static const int messagesPageSize = 50;

  // Animation curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
}
