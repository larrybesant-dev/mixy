import '../../models/friend_model.dart';
import '../../data/repositories/friend_repository.dart';

class AddFriendUseCase {
  final FriendRepository repository;
  AddFriendUseCase(this.repository);
  Future<void> call(FriendModel friend) => repository.addFriend(friend);
}
