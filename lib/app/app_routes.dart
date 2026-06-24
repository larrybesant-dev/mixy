import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'auth_gate.dart';
import '../core/guards/profile_guard.dart';
import '../features/home/home_page_electric.dart';
import '../features/auth/screens/neon_login_page.dart';
import '../features/auth/screens/neon_signup_page.dart';
import '../features/auth/screens/neon_splash_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/profile/screens/profile_page.dart';
import '../features/profile/screens/edit_profile_page.dart';
import '../features/profile/screens/user_profile_page.dart';
import '../features/matching/screens/matches_list_page.dart';
import '../features/chat/screens/chat_list_page.dart';
import '../features/chat/screens/chat_page.dart';
import '../features/group_chat/screens/group_chat_room_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/privacy_settings_page.dart';
import '../features/settings/camera_permissions_page.dart';
import '../features/settings/account_settings_page.dart';
import '../features/settings/notification_settings_page.dart';
import '../features/settings/blocked_users_page.dart';
import '../features/legal/privacy_policy_page.dart';
import '../features/legal/terms_of_service_page.dart';
import '../features/reporting/moderation_page.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/events/screens/create_event_page.dart';
import '../features/events/screens/events_list_page.dart';
import '../features/events/screens/event_details_page.dart';
import '../features/events/screens/event_chat_page.dart';
// Speed Dating imports
// TEMP DISABLED: import '../features/speed_dating/screens/speed_dating_lobby_page.dart';
// Social Feed imports
import '../features/feed/social_feed_page.dart';
import '../features/room/screens/room_by_id_page.dart';
import '../features/room/room_access_wrapper.dart';
import '../features/discover/room_discovery_page.dart';
import '../features/discover/room_discovery_page_complete.dart';
import '../features/room/screens/create_room_page_complete.dart';
import '../features/room/screens/go_live_page.dart';
import '../features/payments/screens/coin_purchase_page.dart';
import '../features/payments/screens/wallet_page.dart';
import '../features/withdrawal/withdrawal_page.dart';
import '../features/withdrawal/withdrawal_history_page.dart';
import '../features/messages/messages_page.dart';
import '../features/leaderboards/leaderboards_page.dart';
import '../features/achievements/achievements_page.dart';
import '../features/admin/admin_dashboard_page.dart';
import '../core/guards/admin_guard.dart';
import '../features/discover/screens/discover_users_page.dart';
import '../features/matching/screens/match_preferences_page.dart';
import '../features/landing/landing_page.dart';
import '../features/profile/screens/create_profile_page.dart';
import '../features/profile/screens/friend_requests_page.dart';
import '../features/speed_dating/screens/speed_dating_matches_inbox.dart';
import '../features/speed_dating/screens/speed_dating_lobby_screen.dart';
import '../features/match_inbox/screens/match_inbox_page.dart';
import '../features/onboarding_flow.dart';
import '../features/onboarding/post_auth_onboarding.dart';
import '../features/error/error_page.dart';
import '../features/debug/screens/test_video_engine_screen.dart';
import '../features/video_room/screens/video_chat_page.dart';
import '../shared/models/room.dart';
import '../features/debug/health_dashboard.dart';

/// Slide transition directions
enum SlideDirection {
  left,
  right,
  up,
  down,
}

class AppRoutes {
  // Public routes (no auth required)
  static const splash = '/';
  static const landing = '/landing';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const error = '/error';

  // Protected routes (auth required)
  static const home = '/home';
  static const createProfile = '/create-profile';
  static const onboarding = '/onboarding';
  static const onboardingWelcome = '/onboarding/welcome';
  static const onboardingPermissions = '/onboarding/permissions';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingAgeVerification = '/onboarding/age-verification';
  static const onboardingTutorial = '/onboarding/tutorial';

  // Profile routes
  static const profile = '/profile';
  static const userProfile = '/profile/user';
  static const editProfile = '/profile/edit';
  static const friendRequests = '/friend-requests';
  static const speedDatingMatches = '/speed-dating/matches';

  // Match Inbox
  static const matchInbox = '/match-inbox';

  // Matching routes
  static const matches = '/matches';
  static const discoverUsers = '/discover-users';
  static const matchPreferences = '/match-preferences';

  // Chat routes
  static const chats = '/chats';
  static const chat = '/chat';
  static const groupChatRoom = '/group-chat-room';
  static const messages = '/messages';

