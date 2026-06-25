import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../shared/providers/providers.dart';
import '../../shared/models/user.dart';
import '../../shared/club_background.dart';
import '../../shared/glow_text.dart';
import '../../shared/neon_button.dart';
import '../../shared/loading_widgets.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  late List<String> _mediaUrls;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mediaUrls = [];
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final userAsync = ref.read(currentUserProvider);
    userAsync.whenData((user) {
      if (user != null && mounted) {
        _usernameController.text = user.username;
        _emailController.text = user.email;
        _bioController.text = user.bio;
        setState(() {
          _mediaUrls = List.from(user.recentMediaUrls);
        });
      }
    });
  }

  Future<void> _pickAvatar() async {
    try {
      XFile? image;

      if (kIsWeb) {
        // On web, show options dialog
        if (!mounted) return;
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choose Image Source'),
            content: const Text('Select where to pick the image from:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (source == null) return;

        image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
      } else {
        // On mobile, use gallery directly
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
      }

      if (image != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);

        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser == null) throw Exception('User not found');

        final storageService = ref.read(storageServiceProvider);
        final imageUrl =
            await storageService.uploadImage(image, currentUser.id);

        if (imageUrl != null) {
          final updatedUser = User(
            id: currentUser.id,
            displayName: currentUser.displayName,
            username: currentUser.username,
            email: currentUser.email,
            bio: currentUser.bio,
            interests: currentUser.interests,
            avatarUrl: imageUrl,
            coinBalance: currentUser.coinBalance,
            createdAt: currentUser.createdAt,
            location: currentUser.location,
            statusMessage: currentUser.statusMessage,
            followersCount: currentUser.followersCount,
            followingCount: currentUser.followingCount,
            totalTipsReceived: currentUser.totalTipsReceived,
            liveSessionsHosted: currentUser.liveSessionsHosted,
            socialLinks: currentUser.socialLinks,
            featuredRoomId: currentUser.featuredRoomId,
            featuredContentUrl: currentUser.featuredContentUrl,
            topGifts: currentUser.topGifts,
            recentMediaUrls: currentUser.recentMediaUrls,
            recentActivity: currentUser.recentActivity,
            isOnline: currentUser.isOnline,
            lastSeen: currentUser.lastSeen,
            membershipTier: currentUser.membershipTier,
            badges: currentUser.badges,
            profileComplete: true,
          );

          await ref.read(firestoreServiceProvider).updateUser(updatedUser);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Avatar updated successfully')),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addMedia() async {
    try {
      XFile? image;

      if (kIsWeb) {
        // On web, show options dialog
        if (!mounted) return;
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choose Image Source'),
            content: const Text('Select where to pick the image from:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                child: const Text('Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (source == null) return;

        image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
      } else {
        // On mobile, use gallery directly
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
      }

      if (image != null) {
        if (!mounted) return;
        setState(() => _isLoading = true);

        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser == null) throw Exception('User not found');

        final storageService = ref.read(storageServiceProvider);
        final imageUrl =
            await storageService.uploadImage(image, currentUser.id);

        if (imageUrl != null) {
          setState(() {
            _mediaUrls.add(imageUrl);
          });

          final updatedUser = User(
            id: currentUser.id,
            displayName: currentUser.displayName,
            username: currentUser.username,
            email: currentUser.email,
            bio: currentUser.bio,
            interests: currentUser.interests,
            avatarUrl: currentUser.avatarUrl,
            coinBalance: currentUser.coinBalance,
            createdAt: currentUser.createdAt,
            location: currentUser.location,
            statusMessage: currentUser.statusMessage,
            followersCount: currentUser.followersCount,
            followingCount: currentUser.followingCount,
            totalTipsReceived: currentUser.totalTipsReceived,
            liveSessionsHosted: currentUser.liveSessionsHosted,
            socialLinks: currentUser.socialLinks,
            featuredRoomId: currentUser.featuredRoomId,
            featuredContentUrl: currentUser.featuredContentUrl,
            topGifts: currentUser.topGifts,
            recentMediaUrls: _mediaUrls,
            recentActivity: currentUser.recentActivity,
            isOnline: currentUser.isOnline,
            lastSeen: currentUser.lastSeen,
            membershipTier: currentUser.membershipTier,
            badges: currentUser.badges,
            profileComplete: true,
          );

          await ref.read(firestoreServiceProvider).updateUser(updatedUser);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo added successfully')),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add photo: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMedia(int index) async {
    final url = _mediaUrls[index];
    setState(() {
      _mediaUrls.removeAt(index);
    });

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) throw Exception('User not found');

      final updatedUser = User(
        id: currentUser.id,
        displayName: currentUser.displayName,
        username: currentUser.username,
        email: currentUser.email,
        bio: currentUser.bio,
        interests: currentUser.interests,
        avatarUrl: currentUser.avatarUrl,
        coinBalance: currentUser.coinBalance,
        createdAt: currentUser.createdAt,
        location: currentUser.location,
        statusMessage: currentUser.statusMessage,
        followersCount: currentUser.followersCount,
        followingCount: currentUser.followingCount,
        totalTipsReceived: currentUser.totalTipsReceived,
        liveSessionsHosted: currentUser.liveSessionsHosted,
        socialLinks: currentUser.socialLinks,
        featuredRoomId: currentUser.featuredRoomId,
        featuredContentUrl: currentUser.featuredContentUrl,
        topGifts: currentUser.topGifts,
        recentMediaUrls: _mediaUrls,
        recentActivity: currentUser.recentActivity,
        isOnline: currentUser.isOnline,
        lastSeen: currentUser.lastSeen,
        membershipTier: currentUser.membershipTier,
        badges: currentUser.badges,
        profileComplete: true,
      );

      await ref.read(firestoreServiceProvider).updateUser(updatedUser);

      // Try to delete from storage
      try {
        await ref.read(storageServiceProvider).deleteFile(url);
      } catch (e) {
        // Ignore storage deletion errors
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newUsername = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) throw Exception('User not found');

      // Check if username is being changed and if it's already taken
      if (newUsername != currentUser.username) {
        final firestoreService = ref.read(firestoreServiceProvider);
        final usernameTaken =
            await firestoreService.isUsernameTaken(newUsername);
        if (usernameTaken) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Username is already taken. Please choose a different one.')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final updatedUser = User(
        id: currentUser.id,
        displayName: currentUser.displayName,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        bio: _bioController.text.trim(),
        interests: currentUser.interests,
        avatarUrl: currentUser.avatarUrl,
        coinBalance: currentUser.coinBalance,
        createdAt: currentUser.createdAt,
        location: currentUser.location,
        statusMessage: currentUser.statusMessage,
        followersCount: currentUser.followersCount,
        followingCount: currentUser.followingCount,
        totalTipsReceived: currentUser.totalTipsReceived,
        liveSessionsHosted: currentUser.liveSessionsHosted,
        socialLinks: currentUser.socialLinks,
        featuredRoomId: currentUser.featuredRoomId,
        featuredContentUrl: currentUser.featuredContentUrl,
        topGifts: currentUser.topGifts,
        recentMediaUrls: _mediaUrls,
        recentActivity: currentUser.recentActivity,
        isOnline: currentUser.isOnline,
        lastSeen: currentUser.lastSeen,
        membershipTier: currentUser.membershipTier,
        badges: currentUser.badges,
        profileComplete: true,
      );

      await ref.read(firestoreServiceProvider).updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const GlowText(
            text: 'Edit Profile',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
            glowColor: Color(0xFFFF4C4C),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: const GlowText(
                text: 'Save',
                fontSize: 16,
                color: Color(0xFFFF4C4C),
                glowColor: Color(0xFFFF4C4C),
              ),
            ),
          ],
        ),
        body: userAsync.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child: GlowText(
                  text: 'User not found',
                  fontSize: 18,
                  color: Color(0xFFFF4C4C),
                ),
              );
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF4C4C),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4C4C).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        key: ValueKey(user.avatarUrl),
                        radius: 60,
                        backgroundImage: user.avatarUrl.isNotEmpty
                            ? NetworkImage(
                                '${user.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}')
                            : null,
                        backgroundColor: const Color(0xFFFF4C4C),
                        child: user.avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      onPressed: _isLoading ? null : _pickAvatar,
                      child: const Text('Change Avatar'),
                    ),
                    const SizedBox(height: 32),

                    // Form fields
                    TextFormField(
                      key: const Key('usernameField'),
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: Color(0xFFFFD700)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username cannot be empty';
                        }
                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (value.trim().length > 20) {
                          return 'Username must be less than 20 characters';
                        }
                        final usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
                        if (!usernameRegex.hasMatch(value.trim())) {
                          return 'Username can only contain letters, numbers, underscores, and dots';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      key: const Key('emailField'),
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email, color: Color(0xFFFFD700)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email cannot be empty';
                        }
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      key: const Key('bioField'),
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.description, color: Color(0xFFFFD700)),
                        hintText: 'Tell us about yourself...',
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      validator: (value) {
                        if (value != null && value.length > 500) {
                          return 'Bio must be less than 500 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Media Gallery
                    Container(
                      key: const Key('photoCarouselContainer'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const GlowText(
                                text: 'My Photos',
                                fontSize: 18,
                                color: Color(0xFFFFD700),
                                glowColor: Color(0xFFFF4C4C),
                              ),
                              NeonButton(
                                key: const Key('addPhotoButton'),
                                onPressed: _isLoading ? null : _addMedia,
                                child: const Text('Add Photo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_mediaUrls.isEmpty)
                            Container(
                              key: const Key('emptyPhotosMessage'),
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_camera,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No photos yet. Add some photos to showcase your style!',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 250,
                              child: PageView.builder(
                                key: const Key('photoCarousel'),
                                itemCount: _mediaUrls.length,
                                controller: PageController(viewportFraction: 0.8),
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(_mediaUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            key: Key('removePhotoButton_$index'),
                                            onTap: () => _removeMedia(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '${index + 1} / ${_mediaUrls.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const GlowText(
                            text: 'Your Stats',
                            fontSize: 18,
                            color: Color(0xFFFFD700),
                            glowColor: Color(0xFFFF4C4C),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('Rooms Created',
                                  user.liveSessionsHosted.toString()),
                              _buildStat('Tips Received',
                                  '\$${user.totalTipsReceived.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const FullScreenLoader(message: 'Loading profile...'),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GlowText(
                  text: 'Failed to load profile',
                  fontSize: 18,
                  color: Color(0xFFFF4C4C),
                  glowColor: Color(0xFFFF4C4C),
                ),
                const SizedBox(height: 8),
                GlowText(
                  text: error.toString(),
                  fontSize: 14,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                NeonButton(
                  onPressed: () => ref.invalidate(currentUserProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        GlowText(
          text: value,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFD700),
          glowColor: const Color(0xFFFF4C4C),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
