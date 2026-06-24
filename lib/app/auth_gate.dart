import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/neon_login_page.dart';
import '../features/profile/screens/create_profile_page.dart';
import '../shared/providers/all_providers.dart';

// Auth wrapper for protected pages
class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // Initialize presence service for authenticated user (non-blocking)
          Future.microtask(() async {
            try {
              final presenceService = ref.read(presenceServiceProvider);
              await presenceService.initializePresence();
              await presenceService.goOnline();
              debugPrint('âœ… Presence initialized for user ${user.uid}');
            } catch (e) {
              debugPrint('âš ï¸ Presence initialization failed: $e');
              // App continues - presence is optional for rendering
            }
          });

          // Temporarily disable email verification requirement for development
          // if (user.emailVerified) {
          // Check if user has completed profile
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
                final profileData =
                    profileSnapshot.data!.data() as Map<String, dynamic>?;
                // Check if profile has required fields (displayName at minimum)
                if (profileData != null && profileData['displayName'] != null) {
                  return child; // Profile complete, show protected content
                }
              }

              // Profile incomplete, redirect to profile creation
              return const CreateProfilePage();
            },
          );
          // } else {
          //   return const EmailVerificationPage();
          // }
        }
        return const NeonLoginPage();
      },
    );
  }
}