  // Video Chat routes (new modern features)
  static const videoChat = '/video-chat';

  // Speed Dating routes
  static const speedDatingLobby = '/speed-dating/lobby';

  // Social Feed routes
  static const feed = '/feed';

  // Events routes (require event guard for details)
  static const events = '/events';
  static const eventDetails = '/events/details';
  static const createEvent = '/events/create';
  static const eventChat = '/event-chat';

  // Room routes
  static const room = '/room';
  static const browseRooms = '/browse-rooms';
  static const discoverRooms = '/discover-rooms';
  static const createRoom = '/create-room';
  static const goLive = '/go-live';

  // Settings routes
  static const settings = '/settings';
  static const privacySettings = '/settings/privacy';
  static const cameraPermissions = '/settings/camera-permissions';
  static const accountSettings = '/settings/account';
  static const notificationSettings = '/settings/notifications';
  static const blockedUsers = '/settings/blocked-users';

  // Legal routes
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';

  // Notifications
  static const notifications = '/notifications';
  static const notificationCenter = '/notifications/center';

  // Gamification routes
  static const leaderboards = '/leaderboards';
  static const achievements = '/achievements';

  // Payment routes
  static const wallet = '/wallet';
  static const buyCoins = '/buy-coins';
  static const withdrawal = '/withdrawal';
  static const withdrawalHistory = '/withdrawal-history';

  // Admin routes
  static const adminDashboard = '/admin';
  static const moderation = '/admin/moderation';

  // Test/Debug routes
  static const testVideo = '/test-video';
  static const healthDashboard = '/health-dashboard';

  // Deep link paths
  static const deepLinkEventPrefix = '/e/';
  static const deepLinkRoomPrefix = '/r/';
  static const deepLinkProfilePrefix = '/u/';
  // DISABLED FOR V1 - Speed Dating deep link
  // static const deepLinkSpeedDatingPrefix = '/sd/';

  // Animation configurations
  static const Duration transitionDuration = Duration(milliseconds: 300);
  static const Curve transitionCurve = Curves.easeInOutCubic;

  /// Parse deep link URI and return route name with arguments
  static Map<String, dynamic>? parseDeepLink(Uri uri) {
    final path = uri.path;

    // Event deep link: /e/{eventId}
    if (path.startsWith(deepLinkEventPrefix)) {
      final eventId = path.substring(deepLinkEventPrefix.length);
      return {
        'route': eventDetails,
        'arguments': {'eventId': eventId},
      };
    }

    // Room deep link: /r/{roomId}
    if (path.startsWith(deepLinkRoomPrefix)) {
      final roomId = path.substring(deepLinkRoomPrefix.length);
      return {
        'route': room,
        'arguments': {'roomId': roomId},
      };
    }

    // Profile deep link: /u/{userId}
    if (path.startsWith(deepLinkProfilePrefix)) {
      final userId = path.substring(deepLinkProfilePrefix.length);
      return {
        'route': userProfile,
        'arguments': {'userId': userId},
      };
    }

    // DISABLED FOR V1 - Speed Dating deep link
    // if (path.startsWith(deepLinkSpeedDatingPrefix)) {
    //   return {
    //     'route': speedDatingLobby,
    //     'arguments': {},
    //   };
    // }

    return null;
  }

  /// Extract query parameters from route settings.
  /// Supports both `Map<String, dynamic>` and a plain String (treated as roomId).
  static Map<String, dynamic> extractQueryParams(RouteSettings settings) {
    if (settings.arguments is Map<String, dynamic>) {
      return settings.arguments as Map<String, dynamic>;
    }
    // Many call-sites pass: Navigator.pushNamed(context, '/room', arguments: room.id)
    // Treat a bare String as the roomId so /room navigation always works.
    if (settings.arguments is String) {
      final id = settings.arguments as String;
      if (id.isNotEmpty) return {'roomId': id};
    }
    return {};
  }

  /// Create slide transition route
  static Route<T> _createSlideRoute<T>({
    required Widget page,
    RouteSettings? settings,
    SlideDirection direction = SlideDirection.left,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;
        switch (direction) {
          case SlideDirection.left:
            begin = const Offset(1.0, 0.0);
            break;
          case SlideDirection.right:
            begin = const Offset(-1.0, 0.0);
            break;
          case SlideDirection.up:
            begin = const Offset(0.0, 1.0);
            break;
          case SlideDirection.down:
            begin = const Offset(0.0, -1.0);
            break;
        }

        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: transitionCurve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Create fade transition route
  static Route<T> _createFadeRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Create scale transition route
  static Route<T> _createScaleRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: transitionCurve),
        );

