/// Notifications Provider
/// FCM token management and notification handling
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../app/app.dart' show appNavigatorKey;
import '../../app/app_routes.dart';

/// Notifications State
class NotificationsState {
  final String? fcmToken;
  final bool isInitialized;
  final bool notificationsEnabled;

  const NotificationsState({
    this.fcmToken,
    this.isInitialized = false,
    this.notificationsEnabled = false,
  });

  NotificationsState copyWith({
    String? fcmToken,
    bool? isInitialized,
    bool? notificationsEnabled,
  }) {
    return NotificationsState(
      fcmToken: fcmToken ?? this.fcmToken,
      isInitialized: isInitialized ?? this.isInitialized,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

/// Notifications Controller
class NotificationsController extends Notifier<NotificationsState> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track subscriptions so they can be cancelled when the notifier is disposed,
  // preventing memory leaks and stale listeners on sign-out / hot-restart.
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _bgMessageSub;

  @override
  NotificationsState build() {
    // Cancel any open subscriptions when this notifier is disposed (e.g. on
    // sign-out or provider container disposal).
    ref.onDispose(() {
      _tokenRefreshSub?.cancel();
      _bgMessageSub?.cancel();
    });
    return const NotificationsState();
  }

  /// Initialize FCM
  Future<void> initialize(String userId) async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final enabled =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      debugPrint(
          'ðŸ“± Notification permission: ${settings.authorizationStatus}');

      if (enabled) {
        // Get FCM token
        final token = await _messaging.getToken();
        debugPrint('ðŸ“± FCM Token: $token');

        if (token != null) {
          // Save token to Firestore
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });

          state = state.copyWith(
            fcmToken: token,
            isInitialized: true,
            notificationsEnabled: true,
          );

          // Listen for token refresh (stored for disposal).
          _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
            debugPrint('ðŸ“± FCM Token refreshed: $newToken');
            _firestore.collection('users').doc(userId).update({
              'fcmToken': newToken,
              'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            });
            state = state.copyWith(fcmToken: newToken);
          });

          // NOTE: Foreground message display is handled by NotificationService
          // to avoid duplicate push notifications. Do NOT add onMessage.listen here.

          // Setup background/app-opened message handler (stored for disposal).
          _bgMessageSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

          // Check if app was opened from terminated state
          final initialMessage = await _messaging.getInitialMessage();
          if (initialMessage != null) {
            _handleBackgroundMessage(initialMessage);
          }

          debugPrint('âœ… FCM initialized successfully');
        }
      } else {
        state = state.copyWith(
          isInitialized: true,
          notificationsEnabled: false,
        );
        debugPrint('âŒ Notification permission denied');
      }
    } catch (e) {
      debugPrint('âŒ Error initializing FCM: $e');
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Handle background/terminated messages
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('ðŸ“¨ Background message: ${message.notification?.title}');

    // Handle notification tap - deep link to relevant screen
    final data = message.data;

    if (!data.containsKey('type')) return;

    final nav = appNavigatorKey.currentState;

    switch (data['type']) {
      case 'message':
        final chatId = data['chatId'];
        if (chatId != null && nav != null) {
          nav.pushNamed(AppRoutes.chat, arguments: {'chatId': chatId});
        }
        break;

      case 'match':
        nav?.pushNamed(AppRoutes.matches);
        break;

      case 'speed_dating_match':
        nav?.pushNamed(AppRoutes.speedDatingMatches);
        break;

      case 'room_invite':
        final roomId = data['roomId'];
        if (roomId != null && nav != null) {
          nav.pushNamed(AppRoutes.room, arguments: {'roomId': roomId});
        }
        break;

      default:
        debugPrint('[FCM] Unknown notification type: ${data['type']}');
    }
  }

  /// Send notification (via Cloud Function)
  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // In production, call Cloud Function to send notification
      // This keeps FCM server key secure on the backend

      await _firestore.collection('notifications').add({
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('âœ… Notification queued for $targetUserId');
    } catch (e) {
      debugPrint('âŒ Error sending notification: $e');
    }
  }

  /// Unsubscribe from notifications
  Future<void> unsubscribe(String userId) async {
    try {
      await _messaging.deleteToken();

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });

      state = state.copyWith(
        fcmToken: null,
        notificationsEnabled: false,
      );

      debugPrint('âœ… Unsubscribed from notifications');
    } catch (e) {
      debugPrint('âŒ Error unsubscribing: $e');
    }
  }
}

/// Provider
final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

/// Notification badge count provider — counts total unread chat messages.
final notificationBadgeProvider =
    StreamProvider.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('chatRooms')
      .where('participants', arrayContains: userId)
      .snapshots()
      .map((snapshot) {
    int totalUnread = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // unreadCounts is a Map<userId, int> — read only this user's count.
      final counts =
          (data['unreadCounts'] as Map<String, dynamic>?) ?? {};
      final userUnread = (counts[userId] as num?)?.toInt() ?? 0;
      totalUnread += userUnread;
    }
    return totalUnread;
  });
});
