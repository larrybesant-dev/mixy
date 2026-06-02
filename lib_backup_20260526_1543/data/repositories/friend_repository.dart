import '../../models/friend_model.dart';

abstract class FriendRepository {
  Future<List<FriendModel>> getFriends(String userId);
  Future<void> addFriend(FriendModel friend);
  Future<void> removeFriend(String friendId);
}
