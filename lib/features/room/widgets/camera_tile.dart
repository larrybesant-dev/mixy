// lib/features/room/widgets/camera_tile.dart
//
// Individual camera-feed tile for live rooms.
//
// Visual states:
//   - Host/Broadcaster : gold neon ring + gold glow shadow
//   - Spotlighted      : blue ring + blue glow shadow
//   - Speaking         : pulsing blue ring animation
//   - Default viewer   : dim grey ring
//
// New params vs previous:
//   - isHost      [bool] : true when this tile belongs to the room host
//   - isSpeaking  [bool] : true when audio activity detected
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/camera_state.dart';
import '../../../../core/design_system/design_constants.dart';

class CameraTile extends StatefulWidget {
  final CameraState cameraState;
  final String roomId;
  final bool isSpotlighted;
  final bool isHost;
  final bool isSpeaking;
  final VoidCallback onSelected;

  const CameraTile({
    super.key,
    required this.cameraState,
    required this.roomId,
    required this.isSpotlighted,
    required this.onSelected,
    this.isHost = false,
    this.isSpeaking = false,
  });

  @override
  State<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<CameraTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _speakController;
  late Animation<double> _speakPulse;

  @override
  void initState() {
    super.initState();
    _speakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _speakPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _speakController, curve: Curves.easeInOut),
    );
    _updateSpeakAnim();
  }

  @override
  void didUpdateWidget(CameraTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSpeaking != widget.isSpeaking) {
      _updateSpeakAnim();
    }
  }

  void _updateSpeakAnim() {
    if (widget.isSpeaking) {
      _speakController.repeat(reverse: true);
    } else {
      _speakController.stop();
      _speakController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _speakController.dispose();
    super.dispose();
  }

  // ---- Border & glow helpers -------------------------------------------

  Color _borderColor() {
    if (widget.isHost) return DesignColors.gold;
    if (widget.isSpotlighted) return DesignColors.accent;
    if (widget.isSpeaking) return DesignColors.accent;
    return const Color(0xFF3A3A4A); // dim grey
  }

  double _borderWidth() {
    if (widget.isHost) return 2.5;
    if (widget.isSpotlighted || widget.isSpeaking) return 2.0;
    return 1.2;
  }

  List<BoxShadow> _glowShadows(double pulseAlpha) {
    if (widget.isHost) {
      return [
        BoxShadow(
          color: DesignColors.gold.withValues(alpha: 0.45),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];
    }
    if (widget.isSpotlighted) {
      return [
        BoxShadow(
          color: DesignColors.accent.withValues(alpha: 0.40),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];
    }
    if (widget.isSpeaking) {
      return [
        BoxShadow(
          color: DesignColors.accent.withValues(alpha: pulseAlpha * 0.55),
          blurRadius: 14,
          spreadRadius: 0,
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSelected,
      child: AnimatedBuilder(
        animation: _speakPulse,
        builder: (context, child) {
          final borderColor = widget.isSpeaking
              ? DesignColors.accent.withValues(alpha: _speakPulse.value)
              : _borderColor();

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: _borderWidth(),
              ),
              color: DesignColors.background,
              boxShadow: _glowShadows(_speakPulse.value),
            ),
            child: child,
          );
        },
        child: _TileContent(
          cameraState: widget.cameraState,
          isHost: widget.isHost,
          isSpotlighted: widget.isSpotlighted,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Static tile content (extracted so AnimatedBuilder only repaints border)
// -----------------------------------------------------------------------

class _TileContent extends StatelessWidget {
  final CameraState cameraState;
  final bool isHost;
  final bool isSpotlighted;

  const _TileContent({
    required this.cameraState,
    required this.isHost,
    required this.isSpotlighted,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera placeholder ----------------------------------------
          Container(
            color: const Color(0xFF0E1222),
            child: Center(
              child: Icon(
                Icons.videocam_rounded,
                size: 46,
                color: DesignColors.accent.withValues(alpha: 0.25),
              ),
            ),
          ),

          // ── Host crown badge ------------------------------------------
          if (isHost)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: DesignColors.gold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: DesignColors.gold.withValues(alpha: 0.8),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded,
                        size: 10, color: DesignColors.gold),
                    SizedBox(width: 3),
                    Text(
                      'HOST',
                      style: TextStyle(
                        color: DesignColors.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Status badge (top-left, below crown if host) ---------------
          Positioned(
            top: isHost ? 32 : 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getStatusIcon(),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quality badge (top-right) ----------------------------------
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cameraState.qualityIcon,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),

          // ── User info overlay (bottom) ---------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cameraState.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isHost ? DesignColors.gold : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (cameraState.isVIP)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star_rounded,
                              color: DesignColors.gold, size: 13),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.visibility_rounded,
                          color: Colors.white38, size: 11),
                      const SizedBox(width: 3),
                      Text(
                        '${cameraState.viewCount}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Spotlight indicator (center) ------------------------------
          if (isSpotlighted)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: DesignColors.accent.withValues(alpha: 0.7),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.center_focus_strong_rounded,
                      color: DesignColors.accent, size: 26),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return DesignColors.success;
      case CameraStatus.loading:
        return DesignColors.secondary;
      case CameraStatus.frozen:
        return DesignColors.error;
      case CameraStatus.error:
        return DesignColors.error;
      case CameraStatus.inactive:
        return const Color(0xFF555565);
    }
  }

  Widget _getStatusIcon() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      case CameraStatus.loading:
        return const SizedBox(
          width: 8,
          height: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        );
      case CameraStatus.frozen:
        return const Icon(Icons.ac_unit_rounded, size: 9, color: Colors.white);
      case CameraStatus.error:
        return const Icon(Icons.warning_amber_rounded,
            size: 9, color: Colors.white);
      case CameraStatus.inactive:
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white54,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    }
  }

  String _getStatusText() {
    switch (cameraState.status) {
      case CameraStatus.active:
        return 'LIVE';
      case CameraStatus.loading:
        return 'LOADING';
      case CameraStatus.frozen:
        return 'FROZEN';
      case CameraStatus.error:
        return 'ERROR';
      case CameraStatus.inactive:
        return 'OFF';
    }
  }
}

