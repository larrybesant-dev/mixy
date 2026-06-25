import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import '../models/user_profile_model.dart';

/// Cache ProfileService as a singleton
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Stream user profile data via cached service
final profileProvider = StreamProvider.family<UserProfile?, String>((ref, userId) {
  final profileService = ref.watch(profileServiceProvider);
  return profileService.streamProfile(userId);
});
