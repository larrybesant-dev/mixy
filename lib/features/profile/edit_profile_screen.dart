import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/layout/app_layout.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import 'profile_completion.dart';
import 'profile_controller.dart';

// Common interest tags users can tap to add
const _kInterestSuggestions = [
  'Music',
  'Gaming',
  'Travel',
  'Fitness',
  'Food',
  'Art',
  'Movies',
  'Sports',
  'Tech',
  'Cooking',
  'Reading',
  'Dancing',
  'Fashion',
  'Photography',
  'Nature',
  'Anime',
  'Comedy',
  'Podcasts',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const EditProfileScreen({super.key, this.initialTab = 0});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _hydratedUserId;

  // Identity
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _aboutMeController = TextEditingController();
  final _locationController = TextEditingController();
  final _genderController = TextEditingController();
  final _relationshipController = TextEditingController();

  // Media
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  bool _isUploadingGallery = false;
  String? _avatarUrl;
  String? _coverPhotoUrl;
  List<String> _galleryUrls = <String>[];

  // Vibe and prompts
  final _vibePromptController = TextEditingController();
  final _firstDatePromptController = TextEditingController();
  final _musicTastePromptController = TextEditingController();
  final _introVideoController = TextEditingController();
  final _musicUrlController = TextEditingController();
  final _musicTitleController = TextEditingController();
  String? _profileAccentColor;

  // Interests
  final _interestInputController = TextEditingController();
  List<String> _interests = [];

  static const int _maxGalleryPhotos = 6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _hydrateFromState(ref.read(profileControllerProvider));
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).loadCurrentProfile(),
    );
  }

  void _hydrateFromState(ProfileState state) {
    final userId = state.userId;
    if (userId == null || userId.isEmpty || _hydratedUserId == userId) {
      return;
    }
    _hydratedUserId = userId;
    _nameController.text = state.username ?? '';
    _emailController.text = state.email ?? '';
    _avatarUrl = state.avatarUrl;
    _coverPhotoUrl = state.coverPhotoUrl;
    _galleryUrls = List<String>.from(state.galleryUrls);
    _bioController.text = state.bio ?? '';
    _aboutMeController.text = state.aboutMe ?? '';
    _locationController.text = state.location ?? '';
    _genderController.text = state.gender ?? '';
    _relationshipController.text = state.relationshipStatus ?? '';
    _vibePromptController.text = state.vibePrompt ?? '';
    _firstDatePromptController.text = state.firstDatePrompt ?? '';
    _musicTastePromptController.text = state.musicTastePrompt ?? '';
    _introVideoController.text = state.introVideoUrl ?? '';
    _musicUrlController.text = state.profileMusicUrl ?? '';
    _musicTitleController.text = state.profileMusicTitle ?? '';
    _profileAccentColor = state.profileAccentColor;
    _interests = List<String>.from(state.interests);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _aboutMeController.dispose();
    _locationController.dispose();
    _genderController.dispose();
    _relationshipController.dispose();
    _vibePromptController.dispose();
    _firstDatePromptController.dispose();
    _musicTastePromptController.dispose();
    _introVideoController.dispose();
    _musicUrlController.dispose();
    _musicTitleController.dispose();
    _interestInputController.dispose();
    super.dispose();
  }

  // ── Photo uploaders ────────────────────────────────────────────────────────

  Future<void> _pickAndUpload({
    required String storagePath,
    required void Function(String url) onSuccess,
    required void Function(bool loading) setLoading,
  }) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setLoading(true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref('$storagePath.$ext');
      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await snap.ref.getDownloadURL();
      if (mounted) onSuccess(url);
    } catch (e, st) {
      developer.log(
        'Upload failed',
        name: 'EditProfile',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      setLoading(false);
    }
  }

  Future<void> _addGalleryPhoto() async {
    if (_galleryUrls.length >= _maxGalleryPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 gallery photos.')),
      );
      return;
    }
    await _pickAndUpload(
      storagePath:
          'users/${FirebaseAuth.instance.currentUser?.uid}/gallery/${DateTime.now().millisecondsSinceEpoch}',
      onSuccess: (url) => setState(() => _galleryUrls = [..._galleryUrls, url]),
      setLoading: (v) => setState(() => _isUploadingGallery = v),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final current = ref.read(profileControllerProvider);
    try {
      await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(
            current.copyWith(
              username: _nameController.text.trim(),
              email: _emailController.text.trim(),
              avatarUrl: _avatarUrl ?? '',
              coverPhotoUrl: _coverPhotoUrl ?? '',
              galleryUrls: List<String>.from(_galleryUrls),
              bio: _bioController.text.trim(),
              aboutMe: _aboutMeController.text.trim(),
              location: _locationController.text.trim(),
              gender: _genderController.text.trim(),
              relationshipStatus: _relationshipController.text.trim(),
              vibePrompt: _vibePromptController.text.trim(),
              firstDatePrompt: _firstDatePromptController.text.trim(),
              musicTastePrompt: _musicTastePromptController.text.trim(),
              introVideoUrl: _introVideoController.text.trim(),
              profileMusicUrl: _musicUrlController.text.trim(),
              profileMusicTitle: _musicTitleController.text.trim(),
              profileAccentColor: _profileAccentColor,
              interests: List<String>.from(_interests),
            ),
          );
      if (!mounted) return;
      
      final updatedState = ref.read(profileControllerProvider);
      if (updatedState.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile saved!'),
            backgroundColor: Color(0xFF2D5016),
            duration: Duration(seconds: 2),
          ),
        );
        if (mounted) context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${updatedState.error}'),
            backgroundColor: const Color(0xFF8B0000),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: const Color(0xFF8B0000),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Completion banner ─────────────────────────────────────────────────────

  Widget _completionBanner(ProfileState s) {
    final pct = ProfileCompletion.completeness(
      s.copyWith(
        username: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : s.username,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : s.bio,
        aboutMe: _aboutMeController.text.trim().isNotEmpty
            ? _aboutMeController.text.trim()
            : s.aboutMe,
        avatarUrl: _avatarUrl ?? s.avatarUrl,
        coverPhotoUrl: _coverPhotoUrl ?? s.coverPhotoUrl,
        interests: _interests.isNotEmpty ? _interests : s.interests,
      ),
    );
    final pctInt = (pct * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VelvetNoir.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile completion',
                style: TextStyle(
                  color: VelvetNoir.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$pctInt%',
                style: TextStyle(
                  color: VelvetNoir.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFF2E2F3A),
              valueColor: AlwaysStoppedAnimation<Color>(VelvetNoir.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Basics ─────────────────────────────────────────────────────────

  Widget _buildPhotosTab(ProfileState s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Social profile media',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lead with visuals first: cover, avatar, and a six-photo gallery.',
          style: TextStyle(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 18),
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: _isUploadingCover
                  ? null
                  : () => _pickAndUpload(
                      storagePath:
                          'users/${FirebaseAuth.instance.currentUser?.uid}/cover',
                      onSuccess: (url) => setState(() => _coverPhotoUrl = url),
                      setLoading: (v) => setState(() => _isUploadingCover = v),
                    ),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2C),
                  borderRadius: BorderRadius.circular(20),
                  image: (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(_coverPhotoUrl ?? ''),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: _isUploadingCover
                      ? const CircularProgressIndicator()
                      : (_coverPhotoUrl == null || (_coverPhotoUrl ?? '').isEmpty)
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white38,
                                size: 36,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Add cover photo',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              margin: const EdgeInsets.all(14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Tap to replace cover',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                ),
              ),
            ),
            Positioned(
              bottom: -34,
              left: 18,
              child: GestureDetector(
                onTap: _isUploadingAvatar
                    ? null
                    : () => _pickAndUpload(
                        storagePath:
                            'users/${FirebaseAuth.instance.currentUser?.uid}/avatar',
                        onSuccess: (url) => setState(() => _avatarUrl = url),
                        setLoading: (v) =>
                            setState(() => _isUploadingAvatar = v),
                      ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFF23253A),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _avatarUrl ?? '',
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorWidget: (___, __, _) =>
                                    const Icon(Icons.person, size: 32),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white54,
                            ),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: VelvetNoir.primary,
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 52),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gallery',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_galleryUrls.length}/$_maxGalleryPhotos',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'This is the part your profile is missing today. Add a gallery so the page feels like a real social profile instead of a settings form.',
          style: TextStyle(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _maxGalleryPhotos,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final hasPhoto = index < _galleryUrls.length;
            return _GallerySlot(
              imageUrl: hasPhoto ? _galleryUrls[index] : null,
              loading: _isUploadingGallery && !hasPhoto,
              onTap: hasPhoto ? null : _addGalleryPhoto,
              onRemove: hasPhoto
                  ? () => setState(() => _galleryUrls.removeAt(index))
                  : null,
            );
          },
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: (_isUploadingGallery || _galleryUrls.length >= _maxGalleryPhotos)
              ? null
              : _addGalleryPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add gallery photo'),
        ),
        const SizedBox(height: 18),
        Text(
          'Intro video',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _introVideoController,
          decoration: const InputDecoration(
            labelText: 'Intro video URL',
            prefixIcon: Icon(Icons.play_circle_outline_rounded),
            hintText: 'https://...',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use a direct intro link so visitors get movement and personality on first view.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Private account'),
          subtitle: Text(
            s.privacy.isPrivate
                ? 'Only followers can view your profile'
                : 'Anyone can view your profile',
          ),
          value: s.privacy.isPrivate,
          onChanged: (val) => ref
              .read(profileControllerProvider.notifier)
              .updateDraft(
                s.copyWith(privacy: s.privacy.copyWith(isPrivate: val)),
              ),
        ),
      ],
    );
  }

  Widget _buildIdentityTab(ProfileState s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          _nameController,
          'Display name',
          Icons.person_outline,
          next: true,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: 'Bio / status',
            hintText: 'The one-liner people see first',
            prefixIcon: Icon(Icons.short_text),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _aboutMeController,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'About me',
            hintText: 'Give your profile some personality beyond a single line.',
            prefixIcon: const Icon(Icons.article_outlined),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        _field(_locationController, 'Location', Icons.place_outlined, next: true),
        const SizedBox(height: 14),
        _field(_genderController, 'Gender', Icons.person_pin_outlined, next: true),
        const SizedBox(height: 14),
        _field(
          _relationshipController,
          'Relationship status',
          Icons.favorite_border,
          next: true,
        ),
        const SizedBox(height: 20),
        Text(
          'Account contact',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _field(_emailController, 'Email', Icons.email_outlined, next: true),
        const SizedBox(height: 6),
        const Text(
          'Public identity belongs here. Password changes should live in account settings, not inside the social profile builder.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildVibeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Prompts that start conversations',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Most social apps feel alive because the profile gives people hooks to respond to. Build those hooks here.',
          style: TextStyle(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _vibePromptController,
          maxLines: 3,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Tonight vibe',
            hintText: 'What energy are you on right now?',
            prefixIcon: Icon(Icons.local_fire_department_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _firstDatePromptController,
          maxLines: 3,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'First date move',
            hintText: 'What is your ideal first link-up?',
            prefixIcon: Icon(Icons.date_range_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _musicTastePromptController,
          maxLines: 3,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Music in rotation',
            hintText: 'What are you playing right now?',
            prefixIcon: Icon(Icons.queue_music_outlined),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _interestInputController,
                decoration: const InputDecoration(
                  hintText: 'Type an interest…',
                  prefixIcon: Icon(Icons.tag),
                ),
                onFieldSubmitted: _addInterest,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _addInterest(_interestInputController.text),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_interests.isNotEmpty) ...[
          const Text(
            'Your interests',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map(
                  (i) => Chip(
                    label: Text(i),
                    onDeleted: () => setState(() => _interests.remove(i)),
                    deleteIconColor: VelvetNoir.primary,
                    backgroundColor: const Color(0xFF1C1F2C),
                    side: BorderSide(color: VelvetNoir.primary.withAlpha(80)),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Profile Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _field(
          _musicTitleController,
          'Song title',
          Icons.music_note_outlined,
          next: true,
        ),
        const SizedBox(height: 14),
        _field(_musicUrlController, 'Direct MP3 URL', Icons.link, next: true),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Enter a direct https link to an MP3 file.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Accent Color',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _colorOption(null, 'Default'),
            _colorOption('#D4A853', 'Gold'),
            _colorOption('#FF6EB4', 'Pink'),
            _colorOption('#4A90E2', 'Blue'),
            _colorOption('#50E3C2', 'Teal'),
            _colorOption('#B8E986', 'Green'),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Suggestions',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kInterestSuggestions
              .where((s) => !_interests.contains(s))
              .map(
                (s) => ActionChip(
                  label: Text(s),
                  onPressed: () => _addInterest(s),
                  backgroundColor: const Color(0xFF16181F),
                  side: const BorderSide(color: Color(0xFF2E2F3A)),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _addInterest(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _interests.contains(trimmed)) return;
    setState(() => _interests.add(trimmed));
    _interestInputController.clear();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool next = false,
  }) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      textInputAction: next ? TextInputAction.next : TextInputAction.done,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    _hydrateFromState(state);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surface,
        title: const Text('Edit Social Profile'),
        actions: [
          TextButton(
            onPressed: state.isLoading ? null : _saveProfile,
            child: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: VelvetNoir.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VelvetNoir.primary,
          labelColor: VelvetNoir.primary,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Photos & Media'),
            Tab(text: 'Identity'),
            Tab(text: 'Vibe & Prompts'),
          ],
        ),
      ),
      body: Column(
        children: [
          _completionBanner(state),
          if (state.error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.pageHorizontalPadding,
                8,
                context.pageHorizontalPadding,
                0,
              ),
              child: Text(
                state.error ?? 'Unknown error',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPhotosTab(state),
                _buildIdentityTab(state),
                _buildVibeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorOption(String? hex, String label) {
    final isSelected = _profileAccentColor == hex;
    final color = hex != null
        ? Color(int.parse(hex.replaceFirst('#', '0xFF')))
        : VelvetNoir.primary;
    return GestureDetector(
      onTap: () => setState(() => _profileAccentColor = hex),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySlot extends StatelessWidget {
  const _GallerySlot({
    required this.imageUrl,
    required this.loading,
    this.onTap,
    this.onRemove,
  });

  final String? imageUrl;
  final bool loading;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').isNotEmpty;
    return Material(
      color: const Color(0xFF1E1E24),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                    ),
                  ),
                )
              else
                Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add photo',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              if (hasImage && onRemove != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



