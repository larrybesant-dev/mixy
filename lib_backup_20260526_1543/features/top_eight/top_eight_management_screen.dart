import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../friends/providers/friends_providers.dart';
import 'top_eight_controller.dart';
import '../auth/controllers/auth_controller.dart';

class TopEightManagementScreen extends ConsumerStatefulWidget {
  const TopEightManagementScreen({super.key});

  @override
  ConsumerState<TopEightManagementScreen> createState() =>
      _TopEightManagementScreenState();
}

class _TopEightManagementScreenState
    extends ConsumerState<TopEightManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authControllerProvider).uid ?? '';
    final topEightUsersAsync = ref.watch(topEightUsersProvider(userId));
    final friendsAsync = ref.watch(friendsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF110D0F),
        title: Text(
          'Manage Top 8',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Column(
        children: [
          // Current Top 8 Section
          Expanded(
            flex: 2,
            child: topEightUsersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: Colors.white))),
              data: (topEight) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Your Top 8 (Drag to reorder)',
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (topEight.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Your Top 8 is empty. Add some friends below!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: topEight.length,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(topEightControllerProvider.notifier)
                                .reorderTopEight(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final user = topEight[index];
                            return ListTile(
                              key: ValueKey(user.id),
                              leading: CircleAvatar(
                                backgroundImage: (user.avatarUrl != null &&
                                        user.avatarUrl!.isNotEmpty)
                                    ? CachedNetworkImageProvider(
                                        user.avatarUrl!)
                                    : null,
                                child: (user.avatarUrl == null ||
                                        user.avatarUrl!.isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user.username,
                                  style: const TextStyle(color: Colors.white)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent),
                                    onPressed: () {
                                      ref
                                          .read(topEightControllerProvider
                                              .notifier)
                                          .removeFromTopEight(user.id);
                                    },
                                  ),
                                  const Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(color: Color(0xFFD4AF37), thickness: 0.5),
          // Search/Friends List Section
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: const Color(0xFF1A1416),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: friendsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                        child: Text('Error: $err',
                            style: const TextStyle(color: Colors.white))),
                    data: (friends) {
                      final topEightIds =
                          topEightUsersAsync.value?.map((e) => e.id).toList() ??
                              [];
                      final filteredFriends = friends.where((f) {
                        final matchesSearch =
                            f.username.toLowerCase().contains(_searchQuery);
                        final notInTopEight = !topEightIds.contains(f.id);
                        return matchesSearch && notInTopEight;
                      }).toList();

                      if (filteredFriends.isEmpty) {
                        return const Center(
                          child: Text('No friends found',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = filteredFriends[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (friend.avatarUrl != null &&
                                      friend.avatarUrl!.isNotEmpty)
                                  ? CachedNetworkImageProvider(
                                      friend.avatarUrl!)
                                  : null,
                              child: (friend.avatarUrl == null ||
                                      friend.avatarUrl!.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(friend.username,
                                style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Color(0xFFD4AF37)),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                if (topEightIds.length >= 8) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'You can only have 8 friends in your Top 8!')),
                                  );
                                  return;
                                }
                                try {
                                  await ref
                                      .read(topEightControllerProvider.notifier)
                                      .addToTopEight(friend.id);
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
