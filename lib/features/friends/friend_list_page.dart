import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/widgets/safe_avatar.dart';
import 'package:mixvy/shared/models/friend_request.dart';
import 'package:mixvy/shared/providers/friend_request_provider.dart';
import 'package:mixvy/shared/providers/friends_provider.dart';
import 'package:mixvy/core/routing/app_routes.dart';

/// Full friend management page.
///
/// Tabs:
///   0 — All Friends
///   1 — Mutual Friends (with a viewed user, or if standalone: top mutuals)
///   2 — Pending Requests
class FriendListPage extends ConsumerStatefulWidget {
  /// When non-null, the Mutual tab shows friends you share with [withUserId].
  final String? withUserId;

  const FriendListPage({super.key, this.withUserId});

  @override
  ConsumerState<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends ConsumerState<FriendListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingFriendRequestCountProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Friends',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: DesignColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(text: 'Friends'),
              const Tab(text: 'Mutual'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Requests'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _AllFriendsTab(query: _query),
                  _MutualFriendsTab(
                    withUserId: widget.withUserId,
                    query: _query,
                  ),
                  _PendingRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search friends…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: DesignColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 0: All Friends
// ─────────────────────────────────────────────────────────────────────────────

class _AllFriendsTab extends ConsumerWidget {
  final String query;
  const _AllFriendsTab({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final filtered = query.isEmpty
        ? friends
        : friends
            .where((f) => f.name.toLowerCase().contains(query))
            .toList();

    if (filtered.isEmpty) {
      return _emptyState('No friends yet', Icons.people_outline);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1, indent: 68),
      itemBuilder: (ctx, i) => _FriendTile(friend: filtered[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Mutual Friends
// ─────────────────────────────────────────────────────────────────────────────

class _MutualFriendsTab extends ConsumerWidget {
  final String? withUserId;
  final String query;

  const _MutualFriendsTab({required this.withUserId, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (withUserId == null) {
      return _emptyState('Open from a user\'s profile to see mutual friends',
          Icons.people);
    }
      // Minimal Mutual Friends row if data is present
      // Removed invalid references to 'user' and 'mutualCount'.

    return FutureBuilder<List<_UserInfo>>(
      future: _fetchMutuals(withUserId!),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent));
        }
        final mutuals = snap.data ?? [];
        final filtered = query.isEmpty
            ? mutuals
            : mutuals
                .where((u) => u.name.toLowerCase().contains(query))
                .toList();
        if (filtered.isEmpty) {
          return _emptyState('No mutual friends', Icons.people_outline);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white10, height: 1, indent: 68),
          itemBuilder: (ctx, i) => _UserInfoTile(user: filtered[i]),
        );
      },
    );
  }

  Future<List<_UserInfo>> _fetchMutuals(String otherId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final myFriendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();
    final myIds = myFriendsSnap.docs.map((d) => d.id).toSet();

    final theirFriendsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherId)
        .collection('friends')
        .get();
    final theirIds = theirFriendsSnap.docs.map((d) => d.id).toSet();

    final mutualIds = myIds.intersection(theirIds).toList();
    if (mutualIds.isEmpty) return [];

    final results = <_UserInfo>[];
    for (var i = 0; i < mutualIds.length; i += 10) {
      final chunk = mutualIds.sublist(
          i, i + 10 > mutualIds.length ? mutualIds.length : i + 10);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        results.add(_UserInfo(
          id: doc.id,
          name: (d['displayName'] as String?)?.isNotEmpty == true
              ? d['displayName'] as String
              : (d['username'] as String?) ?? 'User',
          avatarUrl: (d['photoUrl'] as String?) ??
              (d['avatarUrl'] as String?) ??
              '',
          isOnline: (d['isOnline'] as bool?) ?? false,
        ));
      }
    }
    return results;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Pending Requests
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingFriendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return _emptyState('No pending requests', Icons.mark_email_read_outlined);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const Divider(
            color: Colors.white10,
            height: 1,
            indent: 68,
          ),
          itemBuilder: (ctx, i) =>
              _FriendRequestTile(requestData: requests[i]),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      error: (e, _) =>
          Center(child: Text('Error loading requests', style: TextStyle(color: Colors.red[300]))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiles
// ─────────────────────────────────────────────────────────────────────────────

class _FriendTile extends ConsumerWidget {
  final dynamic friend; // Friend from app_models.dart

  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          SafeAvatar(
            photoUrl: friend.avatarUrl,
            fallbackInitial: friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
            radius: 22,
          ),
          if (friend.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(friend.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.blueAccent),
                SizedBox(width: 4),
                Text(
                  'Friend',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      subtitle: Text(
        friend.isOnline ? 'Online' : 'Last seen recently',
        style: TextStyle(
            color: friend.isOnline
                ? Colors.greenAccent
                : Colors.grey[600],
            fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        color: DesignColors.surfaceLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'message',
              child: Text('Message', style: TextStyle(color: Colors.white))),
          const PopupMenuItem(
              value: 'profile',
              child: Text('View Profile',
                  style: TextStyle(color: Colors.white))),
          const PopupMenuItem(
              value: 'remove',
              child: Text('Remove Friend',
                  style: TextStyle(color: Colors.orangeAccent))),
        ],
        onSelected: (action) => _handleAction(context, ref, action),
      ),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.userProfile,
        arguments: {'userId': friend.id},
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'message':
        Navigator.pushNamed(context, AppRoutes.chat,
            arguments: {'userId': friend.id});
        break;
      case 'profile':
        Navigator.pushNamed(context, AppRoutes.userProfile,
            arguments: {'userId': friend.id});
        break;
      case 'remove':
        final ok = await _confirm(context, 'Remove ${friend.name} as a friend?');
        if (ok) {
          await ref.read(friendServiceProvider).removeFriend(friend.id);
        }
        break;
    }
  }
}

class _FriendRequestTile extends ConsumerWidget {
  final FriendRequest requestData;

  const _FriendRequestTile({required this.requestData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromId = requestData.senderId;
    final name = requestData.senderName ?? fromId;
    final avatar = requestData.senderAvatarUrl ?? '';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SafeAvatar(
        photoUrl: avatar,
        fallbackInitial: name.isNotEmpty ? name[0].toUpperCase() : '?',
        radius: 22,
      ),
      title: Text(name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: const Text('Wants to be your friend',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              await ref.read(friendServiceProvider).rejectFriendRequestFromUser(fromId);
            },
            child: const Text('Decline',
                style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () async {
              await ref.read(friendServiceProvider).acceptFriendRequestFromUser(fromId);
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('You are now friends with $name!', style: const TextStyle(color: Colors.white)),
                    content: const Text('What would you like to do next?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          Navigator.pushNamed(context, AppRoutes.chat, arguments: {'userId': fromId});
                        },
                        child: const Text('Start Chat', style: TextStyle(color: Colors.pinkAccent)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          Navigator.pushNamed(context, AppRoutes.userProfile, arguments: {'userId': fromId});
                        },
                        child: const Text('View Profile', style: TextStyle(color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Accept',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.userProfile,
        arguments: {'userId': fromId},
      ),
    );
  }
}

class _UserInfoTile extends StatelessWidget {
  final _UserInfo user;

  const _UserInfoTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SafeAvatar(
        photoUrl: user.avatarUrl,
        fallbackInitial: user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        radius: 22,
      ),
      // subtitle removed, add any valid subtitle here if needed
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _emptyState(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Colors.white24),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(color: Colors.white38, fontSize: 15)),
      ],
    ),
  );
}

Future<bool> _confirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: DesignColors.surfaceDefault,
          content: Text(message,
              style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm',
                  style: TextStyle(
                      color: Colors.pinkAccent,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ??
      false;
}

class _UserInfo {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;

  const _UserInfo({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
  });
}

