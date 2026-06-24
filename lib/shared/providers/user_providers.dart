import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/user/profile_service.dart';
import '../../services/social/presence_service.dart';
import '../models/user_profile.dart';
import '../models/user_presence.dart';
import 'auth_providers.dart';

/// Service providers
final profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());

final presenceServiceProvider =
    Provider<PresenceService>((ref) => PresenceService());

/// Current user profile provider
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield null;
    return;
  }

  final profileService = ref.watch(profileServiceProvider);
  try {
    final profile = await profileService.getUserProfile(currentUser.id);
    yield profile;
  } catch (e) {
    yield null;
  }
});

/// User profile by ID provider
final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, userId) async* {
  final profileService = ref.watch(profileServiceProvider);
  try {
    final profile = await profileService.getUserProfile(userId);
    yield profile;

    // Keep listening for updates (simplified - in production use Firestore stream)
    await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
      final updated = await profileService.getUserProfile(userId);
      yield updated;
    }
  } catch (e) {
    yield null;
  }
});

/// User presence provider - Phase 2 Hardened
/// Uses error handling and prevents infinite retry loops
final userPresenceProvider =
    StreamProvider.family<UserPresence?, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);

  // Get stream with built-in error handling and retry guards
  return presenceService
      .getUserPresence(userId)
      .handleError((error, stackTrace) {
    debugPrint('âŒ userPresenceProvider error for $userId: $error');
    return null; // Return null on error instead of propagating
  });
});

/// Nearby users provider
final nearbyUsersProvider =
    StreamProvider.family<List<UserProfile>, Map<String, dynamic>>(
        (ref, params) async* {
  final profileService = ref.watch(profileServiceProvider);
  final latitude = params['latitude'] as double;
  final longitude = params['longitude'] as double;
  final radiusKm = params['radiusKm'] as double? ?? 10.0;

  try {
    final users =
        await profileService.getNearbyUsers(latitude, longitude, radiusKm);
    yield users;
  } catch (e) {
    yield [];
  }
});

/// Search users by interests provider
final searchUsersByInterestsProvider =
    StreamProvider.family<List<UserProfile>, List<String>>(
        (ref, interests) async* {
  final profileService = ref.watch(profileServiceProvider);

  try {
    final users = await profileService.searchUsersByInterests(interests);
    yield users;
  } catch (e) {
    yield [];
  }
});

/// Profile controller for profile operations
final userProfileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<UserProfile?>>(() {
  return ProfileController();
});

class ProfileController extends Notifier<AsyncValue<UserProfile?>> {
  late final ProfileService _profileService;
  late final PresenceService _presenceService;

  @override
  AsyncValue<UserProfile?> build() {
    _profileService = ref.watch(profileServiceProvider);
    _presenceService = ref.watch(presenceServiceProvider);
    _loadCurrentUserProfile();
    return const AsyncValue.loading();
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _profileService.getUserProfile(currentUser.id);
      state = AsyncValue.data(profile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update user profile
  Future<void> updateProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      await _profileService.updateUserProfile(profile);
      state = AsyncValue.data(profile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      await _loadCurrentUserProfile();
    }
  }

  /// Update specific profile fields
  Future<void> updateProfileFields(Map<String, dynamic> updates) async {
    try {
      final currentProfile = state.value;
      if (currentProfile == null) {
        throw Exception('No profile loaded');
      }

      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _profileService.updateUserProfile(currentProfile.copyWith(
        displayName: updates['displayName'] ?? currentProfile.displayName,
        bio: updates['bio'] ?? currentProfile.bio,
        interests: updates['interests'] ?? currentProfile.interests,
        photoUrl: updates['photoUrl'] ?? currentProfile.photoUrl,
        coverPhotoUrl: updates['coverPhotoUrl'] ?? currentProfile.coverPhotoUrl,
      ));

      await _loadCurrentUserProfile();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Create initial profile
  Future<void> createInitialProfile(
    String userId,
    String email,
    String displayName,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _profileService.createInitialProfile(userId, email, displayName);
      await _loadCurrentUserProfile();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) return;

      await _presenceService.updatePresence(currentUser.id, isOnline: isOnline);
    } catch (e) {
      // Don't update state on presence error
    }
  }

  /// Update location
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      final currentProfile = state.value;
      if (currentProfile == null) return;

      await _profileService.updateUserProfile(currentProfile.copyWith(
        latitude: latitude,
        longitude: longitude,
      ));

      await _loadCurrentUserProfile();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Refresh profile
  void refreshProfile() {
    _loadCurrentUserProfile();
  }
}

/// User search controller
final userSearchControllerProvider =
    NotifierProvider<UserSearchController, AsyncValue<List<UserProfile>>>(() {
  return UserSearchController();
});

class UserSearchController extends Notifier<AsyncValue<List<UserProfile>>> {
  late final ProfileService _profileService;
  String _searchQuery = '';
  List<String> _interestFilters = [];

  @override
  AsyncValue<List<UserProfile>> build() {
    _profileService = ref.watch(profileServiceProvider);
    return const AsyncValue.data([]);
  }

  /// Search users by query
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    await _performSearch();
  }

  /// Filter by interests
  Future<void> filterByInterests(List<String> interests) async {
    _interestFilters = interests;
    await _performSearch();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _interestFilters = [];
    state = const AsyncValue.data([]);
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty && _interestFilters.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      List<UserProfile> results = [];

      if (_interestFilters.isNotEmpty) {
        results =
            await _profileService.searchUsersByInterests(_interestFilters);
      }

      // Apply text search filter if query provided
      if (_searchQuery.isNotEmpty) {
        results = results.where((user) {
          final displayNameMatch = (user.displayName?.toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase());
          final bioMatch = (user.bio?.toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase());
          final interestsMatch = (user.interests ?? []).any((interest) =>
              interest.toLowerCase().contains(_searchQuery.toLowerCase()));
          return displayNameMatch || bioMatch || interestsMatch;
        }).toList();
      }

      state = AsyncValue.data(results);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// Online users provider
final onlineUsersProvider = StreamProvider<List<String>>((ref) async* {
  // This would be a Firestore query for users where presence.isOnline = true
  // For now, return empty list
  yield [];
});

/// User statistics provider
final userStatisticsProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, userId) async* {
  // This would aggregate various user stats
  // For now, return empty map
  yield {};
});

/// Blocked users provider
final blockedUsersProvider = StreamProvider<List<String>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // This would query the blocks collection
  // For now, return empty list
  yield [];
});

/// User followers provider
final userFollowersProvider =
    StreamProvider.family<List<UserProfile>, String>((ref, userId) async* {
  // This would query followers
  // For now, return empty list
  yield [];
});

/// User following provider
final userFollowingProvider =
    StreamProvider.family<List<UserProfile>, String>((ref, userId) async* {
  // This would query following
  // For now, return empty list
  yield [];
});

// âœ… P1.2: USER DISCOVERY WITH PAGINATION SUPPORT
// The ProfileService queries now use .limit(20) to support pagination
// UI implementations should use PaginationController to load users in batches
// This reduces initial load time and Firestore costs significantly
//
// Usage in UI:
// final controller = PaginationController<UserProfile>(
//   queryBuilder: () => FirebaseFirestore.instance.collection('users').limit(20),
//   fromDocument: (doc) => UserProfile.fromFirestore(doc),
// );
// await controller.loadInitial();
// await controller.loadMore();
