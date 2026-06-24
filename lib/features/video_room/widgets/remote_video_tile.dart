// lib/widgets/remote_video_tile.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/participant_model.dart';

class RemoteVideoTile extends StatelessWidget {
  final ParticipantModel participant;

  const RemoteVideoTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: participant.isScreenSharing ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                kIsWeb ? Icons.videocam_off : Icons.person,
                color: Colors.white54,
                size: 48,
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.black45,
                child: Text(
                  participant.uid,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

