import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mixvy/services/camera/camera_permission_service.dart';
import 'package:mixvy/shared/models/camera_permission.dart';

class CameraPermissionList extends ConsumerWidget {
  final bool
      showRequests; // true for incoming requests, false for granted permissions

  const CameraPermissionList({
    super.key,
    this.showRequests = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<CameraPermission>>(
      stream: showRequests
          ? CameraPermissionService().getPendingRequests()
          : CameraPermissionService().getGrantedPermissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4C4C)),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading permissions',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final permissions = snapshot.data ?? const [];

        if (permissions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showRequests ? Icons.inbox : Icons.check_circle_outline,
                  size: 64,
                  color: Colors.white30,
                ),
                const SizedBox(height: 16),
                Text(
                  showRequests
                      ? 'No pending requests'
                      : 'No active permissions',
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: permissions.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final permission = permissions[index];
            return _PermissionCard(
              permission: permission,
              showActions: showRequests,
            );
          },
        );
      },
    );
  }
}

class _PermissionCard extends ConsumerStatefulWidget {
  final CameraPermission permission;
  final bool showActions;

  const _PermissionCard({
    required this.permission,
    required this.showActions,
  });

  @override
  ConsumerState<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends ConsumerState<_PermissionCard> {
  bool _isProcessing = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final userId = widget.showActions
          ? widget.permission.requesterId
          : widget.permission.requesterId;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (mounted && userDoc.exists) {
        setState(() {
          _userName = userDoc.data()?['username'] ?? 'Unknown User';
        });
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  Future<void> _grantPermission() async {
    setState(() => _isProcessing = true);
    try {
      await CameraPermissionService().grantPermission(widget.permission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission granted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on CameraPermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _denyPermission() async {
    setState(() => _isProcessing = true);
    try {
      await CameraPermissionService().denyPermission(widget.permission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on CameraPermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _revokePermission() async {
    setState(() => _isProcessing = true);
    try {
      await CameraPermissionService().revokePermission(widget.permission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission revoked'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on CameraPermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E2F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.showActions
              ? const Color(0xFFFF4C4C).withValues(alpha: 0.5)
              : const Color(0xFF4CAF50).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFF4C4C),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.showActions
                            ? 'Wants to view your camera'
                            : 'Can view your camera',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.showActions)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  timeago.format(widget.permission.requestedAt),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (widget.permission.expiresAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.timer,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Expires ${timeago.format(widget.permission.expiresAt!)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            if (widget.showActions) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : _denyPermission,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text('Deny'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _grantPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4C4C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Grant',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isProcessing ? null : _revokePermission,
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Revoke'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

