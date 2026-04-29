import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/messaging/screens/messages_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/social/screens/live_floor_screen.dart';
import '../../features/speed_dating/screens/speed_dating_screen.dart';
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

  void _onDestinationSelected(int value) {
    setState(() => _index = value);

    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }

    switch (value) {
      case 0:
        router.go('/home');
      case 1:
        router.go('/messages');
      case 2:
        router.go('/rooms');
      case 3:
        router.go('/speed-dating');
      case 4:
        final userId = ref.read(userProvider)?.id ?? '';
        router.go(userId.isEmpty ? '/home?tab=4' : '/profile/$userId');
      default:
        router.go('/home');
    }
  }

  Widget _buildActivePage() {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return MessagesScreen(userId: user.id, username: user.username);
      case 2:
        return const LiveFloorScreen();
      case 3:
        return const SpeedDatingScreen();
      case 4:
        return user.id.isEmpty
            ? const ProfileScreen()
            : UserProfileScreen(userId: user.id);
      default:
        return const DashboardScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    final sourceIndex = widget.selectedIndex ?? widget.initialIndex;
    _index = sourceIndex.clamp(0, 4);
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
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Dating',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (value) {
            _onDestinationSelected(value);
          },
        ),
      );
    }

    return Scaffold(
      body: _buildActivePage(),
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
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Dating',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (value) {
          _onDestinationSelected(value);
        },
      ),
    );
  }
}
