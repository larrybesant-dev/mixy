import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mixvy/core/services/first_run_service.dart';
import 'package:mixvy/core/services/feature_gate_service.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/auth/screens/login_screen.dart';
import 'package:mixvy/features/messaging/screens/chat_screen.dart';
import 'package:mixvy/features/messaging/screens/new_message_screen.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'package:mixvy/features/profile/profile_screen.dart';
import 'package:mixvy/features/profile/user_profile_screen.dart';
import 'package:mixvy/features/splash/splash_screen.dart';
import 'package:mixvy/presentation/screens/feature_degraded_screen.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/presentation/screens/live_room_screen.dart';
import 'package:mixvy/shared/widgets/app_shell.dart';

typedef FirstRunCheck = Future<bool> Function();
typedef ProfileCompleteCheck = Future<bool> Function(String uid);
typedef LegalAcceptedCheck = Future<bool> Function();

const Duration _routingTelemetryCooldown = Duration(seconds: 30);
final Map<String, DateTime> _routingTelemetryByKey = <String, DateTime>{};

void _emitRoutingTelemetry({
  required String eventName,
  required String feature,
  required String route,
  required FeatureServiceMode mode,
  String result = 'observed',
}) {
  final key = '$eventName|$feature|$route|${mode.name}';
  final now = DateTime.now();
  final previous = _routingTelemetryByKey[key];
  if (previous != null && now.difference(previous) < _routingTelemetryCooldown) {
    return;
  }
  _routingTelemetryByKey[key] = now;

  AppTelemetry.logAction(
    level: mode == FeatureServiceMode.disabled ? 'warning' : 'info',
    domain: 'routing',
    action: eventName,
    message: 'Feature route handled by control policy.',
    result: result,
    metadata: <String, Object?>{
      'feature': feature,
      'route': route,
      'mode': mode.name,
    },
  );
}

bool _isMessagingRoute(String path) {
  return path == '/messages' ||
      path.startsWith('/messages/') ||
      path == '/friends' ||
      path == '/whisper';
}

bool _isRoomRoute(String path) {
  return path == '/live' ||
      path == '/rooms' ||
      path == '/create-room' ||
      path.startsWith('/room/');
}

