import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mixvy/models/room_policy_model.dart';
import 'package:mixvy/services/profile_service.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';

class ProfileState {
  final bool isLoading;
  final String? error, userId, username, email, avatarUrl, coverPhotoUrl, bio, aboutMe, themeId, location, gender, relationshipStatus, vibePrompt, firstDatePrompt, musicTastePrompt, profileAccentColor, profileBgGradientStart, profileBgGradientEnd, profileMusicUrl, profileMusicTitle, introVideoUrl, membershipLevel;
  final int coinBalance, age;
  final List<String> galleryUrls, interests, followers, adultKinks, adultPreferences, adultBoundaries;
  final ProfilePrivacyModel privacy;
  final bool adultModeEnabled, adultConsentAccepted;
  final List<dynamic> adultLookingFor;
  final CamViewPolicy camViewPolicy;

  const ProfileState({
    this.isLoading = false, this.error, this.userId, this.username, this.email, this.avatarUrl,
    this.coverPhotoUrl, this.galleryUrls = const [], this.bio, this.aboutMe, this.themeId = 'midnight',
    this.interests = const [], this.followers = const [], this.adultKinks = const [],
    this.adultPreferences = const [], this.adultBoundaries = const [], this.adultLookingFor = const [],
    this.coinBalance = 0, this.privacy = const ProfilePrivacyModel(), this.adultModeEnabled = false,
    this.adultConsentAccepted = false, this.camViewPolicy = CamViewPolicy.approvedOnly,
    this.age = 0, this.location, this.gender, this.relationshipStatus, this.vibePrompt, 
    this.firstDatePrompt, this.musicTastePrompt, this.profileAccentColor, this.profileBgGradientStart, 
    this.profileBgGradientEnd, this.profileMusicUrl, this.profileMusicTitle, this.introVideoUrl, this.membershipLevel
  });

  ProfileState copyWith({
    bool? isLoading, String? error, String? userId, String? username, String? email, String? avatarUrl, 
    String? coverPhotoUrl, List<String>? galleryUrls, String? bio, String? aboutMe, String? themeId, 
    List<String>? interests, List<String>? followers, List<String>? adultKinks, List<String>? adultPreferences, 
    List<String>? adultBoundaries, List<dynamic>? adultLookingFor, int? coinBalance, ProfilePrivacyModel? privacy, 
    bool? adultModeEnabled, bool? adultConsentAccepted, CamViewPolicy? camViewPolicy, int? age, String? location, 
    String? gender, String? relationshipStatus, String? vibePrompt, String? firstDatePrompt, String? musicTastePrompt, 
    String? profileAccentColor, String? profileBgGradientStart, String? profileBgGradientEnd, String? profileMusicUrl, 
    String? profileMusicTitle, String? introVideoUrl, String? membershipLevel
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading, error: error ?? this.error, userId: userId ?? this.userId,
      username: username ?? this.username, email: email ?? this.email, avatarUrl: avatarUrl ?? this.avatarUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl, galleryUrls: galleryUrls ?? this.galleryUrls,
      bio: bio ?? this.bio, aboutMe: aboutMe ?? this.aboutMe, themeId: themeId ?? this.themeId,
      interests: interests ?? this.interests, followers: followers ?? this.followers,
      adultKinks: adultKinks ?? this.adultKinks, adultPreferences: adultPreferences ?? this.adultPreferences,
      adultBoundaries: adultBoundaries ?? this.adultBoundaries, adultLookingFor: adultLookingFor ?? this.adultLookingFor,
      coinBalance: coinBalance ?? this.coinBalance, privacy: privacy ?? this.privacy,
      adultModeEnabled: adultModeEnabled ?? this.adultModeEnabled, adultConsentAccepted: adultConsentAccepted ?? this.adultConsentAccepted,
      camViewPolicy: camViewPolicy ?? this.camViewPolicy, age: age ?? this.age, location: location ?? this.location,
      gender: gender ?? this.gender, relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      vibePrompt: vibePrompt ?? this.vibePrompt, firstDatePrompt: firstDatePrompt ?? this.firstDatePrompt,
      musicTastePrompt: musicTastePrompt ?? this.musicTastePrompt, profileAccentColor: profileAccentColor ?? this.profileAccentColor,
      profileBgGradientStart: profileBgGradientStart ?? this.profileBgGradientStart, profileBgGradientEnd: profileBgGradientEnd ?? this.profileBgGradientEnd,
      profileMusicUrl: profileMusicUrl ?? this.profileMusicUrl, profileMusicTitle: profileMusicTitle ?? this.profileMusicTitle,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl, membershipLevel: membershipLevel ?? this.membershipLevel,
    );
  }
}

final profileControllerProvider = NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  late final ProfileService _profileService;

  @override
  ProfileState build() {
    // Corrected to use 'firestoreProvider' from your firebase_providers.dart
    _profileService = ProfileService(firestore: ref.read(firestoreProvider));
    return const ProfileState();
  }

  Future<void> updateProfile(ProfileState profile) async {
    state = state.copyWith(isLoading: true);
    try {
      // Build complete userData map from profile state
      final userData = {
        'username': profile.username ?? '',
        'email': profile.email ?? '',
        'avatarUrl': profile.avatarUrl,
        'coverPhotoUrl': profile.coverPhotoUrl,
        'bio': profile.bio,
        'aboutMe': profile.aboutMe,
        'age': profile.age,
        'gender': profile.gender,
        'location': profile.location,
        'relationshipStatus': profile.relationshipStatus,
        'vibePrompt': profile.vibePrompt,
        'firstDatePrompt': profile.firstDatePrompt,
        'musicTastePrompt': profile.musicTastePrompt,
        'interests': profile.interests,
        'themeId': profile.themeId,
        'camViewPolicy': profile.camViewPolicy.toString(),
        'galleryUrls': profile.galleryUrls,
        'introVideoUrl': profile.introVideoUrl,
        'membershipLevel': profile.membershipLevel,
        'coinBalance': profile.coinBalance,
        'adultConsentAccepted': profile.adultConsentAccepted,
        'adultKinks': profile.adultKinks,
        'adultPreferences': profile.adultPreferences,
        'adultBoundaries': profile.adultBoundaries,
        'adultLookingFor': profile.adultLookingFor,
        'profileAccentColor': profile.profileAccentColor,
        'profileBgGradientStart': profile.profileBgGradientStart,
        'profileBgGradientEnd': profile.profileBgGradientEnd,
        'profileMusicUrl': profile.profileMusicUrl,
        'profileMusicTitle': profile.profileMusicTitle,
        // Mark profile as complete when username is set
        'isComplete': (profile.username ?? '').trim().isNotEmpty,
      };
      
      await _profileService.saveProfile(
        userId: profile.userId ?? '', 
        userData: userData, 
        privacy: profile.privacy.isPrivate, 
        adultProfile: profile.adultModeEnabled
      );
      state = profile.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchProfile(String? userId) async {}
  Future<void> loadCurrentProfile() async {}
  void updateDraft(ProfileState profile) { state = profile; }
}
