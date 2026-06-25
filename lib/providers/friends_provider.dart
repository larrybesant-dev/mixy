import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import '../services/friends_service.dart';
import '../models/friend_model.dart';

/// Cache FriendsService as a singleton
final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService();
});

/// Stream user friends via cached service
final friendsProvider = StreamProvider.family<List<Friend>, String>((ref, userId) {
  final friendsService = ref.watch(friendsServiceProvider);
  return friendsService.streamFriends(userId);
});
