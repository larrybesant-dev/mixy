import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/controllers/auth_controller.dart';
import 'guest_mode_provider.dart';

enum SessionCapability {
  sendMessage,
  startConversation,
  followUser,
  createRoom,
  joinRoom,
  createPost,
  createStory,
  createGroup,
  editProfile,
  inviteToRoom,
}

class SessionCapabilities {
  const SessionCapabilities({
    required this.isGuestMode,
    required this.isAuthenticated,
  });

  final bool isGuestMode;
  final bool isAuthenticated;

  bool get canSendMessage => isAuthenticated && !isGuestMode;
  bool get canStartConversation => isAuthenticated && !isGuestMode;
  bool get canFollowUser => isAuthenticated && !isGuestMode;
  bool get canCreateRoom => isAuthenticated && !isGuestMode;
  bool get canJoinRoom => isAuthenticated && !isGuestMode;
  bool get canCreatePost => isAuthenticated && !isGuestMode;
  bool get canCreateStory => isAuthenticated && !isGuestMode;
  bool get canCreateGroup => isAuthenticated && !isGuestMode;
  bool get canEditProfile => isAuthenticated && !isGuestMode;
  bool get canInviteToRoom => isAuthenticated && !isGuestMode;

  bool has(SessionCapability capability) {
    switch (capability) {
      case SessionCapability.sendMessage:
        return canSendMessage;
      case SessionCapability.startConversation:
        return canStartConversation;
      case SessionCapability.followUser:
        return canFollowUser;
      case SessionCapability.createRoom:
        return canCreateRoom;
      case SessionCapability.joinRoom:
        return canJoinRoom;
      case SessionCapability.createPost:
        return canCreatePost;
      case SessionCapability.createStory:
        return canCreateStory;
      case SessionCapability.createGroup:
        return canCreateGroup;
      case SessionCapability.editProfile:
        return canEditProfile;
      case SessionCapability.inviteToRoom:
        return canInviteToRoom;
    }
  }
}

final sessionCapabilitiesProvider = Provider<SessionCapabilities>((ref) {
  final authState = ref.watch(authControllerProvider);
  final isGuestMode = ref.watch(guestModeProvider);
  final isAuthenticated = (authState.uid?.isNotEmpty ?? false);

  return SessionCapabilities(
    isGuestMode: isGuestMode,
    isAuthenticated: isAuthenticated,
  );
});
