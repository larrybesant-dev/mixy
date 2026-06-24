import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/design_constants.dart';
import '../core/web/web_window_service.dart';
import '../features/auth/screens/neon_login_page.dart';
import '../features/auth/screens/neon_signup_page.dart';
import '../features/auth/forgot_password_page.dart';
// TEMP DISABLED: import '../features/onboarding_flow.dart';
import '../features/onboarding/post_auth_onboarding.dart';
import '../features/landing/landing_page.dart';
import '../features/profile/screens/create_profile_page.dart';
import 'app.dart';
import '../shared/providers/all_providers.dart';
import '../core/theme/neon_theme.dart';
import '../core/utils/app_logger.dart';

/// ROOT AUTH GATE - The Single Source of Truth for App Access
/// ============================================================================
///
/// This widget MUST be the root of the app. It controls ALL access to the app
/// using unified Riverpod providers, ensuring no race conditions or stale state.
///
/// Flow:
/// 1. App starts
/// 2. Root Auth Gate watches authStateProvider (Firebase auth stream)
/// 3. If user is null â†’ Show unauthenticated app (landing/login/signup)
/// 4. If user exists â†’ Watch currentUserProvider (loaded profile)
/// 5. If profile incomplete â†’ Show profile creation
/// 6. If profile complete â†’ Show main app
///
/// NO exceptions. NO bypasses. NO race conditions.
/// ============================================================================

class RootAuthGate extends ConsumerWidget {
  const RootAuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the Firebase auth state - foundation of everything
    final authState = ref.watch(authStateProvider);

    return authState.when(
      // Auth state still resolving - show loading splash
      loading: () {
        debugPrint('â³ [RootAuthGate] Firebase auth state still loading...');
        return const _SplashLoadingScreen();
      },

      // Auth error - show splash and log
      error: (error, stack) {
        debugPrint('âŒ [RootAuthGate] Auth state error: $error');
        AppLogger.error('Auth gate error: $error');
        return const _SplashLoadingScreen();
      },

      // No user authenticated - show login/signup flow
      data: (user) {
        if (user == null) {
          debugPrint('ðŸ”“ [RootAuthGate] No user authenticated');
          return const _UnauthenticatedApp();
        }

        // User is authenticated - check if profile is complete
        debugPrint('âœ… [RootAuthGate] User authenticated: ${user.email}');

        return _AuthenticatedAppGate(userId: user.uid);
      },
    );
  }
}

/// ============================================================================
/// UNAUTHENTICATED APP - Landing â†’ Login/Signup
/// ============================================================================
/// Shows only to users who are not logged in.
class _UnauthenticatedApp extends StatelessWidget {
  const _UnauthenticatedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mix & Mingle - Vibes Around the World',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      home: const LandingPage(),
      onGenerateRoute: (settings) {
        debugPrint('ðŸ”“ [Unauthenticated] Route: ${settings.name}');
        switch (settings.name) {
          case '/':
          case '/landing':
            return MaterialPageRoute(builder: (_) => const LandingPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => const NeonLoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const NeonSignupPage());
          case '/forgot-password':
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordPage(),
            );
          default:
            // Block all other routes - send back to landing
            debugPrint(
                'â›” [Unauthenticated] Blocked access to: ${settings.name}');
            return MaterialPageRoute(builder: (_) => const LandingPage());
        }
      },
    );
  }
}

/// ============================================================================
/// AUTHENTICATED APP GATE - Check Profile Completion
/// ============================================================================
/// Shows only to authenticated users.
/// Checks if profile is complete before allowing app access.
///
/// Uses ConsumerStatefulWidget so optional services (presence, window-restore)
/// are initialised exactly ONCE per mount, not on every provider rebuild.
class _AuthenticatedAppGate extends ConsumerStatefulWidget {
  final String userId;

  const _AuthenticatedAppGate({required this.userId});

  @override
  ConsumerState<_AuthenticatedAppGate> createState() =>
      _AuthenticatedAppGateState();
}

class _AuthenticatedAppGateState extends ConsumerState<_AuthenticatedAppGate> {
  /// Ensures optional services are only initialised once per session.
  bool _servicesInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Watch the current user's profile
    final userState = ref.watch(currentUserProvider);

    debugPrint('ðŸ‘¤ [AuthenticatedGate] Checking profile for: ${widget.userId}');

