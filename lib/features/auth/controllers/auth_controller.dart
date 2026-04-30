import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firestore/firestore_debug_tracing.dart';
import '../../../core/telemetry/app_telemetry.dart';
import '../../../presentation/screens/google_sign_in_helper.dart';
import '../../../presentation/screens/apple_sign_in_helper.dart';
import '../../../services/push_messaging_service.dart';
import '../../../services/schema_mutation_service.dart';
import '../../../observability/system_event_bus.dart';

enum AuthBootstrapPhase {
  booting,
  initializingAuth,
  authenticatedStable,
  unauthenticatedStable,
}

class AuthState {
  final bool isLoading;
  final bool hasResolvedSession;
  final String? error;
  final String? uid;
  final AuthBootstrapPhase phase;

  static const Object _unset = Object();

  const AuthState({
    this.isLoading = false,
    this.hasResolvedSession = false,
    this.error,
    this.uid,
    this.phase = AuthBootstrapPhase.booting,
  });

  bool get isRoutingStable =>
      phase == AuthBootstrapPhase.authenticatedStable ||
      phase == AuthBootstrapPhase.unauthenticatedStable;

  bool get isAuthenticatedStable =>
      phase == AuthBootstrapPhase.authenticatedStable;

  bool get isUnauthenticatedStable =>
      phase == AuthBootstrapPhase.unauthenticatedStable;

