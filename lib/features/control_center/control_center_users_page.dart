// lib/features/control_center/control_center_users_page.dart
//
// Admin view of all users: search, suspend/unsuspend, view profile.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/core/routing/app_routes.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';

class ControlCenterUsersPage extends ConsumerStatefulWidget {
  const ControlCenterUsersPage({super.key});

  @override
  ConsumerState<ControlCenterUsersPage> createState() =>
      _ControlCenterUsersPageState();
}

class _ControlCenterUsersPageState
    extends ConsumerState<ControlCenterUsersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> users) {
    if (_query.isEmpty) return users;
    final q = _query.toLowerCase();
    return users.where((u) {
      final name = (u['displayName'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _toggleBan(
      BuildContext context, Map<String, dynamic> user) async {
    final uid = user['id'] as String;
    final isBanned = user['isBanned'] == true;
    final action =
        isBanned ? ActionType.unbanUser : ActionType.banUser;

    await AuditLogService.instance.logAction(
      actionType: action,
      targetId: uid,
      metadata: {'displayName': user['displayName'] ?? uid},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBanned
              ? 'User unbanned'
              : 'User banned'),
          backgroundColor: isBanned ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: DesignColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),

        // ── User list ───────────────────────────────────────────────────────
        Expanded(
          child: usersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: Colors.red)),
            ),
            data: (all) {
              final users = _filter(all);
              if (users.isEmpty) {
                return const Center(
                  child: Text('No users found',
                      style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final u = users[i];
                  final uid = u['id'] as String;
                  final name = u['displayName'] as String? ?? 'Unknown';
                  final avatar = u['profileImageUrl'] as String?;
                  final role = u['role'] as String? ?? 'user';
                  final isBanned = u['isBanned'] == true;

                  return Card(
                    color: DesignColors.surfaceLight,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        backgroundColor: DesignColors.accent.withValues(alpha: 0.3),
                        child: avatar == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Row(
                        children: [
                          _RoleChip(role),
                          if (isBanned) ...[
                            const SizedBox(width: 6),
                            const _RoleChip('banned'),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: Colors.white54),
                        color: DesignColors.surfaceLight,
                        onSelected: (value) {
                          switch (value) {
                            case 'profile':
                              Navigator.pushNamed(
                                context,
                                AppRoutes.userProfile,
                                arguments: uid,
                              );
                            case 'ban':
                              _toggleBan(context, u);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: Text('View Profile',
                                style:
                                    TextStyle(color: Colors.white)),
                          ),
                          PopupMenuItem(
                            value: 'ban',
                            child: Text(
                              isBanned ? 'Unban User' : 'Ban User',
                              style: TextStyle(
                                  color: isBanned
                                      ? Colors.green
                                      : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.role);
  final String role;

  Color get _color => switch (role) {
        'superadmin' => DesignColors.tertiary,
        'admin' => DesignColors.accent,
        'banned' => Colors.red,
        _ => Colors.white24,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color, width: 1),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: _color, fontSize: 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

