import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../observability/startup_timeline.dart';
import '../providers/tab_navigation_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync navigationShell's current index to provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabIndexProvider.notifier).state = widget.navigationShell.currentIndex;
    });
  }

  void _onDestinationSelected(int index) {
    unawaited(HapticFeedback.selectionClick());
    StartupProfiler.instance.markFirstUserAction(
      context: 'bottom_nav_tab_$index',
    );
    
    // Update provider first
    ref.read(selectedTabIndexProvider.notifier).state = index;
    
    // Navigate using go() with explicit paths instead of goBranch()
    final routes = ['/home', '/messages', '/rooms', '/speed-dating', '/profile'];
    if (index >= 0 && index < routes.length) {
      GoRouter.of(context).go(routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
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
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

