import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'analytics/analytics_service.dart';

/// Service for handling Firebase Cloud Messaging and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AnalyticsService _analytics = AnalyticsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Navigation callback for handling notification taps
  void Function(String route)? onNavigate;

  /// Initialize notifications
  Future<void> initialize() async {
    try {
      // Skip Firebase Messaging initialization on web for now
      // to avoid service worker registration issues during development
      if (!kIsWeb) {
        // Request permission for notifications
        await _requestPermission();

        // Get FCM token (this will trigger service worker registration on web)
        final token = await _firebaseMessaging.getToken();
        debugPrint('FCM Token: $token');

        // Configure local notifications for non-web platforms
        await _initializeLocalNotifications();

        // Set up message handlers
        _setupMessageHandlers();
      } else {
        debugPrint(
            'Skipping Firebase Messaging initialization on web (service worker issues)');
      }

      debugPrint('Notification service initialized successfully');
    } catch (e) {
      // Handle service worker registration failures gracefully
      debugPrint('Warning: Notification service initialization failed: $e');
      debugPrint(
          'Push notifications may not work, but app will continue normally');

      // Still try to set up basic message handlers if possible
      try {
        if (!kIsWeb) {
          _setupMessageHandlers();
        }
      } catch (handlerError) {
        debugPrint('Failed to set up message handlers: $handlerError');
      }
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications for non-web platforms
  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );
  }

  /// Set up Firebase message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
      _analytics.trackEngagement('notification_received', parameters: {
        'type': 'foreground',
        'title': message.notification?.title,
      });
    });

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background: ${message.notification?.title}');
      _handleNotificationTap(message.data['route'] ?? '/home');
      _analytics.trackEngagement('notification_opened', parameters: {
        'type': 'background',
        'title': message.notification?.title,
      });
    });

    // Handle messages when app is terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (message.notification == null) return;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'Default',
        channelDescription: 'Default notification channel',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification!.title ?? '',
      body: message.notification!.body ?? '',
      notificationDetails: notificationDetails,
      payload: message.data['route'] ?? '/home',
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(String? route) {
    if (route != null && onNavigate != null) {
      onNavigate!(route);
    } else if (route != null) {
      debugPrint('Navigate to: $route (no navigation callback set)');
    }
  }

  /// Subscribe to topic for real-time notifications
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Send notification for new message
  Future<void> notifyNewMessage(
      String roomId, String senderName, String message) async {
    // This would typically be handled by a Cloud Function
    // For now, we'll just log it
    debugPrint('New message notification: $senderName in room $roomId');
    _analytics.trackEngagement('message_notification_sent', parameters: {
      'room_id': roomId,
      'sender': senderName,
    });
  }

  /// Send notification for new direct message
  Future<void> notifyNewDirectMessage(
      String conversationId, String senderName, String message) async {
    // Show local notification for direct messages
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Message notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: conversationId.hashCode,
      title: 'New message from $senderName',
      body: message.length > 50 ? '${message.substring(0, 47)}...' : message,
      notificationDetails: notificationDetails,
      payload: '/messages?conversationId=$conversationId',
    );

    _analytics.trackEngagement('direct_message_notification_sent', parameters: {
      'conversation_id': conversationId,
      'sender': senderName,
    });
  }

  /// Send notification for room invitation
  Future<void> notifyRoomInvitation(
      String roomId, String roomName, String inviterName) async {
    debugPrint(
        'Room invitation notification: $inviterName invited to $roomName');
    _analytics.trackEngagement('room_invitation_sent', parameters: {
      'room_id': roomId,
      'room_name': roomName,
      'inviter': inviterName,
    });
  }

  /// Send notification for tip received
  Future<void> notifyTipReceived(String fromUser, double amount) async {
    debugPrint('Tip received notification: $amount coins from $fromUser');
    _analytics.trackEngagement('tip_notification_sent', parameters: {
      'from_user': fromUser,
      'amount': amount,
    });
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Delete FCM token
  Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
}

/// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.notification?.title}');
}
