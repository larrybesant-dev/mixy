import 'profile_controller.dart';

class ProfileCompletion {
  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static bool isProfileComplete(ProfileState state) {
    return _hasText(state.username) &&
        state.age >= 18 &&
        _hasText(state.location) &&
        _hasText(state.relationshipStatus) &&
        _hasText(state.avatarUrl) &&
        _hasText(state.coverPhotoUrl) &&
        state.galleryUrls.isNotEmpty;
  }

  static List<String> homeNudgeItems(ProfileState state) {
    final items = <String>[];
    if (_hasText(state.username) == false) items.add('Set display name');
    if (state.age < 18) items.add('Add your age');
    if (_hasText(state.location) == false) items.add('Add your location');
    if (_hasText(state.relationshipStatus) == false) {
      items.add('Add relationship status');
    }
    if (_hasText(state.avatarUrl) == false) items.add('Upload avatar');
    if (_hasText(state.coverPhotoUrl) == false) items.add('Upload cover photo');
    if (state.galleryUrls.isEmpty) items.add('Add a gallery photo');
    if (_hasText(state.bio) == false) items.add('Write a short bio');
    if (_hasText(state.aboutMe) == false) items.add('Tell people about you');
    if (_hasText(state.introVideoUrl) == false) items.add('Add intro video');
    if (state.interests.isEmpty) items.add('Add interests');
    return items;
  }

  static double homeNudgeCompleteness(ProfileState state) {
    int score = 0;
    if (_hasText(state.username)) score++;
    if (state.age >= 18) score++;
    if (_hasText(state.location)) score++;
    if (_hasText(state.relationshipStatus)) score++;
    if (_hasText(state.avatarUrl)) score++;
    if (_hasText(state.coverPhotoUrl)) score++;
    if (state.galleryUrls.isNotEmpty) score++;
    if (_hasText(state.bio)) score++;
    if (_hasText(state.aboutMe)) score++;
    if (_hasText(state.introVideoUrl)) score++;
    if (state.interests.isNotEmpty) score++;
    return score / 11;
  }

  static List<String> requiredSetupItems(ProfileState state) {
    final items = <String>[];
    if (_hasText(state.username) == false) items.add('Add a display name');
    if (state.age < 18) items.add('Add your age');
    if (_hasText(state.location) == false) items.add('Add your location');
    if (_hasText(state.relationshipStatus) == false) {
      items.add('Add relationship status');
    }
    if (_hasText(state.avatarUrl) == false) items.add('Upload a profile photo');
    if (_hasText(state.coverPhotoUrl) == false) items.add('Upload a cover photo');
    if (state.galleryUrls.isEmpty) items.add('Upload a gallery photo');
    return items;
  }

  static double completeness(ProfileState state) {
    int score = 0;
    if (_hasText(state.username)) score++;
    if (state.age >= 18) score++;
    if (_hasText(state.location)) score++;
    if (_hasText(state.relationshipStatus)) score++;
    if (_hasText(state.avatarUrl)) score++;
    if (_hasText(state.coverPhotoUrl)) score++;
    if (state.galleryUrls.isNotEmpty) score++;
    if (_hasText(state.bio)) score++;
    if (_hasText(state.aboutMe)) score++;
    if (state.interests.isNotEmpty) score++;
    if (_hasText(state.introVideoUrl)) score++;
    return score / 11;
  }

  static List<String> guidedSetupItems(ProfileState state) {
    final items = <String>[];
    if (_hasText(state.username) == false) items.add('Set display name');
    if (state.age < 18) items.add('Add your age');
    if (_hasText(state.location) == false) items.add('Add your location');
    if (_hasText(state.relationshipStatus) == false) {
      items.add('Add relationship status');
    }
    if (_hasText(state.avatarUrl) == false) items.add('Upload avatar');
    if (_hasText(state.coverPhotoUrl) == false) items.add('Upload cover photo');
    if (state.galleryUrls.isEmpty) items.add('Add gallery photos');
    if (_hasText(state.bio) == false) items.add('Write a short bio');
    if (_hasText(state.aboutMe) == false) items.add('Tell people about you');
    if (state.interests.isEmpty) items.add('Add interests');
    if (_hasText(state.introVideoUrl) == false) items.add('Add intro video');
    return items;
  }
}