  AuthState copyWith({
    bool? isLoading,
    bool? hasResolvedSession,
    Object? error = _unset,
    Object? uid = _unset,
    AuthBootstrapPhase? phase,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      hasResolvedSession: hasResolvedSession ?? this.hasResolvedSession,
      error: identical(error, _unset) ? this.error : error as String?,
      uid: identical(uid, _unset) ? this.uid : uid as String?,
      phase: phase ?? this.phase,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

class AuthController extends Notifier<AuthState> {
  final GoogleSignInHelper _googleSignInHelper;
  final AppleSignInHelper _appleSignInHelper;
  final SchemaMutationService? _schemaMutationService;

  StreamSubscription<User?>? _authStateSubscription;

  void _setAuthState(AuthState nextState, {required String source}) {
    final previous = state;
    state = nextState;

    if (previous.phase != nextState.phase) {
      SystemEventBus.instance.emit(
        SystemEvent(
          type: 'AUTH_PHASE_CHANGE',
          timestamp: DateTime.now(),
          meta: <String, dynamic>{
            'from': previous.phase.name,
            'to': nextState.phase.name,
            'source': source,
            'uid': nextState.uid,
          },
        ),
      );

      if (nextState.isRoutingStable) {
        SystemEventBus.instance.emit(
          SystemEvent(
            type: 'AUTH_STABLE',
            timestamp: DateTime.now(),
            meta: <String, dynamic>{
              'phase': nextState.phase.name,
              'uid': nextState.uid,
              'source': source,
            },
          ),
        );
      }
    }
  }

  Future<void> signInWithGoogle() async {
    _setAuthState(state.copyWith(
      isLoading: true,
      error: null,
      phase: AuthBootstrapPhase.initializingAuth,
    ), source: 'google_sign_in_start');
    AppTelemetry.updateAuthState(
      userId: state.uid,
      isLoading: true,
      error: null,
    );
    AppTelemetry.logAction(
      domain: 'auth',
      action: 'google_sign_in',
      message: 'Google sign-in started.',
      userId: state.uid,
      result: 'start',
    );
    try {
      await _googleSignInHelper.signInWithGoogle();
      _setAuthState(state.copyWith(
        isLoading: false,
        hasResolvedSession: true,
        uid: _auth.currentUser?.uid,
        phase: _auth.currentUser?.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'google_sign_in_success');
      AppTelemetry.updateAuthState(
        userId: _auth.currentUser?.uid,
        isLoading: false,
        error: null,
      );
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'google-sign-in');
      final message = _getReadableError(e.code);
      _setAuthState(state.copyWith(
        isLoading: false,
        hasResolvedSession: true,
        error: message,
        phase: state.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'google_sign_in_failure');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: message,
      );
    } catch (e) {
      _setAuthState(state.copyWith(
        isLoading: false,
        error: e.toString(),
        phase: state.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'google_sign_in_error');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore? _firestore;
  final Future<void> Function()? _unregisterToken;

  AuthController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Future<void> Function()? unregisterToken,
    GoogleSignInHelper? googleSignInHelper,
    AppleSignInHelper? appleSignInHelper,
    SchemaMutationService? schemaMutationService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore,
       _unregisterToken = unregisterToken,
       _googleSignInHelper = googleSignInHelper ?? getGoogleSignInHelper(),
       _appleSignInHelper = appleSignInHelper ?? getAppleSignInHelper(),
       _schemaMutationService = schemaMutationService;

  @override
  AuthState build() {
    SystemEventBus.instance.emitNow(
      'AUTH_BOOT_START',
      meta: <String, dynamic>{'source': 'auth_controller_build'},
    );

    _authStateSubscription?.cancel();
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (_isAnonymousUser(user)) {
        unawaited(_rejectAnonymousSession());
        return;
      }

      // If we are currently repairing or rejecting a session, do not emit
      // a stable state from the auth stream until that logic concludes.
      if (state.phase == AuthBootstrapPhase.initializingAuth &&
          state.isLoading == true) {
        return;
      }

      _setAuthState(state.copyWith(
        uid: user?.uid,
        isLoading: false,
        hasResolvedSession: true,
        error: null,
        phase: user == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'firebase_auth_state_change');
      AppTelemetry.updateAuthState(
        userId: user?.uid,
        isLoading: false,
        error: null,
      );
      AppTelemetry.logAction(
        domain: 'auth',
        action: 'auth_state_change',
        message: 'Firebase auth state updated.',
        userId: user?.uid,
        result: user == null ? 'signed_out' : 'signed_in',
      );
    });

    // Run critical initialization/repairs.
    // Use initializingAuth + isLoading to guard the stable phase emission.
    Future(() async {
      await _configureWebPersistence();
      await _repairInvalidCachedSession();
      await _completeRedirectSignInIfNeeded();
    });

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    final currentUser = _auth.currentUser;
    if (_isAnonymousUser(currentUser)) {
      unawaited(_rejectAnonymousSession());
      return const AuthState(
        isLoading: true, // Keep loading while we reject
        hasResolvedSession: false,
        phase: AuthBootstrapPhase.initializingAuth,
      );
    }

    AppTelemetry.updateAuthState(
      userId: currentUser?.uid,
      isLoading: false,
      error: null,
    );
    return AuthState(
      isLoading: currentUser != null, // If we have a user, we are initializing/validating
      hasResolvedSession: false,
      uid: currentUser?.uid,
      phase: AuthBootstrapPhase.initializingAuth,
    );
  }

  bool _isAnonymousUser(User? user) => user?.isAnonymous ?? false;

  Future<void> _rejectAnonymousSession() async {
    const message = 'Guest access is disabled. Please sign in with an account.';
    try {
      await _auth.signOut();
    } catch (_) {
      // Best-effort sign-out.
    }

    _setAuthState(state.copyWith(
      isLoading: false,
      hasResolvedSession: true,
      uid: null,
      error: message,
      phase: AuthBootstrapPhase.unauthenticatedStable,
    ), source: 'reject_anonymous_session');
    AppTelemetry.updateAuthState(
      userId: null,
      isLoading: false,
      error: message,
    );
  }

  Future<void> _configureWebPersistence() async {
    if (!kIsWeb) {
      return;
    }

    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'set-persistence');
    } catch (e, st) {
      developer.log(
        'Failed to configure web auth persistence',
        name: 'AuthController',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _repairInvalidCachedSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    if (_isAnonymousUser(user)) {
      await _rejectAnonymousSession();
      return;
    }

    try {
      // Force a network refresh on web so a stale emulator token in localStorage
      // is caught eagerly before the router renders the home screen.
      await user.getIdToken(kIsWeb);
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'cached-session-validation');
      if (_isInvalidSessionError(e.code)) {
        await _auth.signOut();
        _setAuthState(state.copyWith(
          uid: null,
          hasResolvedSession: true,
          error: null,
          phase: AuthBootstrapPhase.unauthenticatedStable,
        ), source: 'repair_invalid_cached_session');
      }
    } catch (e, st) {
      developer.log(
        'Non-Firebase error while validating cached session',
        name: 'AuthController',
        error: e,
        stackTrace: st,
      );
      await _auth.signOut();
      _setAuthState(state.copyWith(
        uid: null,
        hasResolvedSession: true,
        error: null,
        phase: AuthBootstrapPhase.unauthenticatedStable,
      ), source: 'repair_cached_session_error');
    }
  }

  bool _isInvalidSessionError(String code) {
    switch (code) {
      case 'user-token-expired':
      case 'invalid-user-token':
      case 'user-disabled':
      case 'user-not-found':
      case 'invalid-credential':
      case 'requires-recent-login':
        return true;
      default:
        return false;
    }
  }

  Future<void> _completeRedirectSignInIfNeeded() async {
    try {
      await _googleSignInHelper.completePendingRedirectSignIn();
      await _appleSignInHelper.completePendingRedirectSignIn();
      final currentUser = _auth.currentUser;
      final uid = currentUser?.uid;
      if (uid != null && currentUser != null) {
        await _ensureUserDocument(currentUser);
        _setAuthState(state.copyWith(
          uid: uid,
          isLoading: false,
          hasResolvedSession: true,
          error: null,
          phase: AuthBootstrapPhase.authenticatedStable,
        ), source: 'redirect_sign_in_success');
        AppTelemetry.updateAuthState(
          userId: uid,
          isLoading: false,
          error: null,
        );
      }
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'redirect-result');
      _setAuthState(state.copyWith(
        isLoading: false,
        hasResolvedSession: true,
        error: _getReadableError(e.code),
        phase: state.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'redirect_sign_in_failure');
    } catch (_) {
      // Ignore non-auth redirect completion errors to avoid noisy startup failures.
    }
  }

  Future<void> signup(String email, String password, String username) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      _setAuthState(state.copyWith(
        isLoading: false,
        hasResolvedSession: true,
        error: 'A username is required.',
        phase: state.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'signup_validation_failed');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: 'A username is required.',
      );
      return;
    }

    _setAuthState(state.copyWith(
      isLoading: true,
      error: null,
      phase: AuthBootstrapPhase.initializingAuth,
    ), source: 'signup_start');
    AppTelemetry.updateAuthState(
      userId: state.uid,
      isLoading: true,
      error: null,
    );
    AppTelemetry.logAction(
      domain: 'auth',
      action: 'signup',
      message: 'Email signup started.',
      result: 'start',
    );
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final createdUser = cred.user;
      if (createdUser != null) {
        await _ensureUserDocument(
          createdUser,
          preferredUsername: normalizedUsername,
        );
      }
      _setAuthState(state.copyWith(
        isLoading: false,
        uid: cred.user?.uid,
        phase: cred.user?.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'signup_success');
      AppTelemetry.updateAuthState(
        userId: cred.user?.uid,
        isLoading: false,
        error: null,
      );
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'signup');
      final errormessage = _getReadableError(e.code);
      _setAuthState(state.copyWith(
        isLoading: false,
        error: errormessage,
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'signup_failure');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: errormessage,
      );
    } catch (e) {
      _setAuthState(state.copyWith(
        isLoading: false,
        error: "Unexpected error: $e",
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'signup_error');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: 'Unexpected error: $e',
      );
    }
  }

  Future<void> login(String email, String password) async {
    _setAuthState(state.copyWith(
      isLoading: true,
      error: null,
      phase: AuthBootstrapPhase.initializingAuth,
    ), source: 'login_start');
    AppTelemetry.updateAuthState(
      userId: state.uid,
      isLoading: true,
      error: null,
    );
    AppTelemetry.logAction(
      domain: 'auth',
      action: 'login',
      message: 'Email login started.',
      result: 'start',
    );
    try {
      final normalizedEmail = email.trim();

      final cred = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password.trim(),
      );
      final signedInUser = cred.user;
      if (signedInUser != null) {
        await _ensureUserDocument(signedInUser);
      }
      _setAuthState(state.copyWith(
        isLoading: false,
        uid: cred.user?.uid,
        phase: cred.user?.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'login_success');
      AppTelemetry.updateAuthState(
        userId: cred.user?.uid,
        isLoading: false,
        error: null,
      );
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'login');
      final message = _getReadableError(e.code);
      _setAuthState(state.copyWith(
        isLoading: false,
        error: message,
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'login_failure');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: message,
      );
    } catch (e) {
      _setAuthState(state.copyWith(
        isLoading: false,
        error: "Unexpected error: $e",
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'login_error');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: 'Unexpected error: $e',
      );
    }
  }

