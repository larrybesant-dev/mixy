// ============================================================================
// OAUTH AUTHENTICATION SERVICE - DISABLED FOR LAUNCH
// ============================================================================
// OAuth functionality temporarily disabled to ship with Email/Password only
// Will be re-enabled post-launch with proper testing
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Temporarily disabled for launch
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../infra/error_tracking_service.dart';

/// OAuth provider types
enum OAuthProvider {
  google,
  facebook,
  apple,
}

/// OAuth authentication result
class OAuthResult {
  final bool success;
  final UserCredential? credential;
  final String? error;
  final String? message;

  OAuthResult.success(this.credential)
      : success = true,
        error = null,
        message = null;

  OAuthResult.failure(this.error, this.message)
      : success = false,
        credential = null;

  OAuthResult.cancelled()
      : success = false,
        credential = null,
        error = 'cancelled',
        message = 'Sign-in was cancelled';
}

/// Comprehensive OAuth Service
/// Handles Google, Facebook, and Apple Sign-In
class OAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Unused for launch: final AnalyticsService _analytics = AnalyticsService();
  final ErrorTrackingService _errorTracking = ErrorTrackingService();

  // Google Sign-In (DISABLED FOR LAUNCH)
  // GoogleSignIn? _googleSignIn;

  OAuthService() {
    // _initializeGoogleSignIn();
    debugPrint(
        '[OAuth] OAuth features disabled for launch - Email/Password only');
  }

  // DISABLED FOR LAUNCH
  // void _initializeGoogleSignIn() {
  //   if (kIsWeb) {
  //     debugPrint('[OAuth] Web platform - using Firebase Google provider');
  //     return;
  //   }
  //   try {
  //     _googleSignIn = GoogleSignIn(
  //       scopes: ['email', 'profile'],
  //     );
  //     debugPrint('[OAuth] Google Sign-In initialized for mobile');
  //   } catch (e) {
  //     debugPrint('[OAuth] Failed to initialize Google Sign-In: $e');
  //     _errorTracking.recordError(e, StackTrace.current, reason: 'Google Sign-In init failed');
  //   }
  // }

  // ============================================================================
  // GOOGLE SIGN-IN
  // ============================================================================

  /// Sign in with Google - DISABLED FOR LAUNCH
  Future<OAuthResult> signInWithGoogle() async {
    return OAuthResult.failure(
      'not_implemented',
      'Google Sign-In temporarily disabled for launch. Use Email/Password.',
    );
  }

  // DISABLED FOR LAUNCH
  // Future<OAuthResult> _signInWithGoogleWeb() async { ... }
  // Future<OAuthResult> _signInWithGoogleMobile() async { ... }

  // ============================================================================
  // APPLE SIGN-IN
  // ============================================================================

  /// Sign in with Apple - DISABLED FOR LAUNCH
  Future<OAuthResult> signInWithApple() async {
    return OAuthResult.failure(
      'not_implemented',
      'Apple Sign-In temporarily disabled for launch. Use Email/Password.',
    );
  }

  // ============================================================================
  // FACEBOOK SIGN-IN (SCAFFOLDING)
  // ============================================================================

  /// Sign in with Facebook
  /// TODO: Implement Facebook Login SDK integration
  /// Requires: flutter_facebook_auth package
  Future<OAuthResult> signInWithFacebook() async {
    return OAuthResult.failure(
      'not_implemented',
      'Facebook Sign-In is not yet implemented. Coming soon!',
    );

    // IMPLEMENTATION GUIDE:
    // 1. Add flutter_facebook_auth to pubspec.yaml
    // 2. Configure Facebook App ID in Android/iOS
    // 3. Implement the flow below:
    /*
    try {
      // Trigger Facebook login
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Get access token
        final AccessToken accessToken = result.accessToken!;

        // Create Firebase credential
        final credential = FacebookAuthProvider.credential(accessToken.token);

        // Sign in to Firebase
        final userCredential = await _auth.signInWithCredential(credential);

        await _analytics.trackLogin('facebook');
        return OAuthResult.success(userCredential);
      } else if (result.status == LoginStatus.cancelled) {
        return OAuthResult.cancelled();
      } else {
        return OAuthResult.failure('error', result.message ?? 'Facebook login failed');
      }
    } catch (e, stack) {
      _errorTracking.recordError(e, stack, reason: 'Facebook sign-in error');
      return OAuthResult.failure('error', 'Facebook sign-in failed: $e');
    }
    */
  }

  // ============================================================================
  // ACCOUNT LINKING
  // ============================================================================

  /// Link Google account - DISABLED FOR LAUNCH
  Future<OAuthResult> linkGoogleAccount() async {
    return OAuthResult.failure(
      'not_implemented',
      'Account linking temporarily disabled for launch.',
    );
  }

  /// Link Apple account - DISABLED FOR LAUNCH
  Future<OAuthResult> linkAppleAccount() async {
    return OAuthResult.failure(
      'not_implemented',
      'Account linking temporarily disabled for launch.',
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  // REMOVED: _getFirebaseErrorMessage - unused after OAuth disabled

  /// Get available OAuth providers - DISABLED FOR LAUNCH
  List<OAuthProvider> getAvailableProviders() {
    // All OAuth providers disabled for launch
    return [];
  }

  /// Sign out from all providers
  Future<void> signOutAll() async {
    try {
      await _auth.signOut();
      _errorTracking.log('[OAuth] Signed out');
    } catch (e, stack) {
      _errorTracking.recordError(e, stack, reason: 'Sign out error');
      rethrow;
    }
  }
}
