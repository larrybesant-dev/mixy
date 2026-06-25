// lib/core/routing/app_routes.dart
// Centralized route management for MixMingle

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Landing & Auth
import '../../features/landing/landing_page.dart';
import '../../features/auth/screens/age_gate_page.dart';
import '../../features/auth/screens/neon_login_page.dart';
import '../../features/auth/screens/neon_signup_page.dart';
// Removed unused import for forgot_password_page

// Home
import '../../features/home/home_page_electric.dart';

// Rooms
import '../../features/room/screens/rooms_list_page.dart';
import '../../features/room/screens/voice_room_page.dart';
import '../../features/room/providers/room_providers.dart';
import '../../shared/widgets/club_background.dart';

// Chat
import '../../features/chat/screens/chats_list_page.dart';
import '../../features/chat/screens/chat_conversation_page.dart';
import '../../features/chat/screens/message_requests_page.dart';

// Discovery
import '../../features/discovery/discovery_page.dart';

// Profile & Social
import '../../features/profile/screens/following_list_page.dart';
import '../../features/profile/screens/report_user_page.dart';
import '../../features/profile/screens/edit_profile_page.dart';
import '../../features/profile/screens/user_profile_page.dart';
import '../../features/friends/friend_list_page.dart';

// Settings
import '../../features/settings/screens/settings_page.dart';
import '../../features/settings/account_settings_page.dart';
import '../../features/settings/privacy_settings_page.dart';
import '../../features/settings/notification_settings_page.dart';
import '../../features/settings/blocked_users_page.dart';

// Admin
import '../../features/admin/admin_dashboard_page.dart';
import '../../features/admin/super_admin_dashboard_page.dart';
import '../../features/control_center/control_center_dashboard.dart';

// Notifications
import '../../features/notifications/notification_center_page.dart';

// Payments / Coins
import '../../features/payments/screens/coin_purchase_page.dart';

// Events
import '../../features/events/screens/events_page.dart';
import '../../features/events/screens/event_details_page.dart';

// Create Room
import '../../features/room/screens/create_room_page_complete.dart';

// Auth providers (for profile/me route)
import '../../shared/providers/auth_providers.dart';

// Guards
// Removed unused guard imports

// Legal pages
import '../../features/legal/terms_of_service_page.dart';
import '../../features/legal/privacy_policy_page.dart';
import '../../features/settings/agora_test_page.dart';
// Dev / QA screens
import '../../dev/route_test_page.dart';
import '../../dev/provider_debug_page.dart';

// ── New platform features ──────────────────────────────────────────────────────
import '../../features/feed/activity_feed_page.dart';
import '../../features/search/search_page.dart';
import '../../features/stories/stories_viewer_page.dart';
import '../../features/stories/create_story_page.dart';
import '../../features/videos/short_video_feed_page.dart';
import '../../services/social/stories_service.dart';

