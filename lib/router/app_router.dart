/// lib/router/app_router.dart
///
/// MixVy centralized router.
/// Registers EVERY screen in the app. Plug into MaterialApp via:
///
///   MaterialApp(
///     initialRoute: AppRoutes.ageGate,
///     onGenerateRoute: AppRouter.onGenerateRoute,
///   )
///
/// Navigation:
///   Navigator.pushNamed(context, AppRoutes.home);
///   Navigator.pushNamed(context, AppRoutes.room, arguments: roomId);
///   Navigator.pushNamed(context, AppRoutes.profile, arguments: userId);
///
/// Note: This file is the authoritative screen registry for routing QA.
/// When you add/rename/remove a screen, update AppRoutes and this file.
library;

export 'package:mixvy/core/routing/app_routes.dart' show AppRoutes;

// ── Route inventory (all mapped screens) ─────────────────────────────────────
// Auth / Onboarding
//   AgeGatePage          → AppRoutes.ageGate        (/age-gate)
//   NeonLoginPage        → AppRoutes.login           (/login)
//   NeonSignupPage       → AppRoutes.signup          (/signup)
//   ForgotPasswordPage   → AppRoutes.forgotPassword  (/forgot-password)
//   LandingPage          → AppRoutes.landing         (/)
//
// Core
//   HomePageElectric     → AppRoutes.home            (/home)
//   DiscoveryPage        → AppRoutes.discovery       (/discovery)
//
// Profile / Social
//   UserProfilePage      → AppRoutes.userProfile     (/profile) + userId arg
//   EditProfilePage      → AppRoutes.editProfile     (/profile/edit)
//   FollowersListPage    → AppRoutes.followers       (/followers)
//   FollowingListPage    → AppRoutes.following       (/following)
//   FriendListPage       → AppRoutes.friends         (/friends)
//                          AppRoutes.friendRequests  (/profile/friend-requests)
//
// Chat / Messaging
//   ChatsListPage        → AppRoutes.chats / chatList  (/chats)
//   ChatConversationPage → AppRoutes.chat              (/chat) + chatId arg
//   MessageRequestsPage  → AppRoutes.messageRequests   (/message-requests)
//
// Rooms / Live
//   RoomsListPage        → AppRoutes.rooms           (/rooms)
//   VoiceRoomPage        → AppRoutes.room            (/room)  + roomId arg
//                          AppRoutes.liveRoom        (/room/live) + roomId arg
//   CreateRoomPageComplete → AppRoutes.createRoom    (/rooms/create)
//
// Settings
//   SettingsPage         → AppRoutes.settings        (/settings)
//   AccountSettingsPage  → AppRoutes.accountSettings (/settings/account)
//   PrivacySettingsPage  → AppRoutes.privacySettings (/settings/privacy)
//   NotificationSettingsPage → AppRoutes.notificationSettings (/settings/notifications)
//   BlockedUsersPage     → AppRoutes.blockedUsers    (/blocked-users)
//
// Notifications
//   NotificationCenterPage → AppRoutes.notifications (/notifications)
//
// Events
//   EventsPage           → AppRoutes.events          (/events)
//   EventDetailsPage     → AppRoutes.eventDetails    (/events/details) + eventId arg
//
// Payments
//   CoinPurchasePage     → AppRoutes.coins           (/coins)
//
// Admin
//   AdminDashboardPage   → AppRoutes.adminDashboard  (/admin/dashboard)
//
// Dev / QA
//   RouteTestPage        → AppRoutes.routeTest       (/dev/routes)
//   ProviderDebugPage    → AppRoutes.providerDebug   (/dev/providers)

