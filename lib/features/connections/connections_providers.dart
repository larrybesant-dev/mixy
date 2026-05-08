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
      avatarUrl: 'https://i.pravatar.cc/150?u=10',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: 'mock_2',
      email: 'marcus@example.com',
      username: 'Marcus Vibe',
      avatarUrl: 'https://i.pravatar.cc/150?u=11',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: 'mock_3',
      email: 'luna@example.com',
      username: 'Luna Star',
      avatarUrl: 'https://i.pravatar.cc/150?u=12',
      createdAt: DateTime.now(),
    ),
  ];
});
