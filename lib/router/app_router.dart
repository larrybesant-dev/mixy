import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mixvy/core/routing/auth_invariant.dart';
import 'package:mixvy/core/routing/redirect_logic.dart';
import 'package:mixvy/core/routing/redirect_trace.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/after_dark/providers/after_dark_provider.dart';
import 'package:mixvy/features/auth/register_screen.dart';
import 'package:mixvy/features/auth/screens/login_screen.dart';
import 'package:mixvy/features/auth/screens/forgot_password_screen.dart';
import 'package:mixvy/features/beta/beta_feedback_screen.dart';
import 'package:mixvy/features/friends/screens/friends_list_screen.dart';
import 'package:mixvy/features/messaging/screens/chat_screen.dart';
import 'package:mixvy/features/messaging/screens/create_group_chat_screen.dart';
import 'package:mixvy/features/messaging/screens/new_message_screen.dart';
import 'package:mixvy/features/bookmarks/screens/bookmarks_screen.dart';
import 'package:mixvy/features/groups/screens/group_details_screen.dart';
import 'package:mixvy/features/groups/screens/groups_screen.dart';
import 'package:mixvy/features/posts/screens/create_post_screen.dart';
import 'package:mixvy/features/posts/screens/post_comments_screen.dart';
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
import 'package:mixvy/features/trending/screens/trending_screen.dart';
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
import 'package:mixvy/presentation/screens/moderation_dashboard_screen.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/observability/realtime_ops_screen.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/presentation/screens/settings_screen.dart';
import 'package:mixvy/features/room/presentation/live_room_screen.dart';
import 'package:mixvy/shared/widgets/app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-root-navigator',
);

class _RouterRefreshNotifier extends ChangeNotifier {
  AuthState _authState = const AuthState();
  UserModel? _currentUser;
  bool _isAdmin = false;
  bool _isAfterDarkSessionActive = false;

  AuthState get authState => _authState;
  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _isAdmin;
  bool get isAfterDarkSessionActive => _isAfterDarkSessionActive;

  void updateAuthState(AuthState value) {
    if (_authState == value) {
      return;
    }
    _authState = value;
    notifyListeners();
  }

  void updateCurrentUser(UserModel? value) {
    if (_currentUser == value) {
      return;
    }
    _currentUser = value;
    notifyListeners();
  }

  void updateIsAdmin(bool value) {
    if (_isAdmin == value) {
      return;
    }
    _isAdmin = value;
    notifyListeners();
  }

