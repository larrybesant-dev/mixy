import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/design_system/design_constants.dart';
import '../../core/design_system/app_layout.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/user.dart';
import '../../shared/models/privacy_settings.dart';
// TEMP DISABLED: import '../../shared/models/speed_dating.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';
import '../../core/stubs/dev_stubs.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../room/room_access_wrapper.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final privacySettingsAsync = ref.watch(privacySettingsProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: currentUserAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child: GlowText(
                  text: 'User not found',
                  fontSize: 18,
                  color: Color(0xFFFF4C4C),
                ),
              );
            }

            return privacySettingsAsync.when(
              data: (privacySettings) =>
                  _buildProfileContent(user, privacySettings),
              loading: () => _buildProfileContent(user, null),
              error: (error, stack) => _buildProfileContent(user, null),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
            ),
          ),
          error: (error, stack) => Center(
            child: GlowText(
              text: 'Error: ${error.toString()}',
              fontSize: 16,
              color: const Color(0xFFFF4C4C),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(User user, PrivacySettings? privacySettings) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 300,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildCoverPhoto(user),
          ),
          actions: [
            Semantics(
              label: 'Edit Profile',
              button: true,
              child: IconButton(
                key: const Key('profile-edit-btn'),
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/edit-profile'),
              ),
            ),
            Semantics(
              label: 'Settings',
              button: true,
              child: IconButton(
                key: const Key('profile-settings-btn'),
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: _buildProfileHeader(user, privacySettings),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverAppBarDelegate(
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'About'),
                Tab(text: 'Friends'),
                Tab(text: 'Rooms'),
              ],
              labelColor: const Color(0xFFFFD700),
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFFFF4C4C),
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineTab(user),
          _buildAboutTab(user, privacySettings),
          _buildFriendsTab(user),
          _buildRoomsTab(user),
        ],
      ),
    );
  }

  Widget _buildCoverPhoto(User user) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x80FF4C4C),
            Color(0x99FFD700),
            Color(0x804C4CFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Animated background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E2F).withValues(alpha: 0.1),
                    const Color(0xFFFF4C4C).withValues(alpha: 0.05),
                    const Color(0xFFFFD700).withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ),
          // User avatar positioned at bottom
          Positioned(
            bottom: -(AppSizes.avatarHeroRadius - 6),
            left: AppSpacing.spaceLG,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: DesignColors.accent,
                  width: AppSizes.neonRingWidth + 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DesignColors.accent.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                key: ValueKey(user.avatarUrl),
                radius: AppSizes.avatarHeroRadius,
                backgroundImage: user.avatarUrl.isNotEmpty
                    ? NetworkImage(
                        '${user.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}')
                    : null,
                backgroundColor: DesignColors.accent.withValues(alpha: 0.3),
                child: user.avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: AppSizes.avatarHeroRadius * 0.8,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User user, PrivacySettings? privacySettings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.spaceLG,
          AppSizes.avatarHeroRadius + AppSpacing.spaceLG,
          AppSpacing.spaceLG,
          AppSpacing.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlowText(
                      text: _isFieldVisible('displayName', privacySettings)
                          ? (user.displayName ?? "")
                          : user.username,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: DesignColors.gold,
                      glowColor: DesignColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.spaceXS),
                    Text(
                      _isFieldVisible('displayName', privacySettings)
                          ? '@${user.username}'
                          : 'Private Profile',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              _buildStats(user),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLG),
          if (user.bio.isNotEmpty && _isFieldVisible('bio', privacySettings))
            Text(
              user.bio,
              style: AppTypography.body,
            ),
          const SizedBox(height: AppSpacing.spaceLG),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStats(User user) {
    return Row(
      children: [
        _buildStatItem('${user.followersCount}', 'Followers'),
        const SizedBox(width: AppSpacing.spaceLG),
        _buildStatItem('${user.followingCount}', 'Following'),
        const SizedBox(width: AppSpacing.spaceLG),
        _buildStatItem('${user.liveSessionsHosted}', 'Rooms'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        GlowText(
          text: value,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: DesignColors.gold,
          glowColor: DesignColors.accent,
        ),
        Text(
          label,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Edit Profile',
            button: true,
            child: NeonButton(
              key: const Key('edit-profile-main-btn'),
              onPressed: () => Navigator.of(context).pushNamed('/edit-profile'),
              child: const Text('Edit Profile'),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.spaceMD),
        Expanded(
          child: Semantics(
            label: 'Settings',
            button: true,
            child: NeonButton(
              key: const Key('settings-main-btn'),
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              backgroundColor: Colors.transparent,
              child: const Text('Settings'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab(User user) {
    final userActivityAsync = ref.watch(userActivityProvider(user.id));

    return userActivityAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No recent activity yet.\n\nYour posts, room creations, and interactions will appear here.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.spaceLG),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final type = activity['type'] as String? ?? 'unknown';
            final timestamp = activity['timestamp'] as Timestamp?;
            final description =
                activity['description'] as String? ?? 'Activity';

            return Card(
              color: Colors.white.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(bottom: AppSpacing.spaceMD),
              child: ListTile(
                leading: Icon(
                  _getActivityIcon(type),
                  color: _getActivityColor(type),
                ),
                title: Text(
                  description,
                  style:
                      AppTypography.bodySm.copyWith(color: DesignColors.white),
                ),
                subtitle: timestamp != null
                    ? Text(
                        _formatTimestamp(timestamp.toDate()),
                        style: AppTypography.caption,
                      )
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading activity: $error',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'room_created':
        return Icons.mic;
      case 'message_sent':
        return Icons.message;
      case 'user_joined':
        return Icons.person_add;
      case 'gift_received':
        return Icons.card_giftcard;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'room_created':
        return const Color(0xFFFF4C4C);
      case 'message_sent':
        return const Color(0xFFFFD700);
      case 'user_joined':
        return Colors.green;
      case 'gift_received':
        return Colors.purple;
      default:
        return Colors.white70;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildAboutTab(User user, PrivacySettings? privacySettings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAboutSection(
            'Bio', user.bio, _isFieldVisible('bio', privacySettings)),
        const SizedBox(height: 16),
        _buildAboutSection('Location', user.location,
            _isFieldVisible('location', privacySettings)),
        const SizedBox(height: 16),
        _buildInterestsSection(user, privacySettings),
        const SizedBox(height: 16),
        _buildSocialLinksSection(user, privacySettings),
        const SizedBox(height: 16),
        _buildStatsSection(user),
      ],
    );
  }

  Widget _buildAboutSection(String title, String content, bool isVisible) {
    if (!isVisible || content.isEmpty) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlowText(
            text: title,
            fontSize: 18,
            color: const Color(0xFFFFD700),
            glowColor: const Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(User user, PrivacySettings? privacySettings) {
    if (!_isFieldVisible('interests', privacySettings) ||
        user.interests.isEmpty) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Interests',
            fontSize: 18,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.interests
                .map((interest) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFF4C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0x80FFFF4C),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        interest,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksSection(User user, PrivacySettings? privacySettings) {
    if (!_isFieldVisible('socialLinks', privacySettings) ||
        user.socialLinks.isEmpty) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Social Links',
            fontSize: 18,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 12),
          ...user.socialLinks.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStatsSection(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4DFFFF4C),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlowText(
            text: 'Activity Stats',
            fontSize: 18,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(
                  'Rooms Created', user.liveSessionsHosted.toString()),
              _buildStatColumn('Tips Received',
                  '\$${user.totalTipsReceived.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        GlowText(
          text: value,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFD700),
          glowColor: const Color(0xFFFF4C4C),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFriendsTab(User user) {
    final matchesAsync = ref.watch(speedDatingMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: Color(0xFFFF4C4C),
                      ),
                      const SizedBox(height: 16),
                      const GlowText(
                        text: 'No Speed Dating Matches Yet',
                        fontSize: 20,
                        color: Color(0xFFFFD700),
                        glowColor: Color(0xFFFF4C4C),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try speed dating to find your perfect match!\n\nTap the heart icon in the top bar to start.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        label: 'Start Speed Dating',
                        button: true,
                        child: NeonButton(
                          key: const Key('start-speed-dating-btn'),
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed('/speed-dating-lobby');
                          },
                          child: const Text('Start Speed Dating'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return _buildMatchCard(match, user);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFFF4C4C),
            ),
            const SizedBox(height: 16),
            const GlowText(
              text: 'Failed to load matches',
              fontSize: 18,
              color: Color(0xFFFF4C4C),
              glowColor: Color(0xFFFF4C4C),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Retry loading speed dating matches',
              button: true,
              child: NeonButton(
                key: const Key('retry-matches-btn'),
                onPressed: () {
                  ref.invalidate(speedDatingMatchesProvider);
                },
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(SpeedDatingMatch match, User currentUser) {
    // For now, just show a placeholder since we don't have a user provider
    // TODO: Create a userByIdProvider or use firestore service directly
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2A2A3D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFFFFD700),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile picture placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFFFF4C4C),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFFFF4C4C),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Match info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GlowText(
                        text: 'Speed Dating Match',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                        glowColor: Color(0xFFFF4C4C),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'MATCH',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matched on ${match.matchedAt.toString().split(' ')[0]}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Heart icon
            const Icon(
              Icons.favorite,
              color: Color(0xFFFF4C4C),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsTab(User user) {
    final userRoomsAsync = ref.watch(userRoomsProvider(user.id));

    return userRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No rooms created yet.\n\nGo live to create your first room!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Card(
              color: Colors.white.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  room.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.description,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          room.isLive ? Icons.live_tv : Icons.tv_off,
                          size: 16,
                          color: room.isLive ? Colors.red : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          room.isLive ? 'Live' : 'Ended',
                          style: TextStyle(
                            color: room.isLive ? Colors.red : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.people,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${room.participantIds.length}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: room.isLive
                    ? Semantics(
                        label: 'Join room ${room.name}',
                        button: true,
                        child: NeonButton(
                          key: Key('join-room-${room.id}'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RoomAccessWrapper(
                                room: room,
                                userId: fb_auth.FirebaseAuth.instance
                                        .currentUser?.uid ??
                                    '',
                              ),
                            ),
                          ),
                          child: const Text('Join'),
                        ),
                      )
                    : const Icon(Icons.history, color: Colors.white70),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RoomAccessWrapper(
                      room: room,
                      userId:
                          fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading rooms: $error',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  bool _isFieldVisible(String fieldName, PrivacySettings? privacySettings) {
    if (privacySettings == null) {
      return true; // Default to visible if no settings
    }

    switch (fieldName) {
      case 'displayName':
        return privacySettings.displayName != PrivacyLevel.private;
      case 'avatar':
        return privacySettings.avatar != PrivacyLevel.private;
      case 'bio':
        return privacySettings.bio != PrivacyLevel.private;
      case 'location':
        return privacySettings.location != PrivacyLevel.private;
      case 'interests':
        return privacySettings.interests != PrivacyLevel.private;
      case 'socialLinks':
        return privacySettings.socialLinks != PrivacyLevel.private;
      case 'recentMedia':
        return privacySettings.recentMedia != PrivacyLevel.private;
      case 'roomsCreated':
        return privacySettings.roomsCreated != PrivacyLevel.private;
      case 'tipsReceived':
        return privacySettings.tipsReceived != PrivacyLevel.private;
      default:
        return true;
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
