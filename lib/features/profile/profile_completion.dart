import 'profile_controller.dart';

class ProfileCompletion {
  static List<String> homeNudgeItems(ProfileState state) {
    final items = <String>[];
    if ((state.username ?? '').trim().length < 2) items.add('Set display name');
    if ((state.avatarUrl ?? '').trim().isEmpty) items.add('Upload avatar');
    if ((state.bio ?? '').trim().isEmpty) items.add('Write a short bio');
    if (state.interests.isEmpty) items.add('Add interests');
    return items;
  }

  static double homeNudgeCompleteness(ProfileState state) {
    int score = 0;
    if ((state.username ?? '').trim().length >= 2) score++;
    if ((state.avatarUrl ?? '').trim().isNotEmpty) score++;
    if ((state.bio ?? '').trim().isNotEmpty) score++;
    if (state.interests.isNotEmpty) score++;
    return score / 4;
  }

  static List<String> requiredSetupItems(ProfileState state) {
    final items = <String>[];
    if ((state.username ?? '').trim().length < 2) {
      items.add('Add a display name');
    }
    if ((state.email ?? '').trim().isEmpty) {
      items.add('Add an email on your account');
    }
    return items;
  }

  static double completeness(ProfileState state) {
    int score = 0;
    if ((state.username ?? '').trim().length >= 2) score++;
    if ((state.avatarUrl ?? '').trim().isNotEmpty) score++;
    if ((state.coverPhotoUrl ?? '').trim().isNotEmpty) score++;
    if ((state.bio ?? '').trim().isNotEmpty) score++;
    if ((state.aboutMe ?? '').trim().isNotEmpty) score++;
    if (state.interests.isNotEmpty) score++;
    if ((state.introVideoUrl ?? '').trim().isNotEmpty) score++;
    return score / 7;
  }

  static List<String> guidedSetupItems(ProfileState state) {
    final items = <String>[];
    if ((state.username ?? '').trim().length < 2) items.add('Set display name');
    if ((state.avatarUrl ?? '').trim().isEmpty) items.add('Upload avatar');
    if ((state.coverPhotoUrl ?? '').trim().isEmpty) {
      items.add('Upload cover photo');
    }
    if ((state.bio ?? '').trim().isEmpty) items.add('Write a short bio');
    if ((state.aboutMe ?? '').trim().isEmpty) {
      items.add('Tell people about you');
    }
    if (state.interests.isEmpty) items.add('Add interests');
    if ((state.introVideoUrl ?? '').trim().isEmpty) {
      items.add('Add intro video');
    }
    return items;
  }
}




