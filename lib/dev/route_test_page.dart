/// lib/dev/route_test_page.dart
///
/// Developer-only screen that lists every AppRoute and lets you tap into each.
/// Access: Navigate to AppRoutes.routeTest (/dev/routes) or via the
/// 5-tap hidden gesture on the settings page version number.
///
/// Use this during QA to verify every screen loads without crashing.
library;

import 'package:flutter/material.dart';
import 'package:mixvy/core/routing/app_routes.dart';

class RouteTestPage extends StatelessWidget {
  const RouteTestPage({super.key});

  /// All routes that can be navigated to without required arguments.
  static const _noArgRoutes = <String>[
    AppRoutes.ageGate,
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.home,
    AppRoutes.discovery,
    AppRoutes.editProfile,
    AppRoutes.profile,
    AppRoutes.followers,
    AppRoutes.following,
    AppRoutes.friends,
    AppRoutes.friendRequests,
    AppRoutes.chatList,
    AppRoutes.messageRequests,
    AppRoutes.rooms,
    AppRoutes.createRoom,
    AppRoutes.settings,
    AppRoutes.accountSettings,
    AppRoutes.privacySettings,
    AppRoutes.notificationSettings,
    AppRoutes.notifications,
    AppRoutes.blockedUsers,
    AppRoutes.events,
    AppRoutes.coins,
  ];

  /// Routes that require a string argument (shown as info only).
  static const _argRoutes = <String>[
    '${AppRoutes.room} (needs roomId)',
    '${AppRoutes.liveRoom} (needs roomId)',
    '${AppRoutes.chat} (needs chatId)',
    '${AppRoutes.userProfile} (needs userId)',
    '${AppRoutes.eventDetails} (needs eventId)',
    '${AppRoutes.messageThread} (needs threadId)',
    '${AppRoutes.hostTools} (needs roomId)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1520),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🧭 Route Test',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            Text(
              'DEV ONLY — tap to navigate',
              style: TextStyle(color: Color(0xFF8A99B0), fontSize: 11),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('No-Arg Routes (tap to navigate)'),
          ..._noArgRoutes.map((route) => _noArgTile(context, route)),
          const SizedBox(height: 16),
          _sectionHeader('Argument Routes (info only)'),
          ..._argRoutes.map((label) => _argInfoTile(label)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4A90FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _noArgTile(BuildContext context, String route) => Card(
        color: const Color(0xFF0F1520),
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          leading: const Icon(Icons.arrow_forward_ios,
              size: 13, color: Color(0xFF4A90FF)),
          title: Text(
            route,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          ),
          onTap: () => Navigator.pushNamed(context, route),
          trailing: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF8A99B0)),
        ),
      );

  Widget _argInfoTile(String label) => Card(
        color: const Color(0xFF0F1520),
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          leading: const Icon(Icons.info_outline,
              size: 14, color: Color(0xFF8A99B0)),
          title: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF8A99B0), fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      );
}

