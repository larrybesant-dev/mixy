import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import 'top_eight_controller.dart';

/// A provider that decides which data to show for the Top 8 carousel.
/// If real data exists and isn't empty, it shows that. Otherwise, it shows dummy data
/// for testing/demo purposes.
final topEightDisplayProvider = FutureProvider.autoDispose.family<List<UserModel>, String>((ref, userId) async {
  try {
    final realUsers = await ref.watch(topEightUsersProvider(userId).future);
    if (realUsers.isNotEmpty) {
      return realUsers;
    }
  } catch (_) {
    // Fallback to dummy data if error or empty
  }
  
  return ref.watch(dummyTop8Provider);
});

/// A dummy provider that returns 8 mock user profiles.
final dummyTop8Provider = Provider<List<UserModel>>((ref) {
  return [
    UserModel(
      id: '1',
      email: 'alex@example.com',
      username: 'Alex',
      avatarUrl: 'asset:assets/images/avatars/avatar_1.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '2',
      email: 'jordan@example.com',
      username: 'Jordan',
      avatarUrl: 'asset:assets/images/avatars/avatar_2.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '3',
      email: 'casey@example.com',
      username: 'Casey',
      avatarUrl: 'asset:assets/images/avatars/avatar_3.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '4',
      email: 'taylor@example.com',
      username: 'Taylor',
      avatarUrl: 'asset:assets/images/avatars/avatar_4.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '5',
      email: 'riley@example.com',
      username: 'Riley',
      avatarUrl: 'asset:assets/images/avatars/avatar_5.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '6',
      email: 'morgan@example.com',
      username: 'Morgan',
      avatarUrl: 'asset:assets/images/avatars/avatar_1.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '7',
      email: 'quinn@example.com',
      username: 'Quinn',
      avatarUrl: 'asset:assets/images/avatars/avatar_2.png',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '8',
      email: 'skyler@example.com',
      username: 'Skyler',
      avatarUrl: 'asset:assets/images/avatars/avatar_3.png',
      createdAt: DateTime.now(),
    ),
  ];
});
