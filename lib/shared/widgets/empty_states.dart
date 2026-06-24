import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/animations/custom_animations.dart';

/// Mix & Mingle Branded Empty States
/// Consistent, engaging empty state UI across the app

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final bool showAnimation;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            _EmptyStateIcon(
              icon: icon,
              color: iconColor ?? ClubColors.primary,
              showAnimation: showAnimation,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: ClubTextStyles.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: ClubTextStyles.textTheme.bodyMedium?.copyWith(
                color: ClubColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );

    return showAnimation ? FadeInSlideUp(child: content) : content;
  }
}

class _EmptyStateIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool showAnimation;

  const _EmptyStateIcon({
    required this.icon,
    required this.color,
    required this.showAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        size: 64,
        color: color,
      ),
    );

    return showAnimation ? PulseAnimation(child: iconWidget) : iconWidget;
  }
}

/// Pre-built empty states for common scenarios

class NoEventsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateEvent;

  const NoEventsEmptyState({super.key, this.onCreateEvent});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.event,
      iconColor: ClubColors.accent,
      title: 'No Events Yet',
      message:
          'Be the first to create an exciting event and bring people together!',
      actionLabel: onCreateEvent != null ? 'Create Event' : null,
      onAction: onCreateEvent,
    );
  }
}

class NoUsersEmptyState extends StatelessWidget {
  final VoidCallback? onInvite;

  const NoUsersEmptyState({super.key, this.onInvite});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.people_outline,
      iconColor: ClubColors.secondary,
      title: 'No Users Found',
      message: 'Start connecting with people who share your interests!',
      actionLabel: onInvite != null ? 'Invite Friends' : null,
      onAction: onInvite,
    );
  }
}

class NoMessagesEmptyState extends StatelessWidget {
  const NoMessagesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.chat_bubble_outline,
      iconColor: ClubColors.primary,
      title: 'No Messages',
      message: 'Start a conversation and break the ice!',
    );
  }
}

class NoRoomsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateRoom;

  const NoRoomsEmptyState({super.key, this.onCreateRoom});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.video_call,
      iconColor: ClubColors.primary,
      title: 'No Active Rooms',
      message: 'Create a room and start connecting with people live!',
      actionLabel: onCreateRoom != null ? 'Create Room' : null,
      onAction: onCreateRoom,
    );
  }
}

class NoMatchesEmptyState extends StatelessWidget {
  final VoidCallback? onDiscover;

  const NoMatchesEmptyState({super.key, this.onDiscover});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.favorite_border,
      iconColor: ClubColors.accentPurple,
      title: 'No Matches Yet',
      message: 'Keep swiping and connecting to find your perfect match!',
      actionLabel: onDiscover != null ? 'Start Discovering' : null,
      onAction: onDiscover,
    );
  }
}

class NoNotificationsEmptyState extends StatelessWidget {
  const NoNotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.notifications_none,
      iconColor: ClubColors.info,
      title: 'All Caught Up!',
      message: 'You don\'t have any notifications right now.',
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  final String searchQuery;

  const SearchEmptyState({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      iconColor: ClubColors.textSecondary,
      title: 'No Results',
      message:
          'We couldn\'t find anything matching "$searchQuery".\nTry different keywords.',
    );
  }
}

class OfflineEmptyState extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineEmptyState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off,
      iconColor: ClubColors.error,
      title: 'No Connection',
      message: 'Please check your internet connection and try again.',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}

class ErrorEmptyState extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ErrorEmptyState({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      iconColor: ClubColors.error,
      title: 'Oops! Something Went Wrong',
      message:
          errorMessage ?? 'An unexpected error occurred. Please try again.',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}

class ComingSoonEmptyState extends StatelessWidget {
  final String featureName;

  const ComingSoonEmptyState({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.construction,
      iconColor: ClubColors.accent,
      title: 'Coming Soon!',
      message:
          '$featureName is currently under development.\nStay tuned for updates!',
      showAnimation: true,
    );
  }
}

class NoInterestsEmptyState extends StatelessWidget {
  final VoidCallback? onAddInterests;

  const NoInterestsEmptyState({super.key, this.onAddInterests});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.interests,
      iconColor: ClubColors.accent,
      title: 'No Interests Selected',
      message: 'Add your interests to get personalized recommendations!',
      actionLabel: onAddInterests != null ? 'Add Interests' : null,
      onAction: onAddInterests,
    );
  }
}

class NoPhotosEmptyState extends StatelessWidget {
  final VoidCallback? onAddPhotos;

  const NoPhotosEmptyState({super.key, this.onAddPhotos});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.add_photo_alternate,
      iconColor: ClubColors.secondary,
      title: 'No Photos',
      message: 'Add photos to make your profile stand out!',
      actionLabel: onAddPhotos != null ? 'Add Photos' : null,
      onAction: onAddPhotos,
    );
  }
}

/// Mini empty state for inline use
class MiniEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? iconColor;

  const MiniEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor ?? ClubColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: ClubTextStyles.textTheme.bodySmall?.copyWith(
                color: ClubColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
