import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../../services/user/profile_service.dart';
import '../../services/storage/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'video_media_providers.dart'; // Import to use storageServiceProvider

// Profile service provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Current user profile provider - REAL-TIME STREAM
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.streamCurrentUserProfile();
});

// User profile by ID provider - REAL-TIME STREAM
final userProfileProvider =
    StreamProvider.family<UserProfile?, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.streamUserProfile(userId);
});

// Following status provider - REAL-TIME STREAM
final isFollowingProvider =
    StreamProvider.family<bool, Map<String, String>>((ref, params) {
  final profileService = ref.watch(profileServiceProvider);
  final followerId = params['followerId']!;
  final followingId = params['followingId']!;
  return profileService.streamIsFollowing(followerId, followingId);
});

// User rooms provider - REAL-TIME STREAM (returns room IDs)
final userRoomIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.streamUserRooms(userId);
});

// Nearby users provider
final nearbyUsersProvider =
    FutureProvider.family<List<UserProfile>, Map<String, dynamic>>(
        (ref, params) async {
  final profileService = ref.watch(profileServiceProvider);
  final latitude = params['latitude'] as double;
  final longitude = params['longitude'] as double;
  final radiusKm = params['radiusKm'] as double? ?? 10.0;
  return profileService.getNearbyUsers(latitude, longitude, radiusKm);
});

// Search users by interests provider
final searchUsersByInterestsProvider =
    FutureProvider.family<List<UserProfile>, List<String>>(
        (ref, interests) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.searchUsersByInterests(interests);
});

// Search users by query provider
final searchUsersProvider =
    FutureProvider.family<List<UserProfile>, String>((ref, query) async {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.searchUsers(query);
});

// Profile controller for mutations
final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(
    ref.read(profileServiceProvider),
    ref.read(storageServiceProvider),
  );
});

class ProfileController {
  final ProfileService _profileService;
  final StorageService _storageService;

  ProfileController(this._profileService, this._storageService);

  Future<void> updateProfile(UserProfile profile) async {
    try {
      await _profileService.updateUserProfile(profile);
      // Sync displayName to Firebase Auth so the loading fallback can
      // distinguish new users (null displayName) from returning ones.
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && (profile.displayName ?? '').isNotEmpty) {
        await firebaseUser.updateDisplayName(profile.displayName);
        debugPrint(
            '✅ [ProfileController] Firebase Auth displayName synced: ${profile.displayName}');
      }
    } catch (e) {
      debugPrint('Failed to update profile: $e');
      rethrow;
    }
  }

  Future<void> createInitialProfile(
      String userId, String email, String displayName) async {
    try {
      await _profileService.createInitialProfile(userId, email, displayName);
    } catch (e) {
      debugPrint('Failed to create initial profile: $e');
      rethrow;
    }
  }

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _profileService.updateOnlineStatus(userId, isOnline);
    } catch (e) {
      debugPrint('Failed to update online status: $e');
    }
  }

  Future<void> followUser(String followerId, String followingId) async {
    try {
      await _profileService.followUser(followerId, followingId);
    } catch (e) {
      debugPrint('Failed to follow user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      await _profileService.unfollowUser(followerId, followingId);
    } catch (e) {
      debugPrint('Failed to unfollow user: $e');
      rethrow;
    }
  }

  Future<String?> uploadAvatar(XFile image, String userId) async {
    try {
      return await _storageService.uploadAvatar(image, userId);
    } catch (e) {
      debugPrint('Failed to upload avatar: $e');
      rethrow;
    }
  }

  Future<String?> uploadCoverPhoto(XFile image, String userId) async {
    try {
      return await _storageService.uploadCoverPhoto(image, userId);
    } catch (e) {
      debugPrint('Failed to upload cover photo: $e');
      rethrow;
    }
  }

  Future<String?> uploadGalleryPhoto(XFile image, String userId) async {
    try {
      return await _storageService.uploadGalleryPhoto(image, userId);
    } catch (e) {
      debugPrint('Failed to upload gallery photo: $e');
      rethrow;
    }
  }

  Future<void> deleteGalleryPhoto(String photoUrl) async {
    try {
      await _storageService.deleteFile(photoUrl);
    } catch (e) {
      debugPrint('Failed to delete gallery photo: $e');
      rethrow;
    }
  }
  Future<String?> uploadGalleryVideo(XFile video, String userId) async {
    try {
      return await _storageService.uploadGalleryVideo(video, userId);
    } catch (e) {
      debugPrint('Failed to upload gallery video: $e');
      rethrow;
    }
  }}