        return ScaleTransition(
          scale: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final queryParams = extractQueryParams(settings);

    switch (settings.name) {
      // ========== Public Routes ==========
      case splash:
        return _createFadeRoute(
          page: const NeonSplashPage(),
          settings: settings,
        );

      case landing:
        return _createSlideRoute(
          page: const LandingPage(),
          settings: settings,
          direction: SlideDirection.left,
        );

      case login:
        return _createSlideRoute(
          page: const NeonLoginPage(),
          settings: settings,
          direction: SlideDirection.up,
        );

      case signup:
        return _createSlideRoute(
          page: const NeonSignupPage(),
          settings: settings,
          direction: SlideDirection.up,
        );

      case forgotPassword:
        return _createFadeRoute(
          page: const ForgotPasswordPage(),
          settings: settings,
        );

      case error:
        final message =
            queryParams['message'] as String? ?? 'An error occurred';
        return _createFadeRoute(
          page: ErrorPage(errorMessage: message),
          settings: settings,
        );

      // ========== Protected Routes with Auth Guard ==========
      case home:
        return _createFadeRoute(
          page: const AuthGate(child: HomePageElectric()),
          settings: settings,
        );

      case createProfile:
        return _createSlideRoute(
          page: const AuthGate(child: CreateProfilePage()),
          settings: settings,
          direction: SlideDirection.up,
        );

      case onboarding:
        return _createSlideRoute(
          page: const OnboardingFlow(),
          settings: settings,
          direction: SlideDirection.up,
        );

      // Post-auth onboarding sub-routes (all render the same full flow)
      case onboardingWelcome:
      case onboardingPermissions:
      case onboardingProfile:
      case onboardingAgeVerification:
      case onboardingTutorial:
        return _createFadeRoute(
          page: const AuthGate(child: PostAuthOnboarding()),
          settings: settings,
        );

      // ========== Profile Routes ==========
      case profile:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: ProfilePage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case userProfile:
        final userId = queryParams['userId'] as String?;
        if (userId == null) {
          return _createFadeRoute(
            page: const ErrorPage(errorMessage: 'User ID is required'),
            settings: settings,
          );
        }
        return _createSlideRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: UserProfilePage(userId: userId),
            ),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case editProfile:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: EditProfilePage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case friendRequests:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: FriendRequestsPage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case speedDatingMatches:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: SpeedDatingMatchesInbox()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case matchInbox:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: MatchInboxPage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      // ========== Matching Routes ==========
      case matches:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: MatchesPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case discoverUsers:
        return _createFadeRoute(
          page: const AuthGate(
            child: ProfileGuard(child: DiscoverUsersPage()),
          ),
          settings: settings,
        );

      case matchPreferences:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: MatchPreferencesPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Chat Routes ==========
      case chats:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: ChatListPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case chat:
        final chatId = queryParams['chatId'] as String?;
        final userId = queryParams['userId'] as String?;

        if (chatId == null && userId == null) {
          return _createFadeRoute(
            page:
                const ErrorPage(errorMessage: 'Chat ID or User ID is required'),
            settings: settings,
          );
        }

        return _createSlideRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: ChatPage(
                chatId: chatId,
                userId: userId,
              ),
            ),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case groupChatRoom:
        final roomId = queryParams['roomId'] as String?;

        if (roomId == null) {
          return _createFadeRoute(
            page: const ErrorPage(errorMessage: 'Room ID is required'),
            settings: settings,
          );
        }

