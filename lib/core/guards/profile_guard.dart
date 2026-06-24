import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/profile/screens/create_profile_page.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';

/// Guard that ensures user has completed their profile before accessing the child widget
/// Redirects to profile creation page if profile is incomplete
class ProfileGuard extends ConsumerWidget {
  final Widget child;

  const ProfileGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ðŸ”¥ Use Riverpod authStateProvider for reactive auth
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    // Handle auth loading state
    if (authState.isLoading || user == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading profile: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Force rebuild by setting state
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if profile exists and has required fields
        if (snapshot.hasData && snapshot.data!.exists) {
          final profileData = snapshot.data!.data() as Map<String, dynamic>?;

          // Check for required profile fields
          final hasDisplayName = profileData?['displayName'] != null &&
              (profileData!['displayName'] as String).isNotEmpty;
          final hasUsername = profileData?['username'] != null &&
              (profileData!['username'] as String).isNotEmpty;
          // Use 'birthday' — the actual field written by UserProfile.toMap().
          // ('age' is never stored; it is derived from birthday at runtime.)
          final hasBirthday = profileData?['birthday'] != null;
          final hasGender = profileData?['gender'] != null;

          // Profile is complete if it has at least display name or username, birthday, and gender
          if ((hasDisplayName || hasUsername) && hasBirthday && hasGender) {
            return child;
          }
        }

        // Profile is incomplete, redirect to profile creation
        return const CreateProfilePage();
      },
    );
  }
}

