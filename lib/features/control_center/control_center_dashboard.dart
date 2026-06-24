// lib/features/control_center/control_center_dashboard.dart
//
// Root scaffold for the Platform Control Center.
// Provides a tab-bar navigation to: Users | Rooms | Reports | Analytics | Roles
// Access requires at least the `admin` role (enforced by route guard + provider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/control_center_users_page.dart';
import 'package:mixvy/features/control_center/control_center_rooms_page.dart';
import 'package:mixvy/features/control_center/control_center_reports_page.dart';
import 'package:mixvy/features/control_center/control_center_analytics_page.dart';
import 'package:mixvy/features/control_center/control_center_roles_page.dart';

class ControlCenterDashboard extends ConsumerStatefulWidget {
  const ControlCenterDashboard({super.key});

  @override
  ConsumerState<ControlCenterDashboard> createState() =>
      _ControlCenterDashboardState();
}

class _ControlCenterDashboardState
    extends ConsumerState<ControlCenterDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabItems = [
    ('Users', Icons.people),
    ('Rooms', Icons.meeting_room),
    ('Reports', Icons.flag),
    ('Analytics', Icons.bar_chart),
    ('Roles', Icons.verified_user),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabItems.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final isSuperAdmin =
        ref.watch(isSuperAdminProvider).asData?.value ?? false;

    return isAdminAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Access error')),
      ),
      data: (isAdmin) {
        if (!isAdmin) {
          return const Scaffold(
            backgroundColor: DesignColors.background,
            body: Center(
              child: Text(
                'Access Denied',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }

        return ClubBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: DesignColors.surfaceLight,
              title: Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      color: DesignColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Control Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSuperAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: DesignColors.tertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: DesignColors.tertiary, width: 1),
                      ),
                      child: const Text(
                        'SUPER',
                        style: TextStyle(
                          color: DesignColors.tertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              bottom: TabBar(
                controller: _tabs,
                indicatorColor: DesignColors.accent,
                labelColor: DesignColors.accent,
                unselectedLabelColor: Colors.white54,
                tabs: _tabItems
                    .map((t) => Tab(icon: Icon(t.$2), text: t.$1))
                    .toList(),
              ),
            ),
            body: TabBarView(
              controller: _tabs,
              children: const [
                ControlCenterUsersPage(),
                ControlCenterRoomsPage(),
                ControlCenterReportsPage(),
                ControlCenterAnalyticsPage(),
                ControlCenterRolesPage(),
              ],
            ),
          ),
        );
      },
    );
  }
}

