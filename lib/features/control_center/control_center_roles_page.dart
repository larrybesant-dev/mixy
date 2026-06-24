// lib/features/control_center/control_center_roles_page.dart
//
// SuperAdmin-only page for managing global user roles.
// Calls the `setUserRole` Firebase Callable Cloud Function (v2).
// Falls back to direct Firestore write for the optimistic role field
// while custom claims propagate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/core/services/role_service.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';

class ControlCenterRolesPage extends ConsumerWidget {
  const ControlCenterRolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdminAsync = ref.watch(isSuperAdminProvider);

    return isSuperAdminAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
          child: Text('Error', style: TextStyle(color: Colors.red))),
      data: (isSuperAdmin) {
        if (!isSuperAdmin) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.white38, size: 64),
                SizedBox(height: 16),
                Text(
                  'SuperAdmin access required',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return _RoleManagementView();
      },
    );
  }
}

class _RoleManagementView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RoleManagementView> createState() =>
      _RoleManagementViewState();
}

class _RoleManagementViewState
    extends ConsumerState<_RoleManagementView> {
  final _uidController = TextEditingController();
  UserRole _selectedRole = UserRole.user;
  bool _loading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _applyRole() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a user UID.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('setUserRole');
      await callable.call({'uid': uid, 'role': _selectedRole.value});

      await AuditLogService.instance.logAction(
        actionType: ActionType.setRole,
        targetId: uid,
        metadata: {'role': _selectedRole.value},
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Role "${_selectedRole.value}" applied to $uid.';
          _isError = false;
          _uidController.clear();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Error: ${e.message}';
          _isError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Unexpected error: $e';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role assignment form ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DesignColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: DesignColors.tertiary.withValues(alpha: 0.4),
                  width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign Role',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _uidController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'User UID',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: DesignColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<UserRole>(
                  value: _selectedRole,
                  dropdownColor: DesignColors.surfaceLight,
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  underline: Container(
                    height: 1,
                    color: Colors.white24,
                  ),
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.value.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignColors.tertiary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : _applyRole,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Apply Role',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isError ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Existing admin/superadmin users ──────────────────────────────
          const Text(
            'Current Admins',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          usersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: Colors.red)),
            data: (users) {
              final admins = users.where((u) {
                final role = u['role'] as String? ?? 'user';
                return role == 'admin' || role == 'superadmin';
              }).toList();
              if (admins.isEmpty) {
                return const Text('No admins assigned',
                    style: TextStyle(color: Colors.white38));
              }
              return Column(
                children: admins
                    .map((u) => _AdminUserTile(user: u))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = user['displayName'] as String? ?? user['id'] as String;
    final role = user['role'] as String? ?? 'user';
    final avatar = user['profileImageUrl'] as String?;
    final roleColor = role == 'superadmin'
        ? DesignColors.tertiary
        : DesignColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            backgroundColor: roleColor.withValues(alpha: 0.2),
            child: avatar == null
                ? Icon(Icons.person, color: roleColor, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: roleColor, width: 1),
            ),
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                  color: roleColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

