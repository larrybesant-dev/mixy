import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';
import '../../shared/models/room.dart';
import '../../features/room/room_access_wrapper.dart';

/// Phase 15: Push Notifications Service
/// Handles FCM tokens, notification sending, and local notifications

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  // ========================================
  // INITIALIZATION
  // ========================================

  /// Set navigator key for navigation
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Initialize push notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      AppLogger.info('Initializing push notifications');

      // Request permission (iOS)
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get and save FCM token
      await _saveFCMToken();

      // Listen for token refresh
      _fcm.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      AppLogger.info('Push notifications initialized successfully');
    } catch (e, stack) {
      AppLogger.error('Error initializing push notifications', e, stack);
    }
  }

  /// Request notification permission
  static Future<void> _requestPermission() async {
    try {
      // Skip on web - requires user gesture
      if (kIsWeb) {
        AppLogger.info(
            'Skipping notification permission on web (requires user gesture)');
        return;
      }

      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      AppLogger.info(
          'Notification permission: ${settings.authorizationStatus}');
    } catch (e, stack) {
      AppLogger.error('Error requesting notification permission', e, stack);
    }
  }

  /// Initialize local notifications (for foreground display)
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  // ========================================
  // FCM TOKEN MANAGEMENT
  // ========================================

  /// Get and save FCM token
  static Future<void> _saveFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _updateUserToken(token);
        AppLogger.info('FCM token saved: ${token.substring(0, 20)}...');
      }
    } catch (e, stack) {
      AppLogger.error('Error saving FCM token', e, stack);
    }
  }

  /// Handle token refresh
  static Future<void> _onTokenRefresh(String token) async {
    try {
      await _updateUserToken(token);
      AppLogger.info('FCM token refreshed: ${token.substring(0, 20)}...');
    } catch (e, stack) {
      AppLogger.error('Error refreshing FCM token', e, stack);
    }
  }

  /// Update user's FCM token in Firestore
  static Future<void> _updateUserToken(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await SafeFirestore.safeUpdate(
        ref: _firestore.collection('users').doc(userId),
        data: {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e, stack) {
      AppLogger.error('Error updating FCM token', e, stack);
    }
  }

  /// Remove FCM token (on logout)
  static Future<void> removeFCMToken() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await SafeFirestore.safeUpdate(
        ref: _firestore.collection('users').doc(userId),
        data: {
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        },
      );

      await _fcm.deleteToken();
      AppLogger.info('FCM token removed');
    } catch (e, stack) {
      AppLogger.error('Error removing FCM token', e, stack);
    }
  }

  // ========================================
  // MESSAGE HANDLING
  // ========================================

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.info('Foreground message received: ${message.messageId}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Background message handler (must be top-level function)
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    AppLogger.info('Background message received: ${message.messageId}');
    // Background messages are handled by FCM automatically
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('Notification tapped: ${message.messageId}');

    final data = message.data;
    final type = data['type'] as String?;

    // Navigate based on notification type
    switch (type) {
      case 'message':
        final chatId = data['chatId'] as String?;
        if (chatId != null) {
          AppLogger.info('Navigate to chat: $chatId');
          _navigatorKey?.currentState?.pushNamed(
            '/chat',
            arguments: {'chatId': chatId},
          );
        }
        break;

      case 'event_invite':
        final eventId = data['eventId'] as String?;
        if (eventId != null) {
          AppLogger.info('Navigate to event: $eventId');
          _navigatorKey?.currentState?.pushNamed(
            '/event-details',
            arguments: {'eventId': eventId},
          );
        }
        break;

      case 'friend_request':
        final userId = data['userId'] as String?;
        if (userId != null) {
          AppLogger.info('Navigate to profile: $userId');
          _navigatorKey?.currentState?.pushNamed(
            '/profile',
            arguments: {'userId': userId},
          );
        }
        break;

      case 'room_invite':
        final roomId = data['roomId'] as String?;
        if (roomId != null) {
          AppLogger.info('Navigate to room: $roomId');
          _navigateToRoom(roomId);
        }
        break;

      default:
        AppLogger.info('Unknown notification type: $type');
    }
  }

  /// Handle local notification tap
  static void _onLocalNotificationTap(NotificationResponse response) {
    AppLogger.info('Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // ========================================
  // LOCAL NOTIFICATION DISPLAY
  // ========================================

  /// Show local notification (for foreground messages)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    // final android = message.notification?.android;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'mix_mingle_channel',
      'Mix & Mingle Notifications',
      channelDescription: 'Notifications for Mix & Mingle app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? '',
      body: notification.body ?? '',
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  // ========================================
  // NOTIFICATION SENDING (Server-side typically)
  // ========================================

  /// Create notification document (for Cloud Function to process)
  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) return;

    try {
      final notificationData = {
        'recipientId': recipientId,
        'senderId': senderId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };

      await SafeFirestore.safeSet(
        ref: _firestore.collection('notifications_queue').doc(),
        data: notificationData,
      );

      AppLogger.info('Notification queued for: $recipientId');
    } catch (e, stack) {
      AppLogger.error('Error queueing notification', e, stack);
    }
  }

  // ========================================
  // NOTIFICATION TYPES
  // ========================================

  /// Send new message notification
  static Future<void> sendMessageNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: senderName,
      body: message,
      type: 'message',
      data: {'chatId': chatId},
    );
  }

  /// Send friend request notification
  static Future<void> sendFriendRequestNotification({
    required String recipientId,
    required String senderName,
    required String senderId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'New Friend Request',
      body: '$senderName wants to be friends',
      type: 'friend_request',
      data: {'userId': senderId},
    );
  }

  /// Send event invite notification
  static Future<void> sendEventInviteNotification({
    required String recipientId,
    required String eventName,
    required String eventId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'Event Invitation',
      body: 'You\'re invited to $eventName',
      type: 'event_invite',
      data: {'eventId': eventId},
    );
  }

  /// Send room invite notification
  static Future<void> sendRoomInviteNotification({
    required String recipientId,
    required String roomName,
    required String roomId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'Room Invitation',
      body: 'Join $roomName',
      type: 'room_invite',
      data: {'roomId': roomId},
    );
  }

  /// Send speed dating match notification
  static Future<void> sendMatchNotification({
    required String recipientId,
    required String matchName,
    required String matchId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'New Match! ðŸŽ‰',
      body: 'You matched with $matchName',
      type: 'match',
      data: {'userId': matchId},
    );
  }

  // ========================================
  // NOTIFICATION PREFERENCES
  // ========================================

  /// Update notification preferences
  static Future<void> updateNotificationPreferences({
    required bool messages,
    required bool friendRequests,
    required bool events,
    required bool rooms,
    required bool matches,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await SafeFirestore.safeUpdate(
        ref: _firestore.collection('users').doc(userId),
        data: {
          'notificationPreferences': {
            'messages': messages,
            'friendRequests': friendRequests,
            'events': events,
            'rooms': rooms,
            'matches': matches,
          },
        },
      );

      AppLogger.info('Notification preferences updated');
    } catch (e, stack) {
      AppLogger.error('Error updating notification preferences', e, stack);
    }
  }

  static Future<void> _navigateToRoom(String roomId) async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();
      if (!roomDoc.exists) {
        AppLogger.error('Room not found: $roomId');
        return;
      }

      final room = Room.fromFirestore(roomDoc);
      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (context) => RoomAccessWrapper(
            room: room,
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to navigate to room', e, stack);
    }
  }
}
