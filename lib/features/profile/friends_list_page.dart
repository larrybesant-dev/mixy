import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friends_provider.dart';
import '../../shared/providers/providers.dart';

class FriendsListPage extends ConsumerWidget {
  final String userId;
  const FriendsListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: friendsAsync.when(
        data: (friends) => friends.isEmpty
            ? const Center(child: Text('No friends yet'))
            : ListView(
                children: friends.map((f) {
                  final presenceAsync = ref.watch(presenceProvider(f.friendId));
                  return ListTile(
                    title: Text(f.friendId),
                    subtitle: presenceAsync.when(
                      data: (online) => Text(online ? 'Online' : 'Offline'),
                      loading: () => const Text('Checking...'),
                      error: (e, _) => const Text('Unknown'),
                    ),
                    trailing: Text('Last seen: ${f.lastSeen}'),
                  );
                }).toList(),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading friends: $e')),
      ),
    );
  }
}