        return _createSlideRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: GroupChatRoomPage(roomId: roomId),
            ),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case messages:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: MessagesPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case videoChat:
        return _createFadeRoute(
          page: const AuthGate(
            child: ProfileGuard(child: VideoChatPage()),
          ),
          settings: settings,
        );

      // Speed Dating Routes
      case speedDatingLobby:
        return _createScaleRoute(
          page: const AuthGate(
            child: ProfileGuard(
              child: SpeedDatingLobbyScreen(),
            ),
          ),
          settings: settings,
        );

      // Social Feed Route
      case feed:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: SocialFeedPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Events Routes ==========
      case events:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: EventsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case eventDetails:
        final eventId = queryParams['eventId'] as String?;

        if (eventId == null) {
          return _createFadeRoute(
            page: const ErrorPage(errorMessage: 'Event ID is required'),
            settings: settings,
          );
        }

        return _createSlideRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: EventDetailsPage(eventId: eventId),
            ),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case createEvent:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: CreateEventPage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case eventChat:
        final eventId = queryParams['eventId'] as String?;
        final eventTitle = queryParams['eventTitle'] as String?;

        if (eventId == null) {
          return _createFadeRoute(
            page: const ErrorPage(errorMessage: 'Event ID is required'),
            settings: settings,
          );
        }

        return _createSlideRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: EventChatPage(
                eventId: eventId,
                eventTitle: eventTitle ?? 'Event Chat',
              ),
            ),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Room Routes ==========
      case room:
        final roomId = queryParams['roomId'] as String?;
        final room = queryParams['room'] as Room?;

        // âœ… SECURITY FIX: Ensure at least one of roomId or room is provided
        if (roomId == null && room == null) {
          return _createFadeRoute(
            page: const ErrorPage(
                errorMessage: 'Room ID or Room object is required'),
            settings: settings,
          );
        }

        // At this point, we're guaranteed that either room or roomId is non-null
        return _createScaleRoute(
          page: AuthGate(
            child: ProfileGuard(
              child: room != null
                  ? RoomAccessWrapper(
                      room: room,
                      userId:
                          fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '',
                    )
                  : (roomId != null
                      ? RoomByIdPage(roomId: roomId)
                      : const ErrorPage(errorMessage: 'Room ID required')),
            ),
          ),
          settings: settings,
        );

      case browseRooms:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: RoomDiscoveryPageComplete()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case discoverRooms:
        return _createFadeRoute(
          page: const AuthGate(
            child: RoomDiscoveryPage(),
          ),
          settings: settings,
        );

      case createRoom:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: CreateRoomPageComplete()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case goLive:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: CreateRoomPage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      // ========== Settings Routes ==========
      case AppRoutes.settings:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: SettingsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case privacySettings:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: PrivacySettingsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case accountSettings:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: AccountSettingsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case notificationSettings:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: NotificationSettingsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case blockedUsers:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: BlockedUsersPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case cameraPermissions:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: CameraPermissionsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // Legal routes
      case privacyPolicy:
        return _createSlideRoute(
          page: const PrivacyPolicyPage(),
          settings: settings,
          direction: SlideDirection.left,
        );

      case termsOfService:
        return _createSlideRoute(
          page: const TermsOfServicePage(),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Notification Routes ==========
      case notifications:
        return _createSlideRoute(
          page: const AuthGate(
            // NotificationsPage had Stream.value([]) — use the real Firestore-backed center instead
            child: ProfileGuard(child: NotificationCenterPage()),
          ),
          settings: settings,
          direction: SlideDirection.down,
        );

      case notificationCenter:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: NotificationCenterPage()),
          ),
          settings: settings,
          direction: SlideDirection.down,
        );

      // ========== Gamification Routes ==========
      case leaderboards:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: LeaderboardsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case achievements:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: AchievementsPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Payment Routes ==========
      case wallet:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: WalletPage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case buyCoins:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: CoinPurchasePage()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case withdrawal:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: WithdrawalPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case withdrawalHistory:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: WithdrawalHistoryPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Admin Routes ==========
      case adminDashboard:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(
              child: AdminGuard(child: AdminDashboardPage()),
            ),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      case moderation:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: ModerationPage()),
          ),
          settings: settings,
          direction: SlideDirection.left,
        );

      // ========== Test/Debug Routes ==========
      case testVideo:
        return _createSlideRoute(
          page: const AuthGate(
            child: ProfileGuard(child: TestVideoEngineScreen()),
          ),
          settings: settings,
          direction: SlideDirection.up,
        );

      case healthDashboard:
        final agoraAppId = queryParams['agoraAppId'] as String?;
        return _createSlideRoute(
          page: HealthDashboard(agoraAppId: agoraAppId),
          settings: settings,
          direction: SlideDirection.up,
        );

      // ========== Default/404 Route ==========
      default:
        return _createFadeRoute(
          page: ErrorPage(
            errorMessage: 'Route not found: ${settings.name}',
          ),
          settings: settings,
        );
    }
  }
}
