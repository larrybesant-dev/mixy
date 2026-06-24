// lib/features/rooms/pages/recommended_rooms_page.dart
//
// Phase 10 – Full-page list of rooms recommended for the current user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/routing/app_routes.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/providers.dart' hide currentUserProvider;
import '../../../shared/widgets/room_discovery_card.dart';

class RecommendedRoomsPage extends ConsumerWidget {
  const RecommendedRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final userId = currentUser?.id ?? '';
    final roomsAsync = ref.watch(recommendedRoomsProvider(userId));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.background,
        elevation: 0,
        title: const Text(
          'Recommended Rooms',
          style: TextStyle(
            color: DesignColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: DesignColors.white),
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(
              child: Text(
                'No recommendations yet.\nFollow hosts to see their rooms here!',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignColors.white),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RoomDiscoveryCard(
                  room: room,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.room,
                    arguments: room.id,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: DesignColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            'Failed to load recommendations',
            style: TextStyle(color: Colors.red.shade300),
          ),
        ),
      ),
    );
  }
}

