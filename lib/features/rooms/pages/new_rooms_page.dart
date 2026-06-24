// lib/features/rooms/pages/new_rooms_page.dart
//
// Phase 10 – Full-page list of newest public rooms.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/routing/app_routes.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/providers/room_discovery_providers.dart';
import '../../../shared/widgets/room_discovery_card.dart';

class NewRoomsPage extends ConsumerWidget {
  const NewRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(newRoomsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.background,
        elevation: 0,
        title: const Text(
          'New Rooms',
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
                'No new rooms yet.\nBe the first to go live!',
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
            'Failed to load rooms',
            style: TextStyle(color: Colors.red.shade300),
          ),
        ),
      ),
    );
  }
}