Future<String?> evaluateAppRedirect({
  required String matchedLocation,
  required String? uid,
  required bool authLoading,
  required FirstRunCheck isFirstRun,
  required ProfileCompleteCheck isProfileComplete,
  required LegalAcceptedCheck isLegalAccepted,
  bool enableLiveRooms = true,
  bool enableMessaging = true,
  bool isRouteError = false,
  String? redirectFrom,
}) async {
  if (authLoading) {
    return matchedLocation == '/splash' ? null : '/splash';
  }

  if (uid == null) {
    return matchedLocation == '/auth' ? null : '/auth';
  }

  final onboardingIncomplete = await isFirstRun();
  if (onboardingIncomplete) {
    return matchedLocation == '/onboarding' ? null : '/onboarding';
  }

  if (matchedLocation == '/splash' ||
      matchedLocation == '/auth' ||
      matchedLocation == '/login' ||
      matchedLocation == '/onboarding') {
    return '/app';
  }

  if (!enableMessaging && _isMessagingRoute(matchedLocation)) {
    return '/status/messaging-unavailable';
  }

  if (!enableLiveRooms && _isRoomRoute(matchedLocation)) {
    return '/status/rooms-unavailable';
  }

  return null;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-root-navigator',
);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final currentUser = ref.watch(userProvider);
  final gates = ref.watch(featureGateControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) async {
      final decision = await evaluateAppRedirect(
        matchedLocation: state.matchedLocation,
        uid: authState.uid,
        authLoading: !authState.hasResolvedSession,
        isFirstRun: FirstRunService.isFirstRun,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        enableLiveRooms: gates.enableLiveRooms,
        enableMessaging: gates.enableMessaging,
      );

      if (decision == '/status/messaging-unavailable') {
        _emitRoutingTelemetry(
          eventName: 'feature_redirect_event',
          feature: 'messaging',
          route: state.matchedLocation,
          mode: gates.messagingMode,
          result: 'redirected',
        );
      }

      if (decision == '/status/rooms-unavailable') {
        _emitRoutingTelemetry(
          eventName: 'feature_redirect_event',
          feature: 'rooms',
          route: state.matchedLocation,
          mode: gates.liveRoomsMode,
          result: 'redirected',
        );
      }

      return decision;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login',
        redirect: (context, state) => '/auth',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return AppShell(initialIndex: tab);
        },
      ),
      GoRoute(
        path: '/messages',
        redirect: (context, state) => gates.enableMessaging
            ? '/app?tab=1'
            : '/status/messaging-unavailable',
      ),
      GoRoute(
        path: '/live',
        redirect: (context, state) => gates.enableLiveRooms
            ? '/app?tab=2'
            : '/status/rooms-unavailable',
      ),
      GoRoute(
        path: '/discover',
        redirect: (context, state) => '/app?tab=0',
      ),
      GoRoute(
        path: '/profile',
        redirect: (context, state) => '/app?tab=3',
      ),
      GoRoute(
        path: '/messages/new',
        builder: (context, state) {
          if (gates.messagingDegraded) {
            _emitRoutingTelemetry(
              eventName: 'degraded_entry_event',
              feature: 'messaging',
              route: '/messages/new',
              mode: gates.messagingMode,
            );
          }

          if (!gates.enableMessaging) {
            return const FeatureDegradedScreen(
              title: 'Messages temporarily unavailable',
              message:
                  'Messaging is in maintenance mode while we stabilize delivery. You can keep browsing your feed and profile.',
              primaryLabel: 'Go to feed',
              primaryRoute: '/app?tab=0',
              secondaryLabel: 'Open profile',
              secondaryRoute: '/app?tab=3',
              icon: Icons.forum_outlined,
            );
          }

          final user = currentUser;
          if (user == null) return const LoginScreen();
          return Newmessagecreen(
            userId: user.id,
            username: user.username,
            avatarUrl: user.avatarUrl,
          );
        },
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) {
          if (gates.messagingDegraded) {
            _emitRoutingTelemetry(
              eventName: 'degraded_entry_event',
              feature: 'messaging',
              route: '/messages/:conversationId',
              mode: gates.messagingMode,
            );
          }

          if (!gates.enableMessaging) {
            return const FeatureDegradedScreen(
              title: 'Messages temporarily unavailable',
              message:
                  'Messaging has been paused to protect conversation reliability. Please try again shortly.',
              primaryLabel: 'Go to feed',
              primaryRoute: '/app?tab=0',
              secondaryLabel: 'Open profile',
              secondaryRoute: '/app?tab=3',
              icon: Icons.forum_outlined,
            );
          }

          final user = currentUser;
          final conversationId = state.pathParameters['conversationId'];
          if (user == null || conversationId == null || conversationId.isEmpty) {
            return const LoginScreen();
          }
          return ChatScreen(
            conversationId: conversationId,
            userId: user.id,
            username: user.username,
            avatarUrl: user.avatarUrl,
          );
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          if (userId == null || userId.isEmpty) {
            final fallbackUid = FirebaseAuth.instance.currentUser?.uid;
            if (fallbackUid == null) return const ProfileScreen();
            return UserProfileScreen(userId: fallbackUid);
          }
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/room/:roomId',
        builder: (context, state) {
          if (gates.liveRoomsDegraded) {
            _emitRoutingTelemetry(
              eventName: 'degraded_entry_event',
              feature: 'rooms',
              route: '/room/:roomId',
              mode: gates.liveRoomsMode,
            );
          }

          if (!gates.enableLiveRooms) {
            return const FeatureDegradedScreen(
              title: 'Rooms reconnecting...',
              message:
                  'Live rooms are temporarily unavailable while we recover room stability. Messaging and profile remain available.',
              primaryLabel: 'Go to discover',
              primaryRoute: '/app?tab=0',
              secondaryLabel: 'Open profile',
              secondaryRoute: '/app?tab=3',
              icon: Icons.sensors_off_outlined,
            );
          }

          final roomId = state.pathParameters['roomId'];
          if (roomId == null || roomId.isEmpty) {
            return const SizedBox.shrink();
          }
          return LiveRoomScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/status/messaging-unavailable',
        builder: (context, state) {
          _emitRoutingTelemetry(
            eventName: 'degraded_entry_event',
            feature: 'messaging',
            route: '/status/messaging-unavailable',
            mode: gates.messagingMode,
          );
          return const FeatureDegradedScreen(
            title: 'Messages temporarily unavailable',
            message:
                'Messaging is in controlled maintenance mode. The rest of MixVy is still available while we recover.',
            primaryLabel: 'Go to feed',
            primaryRoute: '/app?tab=0',
            secondaryLabel: 'Open profile',
            secondaryRoute: '/app?tab=3',
            icon: Icons.forum_outlined,
          );
        },
      ),
      GoRoute(
        path: '/status/rooms-unavailable',
        builder: (context, state) {
          _emitRoutingTelemetry(
            eventName: 'degraded_entry_event',
            feature: 'rooms',
            route: '/status/rooms-unavailable',
            mode: gates.liveRoomsMode,
          );
          return const FeatureDegradedScreen(
            title: 'Rooms reconnecting...',
            message:
                'Live rooms are temporarily in maintenance mode while we stabilize room lifecycle behavior.',
            primaryLabel: 'Go to discover',
            primaryRoute: '/app?tab=0',
            secondaryLabel: 'Open profile',
            secondaryRoute: '/app?tab=3',
            icon: Icons.sensors_off_outlined,
          );
        },
      ),
    ],
  );
});
