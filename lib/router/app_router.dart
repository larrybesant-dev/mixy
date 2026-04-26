import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/core/services/first_run_service.dart';
import 'package:mixvy/core/services/profile_gate_service.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';
import 'package:mixvy/features/splash/splash_screen.dart';
import 'package:mixvy/features/profile/user_profile_screen.dart';
import 'package:mixvy/features/social/screens/explore_screen.dart';
import 'package:mixvy/features/social/screens/live_floor_screen.dart';
import 'package:mixvy/features/feed/screens/discovery_feed_screen.dart';
import 'package:mixvy/features/social/screens/social_circle_screen.dart';
import 'package:mixvy/presentation/screens/live_room_screen.dart';
import 'package:mixvy/presentation/screens/notifications_screen.dart';
import 'package:mixvy/presentation/screens/settings_screen.dart';
import 'package:mixvy/presentation/screens/account_center_screen.dart';
import 'package:mixvy/presentation/screens/legal_terms_screen.dart';
import 'package:mixvy/presentation/screens/legal_privacy_screen.dart';
import 'package:mixvy/presentation/screens/app_info_screen.dart';
import 'package:mixvy/presentation/screens/moderation_dashboard_screen.dart';
import 'package:mixvy/features/beta/beta_feedback_screen.dart';
import 'package:mixvy/features/beta/beta_tester_provider.dart';
import 'package:mixvy/features/speed_dating/screens/speed_dating_screen.dart';
import 'package:mixvy/core/services/app_settings_service.dart';
import 'package:mixvy/core/services/feature_gate_service.dart';
import 'package:mixvy/features/search/screens/search_screen.dart';
import 'package:mixvy/features/bookmarks/screens/bookmarks_screen.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/features/follow/screens/follow_screens.dart';
import 'package:mixvy/features/posts/screens/create_post_screen.dart';
import 'package:mixvy/features/posts/screens/post_comments_screen.dart';
import 'package:mixvy/features/stories/screens/create_story_screen.dart';
import 'package:mixvy/features/stories/screens/story_viewer_screen.dart';
import 'package:mixvy/features/groups/screens/groups_screen.dart';
import 'package:mixvy/features/groups/screens/create_group_screen.dart';
import 'package:mixvy/features/groups/screens/group_details_screen.dart';
import 'package:mixvy/features/trending/screens/trending_screen.dart';
import 'package:mixvy/presentation/screens/not_found_screen.dart';
import '../features/messaging/screens/whisper_popout_screen.dart';
import '../features/room/screens/cam_popout_screen.dart';
import '../features/feed/screens/room_browser_screen.dart';
import '../features/verification/screens/verification_screen.dart';
import '../features/room/screens/create_room_screen.dart';
import '../features/after_dark/screens/after_dark_age_gate_screen.dart';
import '../features/after_dark/screens/after_dark_pin_screen.dart';
import '../features/after_dark/screens/after_dark_home_screen.dart';
import '../features/after_dark/screens/after_dark_lounges_screen.dart';
import '../features/after_dark/screens/after_dark_profile_screen.dart';
import '../features/after_dark/screens/after_dark_create_lounge_screen.dart';
import '../features/after_dark/widgets/after_dark_shell.dart';

import '../shared/widgets/app_shell.dart';
import '../shared/widgets/messenger_shell_route.dart';
import 'package:mixvy/features/auth/screens/login_screen.dart';
import 'package:mixvy/features/auth/screens/forgot_password_screen.dart';
import 'package:mixvy/features/auth/providers/admin_provider.dart';
import '../features/auth/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/payments/vip_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

const bool _debugRtcEntryEnabled = bool.fromEnvironment(
  'MIXVY_DEBUG_RTC_ENTRY',
  defaultValue: false,
);

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.loadedAt});

  final T value;
  final DateTime loadedAt;
}

class _RouterGateCache {
  static const Duration _profileTtl = Duration(seconds: 20);

  final Map<String, _CacheEntry<bool>> _profileByUid =
      <String, _CacheEntry<bool>>{};
  final Map<String, Future<bool>> _inFlightProfileChecks =
      <String, Future<bool>>{};

