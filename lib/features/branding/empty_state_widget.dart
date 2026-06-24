import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;
  const EmptyStateWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 48, color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 20, color: Colors.white70, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          const Text('Invite someone to start the vibe.', style: TextStyle(fontSize: 16, color: Color(0xFF6C63FF))),
        ],
      ),
    );
  }
}
