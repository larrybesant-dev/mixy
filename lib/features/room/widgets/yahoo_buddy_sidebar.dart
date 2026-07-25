import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../shared/widgets/guest_auth_gate.dart';
import '../../friends/models/friend_roster_entry.dart';
import '../../friends/providers/friends_providers.dart';
import '../../messaging/providers/messaging_provider.dart';

class YahooBuddySidebar extends ConsumerStatefulWidget {
  const YahooBuddySidebar({
    super.key,
    required this.roomId,
    this.onInviteFriend,
    this.showAsDrawer = false,
  });

  final String roomId;
  final Future<void> Function(UserModel friend)? onInviteFriend;
  final bool showAsDrawer;

  @override
  ConsumerState<YahooBuddySidebar> createState() => _YahooBuddySidebarState();
}

class _YahooBuddySidebarState extends ConsumerState<YahooBuddySidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedFriendId;
  String? _hoveredFriendId;
  bool _collapsed = false;

  final Map<String, bool> _groupExpanded = <String, bool>{
    'favorites': true,
    'online': true,
    'away': true,
    'offline': false,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(friendRosterProvider);
    final favoritesAsync = ref.watch(favoriteFriendIdsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: widget.showAsDrawer ? double.infinity : (_collapsed ? 82 : 320),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VelvetNoir.surfaceHigh,
            VelvetNoir.surface,
          ],
        ),
        border: Border(
          right: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.16)),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (!_collapsed) _buildSearch(),
          Expanded(
            child: rosterAsync.when(
              data: (entries) => favoritesAsync.when(
                data: (favoriteIds) => _buildGroups(entries, favoriteIds),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    _buildSimpleMessage('Could not load favorites.'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _buildSimpleMessage('Could not load buddies.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final canCollapse = !widget.showAsDrawer;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VelvetNoir.primary.withValues(alpha: 0.22),
            VelvetNoir.secondary.withValues(alpha: 0.20),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: VelvetNoir.primary.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          if (!_collapsed)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buddy List',
                    style: GoogleFonts.playfairDisplay(
                      color: VelvetNoir.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yahoo-style roster',
                    style: GoogleFonts.raleway(
                      color: VelvetNoir.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Icon(
                Icons.people_alt_rounded,
                color: VelvetNoir.primary,
              ),
            ),
          if (canCollapse)
            IconButton(
              tooltip: _collapsed ? 'Expand panel' : 'Collapse panel',
              onPressed: () => setState(() => _collapsed = !_collapsed),
              icon: Icon(
                _collapsed
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                color: VelvetNoir.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
        style: GoogleFonts.raleway(color: VelvetNoir.onSurface, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search buddies',
          hintStyle: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, size: 18, color: VelvetNoir.primary),
          filled: true,
          fillColor: VelvetNoir.surfaceLow,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildGroups(
      List<FriendRosterEntry> entries, Set<String> favoriteIds) {
    final visible = entries.where((entry) {
      if (_query.isEmpty) return true;
      return entry.user.username.toLowerCase().contains(_query);
    }).toList(growable: false)
      ..sort((left, right) => left.user.username
          .toLowerCase()
          .compareTo(right.user.username.toLowerCase()));

    final favorites = visible
        .where((e) => favoriteIds.contains(e.friendId))
        .toList(growable: false);
    final nonFavorites = visible
        .where((e) => !favoriteIds.contains(e.friendId))
        .toList(growable: false);
    final online =
        nonFavorites.where((e) => e.isOnline).toList(growable: false);
    final away = nonFavorites
        .where((e) => !e.isOnline && e.isRecentlyActive)
        .toList(growable: false);
    final offline = nonFavorites
        .where((e) => !e.isOnline && !e.isRecentlyActive)
        .toList(growable: false);

    if (visible.isEmpty) {
      return _buildSimpleMessage('No buddies match your search.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      children: [
        _buildGroup('favorites', 'Favorites', favorites, Icons.star_rounded),
        _buildGroup('online', 'Online', online, Icons.bolt_rounded),
        _buildGroup('away', 'Away', away, Icons.schedule_rounded),
        _buildGroup('offline', 'Offline', offline, Icons.nightlight_round),
      ],
    );
  }

  Widget _buildGroup(String key, String title, List<FriendRosterEntry> entries,
      IconData icon) {
    final expanded = _groupExpanded[key] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            leading: Icon(icon, size: 18, color: VelvetNoir.primary),
            title: _collapsed
                ? null
                : Text(
                    '$title (${entries.length})',
                    style: GoogleFonts.raleway(
                      color: VelvetNoir.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            trailing: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: VelvetNoir.onSurfaceVariant,
            ),
            onTap: () => setState(() => _groupExpanded[key] = !expanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            crossFadeState:
                expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                for (final entry in entries) _buildBuddyRow(entry),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBuddyRow(FriendRosterEntry entry) {
    final selected = _selectedFriendId == entry.friendId;
    final hovered = _hoveredFriendId == entry.friendId;
    final avatar = entry.user.avatarUrl;

    return FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            _openProfile(entry.user);
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredFriendId = entry.friendId),
        onExit: (_) => setState(() {
          if (_hoveredFriendId == entry.friendId) {
            _hoveredFriendId = null;
          }
        }),
        child: InkWell(
          onTap: () => setState(() => _selectedFriendId = entry.friendId),
          onDoubleTap: () => _openProfile(entry.user),
          onSecondaryTapDown: (details) =>
              _showRowContextMenu(entry, details.globalPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? VelvetNoir.primary.withValues(alpha: 0.16)
                  : hovered
                      ? VelvetNoir.secondary.withValues(alpha: 0.12)
                      : VelvetNoir.surface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? VelvetNoir.primary.withValues(alpha: 0.55)
                    : hovered
                        ? VelvetNoir.secondary.withValues(alpha: 0.45)
                        : VelvetNoir.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          VelvetNoir.secondary.withValues(alpha: 0.42),
                      backgroundImage: avatar == null || avatar.isEmpty
                          ? null
                          : NetworkImage(avatar),
                      child: avatar == null || avatar.isEmpty
                          ? Text(
                              entry.user.username.isEmpty
                                  ? '?'
                                  : entry.user.username[0].toUpperCase(),
                              style: GoogleFonts.raleway(
                                color: VelvetNoir.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _presenceColor(entry),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: VelvetNoir.surface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_collapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.user.username,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _presenceLabel(entry),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Message',
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                    iconSize: 17,
                    color: VelvetNoir.primary,
                    onPressed: () => _startMessage(entry.user),
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  IconButton(
                    tooltip: 'Invite to room',
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                    iconSize: 17,
                    color: VelvetNoir.primary,
                    onPressed: () async {
                      if (widget.onInviteFriend == null) return;
                      await widget.onInviteFriend!(entry.user);
                    },
                    icon: const Icon(Icons.mark_chat_unread_outlined),
                  ),
                  IconButton(
                    tooltip: 'View profile',
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                    iconSize: 17,
                    color: VelvetNoir.primary,
                    onPressed: () => _openProfile(entry.user),
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _presenceColor(FriendRosterEntry entry) {
    if (entry.isOnline) return const Color(0xFF3CCB7F);
    if (entry.isRecentlyActive) return const Color(0xFFE3A44E);
    return const Color(0xFF667085);
  }

  String _presenceLabel(FriendRosterEntry entry) {
    if (entry.isOnline) {
      if ((entry.roomId ?? '').isNotEmpty) {
        return 'In a room now';
      }
      return 'Online';
    }
    if (entry.isRecentlyActive) return 'Away';
    return 'Offline';
  }

  Widget _buildSimpleMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.raleway(
            color: VelvetNoir.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Future<void> _showRowContextMenu(
      FriendRosterEntry entry, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      color: VelvetNoir.surfaceHigh,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem<String>(value: 'message', child: Text('Message')),
        const PopupMenuItem<String>(
            value: 'invite', child: Text('Invite to room')),
        const PopupMenuItem<String>(
            value: 'profile', child: Text('View profile')),
      ],
    );

    if (!mounted || result == null) return;

    switch (result) {
      case 'message':
        await _startMessage(entry.user);
        break;
      case 'invite':
        if (widget.onInviteFriend != null) {
          await widget.onInviteFriend!(entry.user);
        }
        break;
      case 'profile':
        _openProfile(entry.user);
        break;
    }
  }

  Future<void> _startMessage(UserModel friend) async {
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    final allowed = await GuestAuthGate.requireConversationStart(context, ref);
    if (!allowed || !mounted) return;

    try {
      final conversationId =
          await ref.read(messagingControllerProvider).createDirectConversation(
                userId1: currentUser.id,
                user1Name: currentUser.username,
                user1AvatarUrl: currentUser.avatarUrl,
                userId2: friend.id,
                user2Name: friend.username,
                user2AvatarUrl: friend.avatarUrl,
              );

      if (!mounted) return;
      unawaited(GoRouter.of(context).push('/chat/$conversationId'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $error')),
      );
    }
  }

  void _openProfile(UserModel friend) {
    GoRouter.of(context).push('/profile/${friend.id}');
  }
}
