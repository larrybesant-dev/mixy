// lib/models/user_profile_model.dart

class UserProfileModel {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String bio;

  UserProfileModel({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
  });
}
