import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import 'package:mixmingle/app/app_routes.dart';
import 'package:mixmingle/shared/widgets/club_background.dart';
import 'package:mixmingle/shared/widgets/glow_text.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _hasNavigated = false;
  bool _hasMinimumDelayPassed = false;
  Timer? _timeoutTimer;
  late StreamSubscription<firebase_auth.User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('ðŸŽ¬ SplashPage initState called');

    // Minimum splash delay (show branding)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_hasNavigated) {
        debugPrint(
            'â° Minimum delay passed - checking if auth already resolved');
        setState(() {
          _hasMinimumDelayPassed = true;
        });

        // Manually trigger navigation if auth already resolved
        _tryNavigate();
      }
    });

    // Listen to Firebase auth state changes directly (no providers)
    _authSubscription =
        firebase_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted && !_hasNavigated && _hasMinimumDelayPassed) {
        debugPrint(
            'ðŸ”” Auth state changed: ${user != null ? "user present" : "no user"}');
        _tryNavigate();
      }
    });

    // Timeout as safety net - 15 seconds
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_hasNavigated) {
        debugPrint('⚠ Splash timeout (15s) - forcing navigation to onboarding');
        _hasNavigated = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      }
    });
  }

  void _tryNavigate() {
    if (_hasNavigated || !_hasMinimumDelayPassed) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (!_hasNavigated) {
      debugPrint('ðŸ“Š Auth resolved: user=${user?.uid ?? "null"}');
      _hasNavigated = true;
      _timeoutTimer?.cancel();

      if (user != null) {
        debugPrint('✅ User authenticated - navigating to /home');
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        debugPrint('ℹ No user - navigating to onboarding');
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4C4C), Color(0xFFFFD700)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                  Icons.mic,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // App Name
              const GlowText(
                text: 'MIX & MINGLE',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700),
                glowColor: Color(0xFFFF4C4C),
                glowRadius: 12,
              ),
              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Where Music Meets Connection',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 48),

              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4C4C)),
              ),
              const SizedBox(height: 16),

              const Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
