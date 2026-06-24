// Riverpod provider for UserProfile
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_profile.dart';

class UserProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void setProfile(UserProfile? profile) {
    state = profile;
  }

  void clearProfile() {
    state = null;
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile?>(
  () => UserProfileNotifier(),
);
