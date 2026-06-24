/// Friends List Panel - Sliding drawer panel for friends list
///
/// A lightweight, animated sliding panel showing friends list with
/// quick actions. Designed to overlay from the right side of the screen.
///
/// Usage:
/// ```dart
/// Stack(
///   children: [
///     // Main content
///     FriendsListPanel(
///       isOpen: _showFriends,
///       onClose: () => setState(() => _showFriends = false),
///     ),
///   ],
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/design_system/design_constants.dart';
import '../../app/app_routes.dart';
import 'gift_selector.dart';
import 'pop_out_avatar.dart';

/// Sliding friends list panel
class FriendsListPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const FriendsListPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<FriendsListPanel> createState() => _FriendsListPanelState();
}

class _FriendsListPanelState extends State<FriendsListPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    if (widget.isOpen) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FriendsListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) return const SizedBox.shrink();

        return Stack(
          children: [
            // Background overlay
            if (_controller.value > 0)
              GestureDetector(
                onTap: widget.onClose,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),

            // Panel
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SlideTransition(
                position: _offsetAnimation,
                child: _buildPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: DesignColors.surfaceDefault,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildFriendsList()),
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignColors.accent, DesignColors.tertiary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
        style: const TextStyle(color: DesignColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search friends...',
          hintStyle: const TextStyle(color: DesignColors.textGray),
          prefixIcon: const Icon(Icons.search, color: DesignColors.textGray),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: DesignColors.textGray),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: DesignColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Sign in to see friends',
          style: TextStyle(color: DesignColors.textGray),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .snapshots(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: DesignColors.accent),
          );
        }

        if (!friendsSnapshot.hasData || friendsSnapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final friendIds = friendsSnapshot.data!.docs.map((d) => d.id).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendIds.take(10).toList())
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: DesignColors.accent),
              );
            }

            var friends = usersSnapshot.data!.docs;

            // Filter by search query
            if (_searchQuery.isNotEmpty) {
              friends = friends.where((doc) {
                final name =
                    (doc['displayName'] ?? '').toString().toLowerCase();
                final username =
                    (doc['username'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    username.contains(_searchQuery);
              }).toList();
            }

            // Sort: online first
            friends.sort((a, b) {
              final aOnline =
                  a['isOnline'] == true || a['presence'] == 'online';
              final bOnline =
                  b['isOnline'] == true || b['presence'] == 'online';
              if (aOnline && !bOnline) return -1;
              if (!aOnline && bOnline) return 1;
              return 0;
            });

            if (friends.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: friends.length,
              itemBuilder: (context, index) => _buildFriendTile(friends[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: DesignColors.textGray.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No friends yet',
            style: TextStyle(
              color: DesignColors.textGray,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              widget.onClose();
              Navigator.pushNamed(context, AppRoutes.discoverUsers);
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Find Friends'),
            style: TextButton.styleFrom(foregroundColor: DesignColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(QueryDocumentSnapshot friend) {
    final data = friend.data() as Map<String, dynamic>;
    final isOnline = data['isOnline'] == true || data['presence'] == 'online';
    final displayName = data['displayName'] ?? 'User';
    final avatarUrl = data['avatarUrl'] ?? data['avatar'] ?? '';
    final status = data['statusMessage'] ?? data['status'] ?? '';
    final currentRoomId = data['currentRoomId'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              _showFriendActions(friend.id, displayName, currentRoomId),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    PopOutAvatar(
                      uid: friend.id,
                      tooltip: displayName,
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: DesignColors.accent20,
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: DesignColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: DesignColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: DesignColors.surfaceLight,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: DesignColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (status.isNotEmpty)
                        Text(
                          status,
                          style: const TextStyle(
                            color: DesignColors.textGray,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // In room indicator
                if (currentRoomId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam,
                          size: 14,
                          color: DesignColors.secondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: DesignColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFriendActions(String friendId, String friendName, String? roomId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              friendName,
              style: const TextStyle(
                color: DesignColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildActionTile(
              icon: Icons.message,
              label: 'Message',
              color: DesignColors.accent,
              onTap: () {
                Navigator.pop(ctx);
                widget.onClose();
                Navigator.pushNamed(
                  context,
                  AppRoutes.chat,
                  arguments: {'recipientId': friendId},
                );
              },
            ),
            if (roomId != null)
              _buildActionTile(
                icon: Icons.videocam,
                label: 'Join Room',
                color: DesignColors.secondary,
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onClose();
                  Navigator.pushNamed(
                    context,
                    '${AppRoutes.room}/$roomId',
                    arguments: roomId,
                  );
                },
              ),
            _buildActionTile(
              icon: Icons.card_giftcard,
              label: 'Send Gift',
              color: DesignColors.gold,
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => GiftSelector(
                    receiverId: friendId,
                    receiverName: friendName,
                    roomId: '',
                  ),
                );
              },
            ),
            _buildActionTile(
              icon: Icons.person,
              label: 'View Profile',
              color: DesignColors.tertiary,
              onTap: () {
                Navigator.pop(ctx);
                widget.onClose();
                Navigator.pushNamed(
                  context,
                  AppRoutes.userProfile,
                  arguments: friendId,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: DesignColors.textGray,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: DesignColors.surfaceLight,
        onTap: onTap,
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        color: DesignColors.surfaceLight,
        border: Border(
          top: BorderSide(color: DesignColors.divider),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(Icons.home, 'Home', AppRoutes.home),
            _buildNavButton(
                Icons.video_camera_front, 'Rooms', AppRoutes.browseRooms),
            // Speed Dating removed - feature disabled
            // _buildNavButton(Icons.casino, 'Dating', AppRoutes.speedDatingLobby),
            _buildNavButton(
                Icons.account_balance_wallet, 'Wallet', AppRoutes.wallet),
            _buildNavButton(Icons.person, 'Profile', AppRoutes.profile),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, String route) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, color: DesignColors.textGray),
        onPressed: () {
          widget.onClose();
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }
}
