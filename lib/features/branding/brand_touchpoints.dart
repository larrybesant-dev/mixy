import 'package:flutter/material.dart';

class BrandTouchpoints {
  static Widget invitation(String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.local_cafe, size: 48, color: Color(0xFF6C63FF)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(subtitle, style: const TextStyle(fontSize: 18, color: Colors.white70, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        const Text('MIXVY: Where the night begins.', style: TextStyle(fontSize: 16, color: Color(0xFF6C63FF))),
      ],
    );
  }
}
