import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';

/// A dummy provider that returns a list of mock users who sent friend requests.
/// We use StateProvider so we can modify the list (remove users) when
/// the user clicks 'Accept' or 'Ignore'.
final dummyPendingRequestsProvider = StateProvider<List<UserModel>>((ref) {
  return [
    UserModel(
      id: 'mock_1',
      email: 'sarah@example.com',
      username: 'Sarah Jenkins',
      avatarUrl: 'asset:assets/images/avatars/avatar_4.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: 'mock_2',
      email: 'marcus@example.com',
      username: 'Marcus Vibe',
      avatarUrl: 'asset:assets/images/avatars/avatar_5.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: 'mock_3',
      email: 'luna@example.com',
      username: 'Luna Star',
      avatarUrl: 'asset:assets/images/avatars/avatar_1.png',
      createdAt: DateTime.now(),
    ),
  ];
});
