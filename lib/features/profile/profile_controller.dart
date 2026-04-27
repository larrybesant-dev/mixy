import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixvy/models/adult_profile_model.dart';
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mixvy/models/room_policy_model.dart';
import 'package:mixvy/services/profile_service.dart';
import '../auth/controllers/auth_controller.dart';
import '../../core/events/app_event.dart';
import '../../core/events/app_event_bus.dart';
import '../../models/user_model.dart';

class ProfileState {
  final bool isLoading;
  final String? error;
  final String? userId;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final List<String> galleryUrls;
  final String? introVideoUrl;
  final String? bio;
  final String? aboutMe;
  final int? age;
  final String? gender;
  final String? location;
  final String? relationshipStatus;
  final String? vibePrompt;
  final String? firstDatePrompt;
  final String? musicTastePrompt;
  final List<String> interests;
  final int coinBalance;
  final String? membershipLevel;
  final List<String> followers;
  final String themeId;
  final CamViewPolicy camViewPolicy;
  final ProfilePrivacyModel privacy;
  final bool adultModeEnabled;
  final bool adultConsentAccepted;
  final List<String> adultKinks;
  final List<String> adultPreferences;
  final List<String> adultBoundaries;
  final List<AdultRelationshipIntent> adultLookingFor;
  // Profile personalisation
  final String? profileAccentColor;
  final String? profileBgGradientStart;
  final String? profileBgGradientEnd;
  final String? profileMusicUrl;
  final String? profileMusicTitle;

  static const Object _unset = Object();

  const ProfileState({
    this.isLoading = false,
    this.error,
    this.userId,
    this.username,
    this.email,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.galleryUrls = const [],
    this.introVideoUrl,
    this.bio,
    this.aboutMe,
    this.age,
    this.gender,
    this.location,
    this.relationshipStatus,
    this.vibePrompt,
    this.firstDatePrompt,
    this.musicTastePrompt,
    this.interests = const [],
    this.coinBalance = 0,
    this.membershipLevel,
    this.followers = const [],
    this.themeId = 'midnight',
    this.camViewPolicy = CamViewPolicy.approvedOnly,
    this.privacy = const ProfilePrivacyModel(),
    this.adultModeEnabled = false,
    this.adultConsentAccepted = false,
    this.adultKinks = const [],
    this.adultPreferences = const [],
    this.adultBoundaries = const [],
    this.adultLookingFor = const [],
    this.profileAccentColor,
    this.profileBgGradientStart,
    this.profileBgGradientEnd,
    this.profileMusicUrl,
    this.profileMusicTitle,
  });

