import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../app/app_routes.dart';
import '../../../core/design_system/app_layout.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/providers/all_providers.dart';
import '../../../shared/widgets/club_background.dart';
import '../../../shared/models/user_profile.dart';
import '../widgets/profile_music_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vibe chips (ordered as specified in UI spec)
// ─────────────────────────────────────────────────────────────────────────────
const _kVibeChips = <(String, Color)>[
  ('Chill', Color(0xFF4A90FF)),
  ('Hype', Color(0xFFFF4D8B)),
  ('Deep Talk', Color(0xFF8B5CF6)),
  ('Party', Color(0xFFFFAB00)),
  ('Late Night', Color(0xFF6366F1)),
  ('Creative', Color(0xFFFFD700)),
  ('Funny', Color(0xFF00E5CC)),
  ('Flirty', Color(0xFFFF69B4)),
];

const _kGenderOptions = [
  'Man', 'Woman', 'Non-binary', 'Trans man', 'Trans woman', 'Prefer not to say',
];

const _kPronounOptions = [
  'he/him', 'she/her', 'they/them', 'he/they', 'she/they', 'any',
];

const _kInterests = [
  'Music', 'Sports', 'Travel', 'Food', 'Movies',
  'Books', 'Gaming', 'Art', 'Fitness', 'Dancing',
  'Cooking', 'Technology', 'Nature', 'Pets', 'Fashion',
  'Photography', 'Nightlife', 'Volunteering',
];

// ─────────────────────────────────────────────────────────────────────────────

class CreateProfilePage extends ConsumerStatefulWidget {
  const CreateProfilePage({super.key});

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  // ── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ──────────────────────────────────────
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _zipController = TextEditingController();

  // ── ZIP lookup ────────────────────────────────────────────
  String? _zipResolvedCity;
  bool _zipLooking = false;
  String? _zipError;

  // ── Avatar ────────────────────────────────────────────────
  final _imagePicker = ImagePicker();
  String? _profileImageUrl;
  bool _isUploadingAvatar = false;

  // ── Gallery photos (up to 6) ─────────────────────────────
  final List<String> _galleryPhotos = [];
  bool _isUploadingGallery = false;

  // ── Vibe / music ─────────────────────────────────────────
  String? _selectedVibeTag;
  final List<String> _selectedMusicGenres = [];
  String? _selectedCountryCode;

  // ── Music track ───────────────────────────────────────────
  String? _musicTitle;
  String? _musicArtist;
  String? _musicPreviewUrl;
  TrackSource? _musicSource;

  // ── Lifestyle ─────────────────────────────────────────────
  String? _selectedGender;
  String? _selectedPronouns;
  DateTime? _birthday;
  final List<String> _selectedInterests = [];

  // ── Submit ────────────────────────────────────────────────
  bool _isLoading = false;

  // ─────────────────────────────────────────────────────────
  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  // ── ZIP code lookup ──────────────────────────────────────
  Future<void> _lookupZip(String zip) async {
    if (zip.length != 5) return;
    setState(() {
      _zipLooking = true;
      _zipError = null;
      _zipResolvedCity = null;
    });
    try {
      final res = await http.get(Uri.parse('https://api.zippopotam.us/us/$zip'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>;
        if (places.isNotEmpty) {
          final city = places[0]['place name'] as String;
          final state = places[0]['state abbreviation'] as String;
          final resolved = '$city, $state';
          setState(() {
            _zipResolvedCity = resolved;
            _zipError = null;
          });
          _locationController.text = resolved;
        }
      } else {
        setState(() => _zipError = 'ZIP code not found');
      }
    } catch (_) {
      setState(() => _zipError = 'Could not look up ZIP code');
    } finally {
      setState(() => _zipLooking = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        _showSnack('Not authenticated — please sign in again.');
        return;
      }

      setState(() => _isUploadingAvatar = true);
      try {
        final controller = ref.read(storageControllerProvider.notifier);
        final url = await controller.uploadImage(picked, uid);
        if (mounted) {
          setState(() {
            _isUploadingAvatar = false;
            if (url != null) _profileImageUrl = url;
          });
          if (url == null) {
            _showSnack('Upload returned no URL — check Storage rules & CORS.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          final isCors = e.toString().toLowerCase().contains('cors') ||
              e.toString().toLowerCase().contains('access-control') ||
              e.toString().toLowerCase().contains('network');
          _showSnack(isCors
              ? 'Upload blocked: run tools/apply-cors.ps1 to fix web uploads.'
              : 'Photo upload failed: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showSnack('Error picking image: $e');
      }
    }
  }

  // ── Gallery photo upload ─────────────────────────────────
  Future<void> _pickGalleryPhoto() async {
    if (_galleryPhotos.length >= 6 || _isUploadingGallery) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;

      final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return;

      setState(() => _isUploadingGallery = true);
      try {
        final controller = ref.read(storageControllerProvider.notifier);
        final url = await controller.uploadImage(
          picked,
          '${uid}_gallery_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          setState(() {
            if (url != null) _galleryPhotos.add(url);
            _isUploadingGallery = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingGallery = false);
          _showSnack('Gallery upload failed: $e');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error picking image: $e');
    }
  }

  // ── Birthday picker ───────────────────────────────────────
  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 22),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18),
      helpText: 'Select your birthday',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: DesignColors.accent,
            surface: DesignColors.surfaceDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createProfile() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      _showSnack('Please select your gender');
      return;
    }
    if (_selectedInterests.isEmpty) {
      _showSnack('Please select at least one interest');
      return;
    }

    setState(() => _isLoading = true);

    final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Session expired — please sign in again.');
      }
      return;
    }

