// Basic UI widget for UserProfile
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_profile_provider.dart';

class UserProfileWidget extends ConsumerWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    if (profile == null) {
      return const Center(child: Text('No profile loaded'));
    }
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(profile.avatarUrl),
          radius: 40,
        ),
        const SizedBox(height: 16),
        Text(profile.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(profile.bio),
      ],
    );
  }
}
