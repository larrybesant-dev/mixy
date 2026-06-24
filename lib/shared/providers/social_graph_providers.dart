import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/social/social_graph_service.dart';
import '../models/user_profile.dart';
import '../models/user_presence.dart';
import 'user_providers.dart'; // For profileServiceProvider

// Service providers
final socialGraphServiceProvider =
    Provider<SocialGraphService>((ref) => SocialGraphService());

// Followers list provider (stream of user IDs)
final followersIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  final service = ref.watch(socialGraphServiceProvider);
  return service.watchFollowers(userId);
});

// Following list provider (stream of user IDs)
final followingIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  final service = ref.watch(socialGraphServiceProvider);
  return service.watchFollowing(userId);
});

// Mutual friends list provider (stream of user IDs)
final mutualFriendsIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  final service = ref.watch(socialGraphServiceProvider);
  return service.watchMutualFriends(userId);
});

// Is following provider (stream of bool)
final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  final service = ref.watch(socialGraphServiceProvider);
  return service.watchIsFollowing(targetUserId);
});

// Follower profiles provider (FutureProvider for simplicity)
final followerProfilesProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  final service = ref.watch(socialGraphServiceProvider);
  final profileService = ref.watch(profileServiceProvider);

  final ids = await service.getFollowers(userId);
  final profiles = <UserProfile>[];

  for (final id in ids) {
    try {
      final profile = await profileService.getUserProfile(id);
      if (profile != null) {
        profiles.add(profile);
      }
    } catch (e) {
      // Skip profiles that fail to load
      continue;
    }
  }

  return profiles;
});

// Following profiles provider
final followingProfilesProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  final service = ref.watch(socialGraphServiceProvider);
  final profileService = ref.watch(profileServiceProvider);

  final ids = await service.getFollowing(userId);
  final profiles = <UserProfile>[];

  for (final id in ids) {
    try {
      final profile = await profileService.getUserProfile(id);
      if (profile != null) {
        profiles.add(profile);
      }
    } catch (e) {
      // Skip profiles that fail to load
      continue;
    }
  }

  return profiles;
});

// Mutual friends profiles provider
final mutualFriendsProfilesProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, userId) async {
  final service = ref.watch(socialGraphServiceProvider);
  final profileService = ref.watch(profileServiceProvider);

  final ids = await service.getMutualFriends(userId);
  final profiles = <UserProfile>[];

  for (final id in ids) {
    try {
      final profile = await profileService.getUserProfile(id);
      if (profile != null) {
        profiles.add(profile);
      }
    } catch (e) {
      // Skip profiles that fail to load
      continue;
    }
  }

  return profiles;
});

// Suggested users provider (future provider, refreshable)
final suggestedUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final service = ref.watch(socialGraphServiceProvider);
  return service.getSuggestedUsers(limit: 20);
});

// Presence provider (using existing presence service)
final userPresenceProvider =
    StreamProvider.family<UserPresence?, String>((ref, userId) {
  final service = ref.watch(presenceServiceProvider);
  return service.getUserPresence(userId);
});

// Follower/following counts
final followerCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.watch(socialGraphServiceProvider);
  return service.getFollowerCount(userId);
});

final followingCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.watch(socialGraphServiceProvider);
  return service.getFollowingCount(userId);
});

// Follow action provider (for UI interactions)
final followActionProvider =
    FutureProvider.family<void, ({String userId, bool follow})>(
        (ref, params) async {
  final service = ref.watch(socialGraphServiceProvider);

  if (params.follow) {
    await service.followUser(params.userId);
  } else {
    await service.unfollowUser(params.userId);
  }

  // Invalidate related providers to refresh UI
  ref.invalidate(isFollowingProvider(params.userId));
  ref.invalidate(followerCountProvider(params.userId));
});
