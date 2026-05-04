import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final pushEnabled = await PushMessagingService.readPersistedPushEnabled();
    if (!pushEnabled) {
      developer.log(
        '[CONTROL_GATE] push_suppressed reason=background_delivery_blocked messageId=${message.messageId ?? 'unknown'}',
        name: 'PushMessagingService',
      );
      return;
    }
    developer.log(
      'Background push received: ${message.messageId}',
      name: 'PushMessagingService',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to process background push',
      name: 'PushMessagingService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class PushMessagingService {
  PushMessagingService._();

  static final PushMessagingService instance = PushMessagingService._();
  static const String _pushEnabledPreferenceKey =
      'control.enable_push_notifications';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Set this to the app's root navigator key so FCM taps can deep-link.
  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _isInitialized = false;
  bool _isPushEnabled = true;
  String? _lastRegisteredUid;
  String? _lastRegisteredToken;

  bool get isPushEnabled => _isPushEnabled;

  static Future<bool> readPersistedPushEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pushEnabledPreferenceKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _persistPushEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pushEnabledPreferenceKey, enabled);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist push gate state',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _logPushSuppressed(String reason, {String? messageId}) {
    developer.log(
      '[CONTROL_GATE] push_suppressed reason=$reason messageId=${messageId ?? 'unknown'}',
      name: 'PushMessagingService',
    );
  }

  Future<void> setPushEnabled(bool enabled) async {
    if (_isPushEnabled == enabled) {
      return;
    }

    _isPushEnabled = enabled;
    await _persistPushEnabled(enabled);
    if (!enabled) {
      await unregisterCurrentToken();
      developer.log(
        'Push delivery disabled via runtime gate',
        name: 'PushMessagingService',
      );
      return;
    }

    developer.log(
      'Push delivery re-enabled via runtime gate',
      name: 'PushMessagingService',
    );
    await _registerCurrentToken();
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isPushEnabled = await readPersistedPushEnabled();
    _isInitialized = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedMessage);
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerTokenIfPossible(token));
    });
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_registerCurrentToken());
      }
    });

    try {
      await _requestPermission();
      await _handleInitialMessage();
    } catch (error, stackTrace) {
      developer.log(
        'Push messaging initialization failed',
        error: error,
        stackTrace: stackTrace,
        name: 'PushMessagingService',
      );
      // Continue without messaging; not fatal.
    }

    await _registerCurrentToken();
  }

  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _onOpenedMessage(initialMessage);
      }
    } on MissingPluginException catch (error, stackTrace) {
      // Some web runtime/plugin combinations do not implement getInitialMessage.
      developer.log(
        'Push initial message not available on this platform runtime.',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to process initial push message',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _requestPermission() async {
    try {
      final currentSettings = await _messaging.getNotificationSettings();
      if (currentSettings.authorizationStatus !=
          AuthorizationStatus.notDetermined) {
        developer.log(
          'Push permission already resolved: ${currentSettings.authorizationStatus.name}',
          name: 'PushMessagingService',
        );
        return;
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      developer.log(
        'Push permission status: ${settings.authorizationStatus.name}',
        name: 'PushMessagingService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Push permission request failed',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!_isPushEnabled) {
      _logPushSuppressed('token_registration_blocked');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await _registerTokenIfPossible(token);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch push token',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _registerTokenIfPossible(String token) async {
    if (!_isPushEnabled) {
      _logPushSuppressed('token_refresh_registration_blocked');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      return;
    }

    if (_lastRegisteredUid == user.uid &&
        _lastRegisteredToken == trimmedToken) {
      return;
    }

    try {
      await _functions.httpsCallable('registerFcmToken').call({
        'token': trimmedToken,
        'platform': _platformLabel(),
      });
      _lastRegisteredUid = user.uid;
      _lastRegisteredToken = trimmedToken;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to register push token',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> unregisterCurrentToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _lastRegisteredUid = null;
      _lastRegisteredToken = null;
      return;
    }

    try {
      final token = await _messaging.getToken();
      await _functions.httpsCallable('unregisterFcmToken').call({
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to unregister push token',
        name: 'PushMessagingService',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _lastRegisteredUid = null;
      _lastRegisteredToken = null;
    }
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (!_isPushEnabled) {
      _logPushSuppressed(
        'foreground_delivery_blocked',
        messageId: message.messageId,
      );
      return;
    }

    developer.log(
      'Foreground push received: ${message.messageId}',
      name: 'PushMessagingService',
    );
    // Foreground messages are shown as in-app notifications via the
    // notifications stream; no OS notification banner on foreground.
  }

  void _onOpenedMessage(RemoteMessage message) {
    if (!_isPushEnabled) {
      _logPushSuppressed(
        'open_navigation_blocked',
        messageId: message.messageId,
      );
      return;
    }

    developer.log(
      'Push opened by user: ${message.messageId}',
      name: 'PushMessagingService',
    );
    _navigateFromMessage(message);
  }

  /// Derives a Go Router path from an FCM [message] data payload and navigates
  /// to it. Payload fields:
  ///   type        — notification category
  ///   roomId      — for room_invite / room_started
  ///   senderId    — for friend_request / friend_accepted
  ///   matchId     — for speed_dating_match
  void _navigateFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String? ?? '';
    final String? route;

    switch (type) {
      case 'incoming_call':
        final roomId = data['roomId'] as String? ?? '';
        route = roomId.isNotEmpty ? '/room/$roomId' : '/home';
      case 'room_invite':
      case 'room_started':
        final roomId = data['roomId'] as String? ?? '';
        route = roomId.isNotEmpty ? '/room/$roomId' : '/home';
      case 'friend_request':
      case 'friend_accepted':
        final senderId = data['senderId'] as String? ?? '';
        route = senderId.isNotEmpty ? '/profile/$senderId' : '/friends';
      case 'speed_dating_match':
        final roomId = data['roomId'] as String? ?? '';
        route = roomId.isNotEmpty ? '/room/$roomId' : '/speed-dating';
      case 'payment':
        route = '/payments';
      case 'notification':
      default:
        route = '/notifications';
    }

    // Route via the root navigator context so navigation works regardless of
    // which screen is currently showing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final context = _navigatorKey?.currentContext;
        if (context != null && route != null) {
          GoRouter.of(context).go(route);
        }
      } catch (e) {
        developer.log(
          'FCM deep-link navigation failed: $e',
          name: 'PushMessagingService',
        );
      }
    });
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
    _isInitialized = false;
  }
}
