import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'core/config/firebase_options.dart';
import 'app/auth_gate_root.dart';
import 'features/landing/landing_page.dart';
import 'features/auth/screens/neon_login_page.dart';
import 'features/auth/screens/neon_signup_page.dart';
import 'features/auth/forgot_password_page.dart';
import 'core/theme/neon_theme.dart';
import 'core/utils/app_logger.dart';
import 'shared/providers/vibe_theme_provider.dart';
import 'core/health_check_system.dart';
import 'core/crashlytics/crashlytics_service.dart';
import 'core/performance/performance_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/agora/agora_service.dart';
import 'services/room/room_firestore_service.dart';
import 'app/app_routes.dart';
import 'features/buddy_list/buddy_list_screen.dart';
import 'features/buddy_list/buddy_profile_screen.dart';
import 'core/web/web_window_service.dart';
import 'features/video_room/screens/video_window_screen.dart';
import 'features/chat/screens/chat_pop_out_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background message through notification service
  if (message.notification != null) {
    // Initialize notification service
    // final notificationService = NotificationService();
    debugPrint('Handling background message: ${message.notification!.title}');
  }
}

void main() {
  // CRITICAL: All initialization MUST happen inside runZonedGuarded to avoid zone mismatch
  runZonedGuarded(
    () async {
      // Initialize Flutter bindings FIRST - inside the guarded zone
      WidgetsFlutterBinding.ensureInitialized();

      debugPrint('ðŸš€ Starting app initialization...');

      // Set custom error widget for release mode (shows grey by default)
      ErrorWidget.builder = (FlutterErrorDetails details) {
        debugPrint('ðŸ”´ ErrorWidget building for: ${details.exception}');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF080C14),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF6B35), size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${details.exception}'.length > 100
                        ? '${details.exception}'.substring(0, 100)
                        : '${details.exception}',
                    style:
                        const TextStyle(color: Color(0xFF888888), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      };

      try {
        // Initialize Firebase ONCE - block on this
        debugPrint('ðŸ”¥ Initializing Firebase...');
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
        debugPrint('âœ… Firebase initialized successfully');
        AppLogger.info('Firebase initialized successfully');

        // Initialize Crashlytics BEFORE anything else that might error
        debugPrint('ðŸ’¥ Initializing Crashlytics...');
        await CrashlyticsService.instance.initialize();

        // Set up Flutter error handler for Crashlytics
        FlutterError.onError = (FlutterErrorDetails details) {
          debugPrint('âŒ FLUTTER ERROR: ${details.exception}');
          debugPrint('Stack: ${details.stack}');
          AppLogger.error('Flutter Error: ${details.exception}');
          // Skip Crashlytics on web (not supported)
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.recordFlutterFatalError(details);
          }
        };
        debugPrint('âœ… Crashlytics initialized');

        // Initialize Performance Monitoring
        debugPrint('ðŸ“Š Initializing Performance Monitoring...');
        await PerformanceService.instance.initialize();
        debugPrint('âœ… Performance Monitoring initialized');

        // Set up FCM background message handler
        debugPrint('ðŸ“± Setting up FCM...');
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
        debugPrint('âœ… FCM background handler registered');

        // Initialize local notifications (don't block app startup if it fails)
        debugPrint('ðŸ“± Initializing local notifications...');
        NotificationService().initialize().then((_) {
          debugPrint('âœ… Notifications initialized successfully');
        }).catchError((e) {
          debugPrint(
              'âš ï¸  Notification initialization non-fatal failure: $e');
          AppLogger.warning('Notifications unavailable: $e');
          CrashlyticsService.instance
              .recordError(e, reason: 'notification_init_failure');
        });

        // Initialize FCM notifications (don't block app startup if it fails)
        debugPrint('ðŸ“± FCM notification setup deferred to auth gate...');

        // Run health checks
        debugPrint('ðŸ¥ Running project health checks...');
        final healthChecker = ProjectHealthChecker();
        await healthChecker.runAllChecks();
        final healthStatus =
            healthChecker.isHealthy ? 'âœ… HEALTHY' : 'âš ï¸  ISSUES DETECTED';
        debugPrint('Health check status: $healthStatus');
        AppLogger.info('Health check completed: $healthStatus');
      } catch (e, stackTrace) {
        debugPrint('âŒ Initialization error: $e');
        AppLogger.error('Initialization failed: $e');
        CrashlyticsService.instance
            .recordError(e, stackTrace: stackTrace, reason: 'app_init_failure');
        // App will still start even if services fail, but user may experience missing features
      }

      debugPrint('ðŸš€ Running app with Riverpod and Provider setup...');

      runApp(
        riverpod.ProviderScope(
          child: MultiProvider(
            providers: [
              // âœ… Agora Service (singleton)
              Provider<AgoraService>(
                create: (_) => AgoraService(),
              ),

              // âœ… Room Firestore Service (singleton)
              Provider<RoomFirestoreService>(
                create: (_) => RoomFirestoreService(),
              ),
            ],
            child: const _AlwaysLandingApp(),
          ),
        ),
      );
    },
    (error, stackTrace) {
      // Handle async errors with Crashlytics
      debugPrint('âŒ ASYNC ERROR: $error');
      debugPrint('Stack: $stackTrace');
      AppLogger.error('Async Error: $error');
      CrashlyticsService.instance.recordError(
        error,
        stackTrace: stackTrace,
        reason: 'async_error',
      );
    },
  );
}

