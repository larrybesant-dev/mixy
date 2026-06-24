/// Participant Card Widget
///
/// Displays a single participant in a video room with:
/// - Avatar
/// - Name
/// - Speaking indicator + pulse animation
/// - Arrival slide animation
///
/// Usage:
/// ```dart
/// ParticipantCardWidget(
///   participant: participant,
///   onTap: () => handleTap(),
/// )
/// ```
///
/// Enforces: DESIGN_BIBLE.md Section C (Animations) + DESIGN_CONSTANTS
/// Reference: lib/models/participant.dart
library;

import 'package:flutter/material.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/shared/models/participant.dart';

class ParticipantCardWidget extends StatefulWidget {
  /// Participant data (name, uid, speaking state, etc.)
  final Participant participant;

  /// Callback when card is tapped
  final VoidCallback onTap;

  /// Whether to show arrival animation (slide in)
  final bool showArrivalAnimation;

  const ParticipantCardWidget({
    required this.participant,
    required this.onTap,
    this.showArrivalAnimation = true,
    super.key,
  });

  @override
  State<ParticipantCardWidget> createState() => _ParticipantCardWidgetState();
}

class _ParticipantCardWidgetState extends State<ParticipantCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _arrivalController;
  late AnimationController _speakingController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeArrivalAnimation();
    _initializeSpeakingAnimation();
  }

  void _initializeArrivalAnimation() {
    if (!widget.showArrivalAnimation) return;

    _arrivalController = AnimationController(
      vsync: this,
      duration:
          DesignAnimations.presenceSlideInDuration, // 250ms per DESIGN_BIBLE
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _arrivalController,
        curve: DesignAnimations.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _arrivalController,
        curve: DesignAnimations.easeOutCubic,
      ),
    );

    _arrivalController.forward();
  }

  void _initializeSpeakingAnimation() {
    _speakingController = AnimationController(
      vsync: this,
      duration:
          DesignAnimations.speakingPulseDuration, // 200ms per DESIGN_BIBLE
    );

    if (widget.participant.isSpeaking) {
      _speakingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ParticipantCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update speaking animation if state changed
    if (widget.participant.isSpeaking && !oldWidget.participant.isSpeaking) {
      _speakingController.repeat(reverse: true);
    } else if (!widget.participant.isSpeaking &&
        oldWidget.participant.isSpeaking) {
      _speakingController.stop();
    }
  }

  @override
  void dispose() {
    _arrivalController.dispose();
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = _buildCard();

    // Wrap with arrival animation
    if (widget.showArrivalAnimation) {
      return AnimatedBuilder(
        animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
        builder: (context, child) => Transform.translate(
          offset: _slideAnimation.value * 50,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildCard() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        // âœ… Use DesignSpacing
        padding: const EdgeInsets.all(DesignSpacing.lg),
        margin: const EdgeInsets.only(bottom: DesignSpacing.md),

        // âœ… Use DesignBorders, DesignShadows, DesignColors
        decoration: BoxDecoration(
          border: DesignBorders.cardDefault,
          borderRadius: BorderRadius.circular(DesignSpacing.cardBorderRadius),
          color: DesignColors.accent,
          boxShadow: const [DesignShadows.subtle],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + Name + Mute indicator
            Row(
              children: [
                // âœ… Avatar
                Container(
                  width: DesignSpacing.avatarMedium,
                  height: DesignSpacing.avatarMedium,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      DesignSpacing.avatarMedium / 2,
                    ),
                    color: DesignColors.accent,
                  ),
                  child: widget.participant.avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DesignSpacing.avatarMedium / 2,
                          ),
                          child: Image.network(
                            widget.participant.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: DesignColors.accent,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: DesignColors.accent,
                        ),
                ),

                const SizedBox(width: DesignSpacing.lg),

                // âœ… Name using DesignTypography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.participant.name,
                        style: DesignTypography.subheading,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.participant.isSpeaking) ...[
                        const SizedBox(height: DesignSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignSpacing.sm,
                            vertical: DesignSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: DesignColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Speaking now',
                            style: DesignTypography.caption.copyWith(
                              color: DesignColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Mute icon if not speaking
                if (!widget.participant.isSpeaking)
                  const Icon(
                    Icons.mic_off,
                    color: DesignColors.accent,
                    size: 20,
                  ),
              ],
            ),

            // Join time
            Padding(
              padding: const EdgeInsets.only(top: DesignSpacing.md),
              child: Text(
                _formatJoinTime(),
                style: DesignTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJoinTime() {
    final now = DateTime.now();
    final diff = now.difference(widget.participant.joinedAt);

    if (diff.inSeconds < 60) return 'Just joined';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

