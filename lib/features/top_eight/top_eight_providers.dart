import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';

/// A dummy provider that returns 8 mock user profiles.
final dummyTop8Provider = Provider<List<UserModel>>((ref) {
  return [
    UserModel(
      id: '1',
      email: 'alex@example.com',
      username: 'Alex',
      avatarUrl: 'https://i.pravatar.cc/150?u=1',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '2',
      email: 'jordan@example.com',
      username: 'Jordan',
      avatarUrl: 'https://i.pravatar.cc/150?u=2',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '3',
      email: 'casey@example.com',
      username: 'Casey',
      avatarUrl: 'https://i.pravatar.cc/150?u=3',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '4',
      email: 'taylor@example.com',
      username: 'Taylor',
      avatarUrl: 'https://i.pravatar.cc/150?u=4',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '5',
      email: 'riley@example.com',
      username: 'Riley',
      avatarUrl: 'https://i.pravatar.cc/150?u=5',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '6',
      email: 'morgan@example.com',
      username: 'Morgan',
      avatarUrl: 'https://i.pravatar.cc/150?u=6',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '7',
      email: 'quinn@example.com',
      username: 'Quinn',
      avatarUrl: 'https://i.pravatar.cc/150?u=7',
      createdAt: DateTime.now(),
    ),
    UserModel(
      id: '8',
      email: 'skyler@example.com',
      username: 'Skyler',
      avatarUrl: 'https://i.pravatar.cc/150?u=8',
      createdAt: DateTime.now(),
    ),
  ];
});
