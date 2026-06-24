/// Video Grid Widget - Enhanced with smooth animations and pin/unpin effects
///
/// Features:
/// - Smooth tile entry animation (scale 0.8â†’1.0, 300ms)
/// - Pin/unpin visual effects with glowing border animation
/// - Hover effects with scale and shadow elevation
/// - Mini-profile popup on hover (desktop)
/// - Responsive grid layout (1-4 columns based on screen size)
/// - Music track display when showing video
/// - Camera approval badge for pending approvals
/// - Screen share indicator with icon
/// - Dark/light theme support
/// - Aspect ratio maintenance (4:3)
///
/// Usage:
/// ```dart
/// VideoGridWidget(
///   onExpandChat: () => print('Chat expanded'),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_models.dart';
import '../../shared/providers/room_provider.dart';
import '../../shared/providers/ui_provider.dart';
import '../../core/constants/ui_constants.dart';
import '../../core/design_system/design_constants.dart';
import 'mini_profile_popup.dart';

class VideoGridWidget extends ConsumerStatefulWidget {
  final VoidCallback onExpandChat;

  const VideoGridWidget({
    required this.onExpandChat,
    super.key,
  });

  @override
  ConsumerState<VideoGridWidget> createState() => _VideoGridWidgetState();
}

class _VideoGridWidgetState extends ConsumerState<VideoGridWidget> {
  late List<String> videoOrder;
  String? pinnedUserId;

  @override
  void initState() {
    super.initState();
    videoOrder = const [];
  }

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(participantsProvider);
    final screenSize = MediaQuery.of(context).size;
    final darkMode = ref.watch(darkModeProvider);

    if (participants.isEmpty) {
      return _buildEmptyState(context, darkMode);
    }

    // Calculate grid layout based on participant count
    final gridColumns = _getGridColumns(participants.length, screenSize);