  ProfileState copyWith({
    bool? isLoading,
    Object? error = _unset,
    Object? userId = _unset,
    Object? username = _unset,
    Object? email = _unset,
    Object? avatarUrl = _unset,
    Object? coverPhotoUrl = _unset,
    List<String>? galleryUrls,
    Object? introVideoUrl = _unset,
    Object? bio = _unset,
    Object? aboutMe = _unset,
    int? age,
    Object? gender = _unset,
    Object? location = _unset,
    Object? relationshipStatus = _unset,
    Object? vibePrompt = _unset,
    Object? firstDatePrompt = _unset,
    Object? musicTastePrompt = _unset,
    List<String>? interests,
    int? coinBalance,
    Object? membershipLevel = _unset,
    List<String>? followers,
    String? themeId,
    CamViewPolicy? camViewPolicy,
    ProfilePrivacyModel? privacy,
    bool? adultModeEnabled,
    bool? adultConsentAccepted,
    List<String>? adultKinks,
    List<String>? adultPreferences,
    List<String>? adultBoundaries,
    List<AdultRelationshipIntent>? adultLookingFor,
    Object? profileAccentColor = _unset,
    Object? profileBgGradientStart = _unset,
    Object? profileBgGradientEnd = _unset,
    Object? profileMusicUrl = _unset,
    Object? profileMusicTitle = _unset,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      username: identical(username, _unset)
          ? this.username
          : username as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      avatarUrl: identical(avatarUrl, _unset)
          ? this.avatarUrl
          : avatarUrl as String?,
      coverPhotoUrl: identical(coverPhotoUrl, _unset)
          ? this.coverPhotoUrl
          : coverPhotoUrl as String?,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      introVideoUrl: identical(introVideoUrl, _unset)
          ? this.introVideoUrl
          : introVideoUrl as String?,
      bio: identical(bio, _unset) ? this.bio : bio as String?,
      aboutMe: identical(aboutMe, _unset) ? this.aboutMe : aboutMe as String?,
      age: age ?? this.age,
      gender: identical(gender, _unset) ? this.gender : gender as String?,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      relationshipStatus: identical(relationshipStatus, _unset)
          ? this.relationshipStatus
          : relationshipStatus as String?,
      vibePrompt: identical(vibePrompt, _unset)
          ? this.vibePrompt
          : vibePrompt as String?,
      firstDatePrompt: identical(firstDatePrompt, _unset)
          ? this.firstDatePrompt
          : firstDatePrompt as String?,
      musicTastePrompt: identical(musicTastePrompt, _unset)
          ? this.musicTastePrompt
          : musicTastePrompt as String?,
      interests: interests ?? this.interests,
      coinBalance: coinBalance ?? this.coinBalance,
      membershipLevel: identical(membershipLevel, _unset)
          ? this.membershipLevel
          : membershipLevel as String?,
      followers: followers ?? this.followers,
      themeId: themeId ?? this.themeId,
      camViewPolicy: camViewPolicy ?? this.camViewPolicy,
      privacy: privacy ?? this.privacy,
      adultModeEnabled: adultModeEnabled ?? this.adultModeEnabled,
      adultConsentAccepted: adultConsentAccepted ?? this.adultConsentAccepted,
      adultKinks: adultKinks ?? this.adultKinks,
      adultPreferences: adultPreferences ?? this.adultPreferences,
      adultBoundaries: adultBoundaries ?? this.adultBoundaries,
      adultLookingFor: adultLookingFor ?? this.adultLookingFor,
      profileAccentColor: identical(profileAccentColor, _unset)
          ? this.profileAccentColor
          : profileAccentColor as String?,
      profileBgGradientStart: identical(profileBgGradientStart, _unset)
          ? this.profileBgGradientStart
          : profileBgGradientStart as String?,
      profileBgGradientEnd: identical(profileBgGradientEnd, _unset)
          ? this.profileBgGradientEnd
          : profileBgGradientEnd as String?,
      profileMusicUrl: identical(profileMusicUrl, _unset)
          ? this.profileMusicUrl
          : profileMusicUrl as String?,
      profileMusicTitle: identical(profileMusicTitle, _unset)
          ? this.profileMusicTitle
          : profileMusicTitle as String?,
    );
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(
      () => ProfileController(),
    );

class ProfileController extends Notifier<ProfileState> {
  final FirebaseAuth _auth;
  final ProfileService _profileService;

  ProfileController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ProfileService? profileService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _profileService =
           profileService ??
           ProfileService(firestore: firestore ?? FirebaseFirestore.instance);

  @override
  ProfileState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final previousUid = previous?.uid?.trim();
      final nextUid = next.uid?.trim();

      if (nextUid != null && nextUid.isNotEmpty && nextUid != previousUid) {
        Future.microtask(() => fetchProfile(nextUid));
        return;
      }

      if (nextUid == null || nextUid.isEmpty) {
        state = const ProfileState();
      }
    });

