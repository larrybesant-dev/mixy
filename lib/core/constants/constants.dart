// App-wide constants for Mix & Mingle
import 'package:flutter/material.dart';

class AppConstants {
  // App info
  static const String appName = 'Mix & Mingle';
  static const String appVersion = '1.0.0';

  // Agora configuration
  // IMPORTANT: Replace these with your actual Agora credentials
  // Get them from https://console.agora.io
  static const String agoraAppId =
      'ec1b578586d24976a89d787d9ee4d5c7'; // Demo App ID - REPLACE IN PRODUCTION
  static const String agoraAppCertificate =
      '79a3e92a657042d08c3c26a26d1e70b6'; // Demo Certificate - REPLACE IN PRODUCTION

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