    final userProfile = UserProfile(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: _displayNameController.text.trim(),
      photoUrl: _profileImageUrl,
      galleryPhotos: _galleryPhotos.isNotEmpty ? List.unmodifiable(_galleryPhotos) : null,
      interests: _selectedInterests,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      bio: _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : null,
      birthday: _birthday,
      gender: _selectedGender,
      pronouns: _selectedPronouns,
      vibeTag: _selectedVibeTag,
      musicGenres: _selectedMusicGenres.isNotEmpty
          ? List.unmodifiable(_selectedMusicGenres)
          : null,
      countryCode: _selectedCountryCode,
      favoriteTrackPreviewUrl: _musicPreviewUrl,
      favoriteTrackTitle: _musicTitle,
      favoriteTrackArtist: _musicArtist,
      favoriteTrackSource: _musicSource,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(profileControllerProvider).updateProfile(userProfile);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error creating profile: $e');
      }
    }
  }

  // ── Helper: stub profile for ProfileMusicEditor ──────────────
  UserProfile get _musicEditorProfile {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    return UserProfile(
      id: uid,
      email: fb_auth.FirebaseAuth.instance.currentUser?.email ?? '',
      displayName: _displayNameController.text.trim(),
      favoriteTrackPreviewUrl: _musicPreviewUrl,
      favoriteTrackTitle: _musicTitle,
      favoriteTrackArtist: _musicArtist,
      favoriteTrackSource: _musicSource,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Set Up Your Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Header ──────────────────────────────────
                  const Text('Set Up Your Profile', style: AppTypography.sectionTitle),
                  const SizedBox(height: AppSpacing.spaceXS),
                  const Text(
                    'Tell the world who you are',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 2. Avatar ─────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAvatar,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DesignColors.surfaceLight,
                              border: Border.all(
                                color: DesignColors.accent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: DesignColors.accent.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                              image: _profileImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_profileImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _isUploadingAvatar
                                ? const CircularProgressIndicator()
                                : _profileImageUrl == null
                                    ? const Icon(
                                        Icons.camera_alt,
                                        size: 40,
                                        color: DesignColors.accent,
                                      )
                                    : null,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spaceMD),
                        TextButton.icon(
                          onPressed: _isUploadingAvatar ? null : _pickAvatar,
                          icon: const Icon(Icons.upload),
                          label: Text(
                            _profileImageUrl == null
                                ? 'Upload Photo'
                                : 'Change Photo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 3. Display Name ───────────────────────────
                  _sectionLabel('Display Name'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  TextFormField(
                    controller: _displayNameController,
                    maxLength: 40,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: const InputDecoration(
                      hintText: 'What should people call you?',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Display name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Must be at least 2 characters';
                      }
                      if (v.trim().length > 40) {
                        return 'Must be 40 characters or fewer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 4. Bio ────────────────────────────────────
                  _sectionLabel('About Me'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      hintText: 'Tell others about yourself...',
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: null,
                    maxLength: 300,
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 5. Vibe Tags ──────────────────────────────
                  _sectionLabel('Your Vibe'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  Wrap(
                    spacing: AppSpacing.spaceSM,
                    runSpacing: AppSpacing.spaceSM,
                    children: _kVibeChips.map(((String, Color) chip) {
                      final label = chip.$1;
                      final color = chip.$2;
                      final selected = _selectedVibeTag == label;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _selectedVibeTag = selected ? null : label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.45),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.75),
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 6. Music ──────────────────────────────────
                  _sectionLabel('Your Music'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  ProfileMusicEditor(
                    profile: _musicEditorProfile,
                    onTrackChanged: (url, title, artist, source) => setState(() {
                      _musicPreviewUrl = url;
                      _musicTitle = title;
                      _musicArtist = artist;
                      _musicSource = source;
                    }),
                    onRemove: () => setState(() {
                      _musicPreviewUrl = null;
                      _musicTitle = null;
                      _musicArtist = null;
                      _musicSource = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 7. Photos ─────────────────────────────────
                  _sectionLabel('Photos'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  _buildPhotoGrid(),
                  const SizedBox(height: AppSpacing.spaceXL),

                  // ── 8. More About You ─────────────────────────
                  _sectionLabel('More About You'),
                  const SizedBox(height: AppSpacing.spaceMD),
                  _buildLifestyleFields(context),
                  const SizedBox(height: AppSpacing.spaceXXL),

                  // ── 9. Save Button ────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isUploadingAvatar)
                          ? null
                          : _createProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: DesignColors.accent,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Section helpers
  // ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: DesignColors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  // ── Photo Grid (up to 6) ─────────────────────────────────────
  Widget _buildPhotoGrid() {
    const maxPhotos = 6;
    final slots = List<Widget>.generate(_galleryPhotos.length, (i) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _galleryPhotos[i],
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _galleryPhotos.removeAt(i)),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    });

    if (_galleryPhotos.length < maxPhotos) {
      slots.add(
        GestureDetector(
          onTap: _isUploadingGallery ? null : _pickGalleryPhoto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: DesignColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: DesignColors.accent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: _isUploadingGallery
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : const Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: DesignColors.accent,
                      size: 32,
                    ),
                  ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: slots,
    );
  }

  // ── Lifestyle Fields ─────────────────────────────────────────
  Widget _buildLifestyleFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Birthday
        _fieldLabel('Birthday'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickBirthday,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: DesignColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DesignColors.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined,
                    color: DesignColors.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  _birthday == null
                      ? 'Select your birthday'
                      : '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}',
                  style: TextStyle(
                    color: _birthday == null
                        ? DesignColors.textGray
                        : DesignColors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXL),

        // Gender
        _fieldLabel('Gender'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kGenderOptions.map((g) {
            final sel = _selectedGender == g;
            return ChoiceChip(
              label: Text(g),
              selected: sel,
              onSelected: (_) => setState(() =>
                  _selectedGender = sel ? null : g),
              selectedColor: DesignColors.accent,
              labelStyle: TextStyle(
                color: sel ? Colors.white : DesignColors.textGray,
                fontWeight:
                    sel ? FontWeight.w700 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.spaceXL),

        // Pronouns
        _fieldLabel('Pronouns'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPronounOptions.map((p) {
            final sel = _selectedPronouns == p;
            return ChoiceChip(
              label: Text(p),
              selected: sel,
              onSelected: (_) => setState(() =>
                  _selectedPronouns = sel ? null : p),
              selectedColor: DesignColors.tertiary,
              labelStyle: TextStyle(
                color: sel ? Colors.white : DesignColors.textGray,
                fontWeight:
                    sel ? FontWeight.w700 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.spaceXL),

        // Location via ZIP
        _fieldLabel('Location (optional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _zipController,
          decoration: InputDecoration(
            hintText: 'ZIP code — e.g. 90210',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _zipLooking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _zipResolvedCity != null
                    ? const Icon(Icons.check_circle,
                        color: Colors.green)
                    : null,
            errorText: _zipError,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (val) {
            if (val.length == 5) _lookupZip(val);
            if (val.length < 5) {
              setState(() {
                _zipResolvedCity = null;
                _zipError = null;
                _locationController.clear();
              });
            }
          },
        ),
        if (_zipResolvedCity != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place,
                  size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(_zipResolvedCity!,
                  style: const TextStyle(
                      color: Colors.green, fontSize: 13)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.spaceXL),

        // Interests
        _fieldLabel('Interests'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kInterests.map((interest) {
            final sel = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: sel,
              onSelected: (v) => setState(() => v
                  ? _selectedInterests.add(interest)
                  : _selectedInterests.remove(interest)),
              selectedColor: DesignColors.secondary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: sel ? Colors.white : DesignColors.textGray,
              ),
            );
          }).toList(),
        ),
        if (_selectedInterests.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_selectedInterests.length} selected',
            style: const TextStyle(
                color: DesignColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: DesignColors.textGray,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