/// Always show landing page first - user must manually login
class _AlwaysLandingApp extends riverpod.ConsumerWidget {
  const _AlwaysLandingApp();

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    // #8 Adaptive Neon Glow — vibe accent shifts the app-wide primary colour
    final vibeAccent = ref.watch(vibeAccentProvider);
    final themedTheme = NeonTheme.darkTheme.copyWith(
      colorScheme: NeonTheme.darkTheme.colorScheme.copyWith(
        primary: vibeAccent,
      ),
    );
    return MaterialApp(
      title: 'Mix & Mingle - Vibes Around the World',
      debugShowCheckedModeBanner: false,
      theme: themedTheme,
      // Use RootAuthGate as home so returning authenticated users go directly
      // to the app rather than being shown LandingPage on every startup.
      // RootAuthGate handles unauthenticated users by showing LandingPage itself.
      home: const RootAuthGate(),
      onGenerateRoute: (settings) {
        debugPrint('🌐 [AppRouter] Route: ${settings.name}');
        // Strip query-string from the route name before matching.
        // On Flutter Web (hash routing) pop-out windows open at URLs like
        // /buddy-profile?uid=xxx — the full string becomes settings.name,
        // so we must compare only the path portion.
        final rawName = settings.name ?? '';
        final routeUri = Uri.tryParse(rawName);
        final routePath = routeUri?.path ?? rawName;           // e.g. /buddy-profile
        final routeParams = routeUri?.queryParameters ?? {};    // e.g. {uid: 'abc'}

        switch (routePath) {
          case '/':
          case '/landing':
            return MaterialPageRoute(builder: (_) => const LandingPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => const NeonLoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const NeonSignupPage());
          case '/forgot-password':
            return MaterialPageRoute(
                builder: (_) => const ForgotPasswordPage());
          case '/app':
            // After login, go to the auth-protected app
            // On web, also restore any previously-open pop-out windows.
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => WebWindowService.restoreWindowsOnLogin());
            return MaterialPageRoute(builder: (_) => const RootAuthGate());

          // ── Pop-out window routes (no extra auth guard needed;
          //    opened only from authenticated sessions) ────────────────
          case '/buddy-list':
            return MaterialPageRoute(
                builder: (_) => const BuddyListScreen());

          case '/buddy-profile':
            // uid may arrive as a query param in the URL (/buddy-profile?uid=X)
            // or as a plain String argument from Navigator.pushNamed.
            final uid = routeParams['uid'] ??
                (settings.arguments as String? ?? '');
            if (uid.isEmpty) {
              return MaterialPageRoute(
                  builder: (_) => const Scaffold(
                        body: Center(child: Text('User ID missing'))));
            }
            return MaterialPageRoute(
                builder: (_) => BuddyProfileScreen(uid: uid));

          // ── Chat pop-out window ───────────────────────────────
          case '/buddy-chat':
            // chatId / name may arrive as URL params or via arguments String.
            final chatId = routeParams['chatId'] ??
                Uri.tryParse(settings.arguments as String? ?? '')
                    ?.queryParameters['chatId'] ??
                '';
            final peerName = routeParams['name'] ??
                Uri.tryParse(settings.arguments as String? ?? '')
                    ?.queryParameters['name'] ??
                'Chat';
            return MaterialPageRoute(
                builder: (_) => ChatPopOutScreen(
                      chatId: chatId,
                      peerName: Uri.decodeComponent(peerName),
                    ));

          // ── In-app full-page routes ─────────────────────────────────────
          // NOTE: /feed and /speed-dating are intentionally NOT handled here
          // so they fall through to AppRoutes.generateRoute below, which
          // wraps them properly in AuthGate + ProfileGuard.

          case '/video-window':
            final videoUid = routeParams['uid'] ??
                Uri.tryParse(settings.arguments as String? ?? '')
                    ?.queryParameters['uid'] ??
                (settings.arguments as String? ?? '');
            final videoName = routeParams['name'] ??
                Uri.tryParse(settings.arguments as String? ?? '')
                    ?.queryParameters['name'] ??
                '';
            final videoChannelId = routeParams['channelId'];
            final videoAgoraUidStr = routeParams['agoraUid'];
            final videoAgoraUid = videoAgoraUidStr != null
                ? int.tryParse(videoAgoraUidStr)
                : null;
            return MaterialPageRoute(
                builder: (_) => VideoWindowScreen(
                      uid: videoUid,
                      displayName: Uri.decodeComponent(videoName),
                      channelId: videoChannelId,
                      agoraUid: videoAgoraUid,
                    ));

          default:
            // Delegate all authenticated-app routes to the full AppRoutes table
            return AppRoutes.generateRoute(settings);
        }
      },
    );
  }
}