    final user = _auth.currentUser;
    return ProfileState(
      userId: user?.uid,
      email: user?.email,
      username: null,
      avatarUrl: user?.photoURL,
      coverPhotoUrl: null,
      galleryUrls: const [],
      introVideoUrl: null,
      bio: null,
      aboutMe: null,
      age: null,
      gender: null,
      location: null,
      relationshipStatus: null,
      vibePrompt: null,
      firstDatePrompt: null,
      musicTastePrompt: null,
      interests: const [],
    );
  }

  Future<void> loadCurrentProfile() async {
    await fetchProfile(_auth.currentUser?.uid);
  }

  void updateDraft(ProfileState profile) {
    state = profile.copyWith(error: null);
  }

  Future<void> updateProfile(ProfileState profile) async {
    state = state.copyWith(isLoading: true, error: null);

    final user = _auth.currentUser;
    final userId = profile.userId ?? user?.uid;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'No signed-in user');
      return;
    }

    try {
      final normalizedUsername = (profile.username ?? '').trim();
      final normalizedEmail = (profile.email ?? user?.email ?? '').trim();

      if (normalizedUsername.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Username is required.',
        );
        return;
      }
      final normalizedAvatar = (profile.avatarUrl ?? '').trim();
      final normalizedCover = (profile.coverPhotoUrl ?? '').trim();
      final normalizedGallery = profile.galleryUrls
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      final normalizedVideo = (profile.introVideoUrl ?? '').trim();
      final normalizedBio = (profile.bio ?? '').trim();
      final normalizedAboutMe = (profile.aboutMe ?? '').trim();
      final normalizedLocation = (profile.location ?? '').trim();
      final normalizedGender = (profile.gender ?? '').trim();
      final normalizedRelationshipStatus = (profile.relationshipStatus ?? '')
          .trim();
      final normalizedVibe = (profile.vibePrompt ?? '').trim();
      final normalizedFirstDate = (profile.firstDatePrompt ?? '').trim();
      final normalizedMusic = (profile.musicTastePrompt ?? '').trim();
      final normalizedInterests = profile.interests
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      developer.log(
        'Starting profile save for userId: $userId',
        name: 'ProfileController',
      );

      await _profileService.saveProfile(
        userId: userId,
        userData: {
          'uid': userId,
          'username': normalizedUsername,
          'usernameLower': normalizedUsername.toLowerCase(),
          'displayName': normalizedUsername,
          'email': normalizedEmail,
          'photoUrl': normalizedAvatar.isEmpty ? null : normalizedAvatar,
          'avatarUrl': normalizedAvatar.isEmpty ? null : normalizedAvatar,
          'isComplete': normalizedUsername.isNotEmpty,
          'coverPhotoUrl': normalizedCover.isEmpty ? null : normalizedCover,
          'galleryUrls': normalizedGallery,
          'introVideoUrl': normalizedVideo.isEmpty ? null : normalizedVideo,
          'bio': normalizedBio.isEmpty ? null : normalizedBio,
          'aboutMe': normalizedAboutMe.isEmpty ? null : normalizedAboutMe,
          'age': profile.age,
          'gender': normalizedGender.isEmpty ? null : normalizedGender,
          'location': normalizedLocation.isEmpty ? null : normalizedLocation,
          'relationshipStatus': normalizedRelationshipStatus.isEmpty
              ? null
              : normalizedRelationshipStatus,
          'vibePrompt': normalizedVibe.isEmpty ? null : normalizedVibe,
          'firstDatePrompt': normalizedFirstDate.isEmpty
              ? null
              : normalizedFirstDate,
          'musicTastePrompt': normalizedMusic.isEmpty ? null : normalizedMusic,
          'interests': normalizedInterests,
          'themeId': profile.themeId,
          'camViewPolicy': profile.camViewPolicy.name,
          'adultModeEnabled': profile.adultModeEnabled,
          'adultConsentAccepted': profile.adultConsentAccepted,
          'isPrivate': profile.privacy.isPrivate,
          'profileAccentColor': profile.profileAccentColor,
          'profileBgGradientStart': profile.profileBgGradientStart,
          'profileBgGradientEnd': profile.profileBgGradientEnd,
          'profileMusicUrl': profile.profileMusicUrl,
          'profileMusicTitle': profile.profileMusicTitle,
        },
        privacy: profile.privacy,
        adultProfile: AdultProfileModel(
          userId: userId,
          enabled: profile.adultModeEnabled,
          adultConsentAccepted: profile.adultConsentAccepted,
          kinks: profile.adultKinks,
          preferences: profile.adultPreferences,
          boundaries: profile.adultBoundaries,
          lookingFor: profile.adultLookingFor,
        ),
      );

      developer.log(
        'Profile saved successfully for userId: $userId',
        name: 'ProfileController',
      );

      AppEventBus.instance.emit(
        ProfileUpdatedEvent(
          id: 'profile-updated:$userId:${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          sessionId: AppEventIds.profileSession(userId: userId),
          correlationId: AppEventIds.profileCorrelation(userId: userId),
          userId: userId,
        ),
      );

      // Keep profile data in Firestore only.
      // This avoids Auth accounts:update failures (notably on web profile photo updates).
      state = profile.copyWith(
        isLoading: false,
        error: null,
        userId: userId,
        username: normalizedUsername,
        email: normalizedEmail,
        avatarUrl: normalizedAvatar.isEmpty ? null : normalizedAvatar,
        coverPhotoUrl: normalizedCover.isEmpty ? null : normalizedCover,
        galleryUrls: normalizedGallery,
        introVideoUrl: normalizedVideo.isEmpty ? null : normalizedVideo,
        bio: normalizedBio.isEmpty ? null : normalizedBio,
        aboutMe: normalizedAboutMe.isEmpty ? null : normalizedAboutMe,
        age: profile.age,
        gender: normalizedGender.isEmpty ? null : normalizedGender,
        location: normalizedLocation.isEmpty ? null : normalizedLocation,
        relationshipStatus: normalizedRelationshipStatus.isEmpty
            ? null
            : normalizedRelationshipStatus,
        vibePrompt: normalizedVibe.isEmpty ? null : normalizedVibe,
        firstDatePrompt: normalizedFirstDate.isEmpty
            ? null
            : normalizedFirstDate,
        musicTastePrompt: normalizedMusic.isEmpty ? null : normalizedMusic,
        interests: normalizedInterests,
        themeId: profile.themeId,
        camViewPolicy: profile.camViewPolicy,
        privacy: profile.privacy,
        adultModeEnabled: profile.adultModeEnabled,
        adultConsentAccepted: profile.adultConsentAccepted,
        adultKinks: profile.adultKinks,
        adultPreferences: profile.adultPreferences,
        adultBoundaries: profile.adultBoundaries,
        adultLookingFor: profile.adultLookingFor,
        profileAccentColor: profile.profileAccentColor,
        profileBgGradientStart: profile.profileBgGradientStart,
        profileBgGradientEnd: profile.profileBgGradientEnd,
        profileMusicUrl: profile.profileMusicUrl,
        profileMusicTitle: profile.profileMusicTitle,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error saving profile',
        name: 'ProfileController',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save profile: ${e.toString()}',
      );
    }
  }

  Future<void> fetchProfile(String? userId) async {
    final resolvedUserId = userId ?? _auth.currentUser?.uid;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'No signed-in user');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final bundle = await _profileService.loadProfile(resolvedUserId);
      final userData = bundle.userData;
      if (userData.isEmpty) {
        final currentUser = _auth.currentUser;
        state = state.copyWith(
          isLoading: false,
          error: null,
          userId: resolvedUserId,
          username: null,
          email: currentUser?.email,
          avatarUrl: currentUser?.photoURL,
          coverPhotoUrl: null,
          galleryUrls: const [],
          introVideoUrl: null,
          bio: null,
          aboutMe: null,
          age: null,
          gender: null,
          location: null,
          relationshipStatus: null,
          vibePrompt: null,
          firstDatePrompt: null,
          musicTastePrompt: null,
          interests: const [],
        );
        return;
      }

      final user = UserModel.fromJson({'id': resolvedUserId, ...userData});
      // Keep profile data in Firestore only.
      // This avoids Auth accounts:update failures during profile hydration.
      state = state.copyWith(
        isLoading: false,
        error: null,
        userId: user.id.isNotEmpty ? user.id : resolvedUserId,
        username: user.username.isNotEmpty ? user.username : null,
        email: user.email.isNotEmpty ? user.email : _auth.currentUser?.email,
        avatarUrl: user.avatarUrl,
        coverPhotoUrl: user.coverPhotoUrl,
        galleryUrls: user.galleryUrls,
        introVideoUrl: user.introVideoUrl,
        bio: user.bio,
        aboutMe: user.aboutMe,
        age: user.age,
        gender: user.gender,
        location: user.location,
        relationshipStatus: user.relationshipStatus,
        vibePrompt: user.vibePrompt,
        firstDatePrompt: user.firstDatePrompt,
        musicTastePrompt: user.musicTastePrompt,
        interests: user.interests,
        coinBalance: user.coinBalance,
        membershipLevel: user.membershipLevel,
        followers: user.followers,
        themeId: user.themeId,
        camViewPolicy: CamViewPolicy.values.firstWhere(
          (value) => value.name == user.camViewPolicy,
          orElse: () => CamViewPolicy.approvedOnly,
        ),
        privacy: bundle.privacy,
        adultModeEnabled: bundle.adultProfile.enabled,
        adultConsentAccepted: bundle.adultProfile.adultConsentAccepted,
        adultKinks: bundle.adultProfile.kinks,
        adultPreferences: bundle.adultProfile.preferences,
        adultBoundaries: bundle.adultProfile.boundaries,
        adultLookingFor: bundle.adultProfile.lookingFor,
        profileAccentColor: user.profileAccentColor,
        profileBgGradientStart: user.profileBgGradientStart,
        profileBgGradientEnd: user.profileBgGradientEnd,
        profileMusicUrl: user.profileMusicUrl,
        profileMusicTitle: user.profileMusicTitle,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
