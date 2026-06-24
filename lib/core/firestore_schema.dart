/// Firestore Collection Schema Documentation
///
/// This document defines the schema expectations for the Mixmingle app.
/// All writes are validated by firestore.rules and must conform to these schemas.

/// USERS COLLECTION
/// Path: /users/{userId}
/// Purpose: User profiles and account data
/// Ownership: User owns their own doc
///
/// Required fields:
/// - displayName: string (required, min 1 char)
/// - email: string (from auth)
/// - createdAt: Timestamp (serverTimestamp on create)
///
/// Optional fields:
/// - photoUrl: string (profile picture URL)
/// - bio: string (user bio, max 500 chars)
/// - birthDate: string (YYYY-MM-DD format)
/// - lastSeen: Timestamp (last activity)
///
/// Subcollections:
/// - fcmTokens/{tokenId} - FCM push notification tokens
/// - followers/{userId} - List of followers
/// - following/{userId} - List of users this user follows
/// - blocked/{userId} - List of blocked users
/// - event_rsvps/{eventId} - RSVPs to events

/// ROOMS COLLECTION
/// Path: /rooms/{roomId}
/// Purpose: Group chat/video rooms
/// Ownership: Creator can modify; all authenticated can read
///
/// Required fields:
/// - name: string (required, 1-200 chars)
/// - type: string enum ('public', 'private', 'direct')
/// - createdBy: string (user ID of creator)
/// - createdAt: Timestamp (serverTimestamp)
/// - settings: object (room settings)
///
/// Optional fields:
/// - description: string
/// - avatar: string (room image URL)
/// - isActive: boolean
/// - lastMessageAt: Timestamp
///
/// Subcollections:
/// - members/{userId} - Presence list (who's currently in room)
/// - messages/{messageId} - Chat messages
/// - participants/{userId} - Room participants (legacy)
/// - events/{eventId} - Join/leave logs

/// ROOMS -> MEMBERS SUBCOLLECTION
/// Path: /rooms/{roomId}/members/{userId}
/// Purpose: Track who's currently in the room (presence)
/// Ownership: User can only write their own presence
///
/// Required fields:
/// - userId: string (who is in the room)
/// - online: boolean (are they actively connected)
/// - joinedAt: Timestamp (when they joined)
/// - platform: string enum ('web', 'android', 'ios')
///
/// Optional fields:
/// - typing: boolean (are they typing)
/// - lastSeen: Timestamp (last activity time)
/// - role: string enum ('member', 'moderator', 'host')

/// ROOMS -> MESSAGES SUBCOLLECTION
/// Path: /rooms/{roomId}/messages/{messageId}
/// Purpose: Chat messages in a room
/// Ownership: Sender can modify their messages
///
/// Required fields:
/// - text: string (message content, 1-5000 chars)
/// - senderId: string (user ID of sender)
/// - senderName: string (display name of sender)
/// - createdAt: Timestamp (serverTimestamp on create)
/// - type: string enum ('text', 'system', 'image', 'join', 'leave')
/// - deleted: boolean (soft delete flag)
///
/// Optional fields:
/// - replyTo: string (messageId of message being replied to)
/// - attachments: array<object> (image/file attachments)

/// EVENTS COLLECTION
/// Path: /events/{eventId}
/// Purpose: Events/live streams
/// Ownership: Host can modify; all authenticated can read
///
/// Required fields:
/// - title: string (3-100 chars)
/// - description: string (max 2000 chars)
/// - hostId: string (user ID of event host)
/// - createdAt: Timestamp
/// - startTime: Timestamp (when event starts)
///
/// Optional fields:
/// - endTime: Timestamp
/// - avatar: string (event image)
/// - category: string
///
/// Subcollections:
/// - attendees/{userId} - Who's attending

/// NOTIFICATIONS COLLECTION
/// Path: /notifications/{notificationId}
/// Purpose: Push notification records
/// Ownership: User can only read their own
///
/// Required fields:
/// - userId: string (recipient)
/// - title: string
/// - body: string
/// - createdAt: Timestamp
/// - notificationId: string (unique ID)
///
/// Optional fields:
/// - type: string ('message', 'follow', 'event', etc)
/// - relatedId: string (room/user/event being referenced)
/// - read: boolean

library;
