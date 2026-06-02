import '../../models/user_model.dart';

abstract class UserRepository {
  Future<UserModel?> getUser(String uid);
  Future<void> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String uid);
}
