import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../shared/models/user_profile.dart';
import '../shared/models/event.dart';
import '../shared/models/chat_room.dart';
import '../shared/providers/profile_controller.dart';
import '../shared/providers/events_controller.dart';
import '../shared/providers/chat_controller.dart';
import 'profile/profile_page.dart';
import 'events/screens/events_page.dart';
import 'chat/screens/chat_list_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    HomeDashboard(
        onNavigateToTab: (index) => setState(() => _selectedIndex = index)),
    const EventsPage(),
    const ChatListPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeDashboard extends ConsumerWidget {
  final Function(int) onNavigateToTab;

  const HomeDashboard({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final upcomingEventsAsync = ref.watch(upcomingEventsProvider);
    final chatRoomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mix & Mingle'),
        actions: [
          Semantics(
            label: 'Notifications',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // TODO: Navigate to notifications page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Notifications not implemented yet')),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            currentUserAsync.when(
              data: (user) => user != null
                  ? _buildWelcomeSection(user)
                  : const Text('Welcome to Mix & Mingle!'),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading profile: $error'),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context),
            const SizedBox(height: 24),

            // Upcoming Events
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Events',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            upcomingEventsAsync.when(
              data: (events) => events.isEmpty
                  ? const Text('No upcoming events')
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: events.take(5).length,
                        itemBuilder: (context, index) {
                          return EventCardSmall(event: events[index]);
                        },
                      ),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading events: $error'),
            ),
            const SizedBox(height: 24),

            // Recent Messages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Messages',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(2),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            chatRoomsAsync.when(
              data: (chatRooms) => chatRooms.isEmpty
                  ? const Text('No recent messages')
                  : Column(
                      children: chatRooms.take(3).map((room) {
                        return ChatRoomCardSmall(chatRoom: room);
                      }).toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading messages: $error'),
            ),
            const SizedBox(height: 24),

            // Speed Dating Banner
            _buildSpeedDatingBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(UserProfile user) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${user.displayName}!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready to meet someone special?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickActionButton(
              context,
              'Find Events',
              Icons.event,
              () => onNavigateToTab(1),
              key: const Key('findEventsButton'),
            ),
            _buildQuickActionButton(
              context,
              'Start Chat',
              Icons.chat,
              () => onNavigateToTab(2),
              key: const Key('startChatButton'),
            ),
            _buildQuickActionButton(
              context,
              'Speed Date',
              Icons.favorite,
              () => Navigator.pushNamed(context, '/speed-dating-lobby'),
              key: const Key('speedDatingButton'),
            ),
            _buildQuickActionButton(
              context,
              'Edit Profile',
              Icons.person,
              () => onNavigateToTab(3),
              key: const Key('editProfileButton'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuickActionButton(
              context,
              'Browse Rooms',
              Icons.meeting_room,
              () => Navigator.pushNamed(context, '/browse-rooms'),
              key: const Key('browseRoomsButton'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap,
      {Key? key}) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4C4C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: const Color(0xFFFF4C4C)),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDatingBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade300, Colors.red.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.favorite,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Try Speed Dating!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Meet multiple people in quick sessions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Join Speed Dating',
            button: true,
            child: ElevatedButton(
              key: const Key('startSpeedDating'),
              onPressed: () =>
                  Navigator.pushNamed(context, '/speed-dating-lobby'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.pink,
              ),
              child: const Text('Join Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class EventCardSmall extends StatelessWidget {
  final Event event;

  const EventCardSmall({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 16),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd, HH:mm').format(event.startTime),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.location,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${event.attendees.length}/${event.maxAttendees} attending',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatRoomCardSmall extends ConsumerWidget {
  final ChatRoom chatRoom;

  const ChatRoomCardSmall({super.key, required this.chatRoom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProfileProvider).value?.id ?? '';
    final otherUserId =
        chatRoom.participants.firstWhere((id) => id != currentUserId);
    final otherUserAsync = ref.watch(userProfileProvider(otherUserId));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: otherUserAsync.when(
            data: (user) => user?.displayName?.isNotEmpty == true
                ? Text(user!.displayName![0].toUpperCase())
                : const Text('?'),
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => const Icon(Icons.error),
          ),
        ),
        title: otherUserAsync.when(
          data: (user) => Text(user?.displayName ?? 'Unknown User'),
          loading: () => const Text('Loading...'),
          error: (error, stack) => const Text('Error'),
        ),
        subtitle: Text(
          chatRoom.lastMessage.isEmpty
              ? 'No messages yet'
              : chatRoom.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: chatRoom.unreadCounts[currentUserId] != null &&
                chatRoom.unreadCounts[currentUserId]! > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  chatRoom.unreadCounts[currentUserId].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Text(
                DateFormat('HH:mm').format(chatRoom.lastMessageTime.toLocal()),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
