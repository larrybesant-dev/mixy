import 'package:mixvy/presentation/rooms/browser/room_browser_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mixvy/core/routing/redirect_logic.dart';
import 'package:mixvy/core/routing/redirect_trace.dart';
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
import 'package:mixvy/features/top_eight/top_eight_management_screen.dart';
import 'package:mixvy/features/connections/pending_requests_screen.dart';
import 'package:mixvy/features/groups/screens/create_group_screen.dart';
import 'package:mixvy/features/room/screens/cam_popout_screen.dart';
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
import 'package:mixvy/features/room/presentation/call_screen.dart';
import 'package:mixvy/features/room/presentation/live_room_screen.dart';
import 'package:mixvy/shared/providers/tab_navigation_provider.dart';
import 'package:mixvy/features/dashboard/dashboard_screen.dart';
import 'package:mixvy/features/messaging/screens/messages_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-root-navigator',
);

class _RouterRefreshNotifier extends ChangeNotifier {
  AuthState _authState = const AuthState();
  UserModel? _currentUser;
  bool _isAdmin = false;
  bool _isAfterDarkSessionActive = false;
  bool _isReady = false;

  AuthState get authState => _authState;
  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _isAdmin;
  bool get isAfterDarkSessionActive => _isAfterDarkSessionActive;
  bool get isReady => _isReady;

  void init({
    required AuthState authState,
    required UserModel? currentUser,
    required bool isAdmin,
    required bool isAfterDarkSessionActive,
  }) {
    _authState = authState;
    _currentUser = currentUser;
    _isAdmin = isAdmin;
    _isAfterDarkSessionActive = isAfterDarkSessionActive;
  }

  void markReady() {
    if (_isReady) return;
    _isReady = true;
    notifyListeners();
  }

  void updateAuthState(AuthState value) {
    if (_authState == value) return;
    _authState = value;
    if (!_isReady) return;
    notifyListeners();
  }

  void updateCurrentUser(UserModel? value) {
    // Only notify router listeners if the user's core ID changes, preventing 
    // full-app rebuilds when minor profile fields (e.g. followers) change.
    final bool idChanged = _currentUser?.id != value?.id;
    _currentUser = value;
    if (!idChanged) return;

    if (!_isReady) return;
    notifyListeners();
  }

  void updateIsAdmin(bool value) {
    if (_isAdmin == value) return;
    _isAdmin = value;
    if (!_isReady) return;
    notifyListeners();
  }

  void updateAfterDarkSession(bool value) {
    if (_isAfterDarkSessionActive == value) return;
    _isAfterDarkSessionActive = value;
    if (!_isReady) return;
    notifyListeners();
  }
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();

  // Initialize with the current provider state before the router uses this notifier.
  notifier.init(
    authState: ref.read(authControllerProvider),
    currentUser: ref.read(userProvider),
    isAdmin: ref.read(isAdminProvider).valueOrNull ?? false,
    isAfterDarkSessionActive: ref.read(afterDarkSessionProvider),
  );

