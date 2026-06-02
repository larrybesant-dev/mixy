import 'dart:ui';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/layout/app_layout.dart';
import '../../../services/room_service.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../widgets/brand_ui_kit.dart';

// ── colour aliases ────────────────────────────────────────────────────────────
const _surface = Color(0xFF0D0A0C);
const _surfaceHigh = Color(0xFF241820);
const _surfaceHighest = Color(0xFF2A1C23);
const _surfaceLow = Color(0xFF10131A);
const _primary = Color(0xFFD4A853);
const _primaryDim = Color(0xFF8C6020);
const _secondary = Color(0xFFC45E7A);
const _onSurface = Color(0xFFF2EBE0);
const _onVariant = Color(0xFFB09080);
const _ghost = Color(0x1A73757D);

enum _RoomMode { audio, video }

enum _Privacy { public, friends, private }

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  _RoomMode _mode = _RoomMode.audio;
  _Privacy _privacy = _Privacy.public;
  String? _selectedCategory;
  final Set<String> _selectedTags = <String>{};
  String? _thumbnailUrl;
  bool _isCreating = false;
  bool _isUploadingThumbnail = false;
  bool _scheduleMode = false;
  DateTime? _scheduledAt;

  static const List<String> _categories = [
    'Music',
    'Gaming',
    'Dating',
    'Tech Talk',
    'Wellness',
    'Art & Design',
    'Education',
    'Chill',
  ];

  static const List<String> _vibeTags = [
    'Chill',
    'Late Night',
    'Flirty',
    'Deep Talk',
    'Music',
    'Games',
    'Wellness',
    'Networking',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRoom() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_isUploadingThumbnail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the room logo to finish uploading.'),
        ),
      );
      return;
    }
    if (_scheduleMode && _scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a date & time to schedule the room.'),
          backgroundColor: Color(0xFFFF6E84),
        ),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) context.go('/auth');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final roomService = ref.read(roomServiceProvider);
      final normalizedTags = _selectedTags
          .where((tag) => tag != _selectedCategory)
          .map((tag) => tag.toLowerCase())
          .toList(growable: false);
      final user = ref.read(userProvider);
      final hostUsername = user?.username;
      final hostAvatarUrl = user?.avatarUrl;

      if (_scheduleMode) {
        await roomService.createRoom(
          hostId: uid,
          name: _titleController.text.trim(),
          hostUsername: hostUsername,
          hostAvatarUrl: hostAvatarUrl,
          category: _selectedCategory?.toLowerCase(),
          tags: normalizedTags,
          thumbnailUrl: _thumbnailUrl,
          isLive: false,
          scheduledAt: _scheduledAt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Room scheduled! It will appear in Upcoming Rooms.',
              ),
              backgroundColor: Color(0xFF8C6020),
            ),
          );
          context.pop();
        }
      } else {
        final roomId = await roomService.createRoom(
          hostId: uid,
          name: _titleController.text.trim(),
          hostUsername: hostUsername,
          hostAvatarUrl: hostAvatarUrl,
          category: _selectedCategory?.toLowerCase(),
          tags: normalizedTags,
          thumbnailUrl: _thumbnailUrl,
          isLive: true,
        );
        if (mounted) context.go('/rooms/room/$roomId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start room: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF6E84),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _pickAndUploadRoomLogo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) context.go('/auth');
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

    setState(() => _isUploadingThumbnail = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref(
        'rooms/$uid/${DateTime.now().millisecondsSinceEpoch}_logo.$ext',
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
        'Room logo upload failed',
        name: 'CreateRoomScreen',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingThumbnail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      backgroundColor: _surface,
      safeArea: false,
      body: Stack(
        children: [
          // Ambient blob
          Positioned(
            top: -80,
            right: -80,
            child: _ambientBlob(_primary.withAlpha(20), 280),
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
                          const SizedBox(height: 8),
                          _buildTitle(),
                          const SizedBox(height: 32),
                          _sectionLabel('Room Title'),
                          const SizedBox(height: 10),
                          _buildTitleInput(),
                          const SizedBox(height: 28),
                          _sectionLabel('Room Logo (optional)'),
                          const SizedBox(height: 10),
                          _buildLogoPicker(),
                          const SizedBox(height: 28),
                          _sectionLabel('Select Mode'),
                          const SizedBox(height: 10),
                          _buildModeToggle(),
                          const SizedBox(height: 28),
                          _sectionLabel('Privacy Settings'),
                          const SizedBox(height: 10),
                          _buildPrivacyOptions(),
                          const SizedBox(height: 28),
                          _sectionLabel('Category'),
                          const SizedBox(height: 10),
                          _buildCategoryChips(),
                          const SizedBox(height: 20),
                          _sectionLabel('Extra Vibes'),
                          const SizedBox(height: 6),
                          Text(
                            'Pick a few extra vibes so people know the mood.',
                            style: GoogleFonts.raleway(
                              fontSize: 12,
                              color: _onVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildVibeTags(),
                          const SizedBox(height: 28),
                          _sectionLabel('When to Start'),
                          const SizedBox(height: 10),
                          _buildScheduleToggle(),
                          const SizedBox(height: 28),
                          _buildPreviewCard(),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating Start button
          Positioned(bottom: 0, left: 0, right: 0, child: _buildStartButton()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.pageHorizontalPadding,
        vertical: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(color: _ghost),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: _onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const MixvyAppBarLogo(fontSize: 20),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start a Room',
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Broadcast your pulse to the world or keep it intimate.',
          style: GoogleFonts.raleway(fontSize: 14, color: _onVariant),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.raleway(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _onVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ghost),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: _titleController,
        style: GoogleFonts.raleway(fontSize: 16, color: _onSurface),
        decoration: InputDecoration(
          hintText: 'e.g. Late Night Music Session',
          hintStyle: GoogleFonts.raleway(fontSize: 16, color: _onVariant),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Please enter a room title';
          if (v.trim().length < 3) return 'Title must be at least 3 characters';
          return null;
        },
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      children: [
        Expanded(
          child: _modeTile(
            _RoomMode.audio,
            Icons.mic_rounded,
            'Audio Room',
            'Voice broadcast',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modeTile(
            _RoomMode.video,
            Icons.videocam_rounded,
            'Video Room',
            'Camera broadcast',
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ghost),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isUploadingThumbnail
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (_thumbnailUrl?.isNotEmpty ?? false)
                  ? Image.network(
                      _thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (___, __, _) => const Icon(
                        Icons.image_outlined,
                        color: _onVariant,
                        size: 28,
                      ),
                    )
                  : const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _onVariant,
                      size: 28,
                    ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload a group photo or logo for this room.',
                style: GoogleFonts.raleway(fontSize: 13, color: _onSurface),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _isUploadingThumbnail ? null : _pickAndUploadRoomLogo,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      _thumbnailUrl == null ? 'Upload Logo' : 'Change Logo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _surfaceHighest,
                      foregroundColor: _onSurface,
                      side: const BorderSide(color: _ghost),
                    ),
                  ),
                  if (_thumbnailUrl != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isUploadingThumbnail
                          ? null
                          : () => setState(() => _thumbnailUrl = null),
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeTile(_RoomMode mode, IconData icon, String label, String sub) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [_primary, _primaryDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : _surfaceHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : _ghost),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? _surface : _primary, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.raleway(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? _surface : _onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.raleway(
                fontSize: 12,
                color: selected ? _surface.withAlpha(180) : _onVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOptions() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ghost),
      ),
      child: Column(
        children: [
          _privacyTile(
            _Privacy.public,
            Icons.public_rounded,
            'Public',
            'Anyone can join',
          ),
          Divider(height: 1, color: _ghost),
          _privacyTile(
            _Privacy.friends,
            Icons.group_rounded,
            'Friends Only',
            'Only your friends can join',
          ),
          Divider(height: 1, color: _ghost),
          _privacyTile(
            _Privacy.private,
            Icons.lock_rounded,
            'Private',
            'Invite only',
          ),
        ],
      ),
    );
  }

  Widget _privacyTile(
    _Privacy privacy,
    IconData icon,
    String label,
    String sub,
  ) {
    final selected = _privacy == privacy;
    return GestureDetector(
      onTap: () => setState(() => _privacy = privacy),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primary : _onVariant, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.raleway(fontSize: 12, color: _onVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_primary, _primaryDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: _surface,
                ),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _ghost),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategory = selected ? null : cat;
            if (!selected) {
              _selectedTags.add(cat);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [_primary, _primaryDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : _surfaceHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? Colors.transparent : _ghost),
            ),
            child: Text(
              cat,
              style: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _surface : _onVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVibeTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _vibeTags.map((tag) {
        final selected = _selectedTags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedTags.add(tag);
              } else {
                _selectedTags.remove(tag);
              }
            });
          },
          selectedColor: _primary.withAlpha(220),
          backgroundColor: _surfaceHighest,
          checkmarkColor: _surface,
          labelStyle: TextStyle(
            color: selected ? _surface : _onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide(color: selected ? Colors.transparent : _ghost),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildScheduleToggle() {
    // Format the chosen date nicely
    String scheduledLabel = 'Choose date & time';
    if (_scheduledAt != null) {
      final dt = _scheduledAt!;
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      scheduledLabel =
          '${monthNames[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Now / Schedule toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _scheduleMode = false;
                  _scheduledAt = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: !_scheduleMode
                        ? const LinearGradient(
                            colors: [_primary, _primaryDim],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: !_scheduleMode ? null : _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_scheduleMode ? Colors.transparent : _ghost,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: !_scheduleMode ? _surface : _onVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Start Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: !_scheduleMode ? _surface : _onVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _scheduleMode = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: _scheduleMode
                        ? const LinearGradient(
                            colors: [_primary, _primaryDim],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _scheduleMode ? null : _surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _scheduleMode ? Colors.transparent : _ghost,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: _scheduleMode ? _surface : _onVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _scheduleMode ? _surface : _onVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // DateTime picker (shown only in schedule mode)
        if (_scheduleMode) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 30)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _primary,
                      surface: _surfaceHigh,
                    ),
                    dialogTheme: const DialogThemeData(
                      backgroundColor: _surfaceHigh,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked == null || !mounted) return;

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  _scheduledAt ?? now.add(const Duration(hours: 1)),
                ),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _primary,
                      surface: _surfaceHigh,
                    ),
                    dialogTheme: const DialogThemeData(
                      backgroundColor: _surfaceHigh,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (time == null || !mounted) return;

              setState(() {
                _scheduledAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  time.hour,
                  time.minute,
                );
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _surfaceHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _scheduledAt != null ? _primary : _ghost,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 20,
                    color: _scheduledAt != null ? _primary : _onVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scheduledLabel,
                      style: TextStyle(
                        color: _scheduledAt != null ? _onSurface : _onVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _onVariant, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1216), Color(0xFF0D0A0C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ghost),
      ),
      child: Stack(
        children: [
          // Overlay gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.transparent, Color(0xCC0D0A0C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _thumbnailUrl == null
                        ? const LinearGradient(
                            colors: [_primary, _primaryDim],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _thumbnailUrl == null ? null : _surfaceHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (_thumbnailUrl?.isNotEmpty ?? false)
                      ? Image.network(
                          _thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (___, __, _) => Icon(
                            _mode == _RoomMode.video
                                ? Icons.videocam_rounded
                                : Icons.mic_rounded,
                            color: _surface,
                            size: 24,
                          ),
                        )
                      : Icon(
                          _mode == _RoomMode.video
                              ? Icons.videocam_rounded
                              : Icons.mic_rounded,
                          color: _surface,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titleController.text.isEmpty
                            ? 'Previewing your room'
                            : _titleController.text,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                      Text(
                        'YOUR PULSE IS READY',
                        style: GoogleFonts.raleway(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _secondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        24,
      ),
      decoration: BoxDecoration(color: _surface.withAlpha(230)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: _isCreating
                        ? null
                        : const LinearGradient(
                            colors: [_primary, _primaryDim],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _isCreating ? _surfaceHighest : null,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _isCreating
                        ? null
                        : [
                            BoxShadow(
                              color: _primaryDim.withAlpha(90),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isCreating ? null : _startRoom,
                    borderRadius: BorderRadius.circular(999),
                    child: Center(
                      child: _isCreating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _surface,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _scheduleMode
                                      ? 'SCHEDULE ROOM'
                                      : 'START ROOM NOW',
                                  style: GoogleFonts.raleway(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _surface,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _scheduleMode
                                      ? Icons.calendar_today_rounded
                                      : Icons.play_arrow_rounded,
                                  color: _surface,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'By starting a room you agree to our Community Guidelines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(fontSize: 11, color: _onVariant),
          ),
        ],
      ),
    );
  }

  Widget _ambientBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: const SizedBox.expand(),
      ),
    );
  }
}
