import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/auth/auth_service.dart';
import '../models/user.dart' as shared_models;
import '../models/user_profile.dart';
import '../../services/infra/firestore_service.dart';
import 'user_providers.dart';

/// Service providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Auth state stream provider - directly watch Firebase auth state
/// This bypasses the service layer on web to ensure proper initialization
final authStateProvider = StreamProvider<firebase_auth.User?>((ref) {
  return firebase_auth.FirebaseAuth.instance.authStateChanges();
});

/// Current user stream provider (combines auth + Firestore user data)
/// CRITICAL: Resilient fallback - returns Firebase Auth user during Firestore load
final currentUserProvider = StreamProvider<shared_models.User?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (authUser) {
      if (authUser == null) {
        return Stream.value(null);
      }
      // Try Firestore first, but return minimal user data if it fails/times out
      return ref.watch(firestoreServiceProvider).getUserStream(authUser.uid);
    },
    loading: () {
      // CRITICAL: Don't return null during loading
      // Instead, check if we have a cached Firebase user
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      final currentUser = firebaseAuth.currentUser;

      if (currentUser != null) {
        // Return temporary user with Firebase data while Firestore loads.
        // IMPORTANT: Use empty strings when Firebase Auth has no displayName
        // (new users who haven't completed profile) so the auth gate correctly
        // routes them to CreateProfilePage instead of HomePageElectric.
        return Stream.value(
          shared_models.User(
            id: currentUser.uid,
            email: currentUser.email ?? '',
            displayName: currentUser.displayName ?? '',
            username: currentUser.displayName != null
                ? (currentUser.email?.split('@').first ?? '')
                : '',
            bio: '',
            interests: [],
            avatarUrl: currentUser.photoURL ?? '',
            coinBalance: 0,
            createdAt: currentUser.metadata.creationTime ?? DateTime.now(),
            location: '',
            statusMessage: 'Available',
            followersCount: 0,
            followingCount: 0,
            totalTipsReceived: 0,
            liveSessionsHosted: 0,
            socialLinks: {},
            topGifts: [],
            recentMediaUrls: [],
            recentActivity: [],
            membershipTier: 'free',
            badges: [],
            isOnline: true,
          ),
        );
      }
      return Stream.value(null);
    },
    error: (error, stack) {
      // CRITICAL: Don't return null on error
      // Fall back to Firebase user if Firestore fails
      final firebaseAuth = firebase_auth.FirebaseAuth.instance;
      final currentUser = firebaseAuth.currentUser;

      if (currentUser != null) {
        return Stream.value(
          shared_models.User(
            id: currentUser.uid,
            email: currentUser.email ?? '',
            displayName: currentUser.displayName ?? '',
            username: currentUser.displayName != null
                ? (currentUser.email?.split('@').first ?? '')
                : '',
            bio: '',
            interests: [],
            avatarUrl: currentUser.photoURL ?? '',
            coinBalance: 0,
            createdAt: currentUser.metadata.creationTime ?? DateTime.now(),
            location: '',
            statusMessage: 'Available',
            followersCount: 0,
            followingCount: 0,
            totalTipsReceived: 0,
            liveSessionsHosted: 0,
            socialLinks: {},
            topGifts: [],
            recentMediaUrls: [],
            recentActivity: [],
            membershipTier: 'free',
            badges: [],
            isOnline: true,
          ),
        );
      }
      return Stream.value(null);
    },
  );
});

/// Current user profile stream provider (UserProfile model)
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(authStateProvider).when(
        data: (authUser) {
          if (authUser == null) {
            return Stream.value(null);
          }
          return ref
              .watch(profileServiceProvider)
              .getUserProfileStream(authUser.uid);
        },
        loading: () => Stream.value(null),
        error: (_, __) => Stream.value(null),
      );
});

/// Auth controller for authentication operations
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<firebase_auth.User?>>(() {
  return AuthController();
});

class AuthController extends Notifier<AsyncValue<firebase_auth.User?>> {
  late final AuthService _authService;
  late final FirestoreService _firestoreService;

  @override
  AsyncValue<firebase_auth.User?> build() {
    _authService = ref.watch(authServiceProvider);
    _firestoreService = ref.watch(firestoreServiceProvider);
    return const AsyncValue.loading();
  }

  /// Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final userCredential =
          await _authService.signInWithEmailAndPassword(email, password);
      state = AsyncValue.data(userCredential?.user);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncValue.loading();
    try {
      final userCredential =
          await _authService.createUserWithEmailAndPassword(email, password);
      if (userCredential?.user != null) {
        // Create initial user document
        final newUser = shared_models.User(
          id: userCredential!.user!.uid,
          email: email,
          displayName: displayName,
          username: displayName.toLowerCase().replaceAll(' ', '_'),
          bio: '',
          interests: [],
          avatarUrl: '',
          coinBalance: 100,
          createdAt: DateTime.now(),
          location: '',
          statusMessage: 'Available',
          followersCount: 0,
          followingCount: 0,
          totalTipsReceived: 0,
          liveSessionsHosted: 0,
          socialLinks: {},
          topGifts: [],
          recentMediaUrls: [],
          recentActivity: [],
          isOnline: true,
          membershipTier: 'free',
          badges: [],
        );
        await _firestoreService.createUser(newUser);
        state = AsyncValue.data(userCredential.user);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential?.user != null) {
        // Check if user document exists, create if not
        final userDoc =
            await _firestoreService.getUser(userCredential!.user!.uid);
        if (userDoc == null) {
          final newUser = shared_models.User(
            id: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            displayName: userCredential.user!.displayName ?? 'User',
            username: (userCredential.user!.displayName ?? 'user')
                .toLowerCase()
                .replaceAll(' ', '_'),
            bio: '',
            interests: [],
            avatarUrl: userCredential.user!.photoURL ?? '',
            coinBalance: 100,
            createdAt: DateTime.now(),
            location: '',
            statusMessage: 'Available',
            followersCount: 0,
            followingCount: 0,
            totalTipsReceived: 0,
            liveSessionsHosted: 0,
            socialLinks: {},
            topGifts: [],
            recentMediaUrls: [],
            recentActivity: [],
            isOnline: true,
            membershipTier: 'free',
            badges: [],
          );
          await _firestoreService.createUser(newUser);
        }
        state = AsyncValue.data(userCredential.user);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updateDisplayName(displayName);
        await currentUser.updatePhotoURL(photoURL);
        state = AsyncValue.data(currentUser);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Email verification status provider
final emailVerificationStatusProvider = StreamProvider<bool>((ref) {
  return ref.watch(authStateProvider).when(
        data: (user) {
          if (user == null) return Stream.value(false);
          return Stream.periodic(const Duration(seconds: 3), (_) {
            return user.emailVerified;
          }).asyncMap((_) async {
            await user.reload();
            return firebase_auth
                    .FirebaseAuth.instance.currentUser?.emailVerified ??
                false;
          });
        },
        loading: () => Stream.value(false),
        error: (_, __) => Stream.value(false),
      );
});

/// Send email verification
final sendEmailVerificationProvider = FutureProvider((ref) async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user != null && !user.emailVerified) {
    await user.sendEmailVerification();
  }
});
