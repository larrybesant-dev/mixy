import 'package:flutter/material.dart';

class RoomControls extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final VoidCallback onLeave;

  const RoomControls({
    required this.isMuted,
    required this.onMuteToggle,
    required this.onLeave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
          onPressed: onMuteToggle,
        ),
        IconButton(icon: Icon(Icons.exit_to_app), onPressed: onLeave),
      ],
    );
  }
}
