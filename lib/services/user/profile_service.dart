import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/user_profile.dart';
import '../../core/utils/cache_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!..['id'] = doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      // Check cache first
      final cached = AppCaches.userProfiles.get(userId);
      if (cached != null) {
        return cached;
      }

      // Fetch from Firestore
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!..['id'] = doc.id);
        // Cache the result
        AppCaches.userProfiles.put(userId, profile);
        return profile;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Stream user profile by ID
  Stream<UserProfile?> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data()!..['id'] = doc.id);
      }
      return null;
    });
  }

  // Create or update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      // Defensive guard: recover empty id from live auth session
      String resolvedId = profile.id;
      if (resolvedId.isEmpty) {
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception(
              'Cannot update profile: no authenticated user and profile id is empty');
        }
        resolvedId = currentUser.uid;
        debugPrint(
            '⚠️ [ProfileService] profile.id was empty — using auth UID: $resolvedId');
      }

      // Primary write — existing users collection (backward compatible)
      await _firestore.collection('users').doc(resolvedId).set(
            profile.toMap()..['id'] = resolvedId,
            SetOptions(merge: true),
          );

      // Dual-write to split collections (non-blocking, best-effort)
      unawaited(_firestore
          .collection('profiles_public')
          .doc(resolvedId)
          .set(profile.toPublicMap(), SetOptions(merge: true))
          .catchError((e) => debugPrint(
              '⚠️ [ProfileService] profiles_public sync failed: $e')));

      unawaited(_firestore
          .collection('profiles_private')
          .doc(resolvedId)
          .set(profile.toPrivateMap(), SetOptions(merge: true))
          .catchError((e) => debugPrint(
              '⚠️ [ProfileService] profiles_private sync failed: $e')));

      // Invalidate cache after update
      AppCaches.userProfiles.remove(resolvedId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ─── Split-collection read/write methods ────────────────────

  /// Read public profile for any user (uses profiles_public collection).
  Future<UserProfile?> getPublicProfile(String userId) async {
    try {
      final doc =
          await _firestore.collection('profiles_public').doc(userId).get();
      if (!doc.exists) {
        // Fall back to users collection for profiles not yet migrated
        return getUserProfile(userId);
      }
      // Reconstruct with minimal safe fields; full model requires private data too
      final data = doc.data()!..['id'] = userId;
      // Merge with a stub for required private fields so fromMap doesn't crash
      data['email'] ??= '';
      return UserProfile.fromMap(data);
    } catch (e) {
      throw Exception('Failed to get public profile: $e');
    }
  }

  /// Stream public profile for any user.
  Stream<UserProfile?> streamPublicProfile(String userId) {
    return _firestore
        .collection('profiles_public')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!..['id'] = userId;
      data['email'] ??= '';
      try {
        return UserProfile.fromMap(data);
      } catch (_) {
        return null;
      }
    });
  }

  /// Update only the private settings for the owner.
  /// Enforces that only the currently authenticated user can update their own private data.
  Future<void> updatePrivateSettings(
      String userId, Map<String, dynamic> settings) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Cannot update private settings: no authenticated user');
    }
    if (currentUser.uid != userId) {
      throw Exception(
          'Cannot update private settings: userId does not match authenticated user');
    }
    try {
      await _firestore.collection('profiles_private').doc(userId).set(
            settings..['updatedAt'] = FieldValue.serverTimestamp(),
            SetOptions(merge: true),
          );
    } catch (e) {
      throw Exception('Failed to update private settings: $e');
    }
  }

  // Create initial profile for new user
  Future<void> createInitialProfile(
      String userId, String email, String displayName) async {
    final profile = UserProfile(
      id: userId,
      email: email,
      displayName: displayName,
      bio: '',
      birthday: DateTime.now().subtract(const Duration(days: 365 * 18)),
      gender: 'Not specified',
      interests: [],
      galleryPhotos: [],
      location: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await updateUserProfile(profile);
  }

  // Update user online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update online status: $e');
    }
  }

  // Search users by interests
  Future<List<UserProfile>> searchUsersByInterests(
      List<String> interests) async {
    try {
      final query = _firestore
          .collection('users')
          .where('interests', arrayContainsAny: interests);
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data()..['id'] = doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Get users near location (simplified - would need geolocation package for real implementation)
  Future<List<UserProfile>> getNearbyUsers(
      double latitude, double longitude, double radiusKm) async {
    try {
      // This is a simplified version. In production, you'd use geohashing or GeoFirestore
      final query = _firestore.collection('users');
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data()..['id'] = doc.id))
          .where((profile) =>
              _isWithinRadius(profile, latitude, longitude, radiusKm))
          .toList();
    } catch (e) {
      throw Exception('Failed to get nearby users: $e');
    }
  }

  bool _isWithinRadius(
      UserProfile profile, double lat, double lng, double radiusKm) {
    // Check if profile has location data
    if (profile.latitude == null || profile.longitude == null) {
      return false;
    }

    // Haversine distance calculation
    const double earthRadius = 6371; // km
    final dLat = (profile.latitude! - lat) * (pi / 180);
    final dLng = (profile.longitude! - lng) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat) * cos(profile.latitude!) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;
    return distance <= radiusKm;
  }

  // Stream current user profile
  Stream<UserProfile?> streamCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!..['id'] = doc.id);
      }
      return null;
    });
  }

  // Stream user profile by ID
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!..['id'] = doc.id);
      }
      return null;
    });
  }

  // Follow a user
  Future<void> followUser(String followerId, String followingId) async {
    if (followerId == followingId) {
      throw Exception('Cannot follow yourself');
    }

    try {
      final batch = _firestore.batch();

      // Add to followers sub-collection
      batch.set(
        _firestore
            .collection('users')
            .doc(followingId)
            .collection('followers')
            .doc(followerId),
        {'timestamp': FieldValue.serverTimestamp()},
      );

      // Add to following sub-collection
      batch.set(
        _firestore
            .collection('users')
            .doc(followerId)
            .collection('following')
            .doc(followingId),
        {'timestamp': FieldValue.serverTimestamp()},
      );

      // Update follower counts
      batch.update(
        _firestore.collection('users').doc(followerId),
        {'followingCount': FieldValue.increment(1)},
      );

      batch.update(
        _firestore.collection('users').doc(followingId),
        {'followersCount': FieldValue.increment(1)},
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      final batch = _firestore.batch();

      // Remove from followers sub-collection
      batch.delete(
        _firestore
            .collection('users')
            .doc(followingId)
            .collection('followers')
            .doc(followerId),
      );

      // Remove from following sub-collection
      batch.delete(
        _firestore
            .collection('users')
            .doc(followerId)
            .collection('following')
            .doc(followingId),
      );

      // Update follower counts
      batch.update(
        _firestore.collection('users').doc(followerId),
        {'followingCount': FieldValue.increment(-1)},
      );

      batch.update(
        _firestore.collection('users').doc(followingId),
        {'followersCount': FieldValue.increment(-1)},
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  // Check if following a user
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followingId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Stream following status
  Stream<bool> streamIsFollowing(String followerId, String followingId) {
    return _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(followingId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Get followers list
  Future<List<String>> getFollowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // Get following list
  Future<List<String>> getFollowing(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // Search users by name or username
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final lowerQuery = query.toLowerCase();
      final snapshot = await _firestore.collection('users').get();

      return snapshot.docs
          .map((doc) => UserProfile.fromMap(doc.data()..['id'] = doc.id))
          .where((profile) {
            final displayName = (profile.displayName ?? '').toLowerCase();
            final nickname = (profile.nickname ?? '').toLowerCase();
            return displayName.contains(lowerQuery) ||
                nickname.contains(lowerQuery);
          })
          .take(20)
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Get rooms created by user
  Future<List<String>> getUserRooms(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('hostId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // Stream user rooms
  Stream<List<String>> streamUserRooms(String userId) {
    return _firestore
        .collection('rooms')
        .where('hostId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}
