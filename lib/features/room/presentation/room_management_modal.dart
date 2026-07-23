import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/room/controllers/room_management_controller.dart';
import 'package:mixvy/models/room_model.dart';

/// Modal for room owner/admin to manage room settings, admins, and photos
class RoomManagementModal extends ConsumerStatefulWidget {
  final String roomId;
  final RoomModel room;

  const RoomManagementModal({
    required this.roomId,
    required this.room,
    super.key,
  });

  @override
  ConsumerState<RoomManagementModal> createState() =>
      _RoomManagementModalState();
}

class _RoomManagementModalState extends ConsumerState<RoomManagementModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _adminEmailController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _rulesController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _adminEmailController = TextEditingController();
    _nameController = TextEditingController(text: widget.room.name);
    _descriptionController =
        TextEditingController(text: widget.room.description ?? '');
    _rulesController = TextEditingController(text: widget.room.rules ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminEmailController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxHeight: 1200,
        maxWidth: 1200,
      );

      if (images.isEmpty) return;

      // Get Firebase Storage reference
      final storage = ref.read(firebaseStorageProvider);
      final controller = ref.read(roomManagementProvider.notifier);

      for (final image in images) {
        try {
          // Upload to Firebase Storage at /rooms/{roomId}/photos/{timestamp}
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'photo_$timestamp.jpg';
          final refUpload = storage.ref('rooms/${widget.roomId}/photos/$fileName');

          // Read file bytes and upload
          final bytes = await image.readAsBytes();
          await refUpload.putData(
            bytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
            ),
          );

          // Get download URL
          final photoUrl = await refUpload.getDownloadURL();

          // Add photo to room via controller
          await controller.addRoomPhoto(
            roomId: widget.roomId,
            photoUrl: photoUrl,
            caption: 'Room photo',
          );

          debugPrint('[RoomMgmt] Photo uploaded: $fileName');
        } catch (e) {
          debugPrint('[RoomMgmt] Failed to upload photo: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload photo: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[RoomMgmt] Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image picker error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final managementState = ref.watch(roomManagementProvider);
    final permissions =
        ref.watch(roomPermissionsProvider(widget.roomId)).valueOrNull;

    // If user can't manage, show error
    if (permissions != null && !permissions.canManage) {
      return _buildPermissionDenied();
    }

    return Dialog(
      backgroundColor: VelvetNoir.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: VelvetNoir.surface,
          elevation: 0,
          title: Text(
            'Manage Room',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: VelvetNoir.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: VelvetNoir.primary,
            labelColor: VelvetNoir.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Settings'),
              Tab(text: 'Admins'),
              Tab(text: 'Photos'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSettingsTab(managementState),
            _buildAdminsTab(managementState, permissions),
            _buildPhotosTab(managementState, permissions),
          ],
        ),
      ),
    );
  }

  /// Settings tab: Edit room name, description, rules, lock status
  Widget _buildSettingsTab(RoomManagementState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status message
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (state.successMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                state.successMessage!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
          const SizedBox(height: 16),

          // Room name
          Text(
            'Room Name',
            style: GoogleFonts.raleway(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter room name',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
            ),
            style: const TextStyle(color: VelvetNoir.onSurface),
            maxLength: 120,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Description',
            style: GoogleFonts.raleway(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Enter room description',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
            ),
            style: const TextStyle(color: VelvetNoir.onSurface),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          // Rules
          Text(
            'Room Rules',
            style: GoogleFonts.raleway(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rulesController,
            decoration: InputDecoration(
              hintText: 'Enter room rules',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
            ),
            style: const TextStyle(color: VelvetNoir.onSurface),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 16),

          // Lock status
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lock Room',
                  style: GoogleFonts.raleway(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: VelvetNoir.onSurface,
                  ),
                ),
              ),
              Checkbox(
                value: widget.room.isLocked,
                onChanged: (value) {
                  // Will implement with state management
                },
                activeColor: VelvetNoir.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () => _saveRoomSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetNoir.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Save Settings',
                      style: GoogleFonts.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Admins tab: Manage admin list
  Widget _buildAdminsTab(RoomManagementState state, RoomPermissions? permissions) {
    if (permissions == null || !permissions.canManageAdmins) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Only room owner can manage admins',
            style: GoogleFonts.raleway(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
          if (state.successMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child:
                  Text(state.successMessage!, style: const TextStyle(color: Colors.green)),
            ),
          const SizedBox(height: 16),

          // Current admins list
          Text(
            'Current Admins (${widget.room.adminUserIds.length})',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.room.adminUserIds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No admins yet',
                style: GoogleFonts.raleway(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.room.adminUserIds.length,
              itemBuilder: (context, index) {
                final adminId = widget.room.adminUserIds[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VelvetNoir.primary),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            adminId,
                            style: GoogleFonts.raleway(
                              fontSize: 14,
                              color: VelvetNoir.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: state.isLoading
                              ? null
                              : () => _removeAdmin(adminId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // Add admin
          Text(
            'Add Admin',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminEmailController,
            decoration: InputDecoration(
              hintText: 'Enter user ID to add as admin',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: VelvetNoir.primary),
              ),
            ),
            style: const TextStyle(color: VelvetNoir.onSurface),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _addAdmin,
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetNoir.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Add Admin',
                      style: GoogleFonts.raleway(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Photos tab: Upload and manage room photos
  Widget _buildPhotosTab(RoomManagementState state, RoomPermissions? permissions) {
    if (permissions == null || !permissions.canManagePhotos) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'You do not have permission to manage photos',
            style: GoogleFonts.raleway(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(state.error!, style: const TextStyle(color: Colors.red)),
            ),
          if (state.successMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child:
                  Text(state.successMessage!, style: const TextStyle(color: Colors.green)),
            ),
          const SizedBox(height: 16),

          Text(
            'Upload Photos',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VelvetNoir.primary,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: VelvetNoir.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap to upload photos',
                  style: GoogleFonts.raleway(
                    fontSize: 14,
                    color: VelvetNoir.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supports PNG, JPG, GIF',
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : _pickAndUploadImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                'Choose Photos',
                style: GoogleFonts.raleway(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetNoir.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Room Gallery',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: VelvetNoir.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Photos will appear here once uploaded',
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Permission denied dialog
  Widget _buildPermissionDenied() {
    return Center(
      child: Dialog(
        backgroundColor: VelvetNoir.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: VelvetNoir.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: VelvetNoir.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You do not have permission to manage this room',
                textAlign: TextAlign.center,
                style: GoogleFonts.raleway(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VelvetNoir.primary,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.raleway(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRoomSettings() async {
    final controller = ref.read(roomManagementProvider.notifier);
    await controller.updateRoomSettings(
      roomId: widget.roomId,
      name: _nameController.text,
      description: _descriptionController.text,
      rules: _rulesController.text,
      isLocked: widget.room.isLocked,
    );
  }

  Future<void> _addAdmin() async {
    if (_adminEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user ID')),
      );
      return;
    }

    final controller = ref.read(roomManagementProvider.notifier);
    await controller.addAdmin(
      roomId: widget.roomId,
      adminUserId: _adminEmailController.text.trim(),
    );

    _adminEmailController.clear();
  }

  Future<void> _removeAdmin(String adminId) async {
    final controller = ref.read(roomManagementProvider.notifier);
    await controller.removeAdmin(
      roomId: widget.roomId,
      adminUserId: adminId,
    );
  }
}
