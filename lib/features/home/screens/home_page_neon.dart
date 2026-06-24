import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/app/app_routes.dart';
import 'package:mixmingle/shared/providers/profile_completion_providers.dart';
import 'package:mixmingle/core/theme/neon_widgets.dart';
import 'package:mixmingle/core/theme/colors.dart';

class HomePageNeon extends ConsumerWidget {
  const HomePageNeon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsOnboarding = ref.watch(needsOnboardingProvider);
    final user = FirebaseAuth.instance.currentUser;

    // Redirect to onboarding if profile is incomplete
    if (needsOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.onboarding,
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo with glow effect
                  _buildLogoSection(context),

                  const SizedBox(height: 32),

                  // Welcome message
                  NeonText(
                    'WELCOME BACK',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                    glowColor: ClubColors.primary,
                    glowSize: 12,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    user?.email ?? 'Party Starter',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ClubColors.textSecondary,
                        ),
                  ),

                  const SizedBox(height: 40),

                  // Main action buttons grid
                  _buildMainActionsGrid(context),

                  const SizedBox(height: 32),

                  // Feature cards
                  _buildFeatureCardsSection(context),

                  const SizedBox(height: 32),

                  // Bottom action
                  _buildBottomAction(context),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'home_neon_go_live_fab',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.createRoom),
          backgroundColor: ClubColors.primary,
          label: const Text(
            'GO LIVE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          icon: const Icon(Icons.fiber_smart_record),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    return Column(
      children: [
        // Logo container with animated glow
        AnimatedNeonBorder(
          color: ClubColors.primary,
          duration: const Duration(seconds: 3),
          borderRadius: 24,
          borderWidth: 2,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  ClubColors.cardBackground,
                  ClubColors.cardBackground.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image doesn't load
                  return Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [ClubColors.primary, ClubColors.secondary],
                      ),
                    ),
                    child: const Icon(
                      Icons.music_note,
                      size: 48,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Brand name
        NeonText(
          'MIX & MINGLE',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
          glowColor: ClubColors.secondary,
          glowSize: 10,
        ),

        const SizedBox(height: 4),

        NeonText(
          'GLOBAL DJ VIBES',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ClubColors.secondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildMainActionsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionCard(
          context,
          icon: Icons.person,
          label: 'Profile',
          route: AppRoutes.profile,
          color: ClubColors.secondary,
        ),
        _buildActionCard(
          context,
          icon: Icons.favorite,
          label: 'Matches',
          route: AppRoutes.matches,
          color: ClubColors.primary,
        ),
        _buildActionCard(
          context,
          icon: Icons.chat,
          label: 'Chats',
          route: AppRoutes.chats,
          color: ClubColors.accent,
        ),
        _buildActionCard(
          context,
          icon: Icons.live_tv,
          label: 'Discover',
          route: AppRoutes.discoverRooms,
          color: ClubColors.accentPurple,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return NeonGlowBox(
      glowColor: color,
      glowSize: 12,
      padding: EdgeInsets.zero,
      borderRadius: 16,
      animate: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCardsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(
          'FEATURED',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
          glowColor: ClubColors.secondary,
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          context,
          title: 'Create Your Room',
          description:
              'Host your own live broadcast and connect with the world',
          icon: Icons.video_camera_front,
          color: ClubColors.primary,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          title: 'Find Your Vibe',
          description: 'Browse live rooms and discover amazing performances',
          icon: Icons.search,
          color: ClubColors.secondary,
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          title: 'Connect & Chat',
          description: 'Message other users and build your community',
          icon: Icons.message,
          color: ClubColors.accent,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return NeonGlowBox(
      glowColor: color,
      glowSize: 10,
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ClubColors.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Column(
      children: [
        const NeonDivider(color: ClubColors.secondary, glow: true),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIconButton(
              context,
              icon: Icons.settings,
              label: 'Settings',
              route: AppRoutes.settings,
            ),
            _buildIconButton(
              context,
              icon: Icons.notifications,
              label: 'Notifications',
              route: AppRoutes.notifications,
            ),
            _buildIconButton(
              context,
              icon: Icons.logout,
              label: 'Logout',
              route: null,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? route,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ??
          (route != null ? () => Navigator.pushNamed(context, route) : null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: ClubColors.secondary,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ClubColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
