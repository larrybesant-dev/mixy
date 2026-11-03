import 'package:flutter/material.dart';

import '../../core/layout/app_layout.dart';
import '../../features/messaging/widgets/messenger_desktop_overlay.dart';

class PrimaryNavigationShell extends StatelessWidget {
  const PrimaryNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.onFriendsSelected,
    required this.onDiscoverSelected,
    required this.showBetaFeedback,
    required this.onBetaFeedbackSelected,
    required this.child,
    this.activeRoomId,
    this.onReturnToRoom,
  });

  static const desktopNavigationKey =
      ValueKey<String>('primary-desktop-navigation');
  static const mobileNavigationKey =
      ValueKey<String>('primary-mobile-navigation');

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onFriendsSelected;
  final VoidCallback onDiscoverSelected;
  final bool showBetaFeedback;
  final VoidCallback onBetaFeedbackSelected;
  final Widget child;
  final String? activeRoomId;
  final VoidCallback? onReturnToRoom;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.forum_rounded, label: 'Messages'),
    (icon: Icons.groups_rounded, label: 'Rooms'),
    (icon: Icons.favorite_rounded, label: 'Dating'),
    (icon: Icons.account_circle_rounded, label: 'Profile'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  static const _friendsDesktopIndex = 4;
  static const _discoverDesktopIndex = 5;
  static const _betaFeedbackDesktopIndex = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopNavigation =
            constraints.maxWidth >= AppBreakpoints.medium;
        final shellChild = _buildShellChild();

        return MessengerDesktopOverlay(
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0B0B),
            body: useDesktopNavigation
                ? Row(
                    children: [
                      NavigationRail(
                        key: desktopNavigationKey,
                        backgroundColor: const Color(0xFF0B0B0B),
                        selectedIndex: currentIndex == 6
                            ? showBetaFeedback
                                ? _betaFeedbackDesktopIndex
                                : null
                            : currentIndex >= _friendsDesktopIndex
                                ? currentIndex + 2
                                : currentIndex,
                        onDestinationSelected: (index) {
                          if (index == _friendsDesktopIndex) {
                            onFriendsSelected();
                            return;
                          }
                          if (index == _discoverDesktopIndex) {
                            onDiscoverSelected();
                            return;
                          }
                          if (index == _betaFeedbackDesktopIndex) {
                            onBetaFeedbackSelected();
                            return;
                          }
                          onSelected(
                            index > _discoverDesktopIndex ? index - 2 : index,
                          );
                        },
                        extended: true,
                        minExtendedWidth: 196,
                        labelType: NavigationRailLabelType.none,
                        indicatorColor: const Color(0x33D4AF37),
                        selectedIconTheme: const IconThemeData(
                          color: Color(0xFFD4AF37),
                          size: 26,
                        ),
                        unselectedIconTheme: const IconThemeData(
                          color: Color(0xBDF7EDE2),
                          size: 23,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: Color(0xBDF7EDE2),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        leading: const Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: Text(
                            'MIXVY',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        destinations: [
                          for (final item in [
                            ..._items.take(_friendsDesktopIndex),
                            (
                              icon: Icons.forum_outlined,
                              label: 'Messenger',
                            ),
                            (
                              icon: Icons.person_search_outlined,
                              label: 'Find People',
                            ),
                            ..._items.skip(_friendsDesktopIndex),
                          ])
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                          if (showBetaFeedback)
                            const NavigationRailDestination(
                              icon: Icon(Icons.science_outlined),
                              label: Text('Beta Feedback'),
                            ),
                        ],
                      ),
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: Color(0x33781E2B),
                      ),
                      Expanded(child: shellChild),
                    ],
                  )
                : shellChild,
            bottomNavigationBar: useDesktopNavigation
                ? null
                : _VelvetBottomNav(
                    key: mobileNavigationKey,
                    currentIndex: currentIndex,
                    onSelected: onSelected,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildShellChild() {
    if ((activeRoomId ?? '').trim().isEmpty || onReturnToRoom == null) {
      return child;
    }

    return Column(
      children: [
        Material(
          color: const Color(0xFF241820),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFFD4AF37),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'You are still connected to a room',
                        style: TextStyle(
                          color: Color(0xFFF7EDE2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey<String>('return-to-room-button'),
                      onPressed: onReturnToRoom,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Return to Room'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF0B0B0B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _VelvetBottomNav extends StatelessWidget {
  const _VelvetBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = currentIndex >= 4 ? 4 : currentIndex;
    final items = PrimaryNavigationShell._items.take(5).toList(growable: false);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0B),
        border: Border(top: BorderSide(color: Color(0x33781E2B))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _VelvetNavItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VelvetNavItem extends StatelessWidget {
  const _VelvetNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFD4AF37);
    const inactiveColor = Color(0xBDF7EDE2);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: selected ? 24 : 22,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
