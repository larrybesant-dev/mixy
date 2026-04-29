import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mixvy/core/routing/redirect_logic.dart';
import 'package:mixvy/core/routing/redirect_trace.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/auth/register_screen.dart';
import 'package:mixvy/features/auth/screens/login_screen.dart';
import 'package:mixvy/features/beta/beta_feedback_screen.dart';
import 'package:mixvy/features/friends/screens/friends_list_screen.dart';
import 'package:mixvy/features/messaging/screens/chat_screen.dart';
import 'package:mixvy/features/messaging/screens/create_group_chat_screen.dart';
import 'package:mixvy/features/messaging/screens/new_message_screen.dart';
import 'package:mixvy/features/posts/screens/create_post_screen.dart';
import 'package:mixvy/features/payments/payments_screen.dart';
import 'package:mixvy/features/payments/vip_screen.dart';
import 'package:mixvy/features/payments/screens/admin_entitlement_viewer_screen.dart';
import 'package:mixvy/features/profile/edit_profile_screen.dart';
import 'package:mixvy/features/profile/user_profile_screen.dart';
import 'package:mixvy/features/groups/screens/create_group_screen.dart';
import 'package:mixvy/features/room/screens/cam_popout_screen.dart';
import 'package:mixvy/features/social/screens/live_floor_screen.dart';
import 'package:mixvy/features/social/screens/explore_screen.dart';
import 'package:mixvy/features/speed_dating/screens/speed_dating_screen.dart';
import 'package:mixvy/features/room/screens/create_room_screen.dart';
import 'package:mixvy/features/search/screens/search_screen.dart';
import 'package:mixvy/features/stories/screens/create_story_screen.dart';
import 'package:mixvy/features/stories/screens/story_viewer_screen.dart';
import 'package:mixvy/features/verification/screens/verification_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_age_gate_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_create_lounge_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_home_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_lounges_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_pin_screen.dart';
import 'package:mixvy/features/after_dark/screens/after_dark_profile_screen.dart';
import 'package:mixvy/features/after_dark/widgets/after_dark_shell.dart';
import 'package:mixvy/presentation/screens/notifications_screen.dart';
import 'package:mixvy/features/auth/providers/admin_provider.dart';
import 'package:mixvy/presentation/screens/account_center_screen.dart';
import 'package:mixvy/presentation/screens/app_info_screen.dart';
import 'package:mixvy/presentation/screens/feature_degraded_screen.dart';
import 'package:mixvy/presentation/screens/legal_privacy_screen.dart';
import 'package:mixvy/presentation/screens/legal_terms_screen.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/presentation/providers/app_settings_provider.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/presentation/screens/settings_screen.dart';
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

    /// IMPORTANT: keep safe initial route.
    /// On web, re-use the current browser URL so re-created router instances
    /// don't discard the real path by starting at '/' every time.
    initialLocation: kIsWeb
        ? (Uri.base.path.isEmpty ? '/' : Uri.base.path)
        : '/',

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
        path: '/profile/:id',
        builder: (context, state) {
          final uid = state.pathParameters['id'] ?? '';
          if (uid.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Profile unavailable',
              message: 'Could not resolve a profile id for this route.',
              primaryLabel: 'Go home',
              primaryRoute: '/home',
              icon: Icons.lock_outline,
            );
          }
          return UserProfileScreen(userId: uid);
        },
      ),

      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),

      GoRoute(
        path: '/edit-profile',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return EditProfileScreen(initialTab: tab);
        },
      ),

      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendListScreen(),
      ),

      GoRoute(
        path: '/explore',
        builder: (context, state) => const ExploreScreen(),
      ),

      GoRoute(
        path: '/verification',
        builder: (context, state) => const VerificationScreen(),
      ),

      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountCenterScreen(),
      ),

      GoRoute(
        path: '/about',
        builder: (context, state) => const AppInfoScreen(),
      ),

      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const LegalTermsScreen(),
      ),

      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const LegalPrivacyScreen(),
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
          final previewRoom = state.extra is RoomModel
              ? state.extra as RoomModel
              : null;
          return LiveRoomScreen(
            roomId: roomId,
            previewRoom: previewRoom?.id == roomId ? previewRoom : null,
          );
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
        path: '/stories',
        redirect: (context, state) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          return (uid == null || uid.isEmpty) ? '/home' : '/stories/$uid';
        },
      ),

      GoRoute(
        path: '/stories/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return StoryViewerScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/create-story',
        builder: (context, state) {
          final user = currentUser;
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final userId = user?.id ?? uid;
          if (userId.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Not logged in',
              message: 'Please log in to create a story.',
              primaryLabel: 'Go to login',
              primaryRoute: '/auth',
              icon: Icons.lock_outline,
            );
          }
          return CreateStoryScreen(
            userId: userId,
            username: user?.username ?? 'User',
            avatarUrl: user?.avatarUrl,
          );
        },
      ),

      GoRoute(
        path: '/create-post',
        builder: (context, state) {
          final user = currentUser;
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final userId = user?.id ?? uid;
          if (userId.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Not logged in',
              message: 'Please log in to create a post.',
              primaryLabel: 'Go to login',
              primaryRoute: '/auth',
              icon: Icons.lock_outline,
            );
          }
          return CreatePostScreen(
            userId: userId,
            username: user?.username ?? 'User',
            avatarUrl: user?.avatarUrl,
          );
        },
      ),

      GoRoute(
        path: '/cam',
        builder: (context, state) {
          final targetUserId = state.uri.queryParameters['userId'] ?? '';
          if (targetUserId.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Call unavailable',
              message: 'Missing target user id for camera call.',
              primaryLabel: 'Go back home',
              primaryRoute: '/home',
              icon: Icons.videocam_off_outlined,
            );
          }
          return CamPopoutScreen(targetUserId: targetUserId);
        },
      ),

      GoRoute(
        path: '/after-dark/setup',
        redirect: (context, state) => '/after-dark/age-gate',
      ),

      GoRoute(
        path: '/after-dark',
        builder: (context, state) => const AfterDarkShell(
          child: AfterDarkHomeScreen(),
        ),
      ),

      GoRoute(
        path: '/after-dark/age-gate',
        builder: (context, state) => const AfterDarkAgeGateScreen(),
      ),

      GoRoute(
        path: '/after-dark/pin-setup',
        builder: (context, state) => const AfterDarkPinScreen.setup(),
      ),

      GoRoute(
        path: '/after-dark/unlock',
        builder: (context, state) => const AfterDarkPinScreen.unlock(),
      ),

      GoRoute(
        path: '/after-dark/lounges',
        builder: (context, state) => const AfterDarkShell(
          child: AfterDarkLoungesScreen(),
        ),
      ),

      GoRoute(
        path: '/after-dark/profile',
        builder: (context, state) => const AfterDarkShell(
          child: AfterDarkProfileScreen(),
        ),
      ),

      GoRoute(
        path: '/after-dark/create-lounge',
        builder: (context, state) => const AfterDarkShell(
          child: AfterDarkCreateLoungeScreen(),
        ),
      ),

      GoRoute(
        path: '/beta-feedback',
        builder: (context, state) => const BetaFeedbackScreen(),
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
      secondaryRoute: '/home',
      icon: Icons.error_outline,
    );
  }
}