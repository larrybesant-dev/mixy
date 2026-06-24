import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/neon_colors.dart';
import '../../../shared/widgets/neon_components.dart';
import 'dart:async';

/// ============================================================================
/// NEON SPLASH SCREEN - Electric Lounge Brand
/// Animated startup screen with logo and brand
/// ============================================================================

class NeonSplashPage extends StatefulWidget {
  const NeonSplashPage({super.key});

  @override
  State<NeonSplashPage> createState() => _NeonSplashPageState();
}

class _NeonSplashPageState extends State<NeonSplashPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Text animation
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Chain animations
    _logoController.forward().then((_) {
      _textController.forward();
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for splash animation to complete
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // Check authentication status
      debugPrint('ðŸ” Checking Firebase auth status...');
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('âœ… Firebase auth check complete. User: ${user?.email}');

      if (user != null) {
        debugPrint('ðŸ‘¤ User authenticated, navigating to home...');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      } else {
        debugPrint('ðŸ” No user authenticated, navigating to login...');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('âŒ Error in _navigateToNextScreen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.darkBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              NeonColors.darkBg2,
              NeonColors.darkBg,
              NeonColors.darkBg.withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated logo with glow
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: NeonColors.neonOrange
                                    .withValues(alpha: 0.7),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color:
                                    NeonColors.neonBlue.withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    NeonColors.neonOrange
                                        .withValues(alpha: 0.1),
                                    NeonColors.neonBlue.withValues(alpha: 0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: NeonColors.neonOrange
                                      .withValues(alpha: 0.6),
                                  width: 3,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          NeonColors.neonOrange,
                                          NeonColors.neonPurple,
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Animated brand name
              FadeTransition(
                opacity: _textOpacity,
                child: const Column(
                  children: [
                    NeonText(
                      'MIX & MINGLE',
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      textColor: Colors.white,
                      glowColor: NeonColors.neonOrange,
                      glowRadius: 16,
                      letterSpacing: 2,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'GLOBAL DJ VIBES',
                      style: TextStyle(
                        fontSize: 14,
                        color: NeonColors.textSecondary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              FadeTransition(
                opacity: _textOpacity,
                child: const Column(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          NeonColors.neonBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'CONNECTING...',
                      style: TextStyle(
                        fontSize: 12,
                        color: NeonColors.textSecondary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
