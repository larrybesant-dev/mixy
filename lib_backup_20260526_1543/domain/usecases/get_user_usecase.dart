import '../../models/user_model.dart';
import '../../data/repositories/user_repository.dart';

class GetUserUseCase {
  final UserRepository repository;
  GetUserUseCase(this.repository);
  Future<UserModel?> call(String uid) => repository.getUser(uid);
}