    return Container(
      color: DesignColors.surfaceDefault,
      padding: const EdgeInsets.all(Spacing.md),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          alignment: WrapAlignment.center,
          children: participants.asMap().entries.map((entry) {
            final int index = entry.key;
            final participant = entry.value;
            final tileWidth =
                (screenSize.width - (gridColumns + 1) * Spacing.md) /
                    gridColumns;
            final tileHeight = tileWidth * 0.75; // 4:3 aspect ratio

            return _AnimatedVideoTile(
              key: ValueKey(participant.userId),
              participant: participant,
              width: tileWidth,
              height: tileHeight,
              index: index,
              isPinned: pinnedUserId == participant.userId,
              isAnimating: true,
              onPin: () {
                setState(() {
                  pinnedUserId = pinnedUserId == participant.userId
                      ? null
                      : participant.userId;
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Builds empty state when no participants
  Widget _buildEmptyState(BuildContext context, bool darkMode) {
    return Container(
      color: DesignColors.surfaceDefault,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              size: WidgetSizes.largeIconSize,
              color: DesignColors.accent,
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No active video calls',
              style: AppTextStyles.h4.copyWith(
                color: DesignColors.white,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Invite friends or join a group call',
              style: AppTextStyles.body2.copyWith(
                color: DesignColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Determine grid columns based on participant count and screen size
  int _getGridColumns(int participantCount, Size screenSize) {
    if (screenSize.width < ResponsiveBreakpoints.tablet) {
      return 1;
    } else if (screenSize.width < ResponsiveBreakpoints.desktop) {
      return participantCount == 1 ? 1 : 2;
    } else if (screenSize.width < ResponsiveBreakpoints.largeDesktop) {
      return participantCount <= 2 ? participantCount : 3;
    } else {
      return participantCount <= 3 ? participantCount : 4;
    }
  }
}

/// Animated video tile with hover and pin effects
class _AnimatedVideoTile extends ConsumerStatefulWidget {
  final VideoParticipant participant;
  final double width;
  final double height;
  final int index;
  final bool isPinned;
  final bool isAnimating;
  final VoidCallback onPin;

  const _AnimatedVideoTile({
    required this.participant,
    required this.width,
    required this.height,
    required this.index,
    required this.isPinned,
    required this.isAnimating,
    required this.onPin,
    super.key,
  });

  @override
  ConsumerState<_AnimatedVideoTile> createState() => _AnimatedVideoTileState();
}

class _AnimatedVideoTileState extends ConsumerState<_AnimatedVideoTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovered = false;
  OverlayEntry? _popupOverlay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.normal,
      vsync: this,
    );

    // Entry animation: scale from 0.8 to 1.0
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.elastic),
    );

    // Fade in animation
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeOut),
    );

    if (widget.isAnimating) {
      // Stagger animations based on index
      Future.delayed(Duration(milliseconds: widget.index * 100), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _removePopup();
    super.dispose();
  }

  void _removePopup() {
    _popupOverlay?.remove();
    _popupOverlay = null;
  }

  void _showMiniProfilePopup(Offset globalPosition) {
    _removePopup(); // Remove any existing popup

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 280.0;
    const popupHeight = 320.0;

    // Calculate position
    double left = globalPosition.dx + 20; // Offset to the right of cursor
    double top = globalPosition.dy;

    // Adjust if popup would go off right edge
    if (left + popupWidth > screenSize.width - 20) {
      left = globalPosition.dx - popupWidth - 20;
    }

    // Adjust if popup would go off bottom edge
    if (top + popupHeight > screenSize.height - 20) {
      top = screenSize.height - popupHeight - 20;
    }

    // Ensure not negative
    if (left < 20) left = 20;
    if (top < 20) top = 20;

    _popupOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: MiniProfilePopup(
          userId: widget.participant.userId,
          userName: widget.participant.userName,
          avatarUrl: widget.participant.avatarUrl,
          isOnline: true, // They're in the room, so they're online
          onViewProfile: () {
            _removePopup();
            Navigator.of(context).pushNamed(
              '/profile/${widget.participant.userId}',
            );
          },
          onSendFriendRequest: () {
            _removePopup();
            // TODO: Implement friend request
          },
          onTip: () {
            _removePopup();
            // TODO: Show tip dialog
          },
          onDismiss: _removePopup,
        ),
      ),
    );

    overlay.insert(_popupOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);

    return MouseRegion(
      onEnter: (event) {
        setState(() => _isHovered = true);
        // Show popup after brief delay to avoid flickering
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isHovered && mounted) {
            _showMiniProfilePopup(event.position);
          }
        });
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _removePopup();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onLongPress: widget.onPin,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: _buildVideoTile(context, darkMode),
          ),
        ),
      ),
    );
  }

  /// Builds the video tile with all overlays and indicators
  Widget _buildVideoTile(BuildContext context, bool darkMode) {
    return Stack(
      children: [
        /// Main video container with pin effect
        _buildMainVideoContainer(darkMode),

        /// Gradient overlay
        _buildGradientOverlay(),

        /// Top badges (share, camera pending)
        _buildTopBadges(),

        /// Bottom user info
        _buildUserInfo(darkMode),

        /// Pin indicator if pinned
        if (widget.isPinned) _buildPinIndicator(),

        /// Hover effects
        if (_isHovered) _buildHoverOverlay(),
      ],
    );
  }

  /// Main video container with border and animation effects
  Widget _buildMainVideoContainer(bool darkMode) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BorderRadii.lg),
        border: Border.all(
          color: widget.isPinned
              ? DesignColors.accent
              : (darkMode ? DesignColors.accent : DesignColors.accent),
          width: widget.isPinned ? 3 : 1,
        ),
        color: DesignColors.accent,
        boxShadow: _isHovered || widget.isPinned
            ? AppShadows.elevation3
            : AppShadows.elevation1,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BorderRadii.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DesignColors.accent,
              DesignColors.accent,
            ],
          ),
        ),
        child: widget.participant.isVideoEnabled
            ? ClipRRect(
                borderRadius: BorderRadius.circular(BorderRadii.lg),
                child: Image.network(
                  widget.participant.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.person,
                        color: DesignColors.accent,
                        size: WidgetSizes.largeIconSize,
                      ),
                    );
                  },
                ),
              )
            : _buildVideoDisabledContent(),
      ),
    );
  }

  /// Content when video is disabled (shows avatar + camera off icon)
  Widget _buildVideoDisabledContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off,
            color: DesignColors.accent,
            size: WidgetSizes.largeIconSize,
          ),
          const SizedBox(height: Spacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(BorderRadii.lg),
            child: Image.network(
              widget.participant.avatarUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: DesignColors.accent,
                    borderRadius: BorderRadius.circular(BorderRadii.lg),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: DesignColors.accent,
                    size: WidgetSizes.mediumIconSize,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient overlay for text readability
  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BorderRadii.lg),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DesignColors.accent,
              DesignColors.accent.withValues(alpha: 0.4),
            ],
          ),
        ),
      ),
    );
  }

  /// Top badges (screen share, camera pending)
  Widget _buildTopBadges() {
    return Positioned(
      top: Spacing.md,
      left: Spacing.md,
      right: Spacing.md,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.participant.isScreenSharing)
            _buildBadge(
              icon: Icons.screen_share,
              label: 'Sharing',
              color: DesignColors.accent,
            ),
          const SizedBox(width: Spacing.sm),
          if (widget.participant.cameraApprovalStatus == 'pending')
            _buildBadge(
              icon: Icons.hourglass_empty,
              label: 'Pending',
              color: DesignColors.accent,
            ),
        ],
      ),
    );
  }

  /// Reusable badge widget
  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(BorderRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: WidgetSizes.smallIconSize, color: DesignColors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: DesignColors.accent),
          ),
        ],
      ),
    );
  }

  /// User info section at bottom
  Widget _buildUserInfo(bool darkMode) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(BorderRadii.lg),
            bottomRight: Radius.circular(BorderRadii.lg),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DesignColors.accent,
              DesignColors.accent.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.participant.userName,
              style: AppTextStyles.body2.copyWith(
                color: DesignColors.accent,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                  size: WidgetSizes.smallIconSize,
                  color: widget.participant.isAudioEnabled
                      ? DesignColors.accent
                      : DesignColors.accent,
                ),
                const SizedBox(width: Spacing.sm),
                Icon(
                  widget.participant.isVideoEnabled
                      ? Icons.videocam
                      : Icons.videocam_off,
                  size: WidgetSizes.smallIconSize,
                  color: widget.participant.isVideoEnabled
                      ? DesignColors.accent
                      : DesignColors.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Pin indicator with pulsing animation
  Widget _buildPinIndicator() {
    return Positioned(
      top: Spacing.md,
      right: Spacing.md,
      child: _PinPulseAnimation(
        child: Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: DesignColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: DesignColors.accent.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.push_pin,
            color: DesignColors.accent,
            size: WidgetSizes.mediumIconSize,
          ),
        ),
      ),
    );
  }

  /// Hover overlay with affordance
  Widget _buildHoverOverlay() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _isHovered ? 0.1 : 0,
        duration: AnimationDurations.fast,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BorderRadii.lg),
            color: DesignColors.accent,
          ),
        ),
      ),
    );
  }
}

/// Pin pulse animation for pinned video indicator
class _PinPulseAnimation extends StatefulWidget {
  final Widget child;

  const _PinPulseAnimation({required this.child});

  @override
  State<_PinPulseAnimation> createState() => _PinPulseAnimationState();
}

class _PinPulseAnimationState extends State<_PinPulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
