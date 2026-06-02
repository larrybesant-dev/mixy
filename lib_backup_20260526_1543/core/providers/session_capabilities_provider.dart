import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/controllers/auth_controller.dart';

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
  const SessionCapabilities({required this.isAuthenticated});

  final bool isAuthenticated;

  bool get canSendMessage => isAuthenticated;
  bool get canStartConversation => isAuthenticated;
  bool get canFollowUser => isAuthenticated;
  bool get canCreateRoom => isAuthenticated;
  bool get canJoinRoom => isAuthenticated;
  bool get canCreatePost => isAuthenticated;
  bool get canCreateStory => isAuthenticated;
  bool get canCreateGroup => isAuthenticated;
  bool get canEditProfile => isAuthenticated;
  bool get canInviteToRoom => isAuthenticated;

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
  final isAuthenticated = (authState.uid?.isNotEmpty ?? false);

  return SessionCapabilities(isAuthenticated: isAuthenticated);
});
