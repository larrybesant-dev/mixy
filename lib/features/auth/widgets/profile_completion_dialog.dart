import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/profile/profile_controller.dart';
import 'package:mixvy/core/theme.dart';

/// Lightweight post-signup profile completion dialog
/// Collects avatar + bio from new users before heading to home
class ProfileCompletionDialog extends ConsumerStatefulWidget {
  final String userId;
  final String? initialUsername;

  const ProfileCompletionDialog({
    super.key,
    required this.userId,
    this.initialUsername,
  });

  @override
  ConsumerState<ProfileCompletionDialog> createState() =>
      _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends ConsumerState<ProfileCompletionDialog> {
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref('users/${widget.userId}/avatar.$ext');
      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await snap.ref.getDownloadURL();
      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _completeProfile() async {
    setState(() => _isSaving = true);
    try {
      final bio = _bioController.text.trim();
      final profileController = ref.read(profileControllerProvider.notifier);

      // Build profile state with avatar + bio
      final currentState = ref.read(profileControllerProvider);
      final updatedProfile = currentState.copyWith(
        userId: widget.userId,
        username: widget.initialUsername,
        avatarUrl: _avatarUrl,
        bio: bio.isEmpty ? null : bio,
      );

      // Save profile
      await profileController.updateProfile(updatedProfile);

      if (!mounted) return;

      // Check if save was successful
      final updatedState = ref.read(profileControllerProvider);
      if (updatedState.error == null) {
        // Success - navigate to home
        if (mounted) {
          context.go('/home');
        }
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${updatedState.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VelvetNoir.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                '✨ Complete Your Profile',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Help people get to know you',
                style: GoogleFonts.raleway(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 28),

              // Avatar upload
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VelvetNoir.secondary.withOpacity(0.2),
                    border: Border.all(
                      color: VelvetNoir.primary.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: _isUploadingAvatar
                      ? const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                        )
                      : _avatarUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(_avatarUrl!),
                              radius: 50,
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    color: VelvetNoir.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add Photo',
                                    style: GoogleFonts.raleway(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 28),

              // Bio input
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 150,
                style: GoogleFonts.raleway(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tell people about yourself (optional)',
                  hintStyle: GoogleFonts.raleway(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: VelvetNoir.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(
                children: [
                  // Skip button
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => context.go('/home'),
                      child: Text(
                        'Skip for now',
                        style: GoogleFonts.raleway(
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Continue button
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _completeProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: VelvetNoir.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Color(0xFF0B0B0B)),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.raleway(
                                color: VelvetNoir.surface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the profile completion dialog after signup
void showProfileCompletionDialog(
  BuildContext context,
  String userId, {
  String? initialUsername,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ProfileCompletionDialog(
      userId: userId,
      initialUsername: initialUsername,
    ),
  );
}
