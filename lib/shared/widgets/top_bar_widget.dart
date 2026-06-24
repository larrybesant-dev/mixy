// ignore_for_file: deprecated_member_use
/// Top Bar Widget - Navigation bar with animated participant count and theme toggle
///
/// Features:
/// - Animated participant count with scale and fade effect
/// - Live indicator with pulsing animation
/// - Smooth theme toggle with icon rotation
/// - Notification badge with animation
/// - Video quality settings menu
/// - Camera approval settings
/// - Responsive design with proper spacing
/// - Dark/light theme support
/// - Clean visual hierarchy with proper typography
///
/// Usage:
/// ```dart
/// TopBarWidget(
///   onToggleDarkMode: () => print('Theme toggled'),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_models.dart';
import '../../shared/providers/room_provider.dart';
import '../../shared/providers/ui_provider.dart';
import '../../shared/providers/notification_provider.dart';
import '../../core/constants/ui_constants.dart';
import '../../core/design_system/design_constants.dart';

class TopBarWidget extends ConsumerStatefulWidget {
  final VoidCallback onToggleDarkMode;

  const TopBarWidget({
    required this.onToggleDarkMode,
    super.key,
  });

  @override
  ConsumerState<TopBarWidget> createState() => _TopBarWidgetState();
}

class _TopBarWidgetState extends ConsumerState<TopBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _themeToggleController;
  late Animation<double> _themeToggleAnimation;
  int _previousParticipantCount = 0;

  @override
  void initState() {
    super.initState();
    _themeToggleController = AnimationController(
      duration: AnimationDurations.slow,
      vsync: this,
    );

    _themeToggleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _themeToggleController, curve: AppCurves.easeOut),
    );
  }

  @override
  void dispose() {
    _themeToggleController.dispose();
    super.dispose();
  }

  void _handleThemeToggle() {
    _themeToggleController.forward().then((_) {
      _themeToggleController.reset();
    });
    widget.onToggleDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(darkModeProvider);
    final participantCount = ref.watch(participantsCountProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Track participant count changes for animation
    if (participantCount != _previousParticipantCount) {
      _previousParticipantCount = participantCount;
    }

    return Container(
      height: WidgetSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: darkMode ? DesignColors.accent : DesignColors.accent,
        border: Border(
          bottom: BorderSide(
            color: darkMode ? DesignColors.accent : DesignColors.accent,
            width: 1,
          ),
        ),
        boxShadow: AppShadows.elevation2,
      ),
      child: Row(
        children: [
          /// Logo/Title
          _buildLogo(darkMode),
          const SizedBox(width: Spacing.lg),

          /// Live indicator with animated participant count
          _buildLiveIndicator(participantCount, darkMode),

          /// Spacer
          const Spacer(),

          /// Notifications button
          _buildNotificationButton(context, ref, unreadCount, darkMode),
          const SizedBox(width: Spacing.sm),

          /// Video quality settings
          _buildVideoQualityMenu(ref, darkMode),

          /// Theme toggle with animation
          _buildThemeToggle(darkMode),

          /// Settings menu
          _buildSettingsMenu(context, ref, darkMode),
        ],
      ),
    );
  }

  /// Builds the logo/title section
  Widget _buildLogo(bool darkMode) {
    return Text(
      'ðŸŽ¬ Mix & Mingle',
      style: AppTextStyles.h5.copyWith(
        color: DesignColors.accent,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Builds the live indicator with animated participant count
  Widget _buildLiveIndicator(int participantCount, bool darkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: DesignColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(BorderRadii.lg),
        border: Border.all(
          color: DesignColors.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Pulsing live indicator
          _PulsingLiveIndicator(),
          const SizedBox(width: Spacing.md),

          /// Animated participant count
          _AnimatedParticipantCount(count: participantCount),
        ],
      ),
    );
  }

  /// Builds the notification button with badge
  Widget _buildNotificationButton(
    BuildContext context,
    WidgetRef ref,
    int unreadCount,
    bool darkMode,
  ) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: darkMode ? DesignColors.accent : DesignColors.accent,
          ),
          onPressed: () => _showNotificationsPanel(context, ref),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: DesignColors.accent,
                borderRadius: BorderRadius.circular(BorderRadii.lg),
                boxShadow: AppShadows.elevation1,
              ),
              child: Text(
                unreadCount.toString(),
                style: AppTextStyles.caption.copyWith(
                  color: DesignColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the video quality settings menu
  Widget _buildVideoQualityMenu(WidgetRef ref, bool darkMode) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.videocam,
        color: darkMode ? DesignColors.accent : DesignColors.accent,
      ),
      tooltip: 'Video Quality',
      onSelected: (String result) {
        if (result == 'quality_low') {
          ref.read(videoQualityProvider.notifier).setQuality(VideoQuality.low);
        } else if (result == 'quality_medium') {
          ref
              .read(videoQualityProvider.notifier)
              .setQuality(VideoQuality.medium);
        } else if (result == 'quality_high') {
          ref.read(videoQualityProvider.notifier).setQuality(VideoQuality.high);
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'quality_low',
          child: Row(
            children: [
              Icon(Icons.video_call, size: WidgetSizes.smallIconSize),
              SizedBox(width: Spacing.md),
              Text(
                'Low Quality (180p)',
                style: AppTextStyles.body2,
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'quality_medium',
          child: Row(
            children: [
              Icon(Icons.video_call, size: WidgetSizes.smallIconSize),
              SizedBox(width: Spacing.md),
              Text(
                'Medium Quality (360p)',
                style: AppTextStyles.body2,
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'quality_high',
          child: Row(
            children: [
              Icon(Icons.video_call, size: WidgetSizes.smallIconSize),
              SizedBox(width: Spacing.md),
              Text(
                'High Quality (720p)',
                style: AppTextStyles.body2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the theme toggle button with animation
  Widget _buildThemeToggle(bool darkMode) {
    return IconButton(
      icon: AnimatedRotation(
        turns: _themeToggleAnimation.value,
        duration: AnimationDurations.slow,
        child: Icon(
          darkMode ? Icons.light_mode : Icons.dark_mode,
          color: darkMode ? DesignColors.accent : DesignColors.accent,
        ),
      ),
      onPressed: _handleThemeToggle,
      tooltip: darkMode ? 'Light Mode' : 'Dark Mode',
    );
  }

  /// Builds the settings menu
  Widget _buildSettingsMenu(
      BuildContext context, WidgetRef ref, bool darkMode) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: darkMode ? DesignColors.accent : DesignColors.accent,
      ),
      tooltip: 'Settings',
      onSelected: (String result) {
        if (result == 'camera_settings') {
          _showCameraSettingsDialog(context, ref);
        } else if (result == 'audio_settings') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio settings coming soon'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(Spacing.md),
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'camera_settings',
          child: Row(
            children: [
              Icon(Icons.camera_alt, size: WidgetSizes.smallIconSize),
              SizedBox(width: Spacing.md),
              Text('Camera Settings', style: AppTextStyles.body2),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'audio_settings',
          child: Row(
            children: [
              Icon(Icons.settings_voice, size: WidgetSizes.smallIconSize),
              SizedBox(width: Spacing.md),
              Text('Audio Settings', style: AppTextStyles.body2),
            ],
          ),
        ),
      ],
    );
  }

  /// Shows the notifications panel
  void _showNotificationsPanel(BuildContext context, WidgetRef ref) {
    final notifications = ref.read(notificationsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Notifications',
          style: AppTextStyles.h4,
        ),
        content: SizedBox(
          width: 400,
          height: 400,
          child: notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_off,
                        size: WidgetSizes.largeIconSize,
                        color: DesignColors.accent,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        'No notifications',
                        style: AppTextStyles.body1.copyWith(
                          color: DesignColors.accent,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: notifications.map((notification) {
                    return ListTile(
                      title: Text(
                        notification.title,
                        style: AppTextStyles.body1,
                      ),
                      subtitle: Text(
                        notification.message,
                        style: AppTextStyles.body2,
                      ),
                      trailing: notification.isRead
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: DesignColors.accent,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.elevation1,
                              ),
                            ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Shows the camera settings dialog
  void _showCameraSettingsDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(cameraApprovalSettingsProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Camera Approval Settings',
          style: AppTextStyles.h4,
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Who can see your camera?',
                style: AppTextStyles.body1,
              ),
              const SizedBox(height: Spacing.lg),
              RadioListTile<String>(
                title: const Text(
                  'Ask each time',
                  style: AppTextStyles.body1,
                ),
                value: 'ask',
                groupValue: settings['default_mode'],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(cameraApprovalSettingsProvider.notifier)
                        .setDefaultMode(value);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text(
                  'Allow all',
                  style: AppTextStyles.body1,
                ),
                value: 'allow_all',
                groupValue: settings['default_mode'],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(cameraApprovalSettingsProvider.notifier)
                        .setDefaultMode(value);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text(
                  'Deny all',
                  style: AppTextStyles.body1,
                ),
                value: 'deny_all',
                groupValue: settings['default_mode'],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(cameraApprovalSettingsProvider.notifier)
                        .setDefaultMode(value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Pulsing live indicator animation
class _PulsingLiveIndicator extends StatefulWidget {
  @override
  State<_PulsingLiveIndicator> createState() => _PulsingLiveIndicatorState();
}

class _PulsingLiveIndicatorState extends State<_PulsingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: DesignColors.accent.withValues(
                    alpha: _opacityAnimation.value * 0.5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: DesignColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Animated participant count display
class _AnimatedParticipantCount extends StatefulWidget {
  final int count;

  const _AnimatedParticipantCount({required this.count});

  @override
  State<_AnimatedParticipantCount> createState() =>
      _AnimatedParticipantCountState();
}

class _AnimatedParticipantCountState extends State<_AnimatedParticipantCount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationDurations.normal,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.elastic),
    );

    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_AnimatedParticipantCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _controller.forward().then((_) {
        _controller.reset();
      });
    }
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
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Text(
          'LIVE â€¢ ${widget.count} participant${widget.count != 1 ? 's' : ''}',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: DesignColors.accent,
          ),
        ),
      ),
    );
  }
}
