import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/features/profile/profile_view_providers.dart';
import 'package:mixvy/models/user_profile.dart';
import 'package:mixvy/models/user_presence.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

/// A premium, glassmorphic modal bottom sheet displaying user profiles and real-time presence.
/// 
/// Incorporates:
/// - Real-time stream data binding for user presence (no mock data).
/// - Fully-typed Firestore data binding for profile metadata.
/// - Heavy Glassmorphism via [BackdropFilter] and translucent premium borders.
/// - Safe layout wrapping and scrolling to handle extremely long bios with zero pixel overflows.
class UserProfileBottomSheet extends ConsumerStatefulWidget {
  const UserProfileBottomSheet({
    super.key,
    required this.userId,
    this.onFollowChanged,
    this.onClose,
  });

  final String userId;
  final void Function(bool isFollowing)? onFollowChanged;
  final VoidCallback? onClose;

  /// Helper to trigger the bottom sheet.
  static Future<void> show(BuildContext context, String userId) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => UserProfileBottomSheet(userId: userId),
    );
  }

  @override
  ConsumerState<UserProfileBottomSheet> createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends ConsumerState<UserProfileBottomSheet> {
  bool _isFollowingLocal = false;

  void _toggleFollow() {
    setState(() {
      _isFollowingLocal = !_isFollowingLocal;
    });
    if (widget.onFollowChanged != null) {
      widget.onFollowChanged!(_isFollowingLocal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileFutureProvider(widget.userId));
    final presenceAsync = ref.watch(userPresenceStreamProvider(widget.userId));

    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.85;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          maxHeight: maxHeight,
          decoration: BoxDecoration(
            color: const Color(0xCC111319), // 80% opacity Jet Black for premium contrast
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: VelvetNoir.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            top: false,
            child: profileAsync.when(
              data: (profile) {
                final presence = presenceAsync.valueOrNull ?? const UserPresence(isOnline: false);
                return _buildProfileContent(context, profile, presence);
              },
              loading: () => const _LoadingSheetState(),
              error: (error, _) => _ErrorSheetState(
                onRetry: () => ref.invalidate(userProfileFutureProvider(widget.userId)),
                onClose: widget.onClose ?? () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserProfile profile,
    UserPresence presence,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: VelvetNoir.outlineVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Scrollable Profile Area
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Area with Online Glow Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profile.vipLevel > 0
                            ? VelvetNoir.primaryGradient
                            : null,
                        border: profile.vipLevel == 0
                            ? Border.all(
                                color: VelvetNoir.outlineVariant,
                                width: 2,
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: MixvyGoldAvatar(
                        imageUrl: profile.avatarUrl,
                        fallbackInitial: profile.displayName.isNotEmpty
                            ? profile.displayName[0]
                            : '?',
                        radius: 46,
                        isVip: profile.vipLevel > 0,
                        isOnline: presence.isOnline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // User Display Name (Headlines: Playfair Display)
                Text(
                  profile.displayName,
                  style: GoogleFonts.playfairDisplay(
                    color: VelvetNoir.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Username & Connection status
                Text(
                  '@${profile.username}',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Presence Label
                _PresenceStatusLabel(presence: presence),
                const SizedBox(height: 20),

                // Followers & VIP Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMetricChip(
                      icon: Icons.people_rounded,
                      label: '${profile.followersCount} followers',
                    ),
                    if (profile.vipLevel > 0) ...[
                      const SizedBox(width: 12),
                      _buildMetricChip(
                        icon: Icons.star_rounded,
                        label: 'VIP Level ${profile.vipLevel}',
                        color: VelvetNoir.secondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Separator
                Divider(
                  color: VelvetNoir.outlineVariant,
                  thickness: 1,
                  height: 1,
                ),
                const SizedBox(height: 20),

                // Bio Description (Handles long bio cleanly)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'About Me',
                    style: GoogleFonts.playfairDisplay(
                      color: VelvetNoir.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (profile.bio ?? '').isNotEmpty
                        ? profile.bio!
                        : 'No bio provided yet.',
                    style: GoogleFonts.raleway(
                      color: VelvetNoir.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 24),

                // Follow / Action Button
                if (_isFollowingLocal)
                  MixvyGoldOutlineButton(
                    label: 'Unfollow',
                    onPressed: _toggleFollow,
                  )
                else
                  MixvyGoldButton(
                    label: 'Follow',
                    onPressed: _toggleFollow,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    Color color = VelvetNoir.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.raleway(
              color: VelvetNoir.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components: Presence Label
// ─────────────────────────────────────────────────────────────────────────────

class _PresenceStatusLabel extends StatelessWidget {
  const _PresenceStatusLabel({required this.presence});

  final UserPresence presence;

  @override
  Widget build(BuildContext context) {
    if (presence.isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF00FF88), // Vivid Premium Green
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Online Now',
            style: GoogleFonts.raleway(
              color: const Color(0xFF00FF88),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final dateStr = presence.lastSeen != null
        ? _formatLastSeen(presence.lastSeen!)
        : 'recently';

    return Text(
      'Offline • Last seen $dateStr',
      style: GoogleFonts.raleway(
        color: VelvetNoir.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading State (Shimmer Skeleton)
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSheetState extends StatefulWidget {
  const _LoadingSheetState();

  @override
  State<_LoadingSheetState> createState() => _LoadingSheetStateState();
}

class _LoadingSheetStateState extends State<_LoadingSheetState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final opacity = 0.4 + (_shimmer.value * 0.45);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VelvetNoir.surfaceHigh.withValues(alpha: opacity),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 140,
                height: 18,
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceHigh.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error State (Clean fail state)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorSheetState extends StatelessWidget {
  const _ErrorSheetState({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: VelvetNoir.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Could Not Load Profile',
            style: GoogleFonts.playfairDisplay(
              color: VelvetNoir.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We encountered an error loading this member\'s profile. Please try again.',
            style: GoogleFonts.raleway(
              color: VelvetNoir.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          MixvyGoldButton(
            label: 'Retry',
            onPressed: onRetry,
          ),
          const SizedBox(height: 12),
          MixvyGoldOutlineButton(
            label: 'Close',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
