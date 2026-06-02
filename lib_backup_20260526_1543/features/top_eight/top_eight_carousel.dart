import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'top_eight_providers.dart';

class TopEightCarousel extends ConsumerWidget {
  final String? userId;

  const TopEightCarousel({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine which user's Top 8 to show. Default to current user if none provided.
    final auth = ref.watch(firebaseAuthProvider);
    final currentUserId = auth.currentUser?.uid;
    final targetUserId = userId ?? currentUserId ?? '';

    final friendsAsync = ref.watch(topEightDisplayProvider(targetUserId));
    final isOwnProfile = userId == null || userId == currentUserId;

    return friendsAsync.when(
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SizedBox.shrink(),
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFD4AF37), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Top 8 Friends',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37), // Gold accent
                        ),
                      ),
                    ],
                  ),
                  if (isOwnProfile)
                    TextButton(
                      onPressed: () {
                        context.push('/manage-top-8');
                      },
                      child: const Text(
                        'Edit',
                        style:
                            TextStyle(color: Color(0xFFD4AF37), fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: friends.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return GestureDetector(
                    onTap: () => context.push('/profile/${friend.id}'),
                    child: Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.grey[900],
                            backgroundImage: (friend.avatarUrl != null &&
                                    friend.avatarUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(friend.avatarUrl!)
                                : null,
                            child: (friend.avatarUrl == null ||
                                    friend.avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          friend.username,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
