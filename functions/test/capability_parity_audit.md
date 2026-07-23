# Capability to Firestore Rule Parity Audit

Date: 2026-04-30
Scope: backend parity only (`firestore.rules` + rules test suite)

## Matrix

| Capability | Client Enforced | Backend Enforced | Rule Reference | Test Covered | Notes |
|---|---|---|---|---|---|
| sendMessage | Yes | Yes | `canSendMessage()` and room/conversation message creates | Yes | Includes participant gate in room messages |
| startConversation | Yes | Yes | `canStartConversation()` with `validConversationCreate()` | Yes | Payload whitelist enforced |
| followUser | Yes | Yes | `canFollowUser()` in `/follows/{followId}` create/delete | Yes | Canonical edge ID + timestamp required |
| createRoom | Yes | Yes | `canCreateRoom()` in `/rooms/{roomId}` create | Indirect | Covered by signed-in room behavior; add explicit room-create test if desired |
| joinRoom | Yes | Yes | `canJoinRoom()` in room message create + participant self-write constraints | Yes | Participant spoof blocked |
| createPost | Yes | Yes | `canCreatePost()` in `/posts/{postId}` and `/groups/{groupId}/posts/{postId}` | Yes | Identity spoof + guest write blocked |
| createStory | Yes | Yes | `canCreateStory()` in `/users/{userId}/stories/{storyId}` | Yes | Self-only + forged userId blocked |
| editProfile | Yes | Yes | `canEditProfile(userId)` in `/users/{userId}` update | Yes | Whitelist and ownership enforced |
| inviteToRoom | Yes | Partial | `canInviteToRoom()` helper exists but is not yet bound to an invite write rule | No | Potential drift risk: helper currently unused |

## Forged-client/negative-path coverage now present

- Guest unauthenticated write attempts to protected collections are denied.
- Cross-room message injection is denied (`roomId` mismatch and non-participant writes).
- Spoofed identity payloads are denied for posts/stories/participants.
- Unauthorized follow graph mutations are denied via canonical follow edge constraints.

## Known parity gap

- `canInviteToRoom()` is defined in rules but currently not referenced by a concrete invite write path.
- Recommendation: either bind invite writes to this capability (preferred) or remove helper until invite rule path is introduced to avoid silent drift.
