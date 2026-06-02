import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:mixvy/models/adult_profile_model.dart';
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mixvy/models/room_policy_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/flags/feature_flags.dart';
import '../top_eight/top_eight_carousel.dart';
import '../connections/connections_providers.dart';
import '../auth/controllers/auth_controller.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import 'profile_completion.dart';
import 'profile_controller.dart';
import 'widgets/device_settings_panel.dart';
import '../follow/providers/follow_provider.dart';
import '../feed/providers/feed_providers.dart';
import '../feed/widgets/post_card.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPageScaffold(
      backgroundColor: const Color(0xFF0D0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF110D0F),
        foregroundColor: const Color(0xFFF7EDE2),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
          ),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (ref.watch(enableFriendRequestsFeature))
            IconButton(
              tooltip: 'Friend Requests',
              icon: Badge(
                label: Text(
                    ref.watch(dummyPendingRequestsProvider).length.toString()),
                isLabelVisible:
                    ref.watch(dummyPendingRequestsProvider).isNotEmpty,
                child:
                    const Icon(Icons.people_outline, color: Color(0xFFAD9585)),
              ),
              onPressed: () => context.push('/pending-requests'),
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Color(0xFFAD9585)),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/auth');
            },
          ),
        ],
      ),
      body: const ProfileFormView(),
    );
  }
}

class ProfileFormView extends ConsumerStatefulWidget {
  const ProfileFormView({super.key});

  @override
  ConsumerState<ProfileFormView> createState() => _ProfileFormViewState();
}

