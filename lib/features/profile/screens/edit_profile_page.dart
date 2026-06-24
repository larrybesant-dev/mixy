import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/shared/widgets/async_value_view_enhanced.dart';
import 'package:mixvy/shared/providers/profile_controller.dart';
import 'package:mixvy/shared/models/user_profile.dart';
import 'package:mixvy/shared/validation.dart';
import 'package:mixvy/core/design_system/design_constants.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  // ─── Form ────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ─── Text controllers ────────────────────────────────────────
  final _displayNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _zipController = TextEditingController();

  // ZIP lookup state
  String? _zipResolvedCity;
  bool _zipLooking = false;
  String? _zipError;

  Future<void> _lookupZip(String zip) async {
    if (zip.length != 5) return;
    setState(() {
      _zipLooking = true;
      _zipError = null;
      _zipResolvedCity = null;
    });
    try {
      final res =
          await http.get(Uri.parse('https://api.zippopotam.us/us/$zip'));
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
        setState(() {
          _zipError = 'ZIP code not found';
        });
      }
    } catch (_) {
      setState(() {
        _zipError = 'Could not look up ZIP code';
      });
    } finally {
      setState(() {
        _zipLooking = false;
      });
    }
  }

  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _twitterController = TextEditingController();

  // Personality prompt answer controllers (3 slots)
  final List<TextEditingController> _promptAnswerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  final ImagePicker picker = ImagePicker();

  // ─── UI state ────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isUploading = false;
  bool _initialized = false;

  // ─── Section 2 – About You ───────────────────────────────────
  DateTime? _birthday;
  String? _gender;
  String? _pronouns;

  // ─── Section 3 – Your Vibe (personality prompts) ─────────────
  final List<String?> _selectedPromptQuestions = [null, null, null];

  // ─── Section 4 – Lifestyle ───────────────────────────────────
  Map<String, bool> _lifestylePrompts = {};

  // ─── Section 5 – What You're Into ───────────────────────────
  List<String> _selectedInterests = [];
  List<String> _selectedMusicTastes = [];
  String? _selectedVibeTag;
  List<String> _selectedMusicGenres = [];

  // ─── Section 6 – What You're Looking For ────────────────────
  List<String> _lookingFor = [];
  String? _relationshipType;
  List<String> _preferredGenders = [];

  // ─── Section 7 – Your World ──────────────────────────────────
  int _minAge = 18;
  int _maxAge = 45;

  // ─── Section 1 – Gallery photos ─────────────────────────────
  List<String> _galleryPhotos = [];

  // ─── Static catalogs ─────────────────────────────────────────
  static const List<String> _promptQuestions = [
    'My love language is...',
    'My ideal Sunday looks like...',
    'A green flag for me is...',
    'I get weirdly passionate about...',
    'Change my mind about...',
    'The way to my heart is...',
    'My biggest deal-breaker is...',
    "On a Friday night you'll find me...",
    "I'm looking for someone who...",
    "The most spontaneous thing I've done...",
    'Two truths and a lie:',
    'I go crazy for...',
  ];

  static const List<String> _availableInterests = [
    'Music',
    'Sports',
    'Gaming',
    'Movies',
    'Travel',
    'Food',
    'Art',
    'Reading',
    'Dancing',
    'Technology',
    'Fitness',
    'Photography',
    'Hiking',
    'Cooking',
    'Fashion',
    'Comedy',
    'Yoga',
    'Cars',
    'Anime',
    'Podcasts',
    'Astrology',
    'Board Games',
  ];

  static const List<String> _availableMusicTastes = [
    'Hip-Hop',
    'R&B',
    'Pop',
    'Afrobeats',
    'Reggae',
    'House',
    'EDM',
    'Jazz',
    'Rock',
    'Latin',
    'Soul',
    'Dancehall',
    'Gospel',
    'Country',
    'Amapiano',
    'Drill',
  ];

  static const List<String> _genderOptions = [
    'Man',
    'Woman',
    'Non-binary',
    'Genderqueer',
    'Agender',
    'Prefer not to say',
  ];

  static const List<String> _pronounsOptions = [
    'he/him',
    'she/her',
    'they/them',
    'he/they',
    'she/they',
    'any',
  ];

  static const List<String> _lookingForOptions = [
    'Friends',
    'Dating',
    'Networking',
    'Activity Partners',
    'Casual',
    'Long-term',
  ];

  static const List<String> _relationshipTypeOptions = [
    'Casual',
    'Serious',
    'Long-term',
    'Open to anything',
  ];

  static const List<String> _preferredGendersOptions = [
    'Men',
    'Women',
    'Non-binary',
    'Everyone',
  ];

  static const Map<String, String> _lifestyleLabels = {
    'smoking': 'Smoking',
    'drinking': 'Drinking',
    'fitness': 'Fitness lover',
    'pets': 'Has pets',
    'kids': 'Has kids',
  };

  @override
  void dispose() {
    _displayNameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _zipController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _snapchatController.dispose();
    _twitterController.dispose();
    for (final c in _promptAnswerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Initialization ──────────────────────────────────────────
  void _initializeFields(UserProfile profile) {
    if (_initialized) return;
    _initialized = true;

    _displayNameController.text = profile.displayName ?? '';
    _nicknameController.text = profile.nickname ?? '';
    _bioController.text = profile.bio ?? '';
    _locationController.text = profile.location ?? '';

    final links = profile.socialLinks ?? {};
    _instagramController.text = links['instagram'] ?? '';
    _tiktokController.text = links['tiktok'] ?? '';
    _snapchatController.text = links['snapchat'] ?? '';
    _twitterController.text = links['twitter'] ?? '';

    _birthday = profile.birthday;
    _gender = profile.gender;
    _pronouns = profile.pronouns;

    _lifestylePrompts = Map<String, bool>.from(profile.lifestylePrompts ?? {});

    _selectedInterests = List<String>.from(profile.interests ?? []);
    _selectedMusicTastes = List<String>.from(profile.musicTastes ?? []);
    _selectedVibeTag = profile.vibeTag;
    _selectedMusicGenres = List<String>.from(profile.musicGenres ?? []);

    _lookingFor = List<String>.from(profile.lookingFor ?? []);
    _relationshipType = profile.relationshipType;
    _preferredGenders = List<String>.from(profile.preferredGenders ?? []);

    _minAge = profile.minAgePreference ?? 18;
    _maxAge = profile.maxAgePreference ?? 45;

    _galleryPhotos = List<String>.from(profile.galleryPhotos ?? []);

    if (profile.personalityPrompts != null) {
      final entries = profile.personalityPrompts!.entries.toList();
      for (int i = 0; i < entries.length && i < 3; i++) {
        _selectedPromptQuestions[i] = entries[i].key;
        _promptAnswerControllers[i].text = entries[i].value;
      }
    }
  }

  // ─── Photo uploads ───────────────────────────────────────────
  Future<void> _pickAndUploadAvatar(
      String userId, UserProfile currentProfile) async {
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _isUploading = true);
    try {
      final controller = ref.read(profileControllerProvider);
      final profileService = ref.read(profileServiceProvider);
      final url = await controller.uploadAvatar(picked, userId);
      if (url == null) throw Exception('Upload returned null URL');
      if (!mounted) return;
      await profileService
          .updateUserProfile(currentProfile.copyWith(photoUrl: url));
      ref.invalidate(currentUserProfileProvider);
      if (mounted) _showSuccess('Avatar updated');
    } catch (e) {
      if (mounted) _showError('Failed to upload avatar: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndUploadCoverPhoto(
      String userId, UserProfile currentProfile) async {
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _isUploading = true);
    try {
      final controller = ref.read(profileControllerProvider);
      final profileService = ref.read(profileServiceProvider);
      final url = await controller.uploadCoverPhoto(picked, userId);
      if (url == null) throw Exception('Upload returned null URL');
      if (!mounted) return;
      await profileService
          .updateUserProfile(currentProfile.copyWith(coverPhotoUrl: url));
      ref.invalidate(currentUserProfileProvider);
      if (mounted) _showSuccess('Cover photo updated');
    } catch (e) {
      if (mounted) _showError('Failed to upload cover photo: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _addGalleryPhoto(UserProfile profile) async {
    if (_galleryPhotos.length >= 6) return;
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() => _isUploading = true);
    try {
      final controller = ref.read(profileControllerProvider);
      final profileService = ref.read(profileServiceProvider);
      final url = await controller.uploadAvatar(
        picked,
        '${profile.id}_gallery_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (url == null) throw Exception('Upload failed');
      if (!mounted) return;
      setState(() => _galleryPhotos.add(url));
      await profileService
          .updateUserProfile(profile.copyWith(galleryPhotos: _galleryPhotos));
      ref.invalidate(currentUserProfileProvider);
      if (mounted) _showSuccess('Photo added');
    } catch (e) {
      if (mounted) _showError('Failed to add photo: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Save ────────────────────────────────────────────────────
  Future<void> _saveProfile(UserProfile currentProfile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final Map<String, String> prompts = {};
      for (int i = 0; i < 3; i++) {
        final q = _selectedPromptQuestions[i];
        final a = _promptAnswerControllers[i].text.trim();
        if (q != null && a.isNotEmpty) prompts[q] = a;
      }

      final Map<String, String> links = {};
      if (_instagramController.text.trim().isNotEmpty) {
        links['instagram'] = _instagramController.text.trim();
      }
      if (_tiktokController.text.trim().isNotEmpty) {
        links['tiktok'] = _tiktokController.text.trim();
      }
      if (_snapchatController.text.trim().isNotEmpty) {
        links['snapchat'] = _snapchatController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        links['twitter'] = _twitterController.text.trim();
      }

      final updatedProfile = UserProfile(
        id: currentProfile.id,
        email: currentProfile.email,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? ValidationHelpers.sanitizeInput(
                _displayNameController.text.trim())
            : currentProfile.displayName,
        nickname: _nicknameController.text.trim().isNotEmpty
            ? ValidationHelpers.sanitizeInput(_nicknameController.text.trim())
            : currentProfile.nickname,
        bio: _bioController.text.trim().isNotEmpty
            ? ValidationHelpers.sanitizeInput(_bioController.text.trim())
            : currentProfile.bio,
        location: _locationController.text.trim().isNotEmpty
            ? ValidationHelpers.sanitizeInput(_locationController.text.trim())
            : currentProfile.location,
        photoUrl: currentProfile.photoUrl,
        coverPhotoUrl: currentProfile.coverPhotoUrl,
        galleryPhotos: _galleryPhotos,
        birthday: _birthday,
        gender: _gender,
        pronouns: _pronouns,
        lookingFor: _lookingFor.isNotEmpty ? _lookingFor : null,
        relationshipType: _relationshipType,
        minAgePreference: _minAge,
        maxAgePreference: _maxAge,
        preferredGenders:
            _preferredGenders.isNotEmpty ? _preferredGenders : null,
        interests: _selectedInterests.isNotEmpty ? _selectedInterests : null,
        musicTastes:
            _selectedMusicTastes.isNotEmpty ? _selectedMusicTastes : null,
        vibeTag: _selectedVibeTag,
        musicGenres:
            _selectedMusicGenres.isNotEmpty ? _selectedMusicGenres : null,
        personalityPrompts: prompts.isNotEmpty ? prompts : null,
        lifestylePrompts:
            _lifestylePrompts.isNotEmpty ? _lifestylePrompts : null,
        socialLinks: links.isNotEmpty ? links : null,
        isPhotoVerified: currentProfile.isPhotoVerified,
        isPhoneVerified: currentProfile.isPhoneVerified,
        isEmailVerified: currentProfile.isEmailVerified,
        isIdVerified: currentProfile.isIdVerified,
        verifiedOnlyMode: currentProfile.verifiedOnlyMode,
        privateMode: currentProfile.privateMode,
        latitude: currentProfile.latitude,
        longitude: currentProfile.longitude,
        followersCount: currentProfile.followersCount,
        followingCount: currentProfile.followingCount,
        presenceStatus: currentProfile.presenceStatus,
        createdAt: currentProfile.createdAt,
        updatedAt: DateTime.now(),
      );

      final controller = ref.read(profileControllerProvider);
      await controller.updateProfile(updatedProfile);
      if (mounted) {
        _showSuccess('Profile saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Snackbars ───────────────────────────────────────────────
  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline,
            color: DesignColors.success, size: 20),
        const SizedBox(width: 10),
        Text(msg, style: const TextStyle(color: DesignColors.white)),
      ]),
      backgroundColor: DesignColors.surfaceLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: DesignColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(msg, style: const TextStyle(color: DesignColors.white))),
      ]),
      backgroundColor: DesignColors.surfaceLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: AsyncValueViewEnhanced<UserProfile?>(
          value: profileAsync,
          maxRetries: 3,
          screenName: 'EditProfilePage',
          providerName: 'currentUserProfileProvider',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('Profile not found',
                    style: TextStyle(color: DesignColors.white)),
              );
            }
            _initializeFields(profile);
            return _buildBody(profile);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: DesignColors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit Profile',
        style: DesignTypography.heading
            .copyWith(shadows: DesignColors.primaryGlow),
      ),
    );
  }

  Widget _buildBody(UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION 1: YOUR LOOK ──────────────────────────
            _buildSection(
              icon: Icons.photo_camera_outlined,
              title: 'Your Look',
              color: DesignColors.accent,
              children: [
                _buildAvatarRow(profile),
                const SizedBox(height: 16),
                _buildCoverPhotoButton(profile),
                const SizedBox(height: 16),
                _buildGalleryGrid(profile),
              ],
            ),

            // ── SECTION 2: ABOUT YOU ──────────────────────────
            _buildSection(
              icon: Icons.person_outline,
              title: 'About You',
              color: DesignColors.secondary,
              children: [
                _buildNeonTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  icon: Icons.badge_outlined,
                  maxLength: 30,
                  validator: (v) => ValidationHelpers.validateLengthOptional(
                    v,
                    ValidationConstants.displayNameMinLength,
                    ValidationConstants.displayNameMaxLength,
                    'Display Name',
                  ),
                ),
                const SizedBox(height: 12),
                _buildNeonTextField(
                  controller: _nicknameController,
                  label: 'Nickname (optional)',
                  icon: Icons.alternate_email,
                  maxLength: 20,
                ),
                const SizedBox(height: 12),
                _buildNeonTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.edit_outlined,
                  maxLines: 3,
                  maxLength: 300,
                  hint: 'Tell the world who you are...',
                ),
                const SizedBox(height: 16),
                _buildBirthdayPicker(),
                const SizedBox(height: 16),
                _buildChipSelector(
                  label: 'Gender',
                  options: _genderOptions,
                  selected: _gender != null ? [_gender!] : [],
                  onTap: (v) =>
                      setState(() => _gender = (_gender == v) ? null : v),
                ),
                const SizedBox(height: 12),
                _buildChipSelector(
                  label: 'Pronouns',
                  options: _pronounsOptions,
                  selected: _pronouns != null ? [_pronouns!] : [],
                  onTap: (v) =>
                      setState(() => _pronouns = (_pronouns == v) ? null : v),
                ),
              ],
            ),

            // ── SECTION 3: YOUR VIBE ──────────────────────────
            _buildSection(
              icon: Icons.auto_awesome_outlined,
              title: 'Your Vibe',
              subtitle: 'Pick up to 3 prompts and answer them',
              color: DesignColors.tertiary,
              children: List.generate(3, (i) => _buildPromptSlot(i)),
            ),

            // ── SECTION 4: LIFESTYLE ──────────────────────────
            _buildSection(
              icon: Icons.favorite_border,
              title: 'Lifestyle',
              color: DesignColors.secondary,
              children: _lifestyleLabels.entries
                  .map((e) => _buildLifestyleToggle(e.key, e.value))
                  .toList(),
            ),

            // ── SECTION 5: WHAT YOU'RE INTO ───────────────────
            _buildSection(
              icon: Icons.local_fire_department_outlined,
              title: "What You're Into",
              color: DesignColors.accent,
              children: [
                _buildChipSelectorMulti(
                  label: 'Interests',
                  options: _availableInterests,
                  selected: _selectedInterests,
                  onToggle: (v) => setState(() {
                    _selectedInterests.contains(v)
                        ? _selectedInterests.remove(v)
                        : _selectedInterests.add(v);
                  }),
                ),
                const SizedBox(height: 16),
                _buildChipSelectorMulti(
                  label: 'Music Tastes',
                  options: _availableMusicTastes,
                  selected: _selectedMusicTastes,
                  onToggle: (v) => setState(() {
                    _selectedMusicTastes.contains(v)
                        ? _selectedMusicTastes.remove(v)
                        : _selectedMusicTastes.add(v);
                  }),
                ),
                const SizedBox(height: 16),
                // ── Energy Vibe (single-select) ──
                _buildChipSelector(
                  label: 'Your Energy Vibe',
                  options: const [
                    'Chill', 'Hype', 'Deep Talk', 'Romantic',
                    'Funny', 'Creative', 'Adventurous', 'Spiritual'
                  ],
                  selected:
                      _selectedVibeTag != null ? [_selectedVibeTag!] : [],
                  onTap: (v) => setState(
                      () => _selectedVibeTag =
                          (_selectedVibeTag == v) ? null : v),
                ),
                const SizedBox(height: 16),
                // ── Music Genres (multi-select) ──
                _buildChipSelectorMulti(
                  label: 'Favourite Genres',
                  options: const [
                    'Hip-Hop', 'R&B', 'Pop', 'Afrobeats', 'Dancehall',
                    'House', 'Techno', 'Reggae', 'Jazz', 'Soul',
                    'Lo-Fi', 'Drill', 'Amapiano', 'Gospel', 'Country'
                  ],
                  selected: _selectedMusicGenres,
                  onToggle: (v) => setState(() {
                    _selectedMusicGenres.contains(v)
                        ? _selectedMusicGenres.remove(v)
                        : _selectedMusicGenres.add(v);
                  }),
                ),
              ],
            ),

            // ── SECTION 6: WHAT YOU'RE LOOKING FOR ───────────
            _buildSection(
              icon: Icons.search_outlined,
              title: "What You're Looking For",
              color: DesignColors.gold,
              children: [
                _buildChipSelectorMulti(
                  label: "I'm looking for",
                  options: _lookingForOptions,
                  selected: _lookingFor,
                  onToggle: (v) => setState(() {
                    _lookingFor.contains(v)
                        ? _lookingFor.remove(v)
                        : _lookingFor.add(v);
                  }),
                ),
                const SizedBox(height: 16),
                _buildChipSelector(
                  label: 'Relationship Type',
                  options: _relationshipTypeOptions,
                  selected:
                      _relationshipType != null ? [_relationshipType!] : [],
                  onTap: (v) => setState(() =>
                      _relationshipType = (_relationshipType == v) ? null : v),
                ),
                const SizedBox(height: 16),
                _buildChipSelectorMulti(
                  label: 'Interested in',
                  options: _preferredGendersOptions,
                  selected: _preferredGenders,
                  onToggle: (v) => setState(() {
                    _preferredGenders.contains(v)
                        ? _preferredGenders.remove(v)
                        : _preferredGenders.add(v);
                  }),
                ),
              ],
            ),

            // ── SECTION 7: YOUR WORLD ─────────────────────────
            _buildSection(
              icon: Icons.public_outlined,
              title: 'Your World',
              color: DesignColors.success,
              children: [
                // ZIP → City/State lookup
                TextFormField(
                  controller: _zipController,
                  decoration: InputDecoration(
                    labelText: 'ZIP Code (Optional)',
                    hintText: '90210',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: _zipLooking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                      const Icon(Icons.place, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        _zipResolvedCity!,
                        style:
                            const TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildAgeRangeSlider(),
              ],
            ),

            // ── SECTION 8: CONNECT ────────────────────────────
            _buildSection(
              icon: Icons.link_outlined,
              title: 'Connect',
              subtitle: 'Show off your socials',
              color: DesignColors.tertiary,
              children: [
                _buildSocialField('instagram', _instagramController,
                    Icons.camera_alt_outlined, 'Instagram handle'),
                const SizedBox(height: 12),
                _buildSocialField('tiktok', _tiktokController,
                    Icons.music_video_outlined, 'TikTok handle'),
                const SizedBox(height: 12),
                _buildSocialField('snapchat', _snapchatController,
                    Icons.circle_outlined, 'Snapchat username'),
                const SizedBox(height: 12),
                _buildSocialField('twitter', _twitterController, Icons.tag,
                    'X / Twitter handle'),
              ],
            ),

            const SizedBox(height: 8),
            _buildSaveButton(profile),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SECTION SHELL
  // ════════════════════════════════════════════════════════════
  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: DesignColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: DesignTypography.subheading
                                .copyWith(color: color)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: DesignTypography.caption
                                  .copyWith(color: DesignColors.textGray)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // NEON TEXT FIELD
  // ════════════════════════════════════════════════════════════
  Widget _buildNeonTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: DesignColors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            TextStyle(color: DesignColors.textGray.withValues(alpha: 0.6)),
        labelStyle: const TextStyle(color: DesignColors.textGray),
        prefixIcon: Icon(icon, color: DesignColors.accent, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: DesignColors.accent.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignColors.error, width: 2),
        ),
        filled: true,
        fillColor: DesignColors.surfaceDefault,
        counterStyle: const TextStyle(color: DesignColors.textGray),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // AVATAR ROW
  // ════════════════════════════════════════════════════════════
  Widget _buildAvatarRow(UserProfile profile) {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DesignColors.accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: DesignColors.accent.withValues(alpha: 0.45),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: DesignColors.surfaceDefault,
                backgroundImage: profile.photoUrl != null
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                child: profile.photoUrl == null
                    ? const Icon(Icons.person,
                        size: 52, color: DesignColors.textGray)
                    : null,
              ),
            ),
            if (_isUploading)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(
                      color: DesignColors.accent, strokeWidth: 2),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isUploading
                    ? null
                    : () => _pickAndUploadAvatar(profile.id, profile),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: DesignColors.accent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: DesignColors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Photo', style: DesignTypography.subheading),
              const SizedBox(height: 4),
              Text(
                'Square photo recommended.\nShows on your profile card & in rooms.',
                style: DesignTypography.caption
                    .copyWith(color: DesignColors.textGray),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isUploading
                    ? null
                    : () => _pickAndUploadAvatar(profile.id, profile),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text(_isUploading ? 'Uploading…' : 'Change Photo'),
                style: TextButton.styleFrom(
                  foregroundColor: DesignColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // COVER PHOTO BUTTON
  // ════════════════════════════════════════════════════════════
  Widget _buildCoverPhotoButton(UserProfile profile) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isUploading
          ? null
          : () => _pickAndUploadCoverPhoto(profile.id, profile),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: DesignColors.accent.withValues(alpha: 0.4), width: 1),
          image: profile.coverPhotoUrl != null
              ? DecorationImage(
                  image: NetworkImage(profile.coverPhotoUrl!),
                  fit: BoxFit.cover)
              : null,
          color: DesignColors.surfaceDefault,
        ),
        child: profile.coverPhotoUrl == null
            ? Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.panorama_outlined,
                        color: DesignColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text('Upload Cover Photo',
                        style: DesignTypography.body
                            .copyWith(color: DesignColors.accent)),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: DesignColors.background.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 16, color: DesignColors.white),
                  ),
                ),
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // GALLERY GRID  (up to 6 photos)
  // ════════════════════════════════════════════════════════════
  Widget _buildGalleryGrid(UserProfile profile) {
    const int maxPhotos = 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gallery Photos (up to $maxPhotos)',
          style: DesignTypography.body.copyWith(color: DesignColors.textGray),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: maxPhotos,
          itemBuilder: (context, i) {
            if (i < _galleryPhotos.length) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_galleryPhotos[i], fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _galleryPhotos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: DesignColors.white),
                      ),
                    ),
                  ),
                ],
              );
            }
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _addGalleryPhoto(profile),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: DesignColors.accent.withValues(alpha: 0.3),
                  ),
                  color: DesignColors.surfaceDefault,
                ),
                child: const Center(
                  child: Icon(Icons.add_photo_alternate_outlined,
                      color: DesignColors.accent, size: 28),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // BIRTHDAY PICKER
  // ════════════════════════════════════════════════════════════
  Widget _buildBirthdayPicker() {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthday ?? DateTime(now.year - 22, now.month, now.day),
          firstDate: DateTime(1950),
          lastDate: DateTime(now.year - 18, now.month, now.day),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: DesignColors.accent,
                onPrimary: DesignColors.white,
                surface: DesignColors.surfaceLight,
                onSurface: DesignColors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _birthday = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesignColors.accent.withValues(alpha: 0.3)),
          color: DesignColors.surfaceDefault,
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined,
                color: DesignColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Birthday',
                      style: TextStyle(
                          color: DesignColors.textGray, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    _birthday != null
                        ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
                        : 'Tap to set your birthday',
                    style: TextStyle(
                      color: _birthday != null
                          ? DesignColors.white
                          : DesignColors.textGray,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            if (_birthday != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DesignColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: DesignColors.accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Age ${_calcAge(_birthday!)}',
                  style: const TextStyle(
                    color: DesignColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // ════════════════════════════════════════════════════════════
  // CHIP SELECTORS
  // ════════════════════════════════════════════════════════════
  Widget _buildChipSelector({
    required String label,
    required List<String> options,
    required List<String> selected,
    required void Function(String) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                DesignTypography.body.copyWith(color: DesignColors.textGray)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return GestureDetector(
              onTap: () => onTap(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DesignColors.accent.withValues(alpha: 0.18)
                      : DesignColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? DesignColors.accent : DesignColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected
                        ? DesignColors.accent
                        : DesignColors.textGray,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChipSelectorMulti({
    required String label,
    required List<String> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) {
    return _buildChipSelector(
      label: label,
      options: options,
      selected: selected,
      onTap: onToggle,
    );
  }

  // ════════════════════════════════════════════════════════════
  // PERSONALITY PROMPT SLOT
  // ════════════════════════════════════════════════════════════
  Widget _buildPromptSlot(int index) {
    final selected = _selectedPromptQuestions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showPromptPicker(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected != null
                      ? DesignColors.tertiary
                      : DesignColors.divider,
                  width: selected != null ? 1.5 : 1,
                ),
                color: selected != null
                    ? DesignColors.tertiary.withValues(alpha: 0.1)
                    : DesignColors.surfaceDefault,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: selected != null
                        ? DesignColors.tertiary
                        : DesignColors.textGray,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected ?? 'Choose a prompt question ${index + 1}',
                      style: TextStyle(
                        color: selected != null
                            ? DesignColors.white
                            : DesignColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down,
                      color: DesignColors.textGray),
                ],
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _promptAnswerControllers[index],
              maxLines: 2,
              maxLength: 150,
              style: const TextStyle(color: DesignColors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Your answer...',
                hintStyle: TextStyle(
                    color: DesignColors.textGray.withValues(alpha: 0.6)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: DesignColors.tertiary.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: DesignColors.tertiary, width: 2),
                ),
                filled: true,
                fillColor: DesignColors.surfaceDefault,
                counterStyle: const TextStyle(color: DesignColors.textGray),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPromptPicker(int index) {
    final usedQuestions =
        _selectedPromptQuestions.where((q) => q != null).toSet();
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child:
                  Text('Choose a Prompt', style: DesignTypography.subheading),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _promptQuestions.length,
                itemBuilder: (ctx, i) {
                  final q = _promptQuestions[i];
                  final alreadyUsed = usedQuestions.contains(q) &&
                      _selectedPromptQuestions[index] != q;
                  return ListTile(
                    enabled: !alreadyUsed,
                    title: Text(
                      q,
                      style: TextStyle(
                        color: alreadyUsed
                            ? DesignColors.textGray
                            : DesignColors.white,
                      ),
                    ),
                    trailing: _selectedPromptQuestions[index] == q
                        ? const Icon(Icons.check_circle,
                            color: DesignColors.tertiary)
                        : null,
                    onTap: alreadyUsed
                        ? null
                        : () {
                            setState(() => _selectedPromptQuestions[index] = q);
                            Navigator.pop(ctx);
                          },
                  );
                },
              ),
            ),
            if (_selectedPromptQuestions[index] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPromptQuestions[index] = null;
                      _promptAnswerControllers[index].clear();
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Remove prompt',
                      style: TextStyle(color: DesignColors.error)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // LIFESTYLE TOGGLE
  // ════════════════════════════════════════════════════════════
  Widget _buildLifestyleToggle(String key, String label) {
    final isOn = _lifestylePrompts[key] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DesignTypography.body)),
          Switch(
            value: isOn,
            onChanged: (v) => setState(() => _lifestylePrompts[key] = v),
            activeThumbColor: DesignColors.secondary,
            activeTrackColor: DesignColors.secondary.withValues(alpha: 0.4),
            inactiveTrackColor: DesignColors.divider,
            inactiveThumbColor: DesignColors.textGray,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // AGE RANGE SLIDER
  // ════════════════════════════════════════════════════════════
  Widget _buildAgeRangeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age Range Preference',
          style: DesignTypography.body.copyWith(color: DesignColors.textGray),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$_minAge',
              style: DesignTypography.subheading
                  .copyWith(color: DesignColors.accent),
            ),
            Expanded(
              child: RangeSlider(
                values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                min: 18,
                max: 80,
                divisions: 62,
                activeColor: DesignColors.accent,
                inactiveColor: DesignColors.divider,
                onChanged: (range) => setState(() {
                  _minAge = range.start.round();
                  _maxAge = range.end.round();
                }),
              ),
            ),
            Text(
              '$_maxAge',
              style: DesignTypography.subheading
                  .copyWith(color: DesignColors.accent),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // SOCIAL LINK FIELD
  // ════════════════════════════════════════════════════════════
  Widget _buildSocialField(
    String platform,
    TextEditingController controller,
    IconData icon,
    String hint,
  ) {
    final Color color = switch (platform) {
      'instagram' => const Color(0xFFE1306C),
      'tiktok' => const Color(0xFF69C9D0),
      'snapchat' => const Color(0xFFFFFC00),
      'twitter' => const Color(0xFF1DA1F2),
      _ => DesignColors.accent,
    };

    return TextFormField(
      controller: controller,
      style: const TextStyle(color: DesignColors.white),
      decoration: InputDecoration(
        labelText: hint,
        hintText: '@handle',
        hintStyle:
            TextStyle(color: DesignColors.textGray.withValues(alpha: 0.6)),
        labelStyle: const TextStyle(color: DesignColors.textGray),
        prefixIcon: Icon(icon, color: color, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: DesignColors.surfaceDefault,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SAVE BUTTON
  // ════════════════════════════════════════════════════════════
  Widget _buildSaveButton(UserProfile profile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [DesignColors.accent, DesignColors.tertiary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: DesignColors.accent.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : () => _saveProfile(profile),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DesignColors.white,
                    ),
                  )
                : const Text(
                    'Save Profile',
                    style: TextStyle(
                      color: DesignColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

