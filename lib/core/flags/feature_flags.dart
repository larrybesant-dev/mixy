import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feature flag to enable/disable the Top 8 Friends feature.
final enableTop8FriendsFeature = Provider<bool>((ref) {
  // Set to true for testing purposes as requested.
  return true;
});

/// Feature flag to enable/disable the Friend Request system.
final enableFriendRequestsFeature = Provider<bool>((ref) {
  return true;
});



