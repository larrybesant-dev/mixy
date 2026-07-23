import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

/// Displays "Reconnecting..." feedback during connection recovery.
/// 
/// Shows during RtcConnectionState.degraded and .reconnecting states.
/// Auto-hides when connection recovers.
class RecoveryBadge extends StatefulWidget {
  final int attemptNumber;
  final int maxAttempts;

  const RecoveryBadge({
    super.key,
    required this.attemptNumber,
    this.maxAttempts = 3,
  });

  @override
  State<RecoveryBadge> createState() => _RecoveryBadgeState();
}

class _RecoveryBadgeState extends State<RecoveryBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.6 + (_pulseController.value * 0.4);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: VelvetNoir.error.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: VelvetNoir.liveGlow.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation(VelvetNoir.gold),
                  strokeWidth: 2,
                  value: null, // Indeterminate
                ),
              ),
              Text(
                'Reconnecting... (${widget.attemptNumber}/${widget.maxAttempts})',
                style: GoogleFonts.raleway(
                  color: VelvetNoir.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
