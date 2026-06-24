/// FCM Notifications Service - Friend Presence Alerts
///
/// Monitors friend presence changes and sends push notifications
/// Reference: DESIGN_BIBLE.md Section G (Backend Integration)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../infra/firestore_service.dart';
import '../../core/utils/app_logger.dart';
import '../../app/app_routes.dart';

/// FCM Notification service for friend presence alerts
class FcmNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore;

  /// Navigator key for navigation from service
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Set navigator key for navigation
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    AppLogger.info('[FCM] Navigator key set');
  }

  FcmNotificationService({required FirestoreService firestore})
      : _firestore = firestore;

  /// Initialize FCM and setup handlers
  Future<void> initialize() async {
    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
        announcement: false,
      );

      AppLogger.info(
        '[FCM] Notification permission status: ${settings.authorizationStatus}',
      );

      // Get FCM token
      final token = await _messaging.getToken();
      AppLogger.info('[FCM] Token obtained: ${token?.substring(0, 20)}...');

      // Setup message handlers
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageOpenedApp(message);
      });

      AppLogger.info('[FCM] Initialized successfully');
    } catch (e) {
      AppLogger.error('[FCM] Initialization failed: $e');
    }
  }

  /// Send notification when friend comes online
  /// Typically called from Cloud Function, but can be called directly
  Future<void> notifyFriendOnline({
    required String recipientUserId,
    required String friendUserId,
    required String friendName,
    String? roomId,
    String? roomName,
  }) async {
    try {
      await _firestore.sendFriendOnlineNotification(
        recipientUserId,
        friendUserId,
        friendName,
      );

      AppLogger.info(
        '[FCM] Sent friend online notification: $friendName â†’ $recipientUserId',
      );
    } catch (e) {
      AppLogger.error('[FCM] Failed to notify friend online: $e');
    }
  }

  /// Send notification when friend goes offline
  Future<void> notifyFriendOffline({
    required String recipientUserId,
    required String friendUserId,
    required String friendName,
  }) async {
    try {
      await _firestore.sendFriendOfflineNotification(
        recipientUserId,
        friendUserId,
        friendName,
      );

      AppLogger.info(
        '[FCM] Sent friend offline notification: $friendName â†’ $recipientUserId',
      );
    } catch (e) {
      AppLogger.error('[FCM] Failed to notify friend offline: $e');
    }
  }

  /// Send room invitation notification
  Future<void> notifyRoomInvitation({
    required String recipientUserId,
    required String invitedByUserId,
    required String invitedByName,
    required String roomId,
    required String roomName,
  }) async {
    try {
      await _firestore.sendRoomInvitation(
        invitedByUserId,
        invitedByName,
        recipientUserId,
        roomId,
        roomName,
      );

      AppLogger.info(
        '[FCM] Sent room invitation: $roomName ($invitedByName â†’ $recipientUserId)',
      );
    } catch (e) {
      AppLogger.error('[FCM] Failed to send room invitation: $e');
    }
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info(
      '[FCM] Foreground message: ${message.notification?.title}',
    );

    // Show local notification (using awesome_notifications or similar)
    // This would be implemented based on your notification UI library
  }

  /// Handle messages when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info(
      '[FCM] Message opened: ${message.notification?.title}',
    );

    final data = message.data;
    final type = data['type'];

    // Route based on notification type
    switch (type) {
      case 'friendOnline':
        final friendId = data['friendId'] as String?;
        if (friendId != null && _navigatorKey?.currentState != null) {
          AppLogger.info('[FCM] Navigating to friend profile: $friendId');
          _navigatorKey!.currentState!.pushNamed(
            AppRoutes.userProfile,
            arguments: {'userId': friendId},
          );
        }
        break;
      case 'roomInvitation':
        final roomId = data['roomId'] as String?;
        if (roomId != null && _navigatorKey?.currentState != null) {
          AppLogger.info('[FCM] Navigating to room: $roomId');
          _navigatorKey!.currentState!.pushNamed(
            AppRoutes.room,
            arguments: {'roomId': roomId},
          );
        }
        break;
      case 'eventInvite':
        final eventId = data['eventId'] as String?;
        if (eventId != null && _navigatorKey?.currentState != null) {
          AppLogger.info('[FCM] Navigating to event: $eventId');
          _navigatorKey!.currentState!.pushNamed(
            AppRoutes.eventDetails,
            arguments: {'eventId': eventId},
          );
        }
        break;
      default:
        AppLogger.info('[FCM] Unknown notification type: $type');
    }
  }
}

/// FCM notification service provider
/// Note: Typically used in conjunction with PresenceNotificationService
/// which handles the actual presence monitoring and calls this service.
final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  final firestore = FirestoreService();
  return FcmNotificationService(firestore: firestore);
});

/// Watch notification permissions status
final notificationPermissionsProvider =
    FutureProvider<NotificationSettings>((ref) async {
  final messaging = FirebaseMessaging.instance;
  return messaging.getNotificationSettings();
});