  Future<bool> isFirstRun() async {
    // Do not cache here: FirstRunService already caches internally and updates
    // its cache when onboarding is marked as seen.
    return FirstRunService.isFirstRun();
  }

  Future<bool> isProfileComplete(String uid) async {
    final now = DateTime.now();
    final cached = _profileByUid[uid];
    if (cached != null && now.difference(cached.loadedAt) < _profileTtl) {
      return cached.value;
    }

    final inFlight = _inFlightProfileChecks[uid];
    if (inFlight != null) {
      return inFlight;
    }

    final future = ProfileGateService.isProfileComplete(uid)
        .then((isComplete) {
          _profileByUid[uid] = _CacheEntry<bool>(
            value: isComplete,
            loadedAt: DateTime.now(),
          );
          _inFlightProfileChecks.remove(uid);
          return isComplete;
        })
        .catchError((error) {
          _inFlightProfileChecks.remove(uid);
          throw error;
        });

    _inFlightProfileChecks[uid] = future;
    return future;
  }
}

final _routerGateCacheProvider = Provider<_RouterGateCache>((ref) {
  return _RouterGateCache();
});

typedef FirstRunCheck = Future<bool> Function();
typedef ProfileCompleteCheck = Future<bool> Function(String uid);
typedef LegalAcceptedCheck = Future<bool> Function();

String? _pathParamOrNull(GoRouterState state, String key) {
  final value = state.pathParameters[key];
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value;
}

String? _currentUid(Ref ref) {
  return ref.read(userProvider)?.id ??
      FirebaseAuth.instance.currentUser?.uid ??
      ref.read(authControllerProvider).uid;
}

String _currentUsername(Ref ref) {
  return ref.read(userProvider)?.username ?? 'MixVy User';
}

String? _currentAvatarUrl(Ref ref) {
  return ref.read(userProvider)?.avatarUrl ??
      FirebaseAuth.instance.currentUser?.photoURL;
}

int _appShellIndexForLocation(String matchedLocation) {
  // Dynamic routes must be checked before the switch — GoRouter resolves
  // path parameters so the matched location will be e.g. '/messages/abc123',
  // not the template '/messages/:conversationId'.
  if (matchedLocation.startsWith('/messages/')) return 2;
  if (matchedLocation.startsWith('/profile/')) return 4;
  if (matchedLocation.startsWith('/group/')) return 3;
  if (matchedLocation.startsWith('/followers/')) return 3;
  if (matchedLocation.startsWith('/following/')) return 3;
  if (matchedLocation.startsWith('/stories/')) return 0;

  switch (matchedLocation) {
    case '/':
    case '/dashboard':
    case '/discover':
    case '/explore':
    case '/search':
    case '/trending':
      return 0;
    case '/live':
    case '/rooms':
    case '/create-room':
    case '/speed-dating':
      return 1;
    case '/messages':
    case '/messages/new':
      return 2;
    case '/social':
    case '/friends':
    case '/groups':
    case '/create-group':
      return 3;
    case '/profile':
    case '/edit-profile':
    case '/bookmarks':
    case '/notifications':
    case '/settings':
    case '/verification':
    case '/account':
    case '/about':
    case '/payments':
    case '/vip':
      return 4;
    default:
      return 0;
  }
}

final firstRunCheckProvider = Provider<FirstRunCheck>((ref) {
  final gateCache = ref.read(_routerGateCacheProvider);
  return () => gateCache.isFirstRun();
});

final profileCompleteCheckProvider = Provider<ProfileCompleteCheck>((ref) {
  final gateCache = ref.read(_routerGateCacheProvider);
  return (uid) => gateCache.isProfileComplete(uid);
});

final legalAcceptedCheckProvider = Provider<LegalAcceptedCheck>((ref) {
  final service = AppSettingsService();
  return () => service.hasAcceptedCurrentLegal();
});

/// Returns true for routes that are safe to deep-link back to after auth.
/// Excludes auth, legal, onboarding, and splash routes.
bool _isPreservableDeepLink(String path) {
  if (path.isEmpty || path == '/' || path == '/splash') return false;
  const blocked = [
    '/login', '/register', '/onboarding', '/404',
  ];
  if (blocked.contains(path)) return false;
  if (path.startsWith('/legal/') || path.startsWith('/after-dark')) {
    return false;
  }
  return true;
}