    return userState.when(
      // Still loading profile
      loading: () {
        debugPrint('â³ [AuthenticatedGate] Loading user profile...');
        return const _SplashLoadingScreen();
      },

      // Error loading profile - still show splash
      error: (error, stack) {
        debugPrint('âš ï¸ [AuthenticatedGate] Profile load error: $error');
        return const _SplashLoadingScreen();
      },

      // Profile loaded
      data: (user) {
        // Check if profile is complete - either displayName OR username must exist
        debugPrint(
            'ðŸ“„ [AuthenticatedGate] User data: ${user != null ? "exists" : "null"}');
        if (user != null) {
          debugPrint(
              'ðŸ”‘ [AuthenticatedGate] User fields: displayName="${user.displayName}", username="${user.username}", email="${user.email}"');
        }

        final displayName = user?.displayName ?? '';
        final username = user?.username ?? '';
        debugPrint(
            'ðŸ‘¤ [AuthenticatedGate] displayName="$displayName", username="$username"');

        if (displayName.isNotEmpty || username.isNotEmpty) {
          debugPrint('âœ… [AuthenticatedGate] Profile complete. Showing app.');

          // Guard: only initialise once per mount, regardless of how many
          // times the stream fires (prevents duplicate presence listeners and
          // redundant restoreWindowsOnLogin calls).
          if (!_servicesInitialized) {
            _servicesInitialized = true;
            _initializeOptionalServices(widget.userId);
          }

          // Post-auth onboarding gate: shows once per new account.
          // Legacy users (onboardingComplete == null) are treated as complete
          // so they are not interrupted by onboarding.
          final onboardingDone = user?.onboardingComplete ?? true;
          if (!onboardingDone) {
            AppLogger.info(
                '[AuthGate] onboardingComplete=false → showing PostAuthOnboarding');
            return const PostAuthOnboarding();
          }

          // Profile complete + onboarding done → show main app
          return const MixMingleApp();
        }

        debugPrint(
            'ðŸš§ [AuthenticatedGate] Profile incomplete. Forcing completion.');
        return _ProfileIncompleteApp(userId: widget.userId);
      },
    );
  }

  /// Initialize optional services that don't block app rendering
  /// Called at most once per widget mount due to [_servicesInitialized] guard.
  void _initializeOptionalServices(String userId) {
    Future.microtask(() async {
      try {
        // Restore pop-out windows that were open before the user last closed
        // the tab (no-op on mobile/desktop — kIsWeb guard inside the service).
        WebWindowService.restoreWindowsOnLogin();

        // Initialize presence (non-blocking)
        debugPrint('ðŸ“± [Init] Initializing presence for $userId...');
        final presenceService = ref.read(presenceServiceProvider);
        await presenceService.initializePresence();
        await presenceService.goOnline();
        debugPrint('âœ… [Init] Presence initialized');

        // Initialize FCM notifications (non-blocking)
        debugPrint('ðŸ“± [Init] Initializing FCM notifications...');
        // FCM setup happens in main.dart, this is just for reference
        debugPrint('âœ… [Init] FCM notifications ready');

        AppLogger.info('Post-auth initialization complete');
      } catch (e) {
        debugPrint(
            'âš ï¸ [Init] Optional service init failed (non-fatal): $e');
        AppLogger.warning('Optional service initialization failed: $e');
        // App continues - these services are not critical for rendering
      }
    });
  }
}

/// ============================================================================
/// PROFILE INCOMPLETE APP - Force Profile Creation
/// ============================================================================
/// Shows only to authenticated users without complete profiles.
class _ProfileIncompleteApp extends StatelessWidget {
  final String userId;

  const _ProfileIncompleteApp({required this.userId});

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🧩 [ProfileIncomplete] Routing to CreateProfilePage for $userId');

    return MaterialApp(
      title: 'Mix & Mingle',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      home: const CreateProfilePage(),
      onGenerateRoute: (settings) {
        debugPrint('🧩 [ProfileIncomplete] Route: ${settings.name}');
        // After profile creation CreateProfilePage navigates to /home which
        // causes the auth gate to re-evaluate (onboardingComplete now false →
        // HomePageElectric will show the welcome overlay once).
        return MaterialPageRoute(builder: (_) => const CreateProfilePage());
      },
    );
  }
}

/// ============================================================================
/// SPLASH LOADING SCREEN - Shown During Auth State Resolution
/// ============================================================================
class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mix & Mingle',
      debugShowCheckedModeBanner: false,
      theme: NeonTheme.darkTheme,
      home: Scaffold(
        backgroundColor: DesignColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Neon logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DesignColors.accent,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.videocam,
                  color: DesignColors.secondary,
                  size: 50,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Mix & Mingle',
                style: TextStyle(
                  color: DesignColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vibes Around the World',
                style: TextStyle(
                  color: DesignColors.accent,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(DesignColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
