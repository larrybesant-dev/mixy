import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/core/routing/app_routes.dart';
import 'package:mixmingle/core/responsive/responsive_utils.dart';
import 'package:mixmingle/shared/models/user_profile.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';

class MatchDiscoveryPage extends ConsumerStatefulWidget {
  const MatchDiscoveryPage({super.key});

  @override
  ConsumerState<MatchDiscoveryPage> createState() =>
      _MatchDiscoveryPageState();
}

class _MatchDiscoveryPageState extends ConsumerState<MatchDiscoveryPage> {
  int _currentIndex = 0;
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final recommendationsAsync = ref.watch(matchRecommendationsProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Discover'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Match Preferences',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.matchPreferences),
            ),
          ],
        ),
        body: recommendationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48,
                    color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Could not load recommendations',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(matchRecommendationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (profiles) {
            if (profiles.isEmpty || _currentIndex >= profiles.length) {
              return _buildAllDoneView(context);
            }
            final profile = profiles[_currentIndex];
            return _buildCardStack(context, profile, profiles.length);
          },
        ),
      ),
    );
  }

  Widget _buildCardStack(
      BuildContext context, UserProfile profile, int total) {
    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: LinearProgressIndicator(
            value: ((_currentIndex + 1) / total).clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _DiscoveryCard(profile: profile),
          ),
        ),
        _buildActionBar(context, profile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, UserProfile profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pass
        _ActionButton(
          icon: Icons.close_rounded,
          color: Colors.redAccent,
          size: 60,
          onTap: _isActing ? null : () => _pass(),
        ),
        // View Profile
        _ActionButton(
          icon: Icons.person_outline,
          color: Colors.white54,
          size: 48,
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.userProfile, arguments: profile.id),
        ),
        // Like
        _ActionButton(
          icon: Icons.favorite_rounded,
          color: Colors.pinkAccent,
          size: 60,
          onTap: _isActing ? null : () => _like(context, profile),
        ),
      ],
    );
  }

  Future<void> _like(BuildContext context, UserProfile profile) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      final service = ref.read(matchServiceProvider);
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser != null) {
        await service.likeUser(currentUser.id, profile.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '❤️ Liked ${profile.displayName ?? profile.nickname ?? "them"}!'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _isActing = false;
        });
      }
    }
  }

  void _pass() {
    if (_isActing) return;
    setState(() => _currentIndex++);
  }

  Widget _buildAllDoneView(BuildContext context) {
    return Center(
      child: Padding(
        padding: Responsive.responsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration,
                size: Responsive.responsiveIconSize(context, 80),
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              "You've seen everyone!",
              style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 22),
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for more recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: Responsive.responsiveFontSize(context, 16),
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _currentIndex = 0);
                ref.invalidate(matchRecommendationsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discovery Card ────────────────────────────────────────────────────────────

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final displayName = profile.displayName ?? profile.nickname ?? 'Anonymous';
    final photoUrl = profile.photoUrl;
    final isOnline = profile.presenceStatus == 'online';
    // Minimal match indicator: if profile.isMatch is available and true
    final isMatch = (profile as dynamic).isMatch == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          if (photoUrl != null)
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            )
          else
            _placeholder(context),

          // Minimal neon match indicator (top left)
          if (isMatch)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Match',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Theme.of(context).colorScheme.secondary,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Gradient overlay for text legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.5, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // Online badge
          if (isOnline)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Profile info overlay at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54)
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (profile.isPremium)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),

                // Location
                if (profile.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          profile.location!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Bio
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.bio!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Interests chips
                if (profile.interests != null &&
                    profile.interests!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: profile.interests!.take(5).map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white38, width: 1),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.person,
          size: 100,
          color:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Round Action Button ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.white10
              : color.withValues(alpha: 0.15),
          border: Border.all(
              color: onTap == null ? Colors.white24 : color, width: 2),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.white30 : color,
          size: size * 0.45,
        ),
      ),
    );
  }
}
