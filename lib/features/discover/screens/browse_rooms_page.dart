// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/room_providers.dart';
import '../../../shared/models/room.dart';
import '../../../shared/club_background.dart';
import '../../../shared/glow_text.dart';
import '../../../shared/live_room_card.dart';
import '../../../shared/loading_widgets.dart';
import '../../../shared/neon_button.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../room/room_access_wrapper.dart';

class BrowseRoomsPage extends ConsumerWidget {
  const BrowseRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const GlowText(
            text: 'Browse Rooms',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => _showSearchDialog(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: () => _showFilterDialog(context, ref),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search and filter bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        onChanged: (value) => ref
                            .read(searchQueryProvider.notifier)
                            .update(value),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search rooms...',
                          hintStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  NeonButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/create-room'),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.add, size: 24),
                  ),
                ],
              ),
            ),

            // Categories
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('All', true),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Music', false),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Gaming', false),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Chat', false),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Live', false),
                ],
              ),
            ),

            // Rooms list
            Expanded(
              child: roomsAsync.when(
                data: (rooms) {
                  final filteredRooms = _filterRooms(rooms, searchQuery);

                  if (filteredRooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const GlowText(
                            text: 'No rooms found',
                            fontSize: 18,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to start a session!',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 24),
                          NeonButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/create-room'),
                            child: const Text('Create Room'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      // Fetch host profile to get display name
                      final hostProfileAsync =
                          ref.watch(userProvider(room.hostId));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: hostProfileAsync.when(
                          data: (hostProfile) => LiveRoomCard(
                            roomName: room.name ?? room.title,
                            djName: hostProfile?.displayName ??
                                room.hostName ??
                                'Unknown DJ',
                            viewerCount: room.viewerCount,
                            onTap: () => _joinRoom(context, room),
                          ),
                          loading: () => const RoomCardSkeleton(),
                          error: (_, __) => LiveRoomCard(
                            roomName: room.name ?? room.title,
                            djName: room.hostName ?? 'Unknown DJ',
                            viewerCount: room.viewerCount,
                            onTap: () => _joinRoom(context, room),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 8, // Show 8 skeleton items
                  itemBuilder: (context, index) => const RoomCardSkeleton(),
                ),
                error: (error, stack) => Center(
                  child: GlowText(
                    text: 'Error loading rooms: ${error.toString()}',
                    fontSize: 16,
                    color: const Color(0xFFFF4C4C),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: NeonButton(
          onPressed: () => Navigator.of(context).pushNamed('/create-room'),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF4C4C)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF4C4C)
              : const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  List<Room> _filterRooms(List<Room> rooms, String query) {
    if (query.isEmpty) return rooms;
    return rooms
        .where((room) =>
            (room.name?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            room.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3D),
        title: const GlowText(
          text: 'Search Rooms',
          fontSize: 20,
        ),
        content: TextField(
          onChanged: (value) =>
              ref.read(searchQueryProvider.notifier).update(value),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter room name or description...',
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }

  void _joinRoom(BuildContext context, Room room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoomAccessWrapper(
          room: room,
          userId: fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      ),
    );
  }
}

class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _selectedCategory;
  RoomPrivacy? _selectedPrivacy;
  RoomStatus? _selectedStatus;
  bool _onlyLiveRooms = false;

  final List<String> _categories = [
    'Music',
    'Talk Show',
    'Gaming',
    'Comedy',
    'Education',
    'Sports',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3D),
      title: const GlowText(
        text: 'Filter Rooms',
        fontSize: 20,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter
            const Text(
              'Category',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  selectedColor: const Color(0xFFFF4C4C),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Privacy Filter
            const Text(
              'Privacy',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<RoomPrivacy>(
                    title: const Text('Public',
                        style: TextStyle(color: Colors.white70)),
                    value: RoomPrivacy.public,
                    groupValue: _selectedPrivacy,
                    onChanged: (value) =>
                        setState(() => _selectedPrivacy = value),
                    activeColor: const Color(0xFFFF4C4C),
                  ),
                ),
                Expanded(
                  child: RadioListTile<RoomPrivacy>(
                    title: const Text('Private',
                        style: TextStyle(color: Colors.white70)),
                    value: RoomPrivacy.private,
                    groupValue: _selectedPrivacy,
                    onChanged: (value) =>
                        setState(() => _selectedPrivacy = value),
                    activeColor: const Color(0xFFFF4C4C),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status Filter
            const Text(
              'Status',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<RoomStatus>(
                    title: const Text('Live',
                        style: TextStyle(color: Colors.white70)),
                    value: RoomStatus.live,
                    groupValue: _selectedStatus,
                    onChanged: (value) =>
                        setState(() => _selectedStatus = value),
                    activeColor: const Color(0xFFFF4C4C),
                  ),
                ),
                Expanded(
                  child: RadioListTile<RoomStatus>(
                    title: const Text('Ended',
                        style: TextStyle(color: Colors.white70)),
                    value: RoomStatus.ended,
                    groupValue: _selectedStatus,
                    onChanged: (value) =>
                        setState(() => _selectedStatus = value),
                    activeColor: const Color(0xFFFF4C4C),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Live Rooms Only
            CheckboxListTile(
              title: const Text('Live rooms only',
                  style: TextStyle(color: Colors.white70)),
              value: _onlyLiveRooms,
              onChanged: (value) =>
                  setState(() => _onlyLiveRooms = value ?? false),
              activeColor: const Color(0xFFFF4C4C),
              checkColor: Colors.white,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Reset filters
            setState(() {
              _selectedCategory = null;
              _selectedPrivacy = null;
              _selectedStatus = null;
              _onlyLiveRooms = false;
            });
          },
          child: const Text('Reset', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text('Apply', style: TextStyle(color: Color(0xFFFF4C4C))),
        ),
      ],
    );
  }
}
