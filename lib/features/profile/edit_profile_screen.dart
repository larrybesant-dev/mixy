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
  'Music', 'Gaming', 'Travel', 'Fitness', 'Food', 'Art', 'Movies',
  'Sports', 'Tech', 'Cooking', 'Reading', 'Dancing', 'Fashion',
  'Photography', 'Nature', 'Anime', 'Comedy', 'Podcasts',
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

  // Tab 0 – Basics
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  String? _avatarUrl;
  String? _coverPhotoUrl;

  // Tab 1 – About
  final _bioController = TextEditingController();
  final _aboutMeController = TextEditingController();

  // Tab 2 – Personalization
  final _musicUrlController = TextEditingController();
  final _musicTitleController = TextEditingController();
  String? _profileAccentColor;

  // Tab 3 – Interests
  final _interestInputController = TextEditingController();
  List<String> _interests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    final s = ref.read(profileControllerProvider);
    _nameController.text = s.username ?? '';
    _emailController.text = s.email ?? '';
    _avatarUrl = s.avatarUrl;
    _coverPhotoUrl = s.coverPhotoUrl;
    _bioController.text = s.bio ?? '';
    _aboutMeController.text = s.aboutMe ?? '';
    _musicUrlController.text = s.profileMusicUrl ?? '';
    _musicTitleController.text = s.profileMusicTitle ?? '';
    _profileAccentColor = s.profileAccentColor;
    _interests = List<String>.from(s.interests);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _aboutMeController.dispose();
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
      final snap = await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await snap.ref.getDownloadURL();
      if (mounted) onSuccess(url);
    } catch (e, st) {
      developer.log('Upload failed', name: 'EditProfile', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final current = ref.read(profileControllerProvider);
    await ref.read(profileControllerProvider.notifier).updateProfile(
      current.copyWith(
        username: _nameController.text.trim(),
        email: _emailController.text.trim(),
        avatarUrl: _avatarUrl ?? '',
        coverPhotoUrl: _coverPhotoUrl ?? '',
        bio: _bioController.text.trim(),
        aboutMe: _aboutMeController.text.trim(),
        profileMusicUrl: _musicUrlController.text.trim(),
        profileMusicTitle: _musicTitleController.text.trim(),
        profileAccentColor: _profileAccentColor,
        interests: List<String>.from(_interests),
      ),
    );
    if (!mounted) return;
    if (ref.read(profileControllerProvider).error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
      context.pop();
    }
  }

  // ── Completion banner ─────────────────────────────────────────────────────

  Widget _completionBanner(ProfileState s) {
    final pct = ProfileCompletion.completeness(s.copyWith(
      username: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : s.username,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : s.bio,
      aboutMe: _aboutMeController.text.trim().isNotEmpty ? _aboutMeController.text.trim() : s.aboutMe,
      avatarUrl: _avatarUrl ?? s.avatarUrl,
      coverPhotoUrl: _coverPhotoUrl ?? s.coverPhotoUrl,
      interests: _interests.isNotEmpty ? _interests : s.interests,
    ));
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
              Text('Profile completion', style: TextStyle(color: VelvetNoir.primary, fontWeight: FontWeight.w600)),
              Text('$pctInt%', style: TextStyle(color: VelvetNoir.primary, fontWeight: FontWeight.bold)),
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

  Widget _buildBasicsTab(ProfileState s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + Cover row
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover photo
            GestureDetector(
              onTap: _isUploadingCover
                  ? null
                  : () => _pickAndUpload(
                        storagePath: 'users/${FirebaseAuth.instance.currentUser?.uid}/cover',
                        onSuccess: (url) => setState(() => _coverPhotoUrl = url),
                        setLoading: (v) => setState(() => _isUploadingCover = v),
                      ),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F2C),
                  borderRadius: BorderRadius.circular(12),
                  image: (_coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(_coverPhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: _isUploadingCover
                      ? const CircularProgressIndicator()
                      : (_coverPhotoUrl == null || _coverPhotoUrl!.isEmpty)
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: Colors.white38, size: 32),
                                const SizedBox(height: 4),
                                const Text('Add cover photo',
                                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ),
            // Avatar overlapping cover
            Positioned(
              bottom: -28,
              left: 16,
              child: GestureDetector(
                onTap: _isUploadingAvatar
                    ? null
                    : () => _pickAndUpload(
                          storagePath: 'users/${FirebaseAuth.instance.currentUser?.uid}/avatar',
                          onSuccess: (url) => setState(() => _avatarUrl = url),
                          setLoading: (v) => setState(() => _isUploadingAvatar = v),
                        ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF23253A),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: _avatarUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) =>
                                        const Icon(Icons.person, size: 32),
                                  ),
                                )
                              : const Icon(Icons.person, size: 32, color: Colors.white54),
                    ),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: VelvetNoir.primary,
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _field(_nameController, 'Display name', Icons.person_outline, next: true),
        const SizedBox(height: 14),
        _field(_emailController, 'Email', Icons.email_outlined, next: true),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'New password (leave blank to keep)',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Private account'),
          subtitle: Text(s.privacy.isPrivate
              ? 'Only followers can view your profile'
              : 'Anyone can view your profile'),
          value: s.privacy.isPrivate,
          onChanged: (val) => ref.read(profileControllerProvider.notifier)
              .updateDraft(s.copyWith(privacy: s.privacy.copyWith(isPrivate: val))),
        ),
      ],
    );
  }

  // ── Tab 1: About ──────────────────────────────────────────────────────────

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Short bio', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 160,
          decoration: const InputDecoration(
            hintText: 'One sentence that describes you…',
            prefixIcon: Icon(Icons.short_text),
          ),
        ),
        const SizedBox(height: 14),
        const Text('About me', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _aboutMeController,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Tell people more about yourself…',
            prefixIcon: Icon(Icons.article_outlined),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Interests ──────────────────────────────────────────────────────

  Widget _buildInterestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          const Text('Your interests', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map((i) => Chip(
                      label: Text(i),
                      onDeleted: () => setState(() => _interests.remove(i)),
                      deleteIconColor: VelvetNoir.primary,
                      backgroundColor: const Color(0xFF1C1F2C),
                      side: BorderSide(color: VelvetNoir.primary.withAlpha(80)),
                      labelStyle: const TextStyle(color: Colors.white),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        const Text('Suggestions', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kInterestSuggestions
              .where((s) => !_interests.contains(s))
              .map((s) => ActionChip(
                    label: Text(s),
                    onPressed: () => _addInterest(s),
                    backgroundColor: const Color(0xFF16181F),
                    side: const BorderSide(color: Color(0xFF2E2F3A)),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ))
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

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool next = false}) {
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

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(
        backgroundColor: VelvetNoir.surface,
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: state.isLoading ? null : _saveProfile,
            child: state.isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: TextStyle(color: VelvetNoir.primary, fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VelvetNoir.primary,
          labelColor: VelvetNoir.primary,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basics'),
            Tab(text: 'About'),
            Tab(text: 'Personalization'),
            Tab(text: 'Interests'),
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
              child: Text(state.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicsTab(state),
                _buildAboutTab(),
                _buildPersonalizationTab(),
                _buildInterestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _field(_musicTitleController, 'Song Title', Icons.music_note_outlined, next: true),
        const SizedBox(height: 14),
        _field(_musicUrlController, 'Direct MP3 URL', Icons.link, next: true),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Enter a direct https link to an MP3 file.', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        const SizedBox(height: 24),
        const Text('Accent Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
      ],
    );
  }

  Widget _colorOption(String? hex, String label) {
    final isSelected = _profileAccentColor == hex;
    final color = hex != null ? Color(int.parse(hex.replaceFirst('#', '0xFF'))) : VelvetNoir.primary;
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
              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)] : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white54)),
        ],
      ),
    );
  }
}
