import 'package:flutter/material.dart';
import '../../../core/design_system/design_constants.dart';

class HostControlsWidget extends StatelessWidget {
  final bool isHost;
  final bool isRecording;
  final bool isLocked;
  final int maxParticipants;
  final Function(bool)? onRecordingToggle;
  final Function(bool)? onLockToggle;
  final Function(int)? onMaxParticipantsChange;
  final VoidCallback? onEndRoom;
  final VoidCallback? onManageParticipants;

  const HostControlsWidget({
    super.key,
    required this.isHost,
    this.isRecording = false,
    this.isLocked = false,
    this.maxParticipants = 12,
    this.onRecordingToggle,
    this.onLockToggle,
    this.onMaxParticipantsChange,
    this.onEndRoom,
    this.onManageParticipants,
  });

  @override
  Widget build(BuildContext context) {
    if (!isHost) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(DesignSpacing.lg),
      margin: const EdgeInsets.all(DesignSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: DesignColors.shadowColor,
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: DesignColors.gold,
                size: 20,
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                'Host Controls',
                style: DesignTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: DesignColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignSpacing.md),

          // Controls grid
          Wrap(
            spacing: DesignSpacing.md,
            runSpacing: DesignSpacing.md,
            children: [
              // Recording toggle
              _buildControlButton(
                icon: isRecording ? Icons.stop : Icons.videocam,
                label: isRecording ? 'Stop Recording' : 'Start Recording',
                color: isRecording ? DesignColors.error : DesignColors.accent,
                onPressed: () => onRecordingToggle?.call(!isRecording),
              ),

              // Lock room toggle
              _buildControlButton(
                icon: isLocked ? Icons.lock : Icons.lock_open,
                label: isLocked ? 'Unlock Room' : 'Lock Room',
                color: isLocked ? DesignColors.warning : DesignColors.accent,
                onPressed: () => onLockToggle?.call(!isLocked),
              ),

              // Manage participants
              _buildControlButton(
                icon: Icons.people,
                label: 'Manage Participants',
                color: DesignColors.accent,
                onPressed: onManageParticipants,
              ),

              // End room
              _buildControlButton(
                icon: Icons.cancel,
                label: 'End Room',
                color: DesignColors.error,
                onPressed: onEndRoom,
              ),
            ],
          ),

          const SizedBox(height: DesignSpacing.md),

          // Max participants slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Max Participants: $maxParticipants',
                style: DesignTypography.caption.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              Slider(
                value: maxParticipants.toDouble(),
                min: 2,
                max: 50,
                divisions: 24,
                label: maxParticipants.toString(),
                onChanged: (value) =>
                    onMaxParticipantsChange?.call(value.toInt()),
                activeColor: DesignColors.accent,
                inactiveColor: DesignColors.surface,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 140,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: DesignTypography.caption.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: DesignColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.md,
            vertical: DesignSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

// Host controls overlay for positioning
class HostControlsOverlay extends StatelessWidget {
  final Widget child;
  final HostControlsWidget controls;

  const HostControlsOverlay({
    super.key,
    required this.child,
    required this.controls,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 100, // Below the room header
          right: DesignSpacing.lg,
          child: controls,
        ),
      ],
    );
  }
}
