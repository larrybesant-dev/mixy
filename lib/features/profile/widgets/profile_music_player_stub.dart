// Stub implementation for non-web platforms.
// Profile music playback requires a browser audio API.
import 'package:flutter/material.dart';

class ProfileMusicPlayer extends StatelessWidget {
  const ProfileMusicPlayer({
    super.key,
    required this.musicUrl,
    required this.musicTitle,
  });

  final String musicUrl;
  final String musicTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              musicTitle.isNotEmpty ? musicTitle : 'Profile music',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Web only',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
