import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/core/responsive/responsive_utils.dart';
import 'package:mixmingle/core/animations/app_animations.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/app/app_routes.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixmingle/shared/widgets/skeleton_loaders.dart';
import 'package:mixmingle/shared/widgets/follow_button.dart';
import 'package:mixmingle/services/events/reporting_service.dart' as reporting;
import 'package:mixmingle/features/reporting/report_dialog.dart';
import 'package:mixmingle/core/analytics/analytics_service.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'screen_profile');
    AnalyticsService.instance.logDiscoverUserViewed(userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final profileUserId = widget.userId;
    final isOwnProfile = profileUserId == currentUser?.id;

    final profileAsync = ref.watch(userProfileProvider(profileUserId));

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AsyncValueViewEnhanced(
          value: profileAsync,
          maxRetries: 3,
          skeleton: const SkeletonProfileHeader(),
          screenName: 'UserProfilePage',
          providerName: 'userProfileProvider',
          onRetry: () => ref.invalidate(userProfileProvider(profileUserId)),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found'));
            }

            return CustomScrollView(
              slivers: [
                // App bar with profile image
                SliverAppBar(
                  expandedHeight: Responsive.responsiveValue(
                    context: context,
                    mobile: 300.0,
                    tablet: 350.0,
                    desktop: 400.0,
                  ),
                  pinned: true,
                  actions: [
                    if (isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context)
                              .pushNamed(AppRoutes.editProfile);
                        },
                      ),
                    if (!isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () =>
                            _showOptionsMenu(context, ref, profileUserId),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                                Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                        // Profile content
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                height:
                                    Responsive.responsiveSpacing(context, 60)),
                            // Profile image
                            AppAnimations.scaleIn(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: Responsive.responsiveValue(
                                      context: context,
                                      mobile: 60.0,
                                      tablet: 75.0,
                                      desktop: 90.0,
                                    ),
                                    backgroundImage: profile.profileImageUrl !=
                                            null
                                        ? NetworkImage(profile.profileImageUrl!)
                                        : null,
                                    child: profile.profileImageUrl == null
                                        ? Icon(
                                            Icons.person,
                                            size: Responsive.responsiveIconSize(
                                                context, 60),
                                          )
                                        : null,
                                  ),
                                  if (profile.isOnline)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).cardColor,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                                height:
                                    Responsive.responsiveSpacing(context, 16)),
                            // Username
                            AppAnimations.fadeIn(
                              child: Text(
                                profile.username ?? 'User',
                                style: TextStyle(
                                  fontSize: Responsive.responsiveFontSize(
                                      context, 28),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 3.0,
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (profile.age != null || profile.location != null)
                              SizedBox(
                                  height:
                                      Responsive.responsiveSpacing(context, 8)),
                            AppAnimations.fadeIn(
                              child: Text(
                                [
                                  if (profile.age != null)
                                    '${profile.age} years old',
                                  if (profile.location != null)
                                    profile.location,
                                ].join(' â€¢ '),
                                style: TextStyle(
                                  fontSize: Responsive.responsiveFontSize(
                                      context, 16),
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Profile content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: Responsive.responsivePadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bio
                        if (profile.bio != null) ...[
                          AppAnimations.slideInFromBottom(
                            beginOffset: 20,
                            child: Card(
                              child: Padding(
                                padding: Responsive.responsivePadding(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: Responsive.responsiveIconSize(
                                              context, 20),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        SizedBox(
                                            width: Responsive.responsiveSpacing(
                                                context, 8)),
                                        Text(
                                          'About',
                                          style: TextStyle(
                                            fontSize:
                                                Responsive.responsiveFontSize(
                                                    context, 18),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        height: Responsive.responsiveSpacing(
                                            context, 12)),
                                    Text(
                                      profile.bio!,
                                      style: TextStyle(
                                        fontSize: Responsive.responsiveFontSize(
                                            context, 16),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              height:
                                  Responsive.responsiveSpacing(context, 16)),
                        ],

                        // Interests
                        if (profile.interests != null &&
                            profile.interests!.isNotEmpty) ...[
                          AppAnimations.slideInFromBottom(
                            beginOffset: 30,
                            child: Card(
                              child: Padding(
                                padding: Responsive.responsivePadding(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite_outline,
                                          size: Responsive.responsiveIconSize(
                                              context, 20),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        SizedBox(
                                            width: Responsive.responsiveSpacing(
                                                context, 8)),
                                        Text(
                                          'Interests',
                                          style: TextStyle(
                                            fontSize:
                                                Responsive.responsiveFontSize(
                                                    context, 18),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        height: Responsive.responsiveSpacing(
                                            context, 12)),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          profile.interests!.map((interest) {
                                        return Chip(
                                          label: Text(interest),
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              height:
                                  Responsive.responsiveSpacing(context, 16)),
                        ],

                        // Stats
                        AppAnimations.slideInFromBottom(
                          beginOffset: 40,
                          child: _buildStatsCard(context, ref, profileUserId),
                        ),
                        SizedBox(
                            height: Responsive.responsiveSpacing(context, 100)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: !isOwnProfile && currentUser != null
            ? _buildActionButtons(context, ref, profileUserId)
            : null,
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, WidgetRef ref, String userId) {
    return Card(
      child: Padding(
        padding: Responsive.responsivePadding(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(context, 'Matches', '0'),
            _buildStatItem(context, 'Events', '0'),
            _buildStatItem(context, 'Rooms', '0'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 24),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: Responsive.responsiveSpacing(context, 4)),
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.responsiveFontSize(context, 14),
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, String userId) {
    final currentUser = ref.watch(currentUserProvider).value;

    return Container(
      padding: Responsive.responsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Follow button row
            if (currentUser != null)
              Padding(
                padding: EdgeInsets.only(
                    bottom: Responsive.responsiveSpacing(context, 12)),
                child: SizedBox(
                  width: double.infinity,
                  child: FollowButton(
                    currentUserId: currentUser.id,
                    targetUserId: userId,
                  ),
                ),
              ),
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.chat,
                        arguments: {'userId': userId},
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                  ),
                ),
                SizedBox(width: Responsive.responsiveSpacing(context, 16)),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(matchControllerProvider.notifier)
                          .like(userId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Like sent!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.favorite),
                    label: const Text('Like'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block User'),
              onTap: () async {
                Navigator.pop(context);
                final currentUser = await ref.read(currentUserProvider.future);
                if (currentUser != null) {
                  await ref
                      .read(moderationControllerProvider.notifier)
                      .blockUser(currentUser.id, userId);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report User'),
              onTap: () async {
                Navigator.pop(context);

                // Get user profile for name
                final profile =
                    await ref.read(userProfileProvider(userId).future);

                if (context.mounted) {
                  final submitted = await showReportDialog(
                    context: context,
                    type: reporting.ReportType.user,
                    reportedId: userId,
                    reportedName: profile?.displayName,
                  );

                  // Dialog already shows success message if submitted
                  if (submitted == true && context.mounted) {
                    // Optionally navigate away from this user's profile
                    // Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
