import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'top_eight_providers.dart';

class TopEightCarousel extends ConsumerWidget {
  const TopEightCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(dummyTop8Provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
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
              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: friend.avatarUrl != null
                          ? CachedNetworkImageProvider(friend.avatarUrl!)
                          : null,
                      child: friend.avatarUrl == null
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
              );
            },
          ),
        ),
      ],
    );
  }
}
