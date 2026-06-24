import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mixvy/services/camera/camera_permission_service.dart';
import 'package:mixvy/shared/models/camera_permission.dart';
import 'package:mixvy/shared/widgets/camera_permission_list.dart';
import 'package:mixvy/shared/widgets/club_background.dart';

class CameraPermissionsPage extends ConsumerStatefulWidget {
  const CameraPermissionsPage({super.key});

  @override
  ConsumerState<CameraPermissionsPage> createState() =>
      _CameraPermissionsPageState();
}

class _CameraPermissionsPageState extends ConsumerState<CameraPermissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Camera Permissions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF4C4C),
            labelColor: const Color(0xFFFF4C4C),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(
                icon: Icon(Icons.notifications),
                text: 'Requests',
              ),
              Tab(
                icon: Icon(Icons.check_circle),
                text: 'Granted',
              ),
              Tab(
                icon: Icon(Icons.videocam),
                text: 'My Access',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            // Incoming requests
            CameraPermissionList(showRequests: true),
            // Permissions I've granted
            CameraPermissionList(showRequests: false),
            // My permissions (access I have)
            _MyPermissionsTab(),
          ],
        ),
      ),
    );
  }
}

class _MyPermissionsTab extends ConsumerWidget {
  const _MyPermissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: CameraPermissionService().getMyPermissions(),
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

        final permissions = snapshot.data ?? [];

        if (permissions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off,
                  size: 64,
                  color: Colors.white30,
                ),
                SizedBox(height: 16),
                Text(
                  'No camera access granted to you',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
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
            return _MyPermissionCard(permission: permission);
          },
        );
      },
    );
  }
}

class _MyPermissionCard extends ConsumerStatefulWidget {
  final CameraPermission permission;

  const _MyPermissionCard({required this.permission});

  @override
  ConsumerState<_MyPermissionCard> createState() => _MyPermissionCardState();
}

class _MyPermissionCardState extends ConsumerState<_MyPermissionCard> {
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.permission.ownerId)
          .get();
      if (mounted && userDoc.exists) {
        setState(() {
          _ownerName = userDoc.data()?['username'] ?? 'Unknown User';
        });
      }
    } catch (e) {
      debugPrint('Error loading owner name: $e');
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
          color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF4CAF50),
              child: Icon(Icons.videocam, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerName ?? 'Loading...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can view their camera',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.permission.expiresAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
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
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