  void updateAfterDarkSession(bool value) {
    if (_isAfterDarkSessionActive == value) {
      return;
    }
    _isAfterDarkSessionActive = value;
    notifyListeners();
  }
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    notifier.updateAuthState(next);
  }, fireImmediately: true);

  ref.listen<UserModel?>(
    userProvider,
    (_, next) => notifier.updateCurrentUser(next),
    fireImmediately: true,
  );

  ref.listen<AsyncValue<bool>>(
    isAdminProvider,
    (_, next) => notifier.updateIsAdmin(next.valueOrNull ?? false),
    fireImmediately: true,
  );

  ref.listen<bool>(
    afterDarkSessionProvider,
    (_, next) => notifier.updateAfterDarkSession(next),
    fireImmediately: true,
  );

  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.read(_routerRefreshNotifierProvider);
  final streamLifecycleManager = ref.read(streamLifecycleManagerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refreshNotifier,
    initialLocation: kIsWeb
        ? (Uri.base.path.isEmpty ? '/' : Uri.base.path)
        : '/',
    errorBuilder: (context, state) => FeatureDegradedScreen(
      title: 'Page Not Found',
      message: state.error?.toString().isNotEmpty == true
          ? 'We could not open this route. ${state.error}'
          : 'The route you requested is unavailable or no longer exists.',
      primaryLabel: 'Go home',
      primaryRoute: '/home',
      icon: Icons.travel_explore_outlined,
    ),

    redirect: (context, state) {
      final authState = refreshNotifier.authState;
      final location = state.uri.path.isEmpty ? '/' : state.uri.path;
      streamLifecycleManager.updateRoute(location);
      final evaluation = evaluateAppRedirectWithReason(
        matchedLocation: location,
        uid: authState.uid,
        authLoading: !authState.isRoutingStable,
        legalStateResolved: true,
        hasAcceptedLegal: true,
      );

      assert(() {
        if (!authState.isRoutingStable && evaluation.redirectTo != null) {
          throw FlutterError(
            'Router redirect executed before auth bootstrap reached STABLE phase.',
          );
        }
        RedirectTrace.record(
          from: location,
          to: evaluation.redirectTo ?? 'stay',
          reason: evaluation.reason,
        );
        return true;
      }());

      return evaluation.redirectTo;
    },

    routes: [
      /// Root route resolves directly to the correct entry path.
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),

      GoRoute(path: '/auth', builder: (context, state) => const LoginScreen()),

      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendListScreen(),
      ),

      GoRoute(
        path: '/groups',
        builder: (context, state) {
          final uid = refreshNotifier.authState.uid ?? '';
          return GroupsScreen(userId: uid);
        },
      ),

      GoRoute(
        path: '/group/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id'] ?? '';
          final uid = refreshNotifier.authState.uid ?? '';
          if (groupId.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Group unavailable',
              message: 'Could not resolve a group id for this route.',
              primaryLabel: 'Go home',
              primaryRoute: '/home',
              icon: Icons.error_outline,
            );
          }
          return GroupDetailsScreen(groupId: groupId, userId: uid);
        },
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
        path: '/messages',
        builder: (context, state) => const AppShell(initialIndex: 1),
      ),

      GoRoute(
        path: '/messages/new',
        redirect: (context, state) => '/new-message',
      ),

      GoRoute(
        path: '/messages/:threadId',
        redirect: (context, state) {
          final threadId = state.pathParameters['threadId'] ?? '';
          if (threadId.isEmpty) {
            return '/messages';
          }
          return '/chat/$threadId';
        },
      ),

      GoRoute(
        path: '/new-message',
        builder: (context, state) {
          final user = refreshNotifier.currentUser;
          final uid = refreshNotifier.authState.uid ?? '';
          if (!AuthInvariant.hasAuthenticatedUid(uid)) {
            return AuthInvariant.authRequiredScreen(
              message: 'Please sign in to start a new message.',
            );
          }

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
          final user = refreshNotifier.currentUser;
          final uid = refreshNotifier.authState.uid ?? '';
          if (!AuthInvariant.hasAuthenticatedUid(uid)) {
            return AuthInvariant.authRequiredScreen(
              message: 'Please sign in to create a group chat.',
            );
          }

          return CreateGroupChatScreen(
            userId: user?.id ?? uid,
            username: user?.username ?? 'User',
          );
        },
      ),

      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final user = refreshNotifier.currentUser;
          final conversationId = state.pathParameters['id'] ?? '';

          final uid = refreshNotifier.authState.uid ?? '';
          if (!AuthInvariant.hasAuthenticatedUid(uid)) {
            return AuthInvariant.authRequiredScreen(
              message: 'Please sign in to access your chats.',
            );
          }

          return ChatScreen(
            conversationId: conversationId,
            userId: user?.id ?? uid,
            username: user?.username ?? 'Chat',
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

          // Adult rooms require a signed-in user with adult mode enabled.
          // Users who are not signed in or have not enabled adult mode are
          // redirected to /auth so they can sign in / enable the feature.
          final isAdultRoom = previewRoom?.isAdult ?? false;
          final uid = refreshNotifier.authState.uid;
          final isUnauthenticated = uid == null || uid.isEmpty;
          if (isAdultRoom && isUnauthenticated) {
            return const FeatureDegradedScreen(
              title: 'Sign in required',
              message:
                  'This room contains adult content. Please sign in and enable MixVy After Dark to continue.',
              primaryLabel: 'Sign in',
              primaryRoute: '/auth',
              icon: Icons.lock_outline,
            );
          }

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

      GoRoute(path: '/live', redirect: (context, state) => '/rooms'),

      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),

      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),

      GoRoute(
        path: '/bookmarks',
        builder: (context, state) {
          final uid = refreshNotifier.authState.uid ?? '';
          if (uid.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Not logged in',
              message: 'Please log in to view bookmarks.',
              primaryLabel: 'Go to login',
              primaryRoute: '/auth',
              icon: Icons.lock_outline,
            );
          }
          return BookmarksScreen(userId: uid);
        },
      ),

      GoRoute(
        path: '/trending',
        builder: (context, state) => const TrendingScreen(),
      ),

      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: '/ops',
        builder: (context, state) => const RealtimeOpsScreen(),
      ),

      GoRoute(
        path: '/stories',
        redirect: (context, state) {
          final uid = refreshNotifier.authState.uid;
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
          final user = refreshNotifier.currentUser;
          final uid = refreshNotifier.authState.uid ?? '';
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
          final user = refreshNotifier.currentUser;
          final uid = refreshNotifier.authState.uid ?? '';
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
        path: '/post/:id/comments',
        builder: (context, state) {
          final postId = state.pathParameters['id'] ?? '';
          if (postId.isEmpty) {
            return const FeatureDegradedScreen(
              title: 'Comments unavailable',
              message: 'Could not resolve a post id for this route.',
              primaryLabel: 'Go home',
              primaryRoute: '/home',
              icon: Icons.comment_bank_outlined,
            );
          }
          return PostCommentsScreen(postId: postId);
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
        redirect: (context, state) {
          if (!refreshNotifier.isAfterDarkSessionActive) {
            return '/after-dark/unlock';
          }
          return null;
        },
        builder: (context, state) =>
            const AfterDarkShell(child: AfterDarkHomeScreen()),
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
        redirect: (context, state) {
          if (!refreshNotifier.isAfterDarkSessionActive) {
            return '/after-dark/unlock';
          }
          return null;
        },
        builder: (context, state) =>
            const AfterDarkShell(child: AfterDarkLoungesScreen()),
      ),

      GoRoute(
        path: '/after-dark/profile',
        redirect: (context, state) {
          if (!refreshNotifier.isAfterDarkSessionActive) {
            return '/after-dark/unlock';
          }
          return null;
        },
        builder: (context, state) =>
            const AfterDarkShell(child: AfterDarkProfileScreen()),
      ),

      GoRoute(
        path: '/after-dark/create-lounge',
        redirect: (context, state) {
          if (!refreshNotifier.isAfterDarkSessionActive) {
            return '/after-dark/unlock';
          }
          return null;
        },
        builder: (context, state) =>
            const AfterDarkShell(child: AfterDarkCreateLoungeScreen()),
      ),

      GoRoute(
        path: '/beta-feedback',
        builder: (context, state) => const BetaFeedbackScreen(),
      ),

      GoRoute(
        path: '/speed-dating',
        builder: (context, state) => const SpeedDatingScreen(),
      ),

      GoRoute(path: '/vip', builder: (context, state) => const VipScreen()),

      GoRoute(
        path: '/admin-entitlements',
        builder: (context, state) {
          if (!refreshNotifier.isAdmin) {
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
        path: '/moderation',
        builder: (context, state) {
          if (!refreshNotifier.isAdmin) {
            return const FeatureDegradedScreen(
              title: 'Admin only',
              message: 'You do not have access to moderation tools.',
              primaryLabel: 'Go home',
              primaryRoute: '/home',
              icon: Icons.lock_outline,
            );
          }
          return const ModerationDashboardScreen();
        },
      ),

      GoRoute(
        path: '/create-group',
        builder: (context, state) {
          final uid = refreshNotifier.authState.uid ?? '';
          return CreateGroupScreen(userId: uid);
        },
      ),
    ],
  );
});