  ref.listen<AuthState>(authControllerProvider, (_, next) => notifier.updateAuthState(next), fireImmediately: false);
  ref.listen<UserModel?>(userProvider, (_, next) => notifier.updateCurrentUser(next), fireImmediately: false);
  ref.listen<AsyncValue<bool>>(isAdminProvider, (_, next) => notifier.updateIsAdmin(next.valueOrNull ?? false), fireImmediately: false);
  ref.listen<bool>(afterDarkSessionProvider, (_, next) => notifier.updateAfterDarkSession(next), fireImmediately: false);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.read(_routerRefreshNotifierProvider);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refreshNotifier,
    initialLocation: kIsWeb ? (Uri.base.path.isEmpty ? '/' : Uri.base.path) : '/',
    errorBuilder: (context, state) => FeatureDegradedScreen(
      title: 'Page Not Found',
      message: state.error?.toString().isNotEmpty == true ? 'We could not open this route. ${state.error}' : 'The route you requested is unavailable or no longer exists.',
      primaryLabel: 'Go home',
      primaryRoute: '/home',
      icon: Icons.travel_explore_outlined,
    ),
    redirect: (context, state) {
      try {
        final authState = refreshNotifier.authState;
        final location = state.uri.path.isEmpty ? '/' : state.uri.path;
        
        // Handle web bootstrap lag safely without crashing
        // Allow auth routes (/auth, /register, /forgot-password, /onboarding) even during bootstrap
        final isAuthBootstrapRoute = location == '/auth' ||
            location == '/register' ||
            location == '/forgot-password' ||
            location == '/onboarding';
        
        if (!authState.isRoutingStable && !isAuthBootstrapRoute) {
          return '/auth'; // Redirect un-bootstrapped web states straight to login/auth view safely
        }

        final evaluation = evaluateAppRedirectWithReason(
          matchedLocation: location,
          uid: authState.uid,
          authLoading: !authState.isRoutingStable,
          legalStateResolved: true,
          hasAcceptedLegal: true,
        );
        
        RedirectTrace.record(from: location, to: evaluation.redirectTo ?? 'stay', reason: evaluation.reason);
        return evaluation.redirectTo;
      } catch (e) {
        debugPrint('Suppressed web router bootstrap mismatch: $e');
        return '/auth';
      }
    },
    routes: [
      // Custom shell route that bypasses StatefulShellRoute limitations on web
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => _CustomShell(initialIndex: 0),
        routes: [
          GoRoute(path: 'notifications', name: 'notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: 'search', name: 'search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: 'explore', name: 'explore', builder: (context, state) => const ExploreScreen()),
          GoRoute(path: 'trending', name: 'trending', builder: (context, state) => const TrendingScreen()),
          GoRoute(
            path: 'bookmarks',
            name: 'bookmarks',
            redirect: (context, state) {
              final uid = refreshNotifier.authState.uid;
              return (uid == null || uid.isEmpty) ? '/auth' : null;
            },
            builder: (context, state) => BookmarksScreen(
              userId: refreshNotifier.authState.uid!,
            ),
          ),
          GoRoute(
            path: 'create-post',
            name: 'createPost',
            redirect: (context, state) {
              final uid = refreshNotifier.authState.uid;
              return (uid == null || uid.isEmpty) ? '/auth' : null;
            },
            builder: (context, state) {
              final user = refreshNotifier.currentUser;
              final uid = refreshNotifier.authState.uid!;
              final userId = user?.id ?? uid;
              return CreatePostScreen(userId: userId, username: user?.username ?? 'User', avatarUrl: user?.avatarUrl);
            },
          ),
          GoRoute(
            path: 'post/:id/comments',
            name: 'postComments',
            builder: (context, state) {
              final postId = state.pathParameters['id'] ?? '';
              if (postId.isEmpty) return const FeatureDegradedScreen(title: 'Comments unavailable', message: 'Could not resolve a post id.', primaryLabel: 'Go home', primaryRoute: '/home', icon: Icons.comment_bank_outlined);
              return PostCommentsScreen(postId: postId);
            },
          ),
          GoRoute(
            path: 'create-story',
            name: 'createStory',
            redirect: (context, state) {
              final uid = refreshNotifier.authState.uid;
              return (uid == null || uid.isEmpty) ? '/auth' : null;
            },
            builder: (context, state) {
              final user = refreshNotifier.currentUser;
              final uid = refreshNotifier.authState.uid!;
              final userId = user?.id ?? uid;
              return CreateStoryScreen(userId: userId, username: user?.username ?? 'User', avatarUrl: user?.avatarUrl);
            },
          ),
          GoRoute(path: 'stories/:userId', name: 'storyViewer', builder: (context, state) => StoryViewerScreen(userId: state.pathParameters['userId'] ?? '')),
          GoRoute(path: 'ops', name: 'realtimeOps', builder: (context, state) => const RealtimeOpsScreen()),
        ],
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        redirect: (context, state) {
          final uid = refreshNotifier.authState.uid;
          return (uid == null || uid.isEmpty) ? '/auth' : null;
        },
        builder: (context, state) => _CustomShell(initialIndex: 1),
        routes: [
          GoRoute(
            path: 'new',
            name: 'newMessage',
            builder: (context, state) {
              final user = refreshNotifier.currentUser;
              final uid = refreshNotifier.authState.uid ?? '';
              return NewMessageScreen(userId: user?.id ?? uid, username: user?.username ?? 'User', avatarUrl: user?.avatarUrl);
            },
          ),
          GoRoute(
            path: 'create-group-chat',
            name: 'createGroupChat',
            builder: (context, state) {
              final user = refreshNotifier.currentUser;
              final uid = refreshNotifier.authState.uid ?? '';
              return CreateGroupChatScreen(userId: user?.id ?? uid, username: user?.username ?? 'User');
            },
          ),
          GoRoute(
            path: 'chat/:id',
            name: 'chat',
            builder: (context, state) {
              final user = refreshNotifier.currentUser;
              final conversationId = state.pathParameters['id'] ?? '';
              final uid = refreshNotifier.authState.uid ?? '';
              return ChatScreen(conversationId: conversationId, userId: user?.id ?? uid, username: user?.username ?? 'Chat', avatarUrl: user?.avatarUrl);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/rooms',
        name: 'rooms',
        builder: (context, state) => _CustomShell(initialIndex: 2),
        routes: [
          GoRoute(path: 'create', name: 'createRoom', builder: (context, state) => const CreateRoomScreen()),
          GoRoute(path: 'secure-call', name: 'secureCall', builder: (context, state) => const CallScreen()),
          GoRoute(
            path: 'room/:id',
            name: 'liveRoom',
            redirect: (context, state) {
              final previewRoom = state.extra is RoomModel ? state.extra as RoomModel : null;
              final uid = refreshNotifier.authState.uid;
              // Adult room protection: require auth
              if ((previewRoom?.isAdult ?? false) && (uid == null || uid.isEmpty)) {
                return '/auth';
              }
              return null;
            },
            builder: (context, state) {
              final roomId = state.pathParameters['id'] ?? '';
              return LiveRoomScreen(roomId: roomId);
            },
          ),
          GoRoute(path: 'cam', name: 'camPopout', builder: (context, state) => CamPopoutScreen(targetUserId: state.uri.queryParameters['userId'] ?? '')),
        ],
      ),
      GoRoute(
        path: '/speed-dating',
        name: 'speedDating',
        builder: (context, state) => _CustomShell(initialIndex: 3),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        redirect: (context, state) {
          final uid = refreshNotifier.authState.uid;
          if (uid == null || uid.isEmpty) return '/auth';
          if (state.uri.path == '/profile') return '/profile/$uid';
          return null;
        },
        builder: (context, state) => _CustomShell(initialIndex: 4),
        routes: [
          GoRoute(path: ':id', name: 'userProfile', builder: (context, state) => UserProfileScreen(userId: state.pathParameters['id'] ?? '')),
          GoRoute(path: 'edit', name: 'editProfile', builder: (context, state) => EditProfileScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0)),
          GoRoute(path: 'settings', name: 'profileSettings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: 'friends', name: 'profileFriends', builder: (context, state) => const FriendListScreen()),
          GoRoute(path: 'groups', name: 'profileGroups', builder: (context, state) => GroupsScreen(userId: refreshNotifier.authState.uid ?? '')),
          GoRoute(
            path: 'group/:id',
            name: 'groupDetails',
            builder: (context, state) {
              final groupId = state.pathParameters['id'] ?? '';
              if (groupId.isEmpty) return const FeatureDegradedScreen(title: 'Group unavailable', message: 'Could not resolve a group id.', primaryLabel: 'Go home', primaryRoute: '/home', icon: Icons.error_outline);
              return GroupDetailsScreen(groupId: groupId, userId: refreshNotifier.authState.uid ?? '');
            },
          ),
          GoRoute(path: 'create-group', name: 'createGroup', builder: (context, state) => CreateGroupScreen(userId: refreshNotifier.authState.uid ?? '')),
          GoRoute(path: 'manage-top-8', name: 'manageTopEight', builder: (context, state) => const TopEightManagementScreen()),
          GoRoute(path: 'pending-requests', name: 'pendingRequests', builder: (context, state) => const PendingRequestsScreen()),
          GoRoute(path: 'verification', name: 'verification', builder: (context, state) => const VerificationScreen()),
          GoRoute(path: 'account', name: 'account', builder: (context, state) => const AccountCenterScreen()),
          GoRoute(path: 'about', name: 'about', builder: (context, state) => const AppInfoScreen()),
          GoRoute(path: 'legal/terms', name: 'legalTerms', builder: (context, state) => const LegalTermsScreen()),
          GoRoute(path: 'legal/privacy', name: 'legalPrivacy', builder: (context, state) => const LegalPrivacyScreen()),
          GoRoute(
            path: 'payments',
            name: 'payments',
            redirect: (context, state) {
              final uid = refreshNotifier.authState.uid;
              return (uid == null || uid.isEmpty) ? '/auth' : null;
            },
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(path: 'vip', name: 'vip', builder: (context, state) => const VipScreen()),
          GoRoute(
            path: 'admin-entitlements',
            name: 'adminEntitlements',
            redirect: (context, state) {
              if (!refreshNotifier.isAdmin) return '/home';
              return null;
            },
            builder: (context, state) => const AdminEntitlementViewerScreen(),
          ),
          GoRoute(
            path: 'moderation',
            name: 'moderation',
            redirect: (context, state) {
              if (!refreshNotifier.isAdmin) return '/home';
              return null;
            },
            builder: (context, state) => const ModerationDashboardScreen(),
          ),
        ],
      ),

      /// Root level routes
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(path: '/auth', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),

      // After Dark routes
      GoRoute(path: '/after-dark/setup', redirect: (context, state) => '/after-dark/age-gate'),
      GoRoute(
        path: '/after-dark',
        redirect: (context, state) => !refreshNotifier.isAfterDarkSessionActive ? '/after-dark/unlock' : null,
        builder: (context, state) => const AfterDarkShell(child: AfterDarkHomeScreen()),
      ),
      GoRoute(path: '/after-dark/age-gate', builder: (context, state) => const AfterDarkAgeGateScreen()),
      GoRoute(path: '/after-dark/pin-setup', builder: (context, state) => const AfterDarkPinScreen.setup()),
      GoRoute(path: '/after-dark/unlock', builder: (context, state) => const AfterDarkPinScreen.unlock()),
      GoRoute(
        path: '/after-dark/lounges',
        redirect: (context, state) => !refreshNotifier.isAfterDarkSessionActive ? '/after-dark/unlock' : null,
        builder: (context, state) => const AfterDarkShell(child: AfterDarkLoungesScreen()),
      ),
      GoRoute(
        path: '/after-dark/profile',
        redirect: (context, state) => !refreshNotifier.isAfterDarkSessionActive ? '/after-dark/unlock' : null,
        builder: (context, state) => const AfterDarkShell(child: AfterDarkProfileScreen()),
      ),
      GoRoute(
        path: '/after-dark/create-lounge',
        redirect: (context, state) => !refreshNotifier.isAfterDarkSessionActive ? '/after-dark/unlock' : null,
        builder: (context, state) => const AfterDarkShell(child: AfterDarkCreateLoungeScreen()),
      ),

      GoRoute(path: '/beta-feedback', builder: (context, state) => const BetaFeedbackScreen()),

      // Global redirects for deep links and legacy paths
      GoRoute(path: '/live', redirect: (context, state) => '/rooms'),
      GoRoute(path: '/search', redirect: (context, state) => '/home/search'),
      GoRoute(path: '/notifications', redirect: (context, state) => '/home/notifications'),
      GoRoute(path: '/chat/:id', redirect: (context, state) => '/messages/chat/${state.pathParameters['id']}'),
      GoRoute(path: '/room/:id', redirect: (context, state) => '/rooms/room/${state.pathParameters['id']}'),
      GoRoute(path: '/edit-profile', redirect: (context, state) => '/profile/edit'),
      GoRoute(path: '/settings', redirect: (context, state) => '/profile/settings'),
      GoRoute(path: '/friends', redirect: (context, state) => '/profile/friends'),
      GoRoute(path: '/groups', redirect: (context, state) => '/profile/groups'),
    ],
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!refreshNotifier.isReady) {
      refreshNotifier.markReady();
    }
  });

  return router;
});

/// Custom shell implementation using IndexedStack for reliable web navigation
class _CustomShell extends ConsumerWidget {
  const _CustomShell({required this.initialIndex});

  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final currentUser = ref.watch(userProvider);
    final uid = currentUser?.id ?? '';
    final username = currentUser?.username ?? '';

    // Update provider if initialIndex changed (e.g., from deep link or route params)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedIndex != initialIndex) {
        ref.read(selectedTabIndexProvider.notifier).state = initialIndex;
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          const DashboardScreen(),
          MessagesScreen(userId: uid, username: username),
          const RoomBrowserScreen(),
          const SpeedDatingScreen(),
          UserProfileScreen(userId: uid),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Live Rooms'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Dating'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
        onDestinationSelected: (index) {
          // Update provider to switch IndexedStack content
          // Don't call go() - it breaks on Flutter web. Deep linking handled by initial route.
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}