/// App Routes
class AppRoutes {
  static const String landing             = '/';
  static const String login               = '/login';
  static const String signup              = '/signup';
  static const String forgotPassword      = '/forgot-password';
  static const String ageGate             = '/age-gate';
  static const String onboarding          = '/onboarding';
  static const String app                 = '/app';
  static const String home                = '/home';
  static const String rooms               = '/rooms';
  static const String room                = '/room';
  static const String chats               = '/chats';
  static const String chat                = '/chat';
  static const String editProfile         = '/profile/edit';
  static const String userProfile         = '/profile';
  static const String profile             = '/profile/me';
  static const String profileMedia        = '/profile/media';
  static const String discovery           = '/discovery';
  static const String followers           = '/followers';
  static const String following           = '/following';
  static const String suggested           = '/suggested';
  static const String suggestedUsers      = '/suggested-users';
  static const String trendingUsers       = '/trending-users';
  static const String activeNow           = '/active-now';
  static const String matches             = '/matches';
  static const String matchDiscovery      = '/match/discovery';
  static const String matchPreferences    = '/match/preferences';
  static const String events              = '/events';
  static const String eventDetails        = '/events/details';
  static const String discoverRooms       = '/discover/rooms';
  static const String discoverRoomsLive   = '/discover/rooms/live';
  static const String createRoom          = '/rooms/create';
  static const String notifications       = '/notifications';
  static const String settings            = '/settings';
  static const String settingsRoute       = '/settings';
  static const String accountSettings     = '/settings/account';
  static const String privacySettings     = '/settings/privacy';
  static const String notificationSettings = '/settings/notifications';
  static const String coins               = '/coins';
  static const String membershipUpgrade   = '/membership/upgrade';
  static const String reportUser          = '/report/user';
  static const String blockedUsers        = '/blocked-users';
  static const String adminDashboard      = '/admin/dashboard';
  static const String superAdminDashboard  = '/admin/super';
  static const String controlCenter        = '/control-center';
  static const String friends              = '/friends';
  static const String messageRequests      = '/message-requests';
  // ── New canonical aliases expected by lib/router/app_routes.dart ──────────
  static const String friendRequests       = '/profile/friend-requests';
  static const String chatList             = '/chats';
  static const String messageThread        = '/chat/thread';
  static const String liveRoom             = '/room/live';
  static const String hostTools            = '/room/host-tools';
  // Legal pages
  static const String terms                = '/terms';
  static const String privacy              = '/privacy';
  // Dev / QA routes (hidden screens)
  static const String agoraTest            = '/agora-test';
  static const String routeTest            = '/dev/routes';
  static const String providerDebug        = '/dev/providers';
  // ── New platform features ──────────────────────────────────────────────────
  static const String activityFeed         = '/activity-feed';
  static const String search               = '/search';
  static const String stories              = '/stories';
  static const String createStory          = '/stories/create';
  static const String storyViewer          = '/stories/view';
  static const String shortVideos          = '/reels';
  static const String createShortVideo     = '/reels/create';
  static const String eventDetail          = '/events/detail';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    debugPrint('Navigating to: ${routeSettings.name}');
    return MaterialPageRoute(
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          final authState = ref.watch(authStateProvider);
          final userAsync = ref.watch(currentUserProvider);
          if (authState.isLoading || userAsync.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (authState.hasError || userAsync.hasError) {
            return const Scaffold(body: Center(child: Text('Auth error')));
          }
          final user = userAsync.value;
          if (user == null) {
            return const NeonLoginPage();
          }
          if (user.ageVerified != true) {
            return const AgeGatePage();
          }

          // Routes that don't require profileComplete (profile setup, settings, legal, etc)
          final profileNotRequiredRoutes = {
            createRoom,
            '/create-room',  // Also handle the alternative URL
            profile, editProfile, settings, accountSettings,
            privacySettings, notificationSettings, blockedUsers, userProfile,
            terms, privacy, agoraTest, routeTest, providerDebug, login, signup,
          };

          // Check profileComplete only for routes that require it
          if (user.profileComplete != true && !profileNotRequiredRoutes.contains(routeSettings.name)) {
            return const NeonSignupPage();
          }

          switch (routeSettings.name) {
            case landing:
              return const LandingPage();
            case home:
              return const HomePageElectric();
            case rooms:
              return const RoomsListPage();
            case room:
              final roomId = routeSettings.arguments as String?;
              if (roomId == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('Room ID required')),
                );
              }
              return _RoomLoaderPage(roomId: roomId);
            case chats:
              return const ChatsListPage();
            case chat:
              final chatId = routeSettings.arguments as String?;
              if (chatId == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('Chat ID required')),
                );
              }
              return ChatConversationPage(chatId: chatId);
            case following:
              final userId = routeSettings.arguments as String? ?? '';
              return FollowingListPage(userId: userId);
            case friends:
              return const FriendListPage();
            case reportUser:
              final args = routeSettings.arguments as Map<String, dynamic>?;
              return ReportUserPage(
                userId: args?['userId'] as String? ?? '',
                displayName: args?['displayName'] as String?,
              );
            case messageRequests:
              return const MessageRequestsPage();
            case discovery:
              return const DiscoveryPage();
            case settings:
              return const SettingsPage();
            case accountSettings:
              return const AccountSettingsPage();
            case privacySettings:
              return const PrivacySettingsPage();
            case notificationSettings:
              return const NotificationSettingsPage();
            case blockedUsers:
              return const BlockedUsersPage();
            case adminDashboard:
              return const AdminDashboardPage();
            case superAdminDashboard:
              return const SuperAdminDashboardPage();
            case controlCenter:
              return const ControlCenterDashboard();
            case notifications:
              return const NotificationCenterPage();
            case coins:
              return const CoinPurchasePage();
            case createRoom:
            case '/create-room':
              return const CreateRoomPageComplete();
            case events:
              return const EventsPage();
            case eventDetails:
              final eventId = routeSettings.arguments as String? ?? '';
              return EventDetailsPage(eventId: eventId);
            case profile:
              return const _CurrentUserProfilePage();
            case editProfile:
              return const EditProfilePage();
            case userProfile:
              final userId = routeSettings.arguments as String? ?? '';
              return UserProfilePage(userId: userId);
            case friendRequests:
              return const FriendListPage();
            case liveRoom:
              final liveRoomId = routeSettings.arguments as String? ?? '';
              return _RoomLoaderPage(roomId: liveRoomId);
            case terms:
              return const TermsOfServicePage();
            case privacy:
              return const PrivacyPolicyPage();
            case agoraTest:
              return const AgoraTestPage();
            case routeTest:
              return const RouteTestPage();
            case providerDebug:
              return const ProviderDebugPage();
            case activityFeed:
              return const ActivityFeedPage();
            case search:
              return const SearchPage();
            case createStory:
              return const CreateStoryPage();
            case storyViewer:
              final group = routeSettings.arguments as StoryGroup?;
              if (group == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('Story group required')),
                );
              }
              return StoriesViewerPage(group: group);
            case shortVideos:
              return const ShortVideoFeedPage();
            case eventDetail:
              final eventId = routeSettings.arguments as String? ?? '';
              return EventDetailsPage(eventId: eventId);
            default:
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(child: Text('No route defined for \\${routeSettings.name}')),
              );
          }
        });
      },
    );
  }

  // Removed _errorRoute, replaced with inline Scaffold error handling
}

/// Loads a Room from Firestore by ID then hands off to VoiceRoomPage.
/// Used by the /room route so callers only need to pass arguments: roomId.
class _RoomLoaderPage extends ConsumerWidget {
  final String roomId;
  const _RoomLoaderPage({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomByIdProvider(roomId));
    return roomAsync.when(
      loading: () => const ClubBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Room')),
        body: Center(child: Text('Could not load room: $e')),
      ),
      data: (room) {
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Room')),
            body: const Center(child: Text('Room not found.')),
          );
        }
        return VoiceRoomPage(room: room);
      },
    );
  }
}

/// Redirects /profile/me to the current user's UserProfilePage.
class _CurrentUserProfilePage extends ConsumerWidget {
  const _CurrentUserProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return UserProfilePage(userId: uid);
  }
}
