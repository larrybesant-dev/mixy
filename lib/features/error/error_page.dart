import 'package:flutter/material.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';

class ErrorPage extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ErrorPage({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4C4C),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Color(0xFFFF4C4C),
                  ),
                ),
                const SizedBox(height: 24),
                const GlowText(
                  text: 'Oops! Something went wrong',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                  glowColor: Color(0xFFFF4C4C),
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage ??
                      'An unexpected error occurred. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                if (onRetry != null)
                  NeonButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/home'),
                  child: const GlowText(
                    text: 'Go Home',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
