import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/room_service.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../theme/after_dark_theme.dart';

enum _Privacy { public, friends, private }

class AfterDarkCreateLoungeScreen extends ConsumerStatefulWidget {
  const AfterDarkCreateLoungeScreen({super.key});

  @override
  ConsumerState<AfterDarkCreateLoungeScreen> createState() =>
      _AfterDarkCreateLoungeScreenState();
}

class _AfterDarkCreateLoungeScreenState
    extends ConsumerState<AfterDarkCreateLoungeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  _Privacy _privacy = _Privacy.public;
  String? _category;
  String? _thumbnailUrl;
  bool _videoEnabled = false;
  bool _creating = false;
  bool _uploadingThumbnail = false;

  static const List<({String label, String emoji})> _categories = [
    (label: 'Romance', emoji: '💋'),
    (label: 'Roleplay', emoji: '🎭'),
    (label: 'Chat', emoji: '💬'),
    (label: 'Couples', emoji: '💑'),
    (label: 'Dating', emoji: '❤️'),
    (label: 'Party', emoji: '🥂'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_refreshPreview);
    _descCtrl.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_uploadingThumbnail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the lounge logo to finish uploading.'),
        ),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      context.go('/auth');
      return;
    }
    setState(() => _creating = true);
    try {
      final svc = ref.read(roomServiceProvider);
      final tags = <String>[
        if (_category != null) _category!.toLowerCase(),
        if (_videoEnabled) 'video',
        switch (_privacy) {
          _Privacy.public => 'open',
          _Privacy.friends => 'friends-only',
          _Privacy.private => 'private',
        },
      ];
      final roomId = await svc.createRoom(
        hostId: uid,
        name: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category?.toLowerCase(),
        isLive: true,
        isAdult: true,
        thumbnailUrl: _thumbnailUrl,
        tags: tags,
      );
      if (_privacy == _Privacy.private) {
        await ref
            .read(firestoreProvider)
            .collection('rooms')
            .doc(roomId)
            .update({
              'isLocked': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
      if (mounted) context.go('/room/$roomId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lounge: $e'),
            backgroundColor: EmberDark.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      context.go('/auth');
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingThumbnail = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref(
        'rooms/$uid/${DateTime.now().millisecondsSinceEpoch}_after_dark_logo.$ext',
      );
      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await snap.ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _thumbnailUrl = url);
    } catch (e, st) {
      developer.log(
        'After Dark lounge logo upload failed',
        name: 'AfterDarkCreateLoungeScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingThumbnail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      safeArea: false,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    EmberDark.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    EmberDark.secondary.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      context.pageHorizontalPadding,
                      0,
                      context.pageHorizontalPadding,
                      120,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildHeroBadge(),
                          const SizedBox(height: 28),
                          _sectionLabel('Lounge Title'),
                          const SizedBox(height: 10),
                          _buildTitleInput(),
                          const SizedBox(height: 24),
                          _sectionLabel('Description (optional)'),
                          const SizedBox(height: 10),
                          _buildDescInput(),
                          const SizedBox(height: 24),
                          _sectionLabel('Preview'),
                          const SizedBox(height: 10),
                          _buildPreviewCard(),
                          const SizedBox(height: 24),
                          _sectionLabel('Lounge Logo (optional)'),
                          const SizedBox(height: 10),
                          _buildLogoPicker(),
                          const SizedBox(height: 24),
                          _sectionLabel('Category'),
                          const SizedBox(height: 10),
                          _buildCategories(),
                          const SizedBox(height: 24),
                          _sectionLabel('Privacy'),
                          const SizedBox(height: 10),
                          _buildPrivacyOptions(),
                          const SizedBox(height: 24),
                          _buildVideoToggle(),
                          const SizedBox(height: 24),
                          _buildAdultBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildStartButton()),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding - 8,
        12,
        context.pageHorizontalPadding,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: EmberDark.onSurfaceVariant,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              'Open a Lounge',
              style: TextStyle(
                color: EmberDark.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EmberDark.primaryDim.withValues(alpha: 0.25),
            EmberDark.surfaceHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: EmberDark.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set the tone before you go live',
                  style: GoogleFonts.playfairDisplay(
                    color: EmberDark.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This room is reserved for 18+ audiences and will appear only inside After Dark.',
                  style: GoogleFonts.raleway(
                    color: EmberDark.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return TextFormField(
      controller: _titleCtrl,
      style: GoogleFonts.raleway(color: EmberDark.onSurface),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Enter a lounge title' : null,
      decoration: _inputDeco(
        hint: 'e.g. Velvet Confessions…',
        icon: Icons.mic_rounded,
      ),
    );
  }

  Widget _buildDescInput() {
    return TextFormField(
      controller: _descCtrl,
      maxLines: 3,
      style: GoogleFonts.raleway(color: EmberDark.onSurface),
      decoration: _inputDeco(
        hint: 'Describe the mood, energy, and who this lounge is for…',
        icon: Icons.notes_rounded,
        isRound: false,
        radius: 14,
      ),
    );
  }

  Widget _buildPreviewCard() {
    final privacyLabel = switch (_privacy) {
      _Privacy.public => 'OPEN',
      _Privacy.friends => 'FRIENDS',
      _Privacy.private => 'PRIVATE',
    };
    final categoryLabel = _category ?? 'Late Night';
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Your velvet lounge'
        : _titleCtrl.text.trim();
    final description = _descCtrl.text.trim().isEmpty
        ? 'Soft lighting, grown energy, and a room built for chemistry.'
        : _descCtrl.text.trim();

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF411322), Color(0xFF17070D), EmberDark.surfaceHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -10,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EmberDark.secondary.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _previewPill('LIVE'),
                    const SizedBox(width: 8),
                    _previewPill(privacyLabel),
                    const Spacer(),
                    if (_videoEnabled) _previewPill('VIDEO'),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: EmberDark.onSurface,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.raleway(
                    color: EmberDark.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  categoryLabel.toUpperCase(),
                  style: GoogleFonts.raleway(
                    color: EmberDark.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: EmberDark.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: EmberDark.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _uploadingThumbnail
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EmberDark.primary,
                    ),
                  ),
                )
              : (_thumbnailUrl?.isNotEmpty ?? false)
              ? Image.network(
                  _thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.image_outlined,
                    color: EmberDark.onSurfaceVariant,
                    size: 28,
                  ),
                )
              : const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: EmberDark.onSurfaceVariant,
                  size: 28,
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload a photo or mark that sells the mood at a glance.',
                style: GoogleFonts.raleway(
                  color: EmberDark.onSurface,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploadingThumbnail ? null : _pickAndUploadLogo,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      _thumbnailUrl == null ? 'Upload Logo' : 'Change Logo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmberDark.surfaceHigh,
                      foregroundColor: EmberDark.onSurface,
                      side: BorderSide(
                        color: EmberDark.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (_thumbnailUrl != null)
                    TextButton(
                      onPressed: _uploadingThumbnail
                          ? null
                          : () => setState(() => _thumbnailUrl = null),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final selected = _category == c.label;
        return GestureDetector(
          onTap: () => setState(() => _category = selected ? null : c.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected ? EmberDark.primaryGradient : null,
              color: selected ? null : EmberDark.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? EmberDark.primary
                    : EmberDark.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: EmberDark.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${c.emoji} ${c.label}',
              style: GoogleFonts.raleway(
                color: selected ? Colors.white : EmberDark.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrivacyOptions() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: RadioGroup<_Privacy>(
        groupValue: _privacy,
        onChanged: (v) => setState(() => _privacy = v!),
        child: Column(
          children: _Privacy.values.map((p) {
            final (label, subtitle, icon) = switch (p) {
              _Privacy.public => (
                'Public',
                'Any 18+ user can join',
                Icons.public_rounded,
              ),
              _Privacy.friends => (
                'Friends Only',
                'Only your friends can join',
                Icons.group_rounded,
              ),
              _Privacy.private => (
                'Private',
                'Invite-only access',
                Icons.lock_outline_rounded,
              ),
            };
            return RadioListTile<_Privacy>(
              value: p,
              title: Text(
                label,
                style: GoogleFonts.raleway(
                  color: EmberDark.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: GoogleFonts.raleway(
                  color: EmberDark.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              secondary: Icon(icon, color: EmberDark.onSurfaceVariant, size: 20),
              activeColor: EmberDark.primary,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVideoToggle() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: SwitchListTile(
        value: _videoEnabled,
        onChanged: (v) => setState(() => _videoEnabled = v),
        title: Text(
          'Video Lounge',
          style: GoogleFonts.raleway(
            color: EmberDark.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Enable camera-first chemistry for guests who want to be seen',
          style: GoogleFonts.raleway(
            color: EmberDark.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        secondary: const Icon(
          Icons.videocam_outlined,
          color: EmberDark.onSurfaceVariant,
        ),
        activeThumbColor: EmberDark.primary,
      ),
    );
  }

  Widget _buildAdultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: EmberDark.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmberDark.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: EmberDark.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Restricted to After Dark 18+ placement',
            style: GoogleFonts.raleway(
              color: EmberDark.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        12,
        context.pageHorizontalPadding,
        28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EmberDark.surface.withValues(alpha: 0), EmberDark.surface],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: _creating
            ? const Center(
                child: CircularProgressIndicator(color: EmberDark.primary),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: EmberDark.primaryGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: EmberDark.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _create,
                  icon: const Icon(
                    Icons.local_fire_department_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    _privacy == _Privacy.private
                        ? 'Open Private Lounge'
                        : 'Open Lounge',
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.raleway(
      color: EmberDark.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 0.4,
    ),
  );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    bool isRound = true,
    double radius = 999,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.raleway(color: EmberDark.onSurfaceVariant),
      filled: true,
      fillColor: EmberDark.surfaceHigh,
      prefixIcon: Icon(icon, color: EmberDark.onSurfaceVariant, size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: EmberDark.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: EmberDark.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: EmberDark.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: EmberDark.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  Widget _previewPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EmberDark.secondary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          color: EmberDark.onSurface,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
