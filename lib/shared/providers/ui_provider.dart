// UI State Providers - Dark/Light mode, video quality, engagement features

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_models.dart';

/// Dark mode notifier
class DarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final darkModeProvider = NotifierProvider<DarkModeNotifier, bool>(
  () => DarkModeNotifier(),
);

/// Video quality notifier
class VideoQualityNotifier extends Notifier<VideoQuality> {
  @override
  VideoQuality build() => VideoQuality.medium;

  void setQuality(VideoQuality quality) => state = quality;
}

final videoQualityProvider =
    NotifierProvider<VideoQualityNotifier, VideoQuality>(
  () => VideoQualityNotifier(),
);

/// Auto-adjust quality notifier
class AutoAdjustQualityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final autoAdjustQualityProvider =
    NotifierProvider<AutoAdjustQualityNotifier, bool>(
  () => AutoAdjustQualityNotifier(),
);

/// Friends sidebar collapsed notifier
class FriendsSidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final friendsSidebarCollapsedProvider =
    NotifierProvider<FriendsSidebarCollapsedNotifier, bool>(
  () => FriendsSidebarCollapsedNotifier(),
);

/// Groups sidebar collapsed notifier
class GroupsSidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final groupsSidebarCollapsedProvider =
    NotifierProvider<GroupsSidebarCollapsedNotifier, bool>(
  () => GroupsSidebarCollapsedNotifier(),
);

/// Notifications enabled notifier
class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
  () => NotificationsEnabledNotifier(),
);

/// Sound effects enabled notifier
class SoundEffectsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final soundEffectsEnabledProvider =
    NotifierProvider<SoundEffectsEnabledNotifier, bool>(
  () => SoundEffectsEnabledNotifier(),
);

/// Reactions enabled notifier
class ReactionsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final reactionsEnabledProvider =
    NotifierProvider<ReactionsEnabledNotifier, bool>(
  () => ReactionsEnabledNotifier(),
);

/// Camera approval settings - Control who can see your video
class CameraApprovalSettingsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    return {
      'default_mode': 'ask', // 'ask', 'allow_all', 'deny_all'
      'approved_users': '', // comma-separated user IDs
      'blocked_users': '', // comma-separated user IDs
    };
  }

  void setDefaultMode(String mode) {
    state = {...state, 'default_mode': mode};
  }

  void approveUser(String userId) {
    final approved = state['approved_users']?.split(',').toList() ?? [];
    if (!approved.contains(userId)) {
      approved.add(userId);
      state = {
        ...state,
        'approved_users': approved.join(','),
      };
    }
  }

  void blockUser(String userId) {
    final blocked = state['blocked_users']?.split(',').toList() ?? [];
    if (!blocked.contains(userId)) {
      blocked.add(userId);
      state = {
        ...state,
        'blocked_users': blocked.join(','),
      };
    }
  }

  void unblockUser(String userId) {
    final blocked = state['blocked_users']?.split(',').toList() ?? [];
    blocked.removeWhere((id) => id == userId);
    state = {
      ...state,
      'blocked_users': blocked.join(','),
    };
  }

  String getApprovalStatus(String userId) {
    final defaultMode = state['default_mode'] ?? 'ask';
    final approvedUsers = state['approved_users']?.split(',') ?? [];
    final blockedUsers = state['blocked_users']?.split(',') ?? [];

    if (blockedUsers.contains(userId)) {
      return 'denied';
    }
    if (approvedUsers.contains(userId)) {
      return 'approved';
    }
    if (defaultMode == 'allow_all') {
      return 'approved';
    }
    if (defaultMode == 'deny_all') {
      return 'denied';
    }
    return 'pending';
  }
}

final cameraApprovalSettingsProvider =
    NotifierProvider<CameraApprovalSettingsNotifier, Map<String, String>>(
  () => CameraApprovalSettingsNotifier(),
);

/// Favorite groups notifier
class FavoriteGroupsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String groupId) {
    if (state.contains(groupId)) {
      state = {...state}..remove(groupId);
    } else {
      state = {...state, groupId};
    }
  }
}

final favoriteGroupsProvider =
    NotifierProvider<FavoriteGroupsNotifier, Set<String>>(
  () => FavoriteGroupsNotifier(),
);

/// Pinned friends notifier
class PinnedFriendsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String friendId) {
    if (state.contains(friendId)) {
      state = {...state}..remove(friendId);
    } else {
      state = {...state, friendId};
    }
  }
}

final pinnedFriendsProvider =
    NotifierProvider<PinnedFriendsNotifier, Set<String>>(
  () => PinnedFriendsNotifier(),
);

/// User preferences
class UserPreferencesNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    return {
      'show_online_status': true,
      'show_typing_indicator': true,
      'enable_read_receipts': true,
      'video_blur_background': false,
      'auto_mute_on_join': false,
      'default_video_quality': 'medium',
    };
  }

  void updatePreference(String key, dynamic value) {
    state = {...state, key: value};
  }
}

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, Map<String, dynamic>>(
  () => UserPreferencesNotifier(),
);
