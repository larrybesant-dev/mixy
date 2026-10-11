import 'package:flutter/material.dart';

import '../../core/layout/app_layout.dart';

class PrimaryNavigationShell extends StatelessWidget {
  const PrimaryNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.child,
  });

  static const desktopNavigationKey =
      ValueKey<String>('primary-desktop-navigation');
  static const mobileNavigationKey =
      ValueKey<String>('primary-mobile-navigation');

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Feed'),
    (icon: Icons.forum_rounded, label: 'Messages'),
    (icon: Icons.groups_rounded, label: 'Rooms'),
    (icon: Icons.favorite_rounded, label: 'Dating'),
    (icon: Icons.account_circle_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopNavigation =
            constraints.maxWidth >= AppBreakpoints.medium;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0B0B),
          body: useDesktopNavigation
              ? Row(
                  children: [
                    NavigationRail(
                      key: desktopNavigationKey,
                      backgroundColor: const Color(0xFF0B0B0B),
                      selectedIndex: currentIndex,
                      onDestinationSelected: onSelected,
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
                        for (final item in _items)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0x33781E2B),
                    ),
                    Expanded(child: child),
                  ],
                )
              : child,
          bottomNavigationBar: useDesktopNavigation
              ? null
              : _VelvetBottomNav(
                  key: mobileNavigationKey,
                  currentIndex: currentIndex,
                  onSelected: onSelected,
                ),
        );
      },
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
              for (var i = 0; i < PrimaryNavigationShell._items.length; i++)
                Expanded(
                  child: _VelvetNavItem(
                    icon: PrimaryNavigationShell._items[i].icon,
                    label: PrimaryNavigationShell._items[i].label,
                    selected: i == currentIndex,
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

    return InkWell(
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
    );
  }
}