class _ProfileFormViewState extends ConsumerState<ProfileFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _aboutMeController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _interestsController = TextEditingController();
  final _vibeController = TextEditingController();
  final _firstDateController = TextEditingController();
  final _musicTasteController = TextEditingController();
  final _adultKinksController = TextEditingController();
  final _adultPreferencesController = TextEditingController();
  final _adultBoundariesController = TextEditingController();

  String? _loadedUserId;
  String? _selectedGender;
  String? _selectedRelationshipStatus;
  String _selectedThemeId = 'midnight';
  CamViewPolicy _selectedCamViewPolicy = CamViewPolicy.approvedOnly;
  // Profile personalisation
  String? _profileAccentColor;
  String? _profileBgGradientStart;
  String? _profileBgGradientEnd;
  final _profileMusicUrlController = TextEditingController();
  final _profileMusicTitleController = TextEditingController();
  bool _showAge = false;
  bool _showGender = false;
  bool _showLocation = false;
  bool _showRelationshipStatus = false;
  bool _adultModeEnabled = false;
  bool _adultConsentAccepted = false;
  final Set<AdultRelationshipIntent> _adultLookingFor =
      <AdultRelationshipIntent>{};

  bool _isUploadingPhoto = false;
  bool _isUploadingCover = false;
  bool _isUploadingVideo = false;
  bool _isUploadingGallery = false;

  static const int _maxPhotoBytes = 20 * 1024 * 1024;
  static const int _maxInlineProfilePhotoBytes = 700 * 1024;
  static const int _maxInlineCoverPhotoBytes = 700 * 1024;
  static const int _maxInlineGalleryPhotoBytes = 500 * 1024;
  static const int _maxVideoBytes = 120 * 1024 * 1024;
  static const List<String> _genderOptions = [
    'Woman',
    'Man',
    'Non-binary',
    'Trans woman',
    'Trans man',
    'Prefer not to say',
  ];
  static const List<String> _relationshipOptions = [
    'Single',
    'Talking',
    'Dating',
    'Open',
    'Complicated',
    'Prefer not to say',
  ];
  static const List<String> _interestSuggestions = [
    'nightlife',
    'deep talks',
    'afrobeats',
    'house music',
    'food spots',
    'travel',
    'comedy',
    'fitness',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).loadCurrentProfile(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _aboutMeController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _interestsController.dispose();
    _vibeController.dispose();
    _firstDateController.dispose();
    _musicTasteController.dispose();
    _adultKinksController.dispose();
    _adultPreferencesController.dispose();
    _adultBoundariesController.dispose();
    _profileMusicUrlController.dispose();
    _profileMusicTitleController.dispose();
    super.dispose();
  }

  Future<String?> _resolveUploadUserId() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return null;
      // Avoid reload() on web here; it can race auth state and destabilize upload flow.
      await user.getIdToken();
      return user.uid;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve upload user id',
        name: 'ProfileUpload',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String _mapStorageError(FirebaseException e, {required String kind}) {
    final code = e.code.toLowerCase();
    return switch (code) {
      'unauthenticated' ||
      'permission-denied' ||
      'unauthorized' =>
        'Upload blocked by auth permissions. Please sign out and sign in again.',
      'quota-exceeded' => 'Storage quota exceeded. Please try again later.',
      'cancelled' => 'Upload was cancelled.',
      'retry-limit-exceeded' =>
        'Upload timed out. Check your network and retry.',
      'object-not-found' => 'Storage path missing. Please retry.',
      _ => '$kind upload failed (${e.code}): ${e.message ?? 'unknown error'}',
    };
  }

  String _mapPlatformError(PlatformException e, {required String kind}) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').trim();
    if (code.contains('permission') || code.contains('denied')) {
      return '$kind upload blocked by browser/device permissions.';
    }
    if (code.contains('network') || message.toLowerCase().contains('network')) {
      return '$kind upload failed due to network issues. Please retry.';
    }
    return '$kind upload failed (${e.code}): ${message.isEmpty ? 'unknown error' : message}';
  }

  Future<void> _openIntroVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid intro video URL.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open intro video.')),
      );
    }
  }

  /// Resize cover photo to fit 16:7 aspect ratio and compress for storage.
  /// Target dimensions: 1200x525 (16:7 ratio) for optimal quality vs file size.
  Uint8List _resizeCoverPhoto(Uint8List bytes) {
    try {
      developer.log(
        'Starting cover photo resize. Original size: ${bytes.lengthInBytes} bytes',
        name: 'ProfileUpload',
      );

      final image = img.decodeImage(bytes);
      if (image == null) {
        developer.log(
          'Failed to decode image, returning original',
          name: 'ProfileUpload',
        );
        return bytes;
      }

      developer.log(
        'Image decoded. Dimensions: ${image.width}x${image.height}',
        name: 'ProfileUpload',
      );

      final targetAspect = 16 / 7;
      final currentAspect = image.width / image.height;

      late int cropWidth;
      late int cropHeight;
      late int cropX;
      late int cropY;

      if (currentAspect > targetAspect) {
        // Image is too wide, crop horizontally
        cropHeight = image.height;
        cropWidth = (image.height * targetAspect).toInt();
        cropX = ((image.width - cropWidth) / 2).toInt();
        cropY = 0;
      } else {
        // Image is too tall, crop vertically
        cropWidth = image.width;
        cropHeight = (image.width / targetAspect).toInt();
        cropX = 0;
        cropY = ((image.height - cropHeight) / 2).toInt();
      }

      developer.log(
        'Crop: $cropWidth x $cropHeight at ($cropX, $cropY)',
        name: 'ProfileUpload',
      );

      // Crop to 16:7 ratio
      final cropped = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Resize to target dimensions (1200x525)
      final resized = img.copyResize(
        cropped,
        width: 1200,
        height: 525,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG with quality 85 for smaller file size
      final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      developer.log(
        'Resize complete. New size: ${encoded.lengthInBytes} bytes',
        name: 'ProfileUpload',
      );
      return encoded;
    } catch (e, st) {
      developer.log(
        'Error resizing cover photo: $e',
        name: 'ProfileUpload',
        error: e,
        stackTrace: st,
      );
      return bytes; // Return original if resize fails
    }
  }

  Future<String> _uploadToStorage({
    required Uint8List bytes,
    required String userId,
    required String folder,
    required String extension,
    required String contentType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/$userId/$folder/$timestamp.$extension';
    final storage = FirebaseStorage.instance;
    final ref = storage.ref(path);
    final metadata = SettableMetadata(contentType: contentType);
    final isImage = contentType.toLowerCase().startsWith('image/');

    try {
      if (kIsWeb && isImage) {
        final dataUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
        await ref
            .putString(
              dataUrl,
              format: PutStringFormat.dataUrl,
              metadata: metadata,
            )
            .timeout(const Duration(seconds: 45));
      } else {
        await ref.putData(bytes, metadata).timeout(const Duration(seconds: 45));
      }
    } on FirebaseException catch (e) {
      final code = e.code.toLowerCase();
      final shouldRetry = code == 'unauthenticated' ||
          code == 'permission-denied' ||
          code == 'unauthorized';
      if (!shouldRetry) rethrow;
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (kIsWeb && isImage) {
        final dataUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
        await ref
            .putString(
              dataUrl,
              format: PutStringFormat.dataUrl,
              metadata: metadata,
            )
            .timeout(const Duration(seconds: 45));
      } else {
        await ref.putData(bytes, metadata).timeout(const Duration(seconds: 45));
      }
    } on TimeoutException {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'retry-limit-exceeded',
        message: 'Upload timed out before completion.',
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
      } on TimeoutException catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
      } on FirebaseException catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
        final code = e.code.toLowerCase();
        if (code != 'object-not-found' && code != 'unknown') {
          rethrow;
        }
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;
      }

      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    developer.log(
      'Failed to resolve uploaded file download URL after retries',
      name: 'ProfileUpload',
      error: lastError,
      stackTrace: lastStackTrace,
    );

    if (lastError is FirebaseException) {
      throw lastError;
    }

    throw FirebaseException(
      plugin: 'firebase_storage',
      code: 'unknown',
      message: 'Unable to get photo URL after upload.',
    );
  }

  Future<void> _uploadImage({
    required bool isBusy,
    required ValueSetter<bool> setBusy,
    required String folder,
    required String successmessage,
    required ProfileState Function(ProfileState current, String url) transform,
  }) async {
    if (isBusy) return;
    final userId = await _resolveUploadUserId();
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your session expired. Please sign in again to upload.',
          ),
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes().timeout(
            const Duration(seconds: 20),
          );
      if (bytes.lengthInBytes > _maxPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo is too large. Choose one under 20MB.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => setBusy(true));

      // Resize cover photos to fit 16:7 aspect ratio before upload
      var uploadBytes = bytes;
      if (folder == 'cover_photos') {
        uploadBytes = _resizeCoverPhoto(bytes);
      }

      String url;
      // Web fallback: keep image uploads in-profile as data URLs to avoid storage web host API crashes.
      if (kIsWeb) {
        final inlineLimit = switch (folder) {
          'profile_photos' => _maxInlineProfilePhotoBytes,
          'cover_photos' => _maxInlineCoverPhotoBytes,
          'gallery_photos' => _maxInlineGalleryPhotoBytes,
          _ => _maxInlineProfilePhotoBytes,
        };
        if (uploadBytes.lengthInBytes > inlineLimit) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image is too large for web upload. Please choose a smaller file.',
              ),
            ),
          );
          return;
        }
        url = 'data:image/jpeg;base64,${base64Encode(uploadBytes)}';
      } else {
        url = await _uploadToStorage(
          bytes: uploadBytes,
          userId: userId,
          folder: folder,
          extension: 'jpg',
          contentType: 'image/jpeg',
        );
      }

      final controller = ref.read(profileControllerProvider.notifier);
      final current = ref.read(profileControllerProvider);
      final next = transform(current, url);
      controller.updateDraft(next);
      await controller.updateProfile(next);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successmessage)));
    } on FirebaseException catch (e) {
      developer.log(
        'Firebase upload error',
        name: 'ProfileUpload',
        error: e,
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapStorageError(e, kind: 'Photo'))),
      );
    } on PlatformException catch (e) {
      developer.log(
        'Platform upload error',
        name: 'ProfileUpload',
        error: e,
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapPlatformError(e, kind: 'Photo'))),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo upload timed out. Please try again.'),
        ),
      );
    } catch (e) {
      developer.log(
        'Unexpected upload error',
        name: 'ProfileUpload',
        error: e,
        stackTrace: StackTrace.current,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => setBusy(false));
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final current = ref.read(profileControllerProvider);
    await _uploadImage(
      isBusy: _isUploadingPhoto,
      setBusy: (value) => _isUploadingPhoto = value,
      folder: 'profile_photos',
      successmessage: 'Profile photo uploaded.',
      transform: (_, url) {
        return current.copyWith(avatarUrl: url);
      },
    );
  }

  Future<void> _uploadCoverPhoto() async {
    final current = ref.read(profileControllerProvider);
    await _uploadImage(
      isBusy: _isUploadingCover,
      setBusy: (value) => _isUploadingCover = value,
      folder: 'cover_photos',
      successmessage: 'Cover photo uploaded.',
      transform: (_, url) {
        return current.copyWith(coverPhotoUrl: url);
      },
    );
  }

  Future<void> _uploadGalleryPhoto() async {
    final current = ref.read(profileControllerProvider);
    await _uploadImage(
      isBusy: _isUploadingGallery,
      setBusy: (value) => _isUploadingGallery = value,
      folder: 'gallery_photos',
      successmessage: 'Gallery photo uploaded.',
      transform: (_, url) {
        return current.copyWith(
          galleryUrls: {...current.galleryUrls, url}.toList(growable: false),
        );
      },
    );
  }

  Future<void> _uploadVideo() async {
    if (_isUploadingVideo) return;
    final userId = await _resolveUploadUserId();
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your session expired. Please sign in again to upload.',
          ),
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 45),
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxVideoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video is too large. Choose one under 120MB.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isUploadingVideo = true);
      final videoUrl = await _uploadToStorage(
        bytes: bytes,
        userId: userId,
        folder: 'intro_videos',
        extension: 'mp4',
        contentType: 'video/mp4',
      );
      final controller = ref.read(profileControllerProvider.notifier);
      final current = ref.read(profileControllerProvider);
      await controller.updateProfile(current.copyWith(introVideoUrl: videoUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Intro video uploaded.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mapStorageError(e, kind: 'Video'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Video upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingVideo = false);
      }
    }
  }

  List<String> _parseList(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  void _addInterestSuggestion(String suggestion) {
    final interests = _parseList(
      _interestsController.text,
    ).toList(growable: true);
    if (interests.contains(suggestion) || interests.length >= 8) {
      return;
    }
    interests.add(suggestion);
    _interestsController.text = interests.join(', ');
    _interestsController.selection = TextSelection.collapsed(
      offset: _interestsController.text.length,
    );
    setState(() {});
  }

  void _hydrateForm(ProfileState state) {
    if (state.userId == null || state.userId == _loadedUserId) {
      return;
    }
    _loadedUserId = state.userId;
    _nameController.text = state.username ?? '';
    _bioController.text = state.bio ?? '';
    _aboutMeController.text = state.aboutMe ?? '';
    _ageController.text = state.age?.toString() ?? '';
    _locationController.text = state.location ?? '';
    _interestsController.text = state.interests.join(', ');
    _vibeController.text = state.vibePrompt ?? '';
    _firstDateController.text = state.firstDatePrompt ?? '';
    _musicTasteController.text = state.musicTastePrompt ?? '';
    _adultKinksController.text = state.adultKinks.join(', ');
    _adultPreferencesController.text = state.adultPreferences.join(', ');
    _adultBoundariesController.text = state.adultBoundaries.join(', ');
    _selectedGender = state.gender;
    _selectedRelationshipStatus = state.relationshipStatus;
    _selectedThemeId = state.themeId;
    _selectedCamViewPolicy = state.camViewPolicy;
    // Personalisation
    _profileAccentColor = state.profileAccentColor;
    _profileBgGradientStart = state.profileBgGradientStart;
    _profileBgGradientEnd = state.profileBgGradientEnd;
    if (_profileMusicUrlController.text != (state.profileMusicUrl ?? '')) {
      _profileMusicUrlController.text = state.profileMusicUrl ?? '';
    }
    if (_profileMusicTitleController.text != (state.profileMusicTitle ?? '')) {
      _profileMusicTitleController.text = state.profileMusicTitle ?? '';
    }
    _showAge = state.privacy.showAge;
    _showGender = state.privacy.showGender;
    _showLocation = state.privacy.showLocation;
    _showRelationshipStatus = state.privacy.showRelationshipStatus;
    _adultModeEnabled = state.adultModeEnabled;
    _adultConsentAccepted = state.adultConsentAccepted;
    _adultLookingFor
      ..clear()
      ..addAll(state.adultLookingFor);
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    if (_adultModeEnabled && !_adultConsentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm you are 18+ before enabling adult mode.'),
        ),
      );
      return;
    }

    final parsedAge = int.tryParse(_ageController.text.trim());
    if (_ageController.text.trim().isNotEmpty && parsedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be a valid number.')),
      );
      return;
    }

    final controller = ref.read(profileControllerProvider.notifier);
    final current = ref.read(profileControllerProvider);
    await controller.updateProfile(
      current.copyWith(
        username: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        aboutMe: _aboutMeController.text.trim(),
        age: parsedAge,
        gender: _selectedGender,
        location: _locationController.text.trim(),
        relationshipStatus: _selectedRelationshipStatus,
        interests: _parseList(_interestsController.text),
        vibePrompt: _vibeController.text.trim(),
        firstDatePrompt: _firstDateController.text.trim(),
        musicTastePrompt: _musicTasteController.text.trim(),
        themeId: _selectedThemeId,
        camViewPolicy: _selectedCamViewPolicy,
        profileAccentColor: _profileAccentColor,
        profileBgGradientStart: _profileBgGradientStart,
        profileBgGradientEnd: _profileBgGradientEnd,
        profileMusicUrl: _profileMusicUrlController.text.trim().isEmpty
            ? null
            : _profileMusicUrlController.text.trim(),
        profileMusicTitle: _profileMusicTitleController.text.trim().isEmpty
            ? null
            : _profileMusicTitleController.text.trim(),
        privacy: ProfilePrivacyModel(
          showAge: _showAge,
          showGender: _showGender,
          showLocation: _showLocation,
          showRelationshipStatus: _showRelationshipStatus,
        ),
        adultModeEnabled: _adultModeEnabled,
        adultConsentAccepted: _adultConsentAccepted,
        adultKinks: _parseList(_adultKinksController.text),
        adultPreferences: _parseList(_adultPreferencesController.text),
        adultBoundaries: _parseList(_adultBoundariesController.text),
        adultLookingFor: _adultLookingFor.toList(growable: false),
      ),
    );
    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    if (state.error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    _hydrateForm(state);
    final requiredItems = ProfileCompletion.requiredSetupItems(state);
    final guidedItems = ProfileCompletion.guidedSetupItems(state);
    final isSetupComplete = requiredItems.isEmpty;
    final profileStrength = ProfileCompletion.completeness(state);
    final hasPendingUploads = _isUploadingPhoto ||
        _isUploadingCover ||
        _isUploadingGallery ||
        _isUploadingVideo;

    if (state.isLoading && state.userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSetupComplete)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finish setup to unlock all pages',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        ...requiredItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.radio_button_unchecked,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text(item)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _ProfileActionBar(
                  profileStrength: profileStrength,
                  isLoading: state.isLoading,
                  hasPendingUploads: hasPendingUploads,
                  onSave: _saveProfile,
                ),
                const SizedBox(height: 14),
                _HeroCard(
                  state: state,
                  profileStrength: profileStrength,
                  onUploadAvatar: _uploadPhoto,
                  onUploadCover: _uploadCoverPhoto,
                  onUploadGallery: _uploadGalleryPhoto,
                  onUploadVideo: _uploadVideo,
                  isUploadingPhoto: _isUploadingPhoto,
                  isUploadingCover: _isUploadingCover,
                  isUploadingGallery: _isUploadingGallery,
                  isUploadingVideo: _isUploadingVideo,
                ),
                if (ref.watch(enableTop8FriendsFeature)) ...[
                  const SizedBox(height: 18),
                  const TopEightCarousel(),
                ],
                const SizedBox(height: 18),
                if (state.userId != null) ...[
                  _SectionCard(
                    title: 'My Posts',
                    subtitle: 'Everything you have shared.',
                    child: Consumer(
                      builder: (context, ref, _) {
                        final postsAsync = ref.watch(
                          userPostsStreamProvider(state.userId!),
                        );
                        return postsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (__, _) => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Could not load posts.'),
                          ),
                          data: (posts) => posts.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No posts yet. Share something!',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : Column(
                                  children: posts
                                      .map(
                                        (p) => PostCard(
                                          post: p,
                                          currentUserId: state.userId!,
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _SectionCard(
                  title: 'Guided setup',
                  subtitle: guidedItems.isEmpty
                      ? 'Everything essential is complete. Tune details anytime.'
                      : 'Finish these steps to improve discovery and trust.',
                  child: guidedItems.isEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Profile basics complete. Great start.',
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: guidedItems
                              .take(4)
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: const Icon(
                                    Icons.radio_button_unchecked,
                                    size: 18,
                                  ),
                                  title: Text(item),
                                ),
                              )
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Identity',
                  subtitle: 'Core profile details other people can discover.',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter at least 2 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(labelText: 'Bio'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _aboutMeController,
                        decoration: const InputDecoration(
                          labelText: 'About me',
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                              ),
                              items: _genderOptions
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) =>
                                  setState(() => _selectedGender = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRelationshipStatus,
                        decoration: const InputDecoration(
                          labelText: 'Relationship status',
                        ),
                        items: _relationshipOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _selectedRelationshipStatus = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Privacy and cam control',
                  subtitle:
                      'Choose what stays public and how camera access should be handled later in live contexts.',
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _showAge,
                        onChanged: (value) => setState(() => _showAge = value),
                        title: const Text('Show age'),
                      ),
                      SwitchListTile(
                        value: _showGender,
                        onChanged: (value) =>
                            setState(() => _showGender = value),
                        title: const Text('Show gender'),
                      ),
                      SwitchListTile(
                        value: _showLocation,
                        onChanged: (value) =>
                            setState(() => _showLocation = value),
                        title: const Text('Show location'),
                      ),
                      SwitchListTile(
                        value: _showRelationshipStatus,
                        onChanged: (value) =>
                            setState(() => _showRelationshipStatus = value),
                        title: const Text('Show relationship status'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<CamViewPolicy>(
                        initialValue: _selectedCamViewPolicy,
                        decoration: const InputDecoration(
                          labelText: 'Who can view my cam',
                        ),
                        items: CamViewPolicy.values
                            .map(
                              (value) => DropdownMenuItem<CamViewPolicy>(
                                value: value,
                                child: Text(_camPolicyLabel(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCamViewPolicy = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Appearance ───────────────────────────────────────────
                _SectionCard(
                  title: 'Appearance',
                  subtitle:
                      'Pick a profile theme, custom gradient, and accent colour.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      // Visual theme swatches
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _ProfileTheme.all.map((t) {
                          final selected = _selectedThemeId == t.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedThemeId = t.id),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 56,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [t.gradientStart, t.gradientEnd],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: selected
                                        ? Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            width: 2.5,
                                          )
                                        : Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: t.gradientStart.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: selected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      // Accent / font colour
                      Text(
                        'Accent colour',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Used for text highlights on your profile.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _ColorSwatchRow(
                        selectedHex: _profileAccentColor,
                        onSelected: (hex) =>
                            setState(() => _profileAccentColor = hex),
                      ),
                      const SizedBox(height: 18),
                      // Custom background gradient
                      Text(
                        'Custom background gradient',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Overrides the theme gradient on your profile card.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                _ColorSwatchRow(
                                  selectedHex: _profileBgGradientStart,
                                  onSelected: (hex) => setState(
                                    () => _profileBgGradientStart = hex,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                _ColorSwatchRow(
                                  selectedHex: _profileBgGradientEnd,
                                  onSelected: (hex) => setState(
                                    () => _profileBgGradientEnd = hex,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_profileBgGradientStart != null &&
                          _profileBgGradientEnd != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _hexToColor(_profileBgGradientStart!),
                                  _hexToColor(_profileBgGradientEnd!),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _profileBgGradientStart = null;
                            _profileBgGradientEnd = null;
                          }),
                          icon: const Icon(Icons.clear, size: 14),
                          label: const Text('Clear custom gradient'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Profile Music ────────────────────────────────────────
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Profile music',
                  subtitle:
                      'Add a track that plays when people visit your profile — MySpace style.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _profileMusicUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Audio URL (HTTPS, .mp3 / .ogg / .wav)',
                          hintText: 'https://example.com/your-track.mp3',
                          prefixIcon: Icon(Icons.link_rounded, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null || uri.scheme != 'https') {
                            return 'Must be an HTTPS URL.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _profileMusicTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Track title (shown on your profile)',
                          hintText: 'e.g. Drake — Rich Flex',
                          prefixIcon: Icon(Icons.music_note_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Profile vibe ──────────────────────────────────────────
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Profile vibe',
                  subtitle: 'Conversation hooks shown on your public page.',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _interestsController,
                        decoration: const InputDecoration(
                          labelText: 'Interests',
                          hintText: 'Comma-separated interests',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interestSuggestions
                            .map(
                              (suggestion) => ActionChip(
                                label: Text(suggestion),
                                onPressed: () =>
                                    _addInterestSuggestion(suggestion),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _vibeController,
                        decoration: const InputDecoration(
                          labelText: 'Tonight vibe',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firstDateController,
                        decoration: const InputDecoration(
                          labelText: 'First date move',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _musicTasteController,
                        decoration: const InputDecoration(
                          labelText: 'Music taste',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Device settings ───────────────────────────────────────
                _SectionCard(
                  title: 'Devices',
                  subtitle:
                      'Choose which camera and microphone to use in live rooms.',
                  child: const DeviceSettingsPanel(),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Adult mode',
                  subtitle:
                      'Stored separately and reserved for adult-only contexts. It is not shown on the public profile page.',
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _adultModeEnabled,
                        onChanged: (value) =>
                            setState(() => _adultModeEnabled = value),
                        title: const Text('Enable naughty side'),
                      ),
                      CheckboxListTile(
                        value: _adultConsentAccepted,
                        onChanged: (value) => setState(
                          () => _adultConsentAccepted = value ?? false,
                        ),
                        title: const Text('I confirm I am 18+'),
                      ),
                      if (_adultModeEnabled) ...[
                        TextFormField(
                          controller: _adultKinksController,
                          decoration: const InputDecoration(labelText: 'Kinks'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _adultPreferencesController,
                          decoration: const InputDecoration(
                            labelText: 'Preferences',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _adultBoundariesController,
                          decoration: const InputDecoration(
                            labelText: 'Boundaries',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Looking for',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: AdultRelationshipIntent.values
                              .map(
                                (intent) => FilterChip(
                                  label: Text(_adultIntentLabel(intent)),
                                  selected: _adultLookingFor.contains(intent),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _adultLookingFor.add(intent);
                                      } else {
                                        _adultLookingFor.remove(intent);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((state.introVideoUrl ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Intro video ready'),
                    trailing: TextButton(
                      onPressed: () =>
                          _openIntroVideo(state.introVideoUrl!.trim()),
                      child: const Text('Open'),
                    ),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : _saveProfile,
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _adultIntentLabel(AdultRelationshipIntent value) {
    switch (value) {
      case AdultRelationshipIntent.love:
        return 'Love';
      case AdultRelationshipIntent.fun:
        return 'Fun';
      case AdultRelationshipIntent.hookups:
        return 'Hookups';
      case AdultRelationshipIntent.openConnection:
        return 'Open connection';
    }
  }

  String _camPolicyLabel(CamViewPolicy value) {
    switch (value) {
      case CamViewPolicy.everyone:
        return 'Everyone can view my cam';
      case CamViewPolicy.friendsOnly:
        return 'Friends only';
      case CamViewPolicy.approvedOnly:
        return 'People I approve';
      case CamViewPolicy.nobody:
        return 'Nobody';
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.state,
    required this.profileStrength,
    required this.onUploadAvatar,
    required this.onUploadCover,
    required this.onUploadGallery,
    required this.onUploadVideo,
    required this.isUploadingPhoto,
    required this.isUploadingCover,
    required this.isUploadingGallery,
    required this.isUploadingVideo,
  });

  final ProfileState state;
  final double profileStrength;
  final Future<void> Function() onUploadAvatar;
  final Future<void> Function() onUploadCover;
  final Future<void> Function() onUploadGallery;
  final Future<void> Function() onUploadVideo;
  final bool isUploadingPhoto;
  final bool isUploadingCover;
  final bool isUploadingGallery;
  final bool isUploadingVideo;

  @override
  Widget build(BuildContext context) {
    Future<void> safeRunUpload(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        developer.log(
          'Unhandled profile upload error',
          name: 'ProfileUpload',
          error: error,
          stackTrace: stackTrace,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Picture upload failed. Please try again.'),
          ),
        );
      }
    }

    final vnUploadBtn = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFD4AF37),
      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1416), Color(0xFF120E10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 7,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: (state.coverPhotoUrl ?? '').trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: (state.coverPhotoUrl ?? "").trim(),
                            fit: BoxFit.cover,
                            errorWidget: (___, __, _) =>
                                const Icon(Icons.landscape_rounded, size: 40),
                          )
                        : const Icon(Icons.landscape_rounded, size: 40),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: profileStrength,
                          strokeWidth: 2.6,
                          backgroundColor: Colors.white.withValues(alpha: 0.28),
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(100 * profileStrength).round()}% ready',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: GestureDetector(
              onTap:
                  isUploadingPhoto ? null : () => safeRunUpload(onUploadAvatar),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: isUploadingPhoto
                        ? SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : (state.avatarUrl ?? '').trim().isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: (state.avatarUrl ?? "").trim(),
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (___, __, _) =>
                                      const Icon(Icons.person, size: 32),
                                ),
                              )
                            : const Icon(Icons.person, size: 32),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            (state.username ?? '').trim().isEmpty
                ? 'Your profile'
                : (state.username ?? "Guest").trim(),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if ((state.age?.toString() ?? '').isNotEmpty)
                _FactChip(icon: Icons.cake_outlined, text: '${state.age}'),
              if ((state.location ?? '').trim().isNotEmpty)
                _FactChip(
                  icon: Icons.place_outlined,
                  text: (state.location ?? "Unknown").trim(),
                ),
              if ((state.gender ?? '').trim().isNotEmpty)
                _FactChip(
                  icon: Icons.person_outline,
                  text: (state.gender ?? "Not Specified").trim(),
                ),
              if ((state.relationshipStatus ?? '').trim().isNotEmpty)
                _FactChip(
                  icon: Icons.favorite_border,
                  text: (state.relationshipStatus ?? "Single").trim(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: profileStrength,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text(
            'Profile strength ${(100 * profileStrength).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Consumer(
            builder: (context, ref, _) {
              final counts = state.userId != null
                  ? ref.watch(followCountProvider(state.userId!)).valueOrNull
                  : null;
              return Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Followers',
                      value: '${counts?.followers ?? state.followers.length}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: 'Following',
                      value: '${counts?.following ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: 'Photos',
                      value: '${state.galleryUrls.length}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: isUploadingPhoto
                    ? null
                    : () => safeRunUpload(onUploadAvatar),
                icon: const Icon(Icons.photo_camera_back_outlined, size: 16),
                label: Text(isUploadingPhoto ? 'Uploading...' : 'Profile Pic'),
                style: vnUploadBtn,
              ),
              OutlinedButton.icon(
                onPressed: isUploadingCover
                    ? null
                    : () => safeRunUpload(onUploadCover),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(isUploadingCover ? 'Uploading...' : 'Cover'),
                style: vnUploadBtn,
              ),
              OutlinedButton.icon(
                onPressed: isUploadingGallery
                    ? null
                    : () => safeRunUpload(onUploadGallery),
                icon: const Icon(Icons.collections_outlined, size: 16),
                label: Text(isUploadingGallery ? 'Uploading...' : 'Gallery'),
                style: vnUploadBtn,
              ),
              OutlinedButton.icon(
                onPressed: isUploadingVideo
                    ? null
                    : () => safeRunUpload(onUploadVideo),
                icon: const Icon(Icons.videocam_outlined, size: 16),
                label: Text(isUploadingVideo ? 'Uploading...' : 'Intro video'),
                style: vnUploadBtn,
              ),
            ],
          ),
          if (state.galleryUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.galleryUrls.length,
                separatorBuilder: (__, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = state.galleryUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (___, __, _) => Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileActionBar extends StatelessWidget {
  const _ProfileActionBar({
    required this.profileStrength,
    required this.isLoading,
    required this.hasPendingUploads,
    required this.onSave,
  });

  final double profileStrength;
  final bool isLoading;
  final bool hasPendingUploads;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile readiness ${(profileStrength * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPendingUploads
                      ? 'Uploads in progress. You can still save now.'
                      : 'Keep editing until everything feels true to you.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onSave,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0D0A0C),
                    ),
                  )
                : const Icon(
                    Icons.publish_outlined,
                    color: Color(0xFF0D0A0C),
                    size: 18,
                  ),
            label: Text(
              isLoading ? 'Saving...' : 'Publish',
              style: const TextStyle(
                color: Color(0xFF0D0A0C),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF0D0A0C),
              disabledBackgroundColor: Color(0xFFD4AF37),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1416),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFFF7EDE2)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD4AF37),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFFAD9585)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile theme definitions
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTheme {
  const _ProfileTheme({
    required this.id,
    required this.label,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final String id;
  final String label;
  final Color gradientStart;
  final Color gradientEnd;

  static const all = <_ProfileTheme>[
    _ProfileTheme(
      id: 'midnight',
      label: 'Midnight',
      gradientStart: Color(0xFF1A1A2E),
      gradientEnd: Color(0xFF16213E),
    ),
    _ProfileTheme(
      id: 'sunset',
      label: 'Sunset',
      gradientStart: Color(0xFFFF6B6B),
      gradientEnd: Color(0xFFFFE66D),
    ),
    _ProfileTheme(
      id: 'emerald',
      label: 'Emerald',
      gradientStart: Color(0xFF134E5E),
      gradientEnd: Color(0xFF71B280),
    ),
    _ProfileTheme(
      id: 'neon',
      label: 'Neon',
      gradientStart: Color(0xFF0F0C29),
      gradientEnd: Color(0xFF302B63),
    ),
    _ProfileTheme(
      id: 'rose',
      label: 'Rose',
      gradientStart: Color(0xFF833AB4),
      gradientEnd: Color(0xFFFD1D1D),
    ),
    _ProfileTheme(
      id: 'ocean',
      label: 'Ocean',
      gradientStart: Color(0xFF1A6B8A),
      gradientEnd: Color(0xFF00C6FF),
    ),
    _ProfileTheme(
      id: 'gold',
      label: 'Gold',
      gradientStart: Color(0xFF7B4F00),
      gradientEnd: Color(0xFFFFD700),
    ),
    _ProfileTheme(
      id: 'noir',
      label: 'Noir',
      gradientStart: Color(0xFF0D0D0D),
      gradientEnd: Color(0xFF2C2C2C),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour swatch row (preset colour picker)
// ─────────────────────────────────────────────────────────────────────────────

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selectedHex, required this.onSelected});

  final String? selectedHex;
  final ValueChanged<String?> onSelected;

  static const _swatches = <String>[
    '#D4A853', // champagne gold
    '#C45E7A', // rose wine
    '#8C6020', // deep amber
    '#FF6E84', // blush
    '#FFA040', // orange
    '#F2EBE0', // warm cream
    '#B09080', // warm taupe
    '#6B3040', // burgundy
    '#3D1A22', // deep wine
    '#FFFFFF', // white
    '#FF1744', // red
    '#4CAF50', // green
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "None" option
        GestureDetector(
          onTap: () => onSelected(null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: selectedHex == null
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.3),
                width: selectedHex == null ? 2.5 : 1,
              ),
            ),
            child: selectedHex == null
                ? const Center(
                    child: Icon(Icons.close, size: 14, color: Colors.white54),
                  )
                : null,
          ),
        ),
        ..._swatches.map((hex) {
          final isSelected = selectedHex == hex;
          final color = _hexToColor(hex);
          return GestureDetector(
            onTap: () => onSelected(hex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ]
                    : [],
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

/// Parses a hex colour string (with or without leading #) into a [Color].
Color _hexToColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  try {
    return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}