  String _getReadableError(String code) {
    switch (code) {
      case 'invalid-credential':
        return 'Invalid email or password. If this account was created with Google, use Google Sign-In';
      case 'invalid-login-credentials':
        return 'Invalid email or password';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later';
      case 'account-exists-with-different-credential':
        return 'Account exists with another sign-in method. Try a different provider.';
      case 'popup-blocked':
      case 'popup-closed-by-user':
      case 'web-context-cancelled':
      case 'canceled':
        return 'Sign-in was cancelled. Please try again.';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'Login failed: $code';
    }
  }

  Future<void> signInWithApple() async {
    _setAuthState(state.copyWith(
      isLoading: true,
      error: null,
      phase: AuthBootstrapPhase.initializingAuth,
    ), source: 'apple_sign_in_start');
    AppTelemetry.updateAuthState(
      userId: state.uid,
      isLoading: true,
      error: null,
    );
    try {
      await _appleSignInHelper.signInWithApple();
      final user = _auth.currentUser;
      if (user != null) {
        await _ensureUserDocument(user);
      }
      _setAuthState(state.copyWith(
        isLoading: false,
        hasResolvedSession: true,
        uid: user?.uid,
        phase: user?.uid == null
            ? AuthBootstrapPhase.unauthenticatedStable
            : AuthBootstrapPhase.authenticatedStable,
      ), source: 'apple_sign_in_success');
      AppTelemetry.updateAuthState(
        userId: user?.uid,
        isLoading: false,
        error: null,
      );
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'apple-sign-in');
      final message = _getReadableError(e.code);
      _setAuthState(state.copyWith(
        isLoading: false,
        error: message,
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'apple_sign_in_failure');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: message,
      );
    } catch (e) {
      _setAuthState(state.copyWith(
        isLoading: false,
        error: e.toString(),
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'apple_sign_in_error');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    AppTelemetry.logAction(
      domain: 'auth',
      action: 'logout',
      message: 'Logout cleanup started.',
      userId: _auth.currentUser?.uid ?? state.uid,
      result: 'start',
    );
    await _cleanupSession();
  }

  Future<void> finalizeSessionCleanup({String? uidOverride}) async {
    await _cleanupSession(signOut: false, uidOverride: uidOverride);
  }

  Future<void> _cleanupSession({
    bool signOut = true,
    String? uidOverride,
  }) async {
    try {
      await (_unregisterToken?.call() ??
          PushMessagingService.instance.unregisterCurrentToken());
    } catch (_) {
      // Best-effort cleanup.
    }

    if (signOut) {
      await _auth.signOut();
    }

    _setAuthState(state.copyWith(
      isLoading: false,
      uid: null,
      error: null,
      hasResolvedSession: true,
      phase: AuthBootstrapPhase.unauthenticatedStable,
    ), source: 'cleanup_session');
    AppTelemetry.updateAuthState(userId: null, isLoading: false, error: null);
  }

  Future<void> _ensureUserDocument(
    User user, {
    String? preferredUsername,
  }) async {
    final firestore = _firestore ?? _tryResolveFirestore();
    if (firestore == null) {
      return;
    }

    try {
      final mutationService =
          _schemaMutationService ?? SchemaMutationService(firestore: firestore);
      await traceFirestoreWrite<void>(
        path: 'users/${user.uid}',
        operation: 'ensure_user_document',
        userId: user.uid,
        action: () => mutationService.createUserProfile(
          user: user,
          preferredUsername: preferredUsername,
        ),
      );
    } catch (e, st) {
      developer.log(
        'Failed to ensure user document for ${user.uid}',
        name: 'AuthController',
        error: e,
        stackTrace: st,
      );
    }
  }

  FirebaseFirestore? _tryResolveFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> resetPassword(String email) async {
    _setAuthState(state.copyWith(
      isLoading: true,
      error: null,
      phase: AuthBootstrapPhase.initializingAuth,
    ), source: 'reset_password_start');
    AppTelemetry.updateAuthState(
      userId: state.uid,
      isLoading: true,
      error: null,
    );
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _setAuthState(state.copyWith(
        isLoading: false,
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'reset_password_success');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: null,
      );
    } on FirebaseAuthException catch (e, st) {
      _logAuthException(e, st, context: 'reset-password');
      final errormessage = _getReadableError(e.code);
      _setAuthState(state.copyWith(
        isLoading: false,
        error: errormessage,
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'reset_password_failure');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: errormessage,
      );
    } catch (e) {
      _setAuthState(state.copyWith(
        isLoading: false,
        error: "Unexpected error: $e",
        phase: state.uid == null
        ? AuthBootstrapPhase.unauthenticatedStable
        : AuthBootstrapPhase.authenticatedStable,
      ), source: 'reset_password_error');
      AppTelemetry.updateAuthState(
        userId: state.uid,
        isLoading: false,
        error: 'Unexpected error: $e',
      );
    }
  }

  void _logAuthException(
    FirebaseAuthException e,
    StackTrace stackTrace, {
    required String context,
  }) {
    AppTelemetry.logAction(
      level: 'error',
      domain: 'auth',
      action: context,
      message: 'FirebaseAuthException occurred.',
      userId: _auth.currentUser?.uid ?? state.uid,
      result: e.code,
      error: e,
      stackTrace: stackTrace,
    );
    developer.log(
      'FirebaseAuthException in $context: ${e.code}',
      name: 'AuthController',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
