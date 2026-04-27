import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/screens/discovery_feed_screen.dart';
import '../../features/messaging/screens/messages_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/social/screens/live_floor_screen.dart';
import '../../presentation/providers/user_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = 0,
    this.selectedIndex,
    this.child,
    this.useDesktopMessengerLayout = false,
  });

  final int initialIndex;
  final int? selectedIndex;
  final Widget? child;
  final bool useDesktopMessengerLayout;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final sourceIndex = widget.selectedIndex ?? widget.initialIndex;
    _index = sourceIndex.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none),
              selectedIcon: Icon(Icons.mic),
              label: 'Live Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (value) {
            setState(() => _index = value);
          },
        ),
      );
    }

    final user = ref.watch(userProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      const DiscoveryFeedScreen(),
      MessagesScreen(userId: user.id, username: user.username),
      const LiveFloorScreen(),
      user.id.isEmpty ? const ProfileScreen() : UserProfileScreen(userId: user.id),
    ];

    if (widget.child != null) {
      pages[_index] = widget.child!;
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Live Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
      ),
    );
  }
}