bool _isLiveRoomsEntryRoute(String path) {
  return path == '/live' ||
      path == '/rooms' ||
      path == '/create-room' ||
      path == '/speed-dating' ||
      path.startsWith('/room/');
}

bool _isMessagingEntryRoute(String path) {
  return path == '/messages' ||
      path == '/messages/new' ||
      path == '/friends' ||
      path == '/whisper' ||
      path.startsWith('/messages/');
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
  // Optional: the decoded value of the 'from' query param carried through splash.
  // Set by the router redirect when the user landed on /splash?from=...
  String? redirectFrom,
}) async {
  developer.log(
    'redirect check location=$matchedLocation uid=${uid ?? 'null'} authLoading=$authLoading debugRtcEntry=$_debugRtcEntryEnabled redirectFrom=${redirectFrom ?? 'null'}',
    name: 'AppRouter',
  );

  if (isRouteError || matchedLocation == '/404') {
    developer.log(
      'redirect decision from=$matchedLocation to=stay reason=route_error_or_404',
      name: 'AppRouter',
    );
    return null;
  }

  if (!enableLiveRooms && _isLiveRoomsEntryRoute(matchedLocation)) {
    developer.log(
      'redirect decision from=$matchedLocation to=/discover reason=live_rooms_disabled',
      name: 'AppRouter',
    );
    return '/discover';
  }

  if (!enableMessaging && _isMessagingEntryRoute(matchedLocation)) {
    developer.log(
      'redirect decision from=$matchedLocation to=/social reason=messaging_disabled',
      name: 'AppRouter',
    );
    return '/social';
  }

  // Let After Dark handle its own guard (age-gate + PIN redirect).
  if (matchedLocation.startsWith('/after-dark')) {
    developer.log(
      'redirect decision from=$matchedLocation to=stay reason=after_dark_self_guarded',
      name: 'AppRouter',
    );
    return null;
  }

  if (authLoading) {
    if (matchedLocation == '/splash') {
      developer.log(
        'redirect decision from=$matchedLocation to=stay reason=auth_loading_hold',
        name: 'AppRouter',
      );
      return null;
    }
    // Preserve the intended deep link through the auth-loading pause so that
    // a web refresh on e.g. /room/abc123 comes back to that room once auth
    // resolves, rather than silently dropping the user at /discover.
    final encodedFrom = _isPreservableDeepLink(matchedLocation)
        ? '?from=${Uri.encodeComponent(matchedLocation)}'
        : '';
    final target = '/splash$encodedFrom';
    developer.log(
      'redirect decision from=$matchedLocation to=$target reason=auth_loading_redirect',
      name: 'AppRouter',
    );
    return target;
  }

  final loggedIn = uid != null;
  final isSplash = matchedLocation == '/splash';
  final isRtcRoute =
      matchedLocation == '/live' || matchedLocation.startsWith('/room/');

  if (kDebugMode && _debugRtcEntryEnabled && isSplash) {
    developer.log(
      'Debug entry override active -> /room/debug-rtc',
      name: 'AppRouter',
    );
    developer.log(
      'redirect decision from=$matchedLocation to=/room/debug-rtc reason=debug_rtc_entry_override',
      name: 'AppRouter',
    );
    return '/room/debug-rtc';
  }

  final isLoggingIn =
      matchedLocation == '/login' || matchedLocation == '/register';
  final isOnboarding = matchedLocation == '/onboarding';
  final isLegalRoute = matchedLocation.startsWith('/legal/');
  final isProfile = matchedLocation == '/profile';
  final firstRun = await isFirstRun();

  if (firstRun && !isOnboarding && !isLegalRoute) {
    developer.log(
      'redirect decision from=$matchedLocation to=/onboarding reason=first_run',
      name: 'AppRouter',
    );
    return '/onboarding';
  }
  if (!firstRun && isOnboarding) {
    final target = loggedIn ? '/discover' : '/login';
    developer.log(
      'redirect decision from=$matchedLocation to=$target reason=onboarding_already_seen',
      name: 'AppRouter',
    );
    return target;
  }

  final legalAccepted = await isLegalAccepted();
  if (!legalAccepted && !isOnboarding && !isLegalRoute) {
    developer.log(
      'redirect decision from=$matchedLocation to=/legal/terms reason=legal_not_accepted',
      name: 'AppRouter',
    );
    return '/legal/terms';
  }

  if (!loggedIn && !isLoggingIn && !isLegalRoute) {
    if (kDebugMode && isRtcRoute) {
      developer.log(
        'Debug bypass: allowing signed-out access to $matchedLocation for RTC validation.',
        name: 'AppRouter',
      );
      developer.log(
        'redirect decision from=$matchedLocation to=stay reason=debug_signed_out_rtc_bypass',
        name: 'AppRouter',
      );
      return null;
    }
    developer.log(
      'redirect decision from=$matchedLocation to=/login reason=signed_out_guard',
      name: 'AppRouter',
    );
    return '/login';
  }
  if (loggedIn) {
    final profileComplete = await isProfileComplete(uid);
    if (!profileComplete && !isProfile) {
      if (kDebugMode && isRtcRoute) {
        developer.log(
          'Debug bypass: skipping profile gate for $matchedLocation during RTC validation.',
          name: 'AppRouter',
        );
        developer.log(
          'redirect decision from=$matchedLocation to=stay reason=debug_profile_gate_bypass',
          name: 'AppRouter',
        );
      } else {
        developer.log(
          'redirect decision from=$matchedLocation to=/profile reason=profile_incomplete',
          name: 'AppRouter',
        );
        return '/profile';
      }
    }
    if (profileComplete && (isLoggingIn || isSplash)) {
      // If auth resolved while we were holding a deep-link destination,
      // go there directly instead of /discover.
      if (isSplash &&
          redirectFrom != null &&
          redirectFrom.isNotEmpty &&
          _isPreservableDeepLink(redirectFrom)) {
        developer.log(
          'redirect decision from=$matchedLocation to=$redirectFrom reason=restore_deeplink',
          name: 'AppRouter',
        );
        return redirectFrom;
      }
      developer.log(
        'redirect decision from=$matchedLocation to=/discover reason=post_auth_default',
        name: 'AppRouter',
      );
      return '/discover';
    }
  }
  if (!loggedIn && isSplash) {
    developer.log(
      'redirect decision from=$matchedLocation to=/login reason=splash_signed_out',
      name: 'AppRouter',
    );
    return '/login';
  }
  developer.log(
    'redirect decision from=$matchedLocation to=stay reason=no_redirect',
    name: 'AppRouter',
  );
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final featureGates = ref.watch(featureGateControllerProvider);
  final firstRunCheck = ref.read(firstRunCheckProvider);
  final profileCompleteCheck = ref.read(profileCompleteCheckProvider);
  final legalAcceptedCheck = ref.read(legalAcceptedCheckProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (context, state) =>
        NotFoundScreen(path: state.uri.toString()),
    redirect: (context, state) async {
      try {
        return evaluateAppRedirect(
          matchedLocation: state.matchedLocation,
          uid: authState.uid,
          authLoading: !authState.hasResolvedSession,
          isFirstRun: firstRunCheck,
          isProfileComplete: profileCompleteCheck,
          isLegalAccepted: legalAcceptedCheck,
          enableLiveRooms: featureGates.enableLiveRooms,
          enableMessaging: featureGates.enableMessaging,
          isRouteError: state.error != null,
          redirectFrom: state.uri.queryParameters['from'],
        );
      } catch (error, stackTrace) {
        developer.log(
          'Router redirect failed for ${state.matchedLocation}',
          name: 'AppRouter',
          error: error,
          stackTrace: stackTrace,
        );
        return null;
      }
    },
    routes: [
      // ── Auth / legal / onboarding — no shell ───────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
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
        path: '/404',
        builder: (context, state) => NotFoundScreen(path: state.uri.toString()),
      ),
      // ── Full-screen overlays — bypass shell ────────────────────────────
      GoRoute(
        path: '/room/:roomId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final roomId = _pathParamOrNull(state, 'roomId');
          if (roomId == null) {
            return NotFoundScreen(path: state.uri.toString());
          }
          return LiveRoomScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/whisper',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          if (userId.isEmpty) return NotFoundScreen(path: state.uri.toString());
          return WhisperPopoutScreen(targetUserId: userId);
        },
      ),
      GoRoute(
        path: '/cam',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          if (userId.isEmpty) return NotFoundScreen(path: state.uri.toString());
          return CamPopoutScreen(targetUserId: userId);
        },
      ),
      // ── Shell — persistent bottom nav + drawer on every page ───────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(
          selectedIndex: _appShellIndexForLocation(state.matchedLocation),
          useDesktopMessengerLayout: MessengerRouteState.matches(state),
          child: child,
        ),
        routes: [
          GoRoute(path: '/', redirect: (context, state) => '/discover'),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoveryFeedScreen(),
          ),
          GoRoute(
            path: '/live',
            builder: (context, state) => const LiveFloorScreen(),
          ),
          GoRoute(
            path: '/explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialCircleScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return const ProfileScreen();
              return UserProfileScreen(userId: uid);
            },
          ),
          GoRoute(
            path: '/edit-profile',
            builder: (context, state) {
              final tab =
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
              return EditProfileScreen(initialTab: tab);
            },
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) {
              final userId = _pathParamOrNull(state, 'userId');
              if (userId == null) {
                return NotFoundScreen(path: state.uri.toString());
              }
              return UserProfileScreen(userId: userId);
            },
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(path: '/vip', builder: (context, state) => const VipScreen()),
          GoRoute(
            path: '/speed-dating',
            builder: (context, state) => const SpeedDatingScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
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
            path: '/moderation',
            builder: (context, state) {
              final isAdmin =
                  ref.read(isAdminProvider).valueOrNull ?? false;
              if (!isAdmin) {
                return NotFoundScreen(path: state.uri.toString());
              }
              return const ModerationDashboardScreen();
            },
          ),
          GoRoute(
            path: '/beta-feedback',
            builder: (context, state) {
              final isBeta =
                  ref.read(isBetaTesterProvider).valueOrNull ?? false;
              if (!isBeta) return NotFoundScreen(path: state.uri.toString());
              return const BetaFeedbackScreen();
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/bookmarks',
            builder: (context, state) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return BookmarksScreen(userId: uid);
            },
          ),
          ShellRoute(
            builder: (context, state, child) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return MessengerShellRouteView(
                routeState: MessengerRouteState.fromGoRouterState(state),
                userId: uid,
                username: _currentUsername(ref),
                avatarUrl: _currentAvatarUrl(ref),
                child: child,
              );
            },
            routes: [
              GoRoute(
                path: '/friends',
                builder: (context, state) => buildMessengerRouteChild(
                  routeState: MessengerRouteState.fromGoRouterState(state),
                  userId: _currentUid(ref) ?? '',
                  username: _currentUsername(ref),
                  avatarUrl: _currentAvatarUrl(ref),
                ),
              ),
              GoRoute(
                path: '/messages',
                builder: (context, state) => buildMessengerRouteChild(
                  routeState: MessengerRouteState.fromGoRouterState(state),
                  userId: _currentUid(ref) ?? '',
                  username: _currentUsername(ref),
                  avatarUrl: _currentAvatarUrl(ref),
                ),
              ),
              GoRoute(
                path: '/messages/new',
                builder: (context, state) => buildMessengerRouteChild(
                  routeState: MessengerRouteState.fromGoRouterState(state),
                  userId: _currentUid(ref) ?? '',
                  username: _currentUsername(ref),
                  avatarUrl: _currentAvatarUrl(ref),
                ),
              ),
              GoRoute(
                path: '/messages/:conversationId',
                builder: (context, state) {
                  final conversationId = _pathParamOrNull(
                    state,
                    'conversationId',
                  );
                  if (conversationId == null) {
                    return NotFoundScreen(path: state.uri.toString());
                  }
                  return buildMessengerRouteChild(
                    routeState: MessengerRouteState.fromGoRouterState(state),
                    userId: _currentUid(ref) ?? '',
                    username: _currentUsername(ref),
                    avatarUrl: _currentAvatarUrl(ref),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/followers/:userId',
            builder: (context, state) {
              final userId = _pathParamOrNull(state, 'userId');
              if (userId == null) {
                return NotFoundScreen(path: state.uri.toString());
              }
              return FollowersScreen(userId: userId);
            },
          ),
          GoRoute(
            path: '/following/:userId',
            builder: (context, state) {
              final userId = _pathParamOrNull(state, 'userId');
              if (userId == null) {
                return NotFoundScreen(path: state.uri.toString());
              }
              return FollowingScreen(userId: userId);
            },
          ),
          GoRoute(
            path: '/create-post',
            builder: (context, state) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return CreatePostScreen(
                userId: uid,
                username: _currentUsername(ref),
                avatarUrl: _currentAvatarUrl(ref),
              );
            },
          ),
          GoRoute(
            path: '/create-story',
            builder: (context, state) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return CreateStoryScreen(
                userId: uid,
                username: _currentUsername(ref),
                avatarUrl: _currentAvatarUrl(ref),
              );
            },
          ),
          GoRoute(
            path: '/stories/:userId',
            builder: (context, state) {
              final userId = _pathParamOrNull(state, 'userId');
              if (userId == null) {
                return NotFoundScreen(path: state.uri.toString());
              }
              return StoryViewerScreen(userId: userId);
            },
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return GroupsScreen(userId: uid);
            },
          ),
          GoRoute(
            path: '/create-group',
            builder: (context, state) {
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return CreateGroupScreen(userId: uid);
            },
          ),
          GoRoute(
            path: '/group/:groupId',
            builder: (context, state) {
              final groupId = _pathParamOrNull(state, 'groupId');
              if (groupId == null) {
                return NotFoundScreen(path: state.uri.toString());
              }
              final uid = _currentUid(ref);
              if (uid == null) return const LoginScreen();
              return GroupDetailsScreen(groupId: groupId, userId: uid);
            },
          ),
          GoRoute(
            path: '/trending',
            builder: (context, state) => const TrendingScreen(),
          ),
          GoRoute(
            path: '/rooms',
            builder: (context, state) {
              final category = state.uri.queryParameters['category'];
              return RoomBrowserScreen(initialCategory: category);
            },
          ),
          GoRoute(
            path: '/create-room',
            builder: (context, state) => const CreateRoomScreen(),
          ),
          GoRoute(
            path: '/post/:postId/comments',
            builder: (context, state) {
              final postId = state.pathParameters['postId']!;
              return PostCommentsScreen(postId: postId);
            },
          ),
        ],
      ),

      // ── After Dark — no-shell setup routes ────────────────────────────────
      GoRoute(
        path: '/after-dark/setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AfterDarkAgeGateScreen(),
      ),
      GoRoute(
        path: '/after-dark/pin-setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AfterDarkPinScreen.setup(),
      ),
      GoRoute(
        path: '/after-dark/unlock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AfterDarkPinScreen.unlock(),
      ),

      // ── After Dark — shell routes ──────────────────────────────────────────
      ShellRoute(
        navigatorKey: _afterDarkShellKey,
        builder: (context, state, child) => AfterDarkShell(child: child),
        routes: [
          GoRoute(
            path: '/after-dark',
            builder: (context, state) => const AfterDarkHomeScreen(),
          ),
          GoRoute(
            path: '/after-dark/lounges',
            builder: (context, state) => const AfterDarkLoungesScreen(),
          ),
          GoRoute(
            path: '/after-dark/profile',
            builder: (context, state) => const AfterDarkProfileScreen(),
          ),
          GoRoute(
            path: '/after-dark/create-lounge',
            builder: (context, state) => const AfterDarkCreateLoungeScreen(),
          ),
        ],
      ),
    ],
  );
});

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-root-navigator',
);

final _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-shell-navigator',
);

final _afterDarkShellKey = GlobalKey<NavigatorState>(
  debugLabel: 'mixvy-after-dark-shell-navigator',
);
