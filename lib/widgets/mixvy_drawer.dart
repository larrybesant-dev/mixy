import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../features/auth/providers/admin_provider.dart';
import '../features/beta/beta_tester_provider.dart';
import '../presentation/providers/notification_provider.dart';
import 'brand_ui_kit.dart';

class MixVyDrawer extends ConsumerWidget {
  final String? userId;
  final bool embedded;
  final VoidCallback? onClose;

  const MixVyDrawer({
    super.key,
    this.userId,
    this.embedded = false,
    this.onClose,
  });

  String _currentLocation(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return ModalRoute.of(context)?.settings.name ?? '';
    }
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: VelvetNoir.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    int badgeCount = 0,
  }) {
    final location = _currentLocation(context);
    final isSelected = route == '/'
        ? location == '/'
        : location == route || location.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!embedded) {
            // Close the drawer, then navigate after the frame so the context
            // is still valid and the drawer animation doesn't compete.
            Navigator.of(context).maybePop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(route);
            });
          } else {
            context.go(route);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      VelvetNoir.primary.withValues(alpha: 0.14),
                      VelvetNoir.secondary.withValues(alpha: 0.10),
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : VelvetNoir.surfaceHigh.withValues(alpha: 0.38),
            border: Border.all(
              color: isSelected
                  ? VelvetNoir.primary.withValues(alpha: 0.30)
                  : VelvetNoir.outlineVariant.withValues(alpha: 0.36),
            ),
          ),
          child: ListTile(
            leading: badgeCount > 0
                ? Badge(
                    label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? VelvetNoir.primary
                          : VelvetNoir.onSurface.withValues(alpha: 0.9),
                    ),
                  )
                : Icon(
                    icon,
                    color: isSelected
                        ? VelvetNoir.primary
                        : VelvetNoir.onSurface.withValues(alpha: 0.9),
                  ),
            title: Text(
              title,
              style: GoogleFonts.raleway(
                color: VelvetNoir.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            trailing: isSelected
                ? const Icon(
                    Icons.chevron_right_rounded,
                    color: VelvetNoir.primary,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final isBetaTester = ref.watch(isBetaTesterProvider).valueOrNull ?? false;

    final drawerContent = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VelvetNoir.surfaceLow, VelvetNoir.surface],
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  VelvetNoir.primary.withValues(alpha: 0.18),
                  VelvetNoir.secondary.withValues(alpha: 0.20),
                  VelvetNoir.surfaceHigh,
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: VelvetNoir.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MixvyMonogram(size: 44, glow: true),
                    const SizedBox(width: 12),
                    const Expanded(child: MixvyAppBarLogo(fontSize: 20)),
                    if (embedded && onClose != null)
                      IconButton(
                        tooltip: 'Hide menu',
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: VelvetNoir.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Meet. Connect. Vibe after dark.',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Luxury social spaces, polished discovery, and live energy.',
                  style: GoogleFonts.raleway(
                    color: VelvetNoir.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionLabel(context, 'NAVIGATE'),
          _navItem(
            context,
            icon: Icons.home_rounded,
            title: 'Home Feed',
            route: '/home',
          ),
          _navItem(
            context,
            icon: Icons.meeting_room_outlined,
            title: 'Rooms',
            route: '/home',
          ),
          _navItem(
            context,
            icon: Icons.mail_rounded,
            title: 'message',
            route: '/home',
          ),
          _navItem(
            context,
            icon: Icons.people_outline_rounded,
            title: 'Groups',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.person_rounded,
            title: 'Profile',
            route: '/profile',
          ),
          _sectionLabel(context, 'CREATE'),
          _navItem(
            context,
            icon: Icons.mic_external_on_rounded,
            title: 'Host Room',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.article_outlined,
            title: 'New Post',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.auto_stories_outlined,
            title: 'New Story',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.group_add_outlined,
            title: 'New Group',
            route: '/fallback',
          ),
          _sectionLabel(context, 'MORE'),
          _navItem(
            context,
            icon: Icons.search_rounded,
            title: 'Search',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.meeting_room_rounded,
            title: 'Room Directory',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            route: '/fallback',
            badgeCount: unreadCount,
          ),
          _navItem(
            context,
            icon: Icons.bookmark_rounded,
            title: 'Bookmarks',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.people_alt_rounded,
            title: 'Friends',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.trending_up_rounded,
            title: 'Trending',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.local_fire_department_rounded,
            title: 'Live Speed Dating',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.nightlight_rounded,
            title: 'After Dark',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.verified_user_rounded,
            title: 'Get Verified',
            route: '/fallback',
          ),
          _navItem(
            context,
            icon: Icons.payments_rounded,
            title: 'Payments',
            route: '/fallback',
          ),
          if (isBetaTester)
            _navItem(
              context,
              icon: Icons.science_outlined,
              title: 'Beta Feedback',
              route: '/fallback',
            ),
          if (isAdmin)
            _navItem(
              context,
              icon: Icons.admin_panel_settings_rounded,
              title: 'Entitlement Support',
              route: '/admin-entitlements',
            ),
          _navItem(
            context,
            icon: Icons.settings_rounded,
            title: 'Settings',
            route: '/fallback',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    if (embedded) {
      return Material(color: Colors.transparent, child: drawerContent);
    }

    return Drawer(child: drawerContent);
  }
}
