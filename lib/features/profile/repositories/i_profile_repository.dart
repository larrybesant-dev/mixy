// lib/features/profile/repositories/i_profile_repository.dart
//
// Abstract contract for user-profile operations.
import 'package:mixvy/shared/models/user_profile.dart';

abstract class IProfileRepository {
  /// Fetch a single user profile by UID.
  Future<UserProfile?> getProfile(String uid);

  /// Stream a user profile, emitting updates in real time.
  Stream<UserProfile?> watchProfile(String uid);

  /// Create or fully replace a user profile document.
  Future<void> setProfile(UserProfile profile);

  /// Update selected fields of an existing profile.
  /// Caller must provide the UID of the CURRENT authenticated user.
  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> fields,
  });

  /// Upload a profile avatar and return the download URL.
  Future<String> uploadAvatar({
    required String uid,
    required List<int> imageBytes,
    required String mimeType,
  });

  /// Delete a user profile document (admin / account-deletion path).
  Future<void> deleteProfile(String uid);

  /// Search profiles by display name prefix.
  Future<List<UserProfile>> searchByName(String query, {int limit = 20});
}

