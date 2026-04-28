import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mixvy/core/routing/redirect_logic.dart';
import 'package:mixvy/core/routing/redirect_trace.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/auth/screens/login_screen.dart';
import 'package:mixvy/features/messaging/screens/chat_screen.dart';
import 'package:mixvy/features/messaging/screens/create_group_chat_screen.dart';
import 'package:mixvy/features/messaging/screens/new_message_screen.dart';
import 'package:mixvy/features/payments/vip_screen.dart';
import 'package:mixvy/features/payments/screens/admin_entitlement_viewer_screen.dart';
import 'package:mixvy/features/profile/user_profile_screen.dart';
import 'package:mixvy/features/groups/screens/create_group_screen.dart';
import 'package:mixvy/features/social/screens/live_floor_screen.dart';
import 'package:mixvy/features/speed_dating/screens/speed_dating_screen.dart';
import 'package:mixvy/features/room/screens/create_room_screen.dart';
import 'package:mixvy/features/search/screens/search_screen.dart';
import 'package:mixvy/presentation/screens/notifications_screen.dart';
import 'package:mixvy/features/auth/providers/admin_provider.dart';
import 'package:mixvy/presentation/screens/feature_degraded_screen.dart';
import 'package:mixvy/core/services/app_settings_service.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'package:mixvy/presentation/providers/app_settings_provider.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/presentation/screens/live_room_screen.dart';
import 'package:mixvy/shared/widgets/app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
GlobalKey<NavigatorState>(debugLabel: 'mixvy-root-navigator');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final currentUser = ref.watch(userProvider);
  final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
  final appSettingsAsync = ref.watch(appSettingsControllerProvider);
  final appSettings = appSettingsAsync.valueOrNull;

  return GoRouter(
    navigatorKey: rootNavigatorKey,

    /// IMPORTANT: keep safe initial route
    initialLocation: '/',

    redirect: (context, state) {
      final evaluation = evaluateAppRedirectWithReason(
        matchedLocation: state.matchedLocation,
        uid: authState.uid,
        authLoading: !authState.hasResolvedSession,
        legalStateResolved: appSettings != null,
        hasAcceptedLegal: appSettings?.hasAcceptedCurrentLegal ?? false,
      );

      assert(() {
        RedirectTrace.record(
          from: state.matchedLocation,
          to: evaluation.redirectTo ?? 'stay',
          reason: evaluation.reason,
        );
        return true;
      }());

      return evaluation.redirectTo;
    },

    routes: [
      /// ✅ ROOT FIX (CRITICAL FOR WEB)
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),

      GoRoute(
        path: '/auth',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) {
          final tab =
              int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return AppShell(initialIndex: tab);
        },
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            return const FeatureDegradedScreen(
              title: 'Not logged in',
              message: 'Please log in to view profile.',
              primaryLabel: 'Go to login',
              primaryRoute: '/auth',
              icon: Icons.lock_outline,
            );
          }
          return UserProfileScreen(userId: uid);
        },
      ),

      GoRoute(
        path: '/new-message',
        builder: (context, state) {
          final user = currentUser;
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

          return NewMessageScreen(
            userId: user?.id ?? uid,
            username: user?.username ?? 'User',
            avatarUrl: user?.avatarUrl,
          );
        },
      ),

      GoRoute(
        path: '/create-group-chat',
        builder: (context, state) {
          final user = currentUser;
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

          return CreateGroupChatScreen(
            userId: user?.id ?? uid,
            username: user?.username ?? 'User',
          );
        },
      ),

      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final user = currentUser;
          final conversationId = state.pathParameters['id'] ?? '';

          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

          return ChatScreen(
            conversationId: conversationId,
            userId: user?.id ?? uid,
            username: user?.username ??
                FirebaseAuth.instance.currentUser?.displayName ??
                'Chat',
            avatarUrl: user?.avatarUrl,
          );
        },
      ),

      GoRoute(
        path: '/room/:id',
        builder: (context, state) {
          final roomId = state.pathParameters['id'] ?? '';
          return LiveRoomScreen(roomId: roomId);
        },
      ),

      GoRoute(
        path: '/rooms',
        builder: (context, state) => const LiveFloorScreen(),
      ),

      GoRoute(
        path: '/live',
        redirect: (context, state) => '/rooms',
      ),

      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),

      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: '/speed-dating',
        builder: (context, state) => const SpeedDatingScreen(),
      ),

      GoRoute(
        path: '/vip',
        builder: (context, state) => const VipScreen(),
      ),

      GoRoute(
        path: '/admin-entitlements',
        builder: (context, state) {
          if (!isAdmin) {
            return const FeatureDegradedScreen(
              title: 'Admin only',
              message: 'You do not have access to entitlement support tools.',
              primaryLabel: 'Go home',
              primaryRoute: '/home',
              icon: Icons.lock_outline,
            );
          }
          return const AdminEntitlementViewerScreen();
        },
      ),

      GoRoute(
        path: '/create-group',
        builder: (context, state) {
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          return CreateGroupScreen(userId: uid);
        },
      ),

      GoRoute(
        path: '/fallback',
        builder: (context, state) => const _MvpFallbackScreen(),
      ),
    ],
  );
});

/// SAFETY FALLBACK SCREEN
class _MvpFallbackScreen extends StatelessWidget {
  const _MvpFallbackScreen();

  @override
  Widget build(BuildContext context) {
    return const FeatureDegradedScreen(
      title: 'Unavailable right now',
      message: 'This screen is temporarily unavailable. Return home and try again.',
      primaryLabel: 'Go home',
      primaryRoute: '/home',
      secondaryLabel: 'Open profile',
      secondaryRoute: '/profile',
      icon: Icons.error_outline,
    );
  }
}