const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  after,
  before,
  beforeEach,
  describe,
  it,
} = require("node:test");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "..", "..", "firestore.rules"),
  "utf8",
);

function getFirestoreHostAndPort() {
  const raw = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  const [host, portText] = raw.split(":");
  return {
    host: host || "127.0.0.1",
    port: Number(portText || 8080),
  };
}

let testEnv;

before(async () => {
  const {host, port} = getFirestoreHostAndPort();
  testEnv = await initializeTestEnvironment({
    projectId: "mixvy-rules-test",
    firestore: {
      host,
      port,
      rules,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, "posts", "post-1"), {
      authorId: "author-1",
      commentCount: 0,
      createdAt: Timestamp.now(),
    });

    await setDoc(doc(db, "presence", "user-1"), {
      isOnline: true,
      status: "online",
      lastSeen: Timestamp.now(),
    });

    await setDoc(doc(db, "speed_dating_queue", "user-1"), {
      uid: "user-1",
      matched: false,
      joinedAt: Timestamp.now(),
    });

    await setDoc(doc(db, "speed_dating_sessions", "session-1"), {
      participantIds: ["user-1", "user-2"],
      active: true,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.now(),
    });

    await setDoc(doc(db, "posts", "post-1", "comments", "comment-1"), {
      authorId: "author-1",
      authorName: "Author",
      text: "seed comment",
      createdAt: Timestamp.now(),
    });

    await setDoc(doc(db, "users", "user-1"), {
      uid: "user-1",
      username: "user-1",
      email: "user-1@example.com",
      bio: "hello",
      isPrivate: false,
      updatedAt: Timestamp.now(),
    });
  });
});

describe("firestore rules", () => {
  it("allows signed-in users to read top-level presence and only self to write", async () => {
    const viewerDb = testEnv.authenticatedContext("viewer-1").firestore();
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(getDoc(doc(viewerDb, "presence", "user-1")));
    await assertSucceeds(setDoc(doc(selfDb, "presence", "user-1"), {
      isOnline: false,
      status: "offline",
      lastSeen: Timestamp.now(),
      inRoom: null,
    }));
    await assertFails(setDoc(doc(otherDb, "presence", "user-1"), {
      isOnline: false,
      status: "offline",
      lastSeen: Timestamp.now(),
    }));
  });

  it("allows only self to read queue entries and blocks direct client queue writes", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(getDoc(doc(selfDb, "speed_dating_queue", "user-1")));
    await assertFails(getDoc(doc(otherDb, "speed_dating_queue", "user-1")));
    await assertFails(setDoc(doc(selfDb, "speed_dating_queue", "user-1"), {
      uid: "user-1",
      matched: false,
      joinedAt: Timestamp.now(),
    }));
  });

  it("allows session reads only to participants", async () => {
    const participantDb = testEnv.authenticatedContext("user-1").firestore();
    const outsiderDb = testEnv.authenticatedContext("user-3").firestore();

    await assertSucceeds(getDoc(doc(participantDb, "speed_dating_sessions", "session-1")));
    await assertFails(getDoc(doc(outsiderDb, "speed_dating_sessions", "session-1")));
  });

  it("allows signed-in users to create comments but blocks non-authors from mutating post counters", async () => {
    const commenterDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(collection(commenterDb, "posts", "post-1", "comments")), {
      authorId: "user-2",
      authorName: "Commenter",
      text: "First!",
      createdAt: Timestamp.now(),
    }));

    await assertFails(updateDoc(doc(commenterDb, "posts", "post-1"), {
      commentCount: 1,
    }));
  });

  it("allows authors to delete their own comments and blocks others", async () => {
    const authorDb = testEnv.authenticatedContext("author-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertFails(deleteDoc(doc(otherDb, "posts", "post-1", "comments", "comment-1")));
    await assertSucceeds(deleteDoc(doc(authorDb, "posts", "post-1", "comments", "comment-1")));
  });

  it("blocks anonymous users from protected reads", async () => {
    const anonDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(anonDb, "presence", "user-1")));
    await assertFails(getDoc(doc(anonDb, "speed_dating_sessions", "session-1")));
  });

  it("blocks direct client writes to transactions even when senderId matches auth", async () => {
    const senderDb = testEnv.authenticatedContext("user-1").firestore();

    await assertFails(setDoc(doc(senderDb, "transactions", "tx-user-1"), {
      senderId: "user-1",
      receiverId: "user-2",
      participants: ["user-1", "user-2"],
      amount: 5,
      status: "sent",
      timestamp: Timestamp.now(),
    }));
  });

  it("blocks direct client writes to room speakers while still allowing participant reads", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-1"), {
        hostId: "host-1",
        ownerId: "host-1",
        isLocked: false,
      });
      await setDoc(doc(db, "rooms", "room-1", "participants", "user-1"), {
        userId: "user-1",
        role: "member",
      });
      await setDoc(doc(db, "rooms", "room-1", "speakers", "host-1"), {
        userId: "host-1",
        role: "speaker",
      });
    });

    const participantDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(getDoc(doc(participantDb, "rooms", "room-1", "speakers", "host-1")));
    await assertFails(setDoc(doc(participantDb, "rooms", "room-1", "speakers", "user-1"), {
      userId: "user-1",
      role: "speaker",
      joinedAt: Timestamp.now(),
    }));
  });

  it("allows authenticated follow edge writes only on the caller-owned follower/following docs", async () => {
    const followerDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-3").firestore();

    await assertSucceeds(setDoc(doc(followerDb, "users", "user-1", "following", "user-2"), {
      followedAt: Timestamp.now(),
    }));
    await assertSucceeds(setDoc(doc(followerDb, "users", "user-2", "followers", "user-1"), {
      followedAt: Timestamp.now(),
    }));

    await assertFails(setDoc(doc(otherDb, "users", "user-1", "following", "user-2"), {
      followedAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(otherDb, "users", "user-2", "followers", "user-1"), {
      followedAt: Timestamp.now(),
    }));
  });

  it("allows room message writes only for participants and blocks non-participants", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-chat-1"), {
        hostId: "host-1",
        ownerId: "host-1",
        isLocked: false,
      });
      await setDoc(doc(db, "rooms", "room-chat-1", "participants", "user-1"), {
        userId: "user-1",
        role: "member",
      });
    });

    const senderDb = testEnv.authenticatedContext("user-1").firestore();
    const outsiderDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(senderDb, "rooms", "room-chat-1", "messages", "message-1"), {
      id: "message-1",
      senderId: "user-1",
      roomId: "room-chat-1",
      content: "hello room",
      sentAt: serverTimestamp(),
      clientSentAt: Timestamp.now(),
    }));

    await assertFails(setDoc(doc(outsiderDb, "rooms", "room-chat-1", "messages", "message-unauthorized"), {
      id: "message-unauthorized",
      senderId: "user-2",
      roomId: "room-chat-1",
      content: "not in participants",
      sentAt: serverTimestamp(),
      clientSentAt: Timestamp.now(),
    }));

    await assertFails(setDoc(doc(senderDb, "rooms", "room-chat-1", "messages", "message-2"), {
      id: "message-2",
      senderId: "user-1",
      roomId: "other-room",
      content: "wrong room",
      sentAt: serverTimestamp(),
      clientSentAt: Timestamp.now(),
    }));
  });

  it("enforces canonical follows edge writes", async () => {
    const followerDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(setDoc(doc(followerDb, "follows", "user-1_user-2"), {
      followerUserId: "user-1",
      followedUserId: "user-2",
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(followerDb, "follows", "wrong-id"), {
      followerUserId: "user-1",
      followedUserId: "user-2",
      createdAt: serverTimestamp(),
    }));
  });

  it("allows only self profile identity updates and blocks non-whitelisted fields", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(updateDoc(doc(selfDb, "users", "user-1"), {
      bio: "updated bio",
      updatedAt: Timestamp.now(),
    }));

    await assertFails(updateDoc(doc(otherDb, "users", "user-1"), {
      bio: "malicious write",
      updatedAt: Timestamp.now(),
    }));

    await assertFails(updateDoc(doc(selfDb, "users", "user-1"), {
      membershipLevel: "vip",
    }));
  });

  it("enforces constrained conversation creation payload", async () => {
    const userDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(setDoc(doc(userDb, "conversations", "conv-1"), {
      type: "direct",
      participantIds: ["user-1", "user-2"],
      participantNames: {
        "user-1": "User 1",
        "user-2": "User 2",
      },
      createdAt: serverTimestamp(),
      lastReadAt: {
        "user-1": serverTimestamp(),
        "user-2": serverTimestamp(),
      },
      isArchived: false,
      status: "active",
    }));

    await assertFails(setDoc(doc(userDb, "conversations", "conv-invalid"), {
      type: "direct",
      participantIds: ["user-1", "user-2"],
      participantNames: {
        "user-1": "User 1",
        "user-2": "User 2",
      },
      createdAt: serverTimestamp(),
      lastReadAt: {
        "user-1": serverTimestamp(),
        "user-2": serverTimestamp(),
      },
      isArchived: false,
      status: "active",
      injected: true,
    }));
  });

  it("enforces post creation identity and blocks guest writes", async () => {
    const authorDb = testEnv.authenticatedContext("user-1").firestore();
    const guestDb = testEnv.unauthenticatedContext().firestore();

    await assertSucceeds(setDoc(doc(authorDb, "posts", "post-cap-1"), {
      authorId: "user-1",
      text: "hello",
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(authorDb, "posts", "post-cap-spoof"), {
      authorId: "user-2",
      text: "spoof",
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(guestDb, "posts", "post-cap-guest"), {
      authorId: "guest",
      text: "guest",
      createdAt: serverTimestamp(),
    }));
  });

  it("enforces story creation identity and blocks forged userId", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "users", "user-1", "stories", "story-1"), {
      userId: "user-1",
      text: "story",
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(selfDb, "users", "user-1", "stories", "story-spoof"), {
      userId: "user-2",
      text: "spoofed",
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(otherDb, "users", "user-1", "stories", "story-cross-user"), {
      userId: "user-1",
      text: "cross write",
      createdAt: serverTimestamp(),
    }));
  });

  it("enforces inviteToRoom capability on room_invite notifications", async () => {
    const inviterDb = testEnv.authenticatedContext("user-1").firestore();
    const guestDb = testEnv.unauthenticatedContext().firestore();

    // Valid: authenticated user inviting a friend (actorId == uid).
    await assertSucceeds(setDoc(doc(inviterDb, "notifications", "notif-invite-ok"), {
      userId: "user-2",
      actorId: "user-1",
      type: "room_invite",
      content: "user-1 invited you to join a room",
      roomId: "room-1",
      isRead: false,
      createdAt: serverTimestamp(),
    }));

    // Blocked: guest (unauthenticated) cannot send a room invite.
    await assertFails(setDoc(doc(guestDb, "notifications", "notif-invite-guest"), {
      userId: "user-2",
      actorId: "guest",
      type: "room_invite",
      content: "guest trying to invite",
      roomId: "room-1",
      isRead: false,
      createdAt: serverTimestamp(),
    }));

    // Blocked: spoofed actorId — inviter claims to be a different user.
    await assertFails(setDoc(doc(inviterDb, "notifications", "notif-invite-spoof"), {
      userId: "user-3",
      actorId: "user-99",
      type: "room_invite",
      content: "spoofed invite",
      roomId: "room-1",
      isRead: false,
      createdAt: serverTimestamp(),
    }));

    // Allowed: non-room_invite notifications are unaffected by the capability check.
    await assertSucceeds(setDoc(doc(inviterDb, "notifications", "notif-follow-ok"), {
      userId: "user-2",
      actorId: "user-1",
      type: "follow",
      content: "user-1 followed you",
      isRead: false,
      createdAt: serverTimestamp(),
    }));
  });

  it("blocks participant spoof writes for other user IDs", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-participant-1"), {
        hostId: "host-1",
        ownerId: "host-1",
        isLocked: false,
      });
    });

    const userDb = testEnv.authenticatedContext("user-1").firestore();

    await assertFails(setDoc(doc(userDb, "rooms", "room-participant-1", "participants", "user-2"), {
      userId: "user-2",
      role: "audience",
      isBanned: false,
      isMuted: false,
    }));

    await assertFails(setDoc(doc(userDb, "rooms", "room-participant-1", "participants", "user-1"), {
      userId: "user-2",
      role: "audience",
      isBanned: false,
      isMuted: false,
    }));
  });

  it("enforces verification_requests contract for create and rejected-only delete", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "verification_requests", "user-1"), {
      userId: "user-1",
      reason: "I meet verification requirements",
      status: "pending",
      submittedAt: serverTimestamp(),
      reviewedAt: null,
      reviewNote: null,
    }));

    await assertFails(setDoc(doc(otherDb, "verification_requests", "user-1"), {
      userId: "user-1",
      reason: "spoof",
      status: "pending",
      submittedAt: serverTimestamp(),
      reviewedAt: null,
      reviewNote: null,
    }));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "verification_requests", "user-1"), {
        userId: "user-1",
        reason: "rejected sample",
        status: "rejected",
        submittedAt: Timestamp.now(),
        reviewedAt: Timestamp.now(),
        reviewNote: "needs updates",
      });
    });

    await assertSucceeds(deleteDoc(doc(selfDb, "verification_requests", "user-1")));
  });

  it("enforces room typing self-write only", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-typing-1"), {
        hostId: "host-1",
        isAdult: false,
      });
      await setDoc(doc(db, "rooms", "room-typing-1", "participants", "user-1"), {
        userId: "user-1",
        role: "audience",
      });
    });

    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "rooms", "room-typing-1", "typing", "user-1"), {
      isTyping: true,
      updatedAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(otherDb, "rooms", "room-typing-1", "typing", "user-1"), {
      isTyping: true,
      updatedAt: serverTimestamp(),
    }));
  });

  it("enforces nested WebRTC ICE writes under webrtc_calls", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-webrtc-1"), {
        hostId: "host-1",
        isAdult: false,
      });
      await setDoc(doc(db, "rooms", "room-webrtc-1", "participants", "viewer-1"), {
        userId: "viewer-1",
        role: "audience",
      });
      await setDoc(doc(db, "rooms", "room-webrtc-1", "participants", "broadcaster-1"), {
        userId: "broadcaster-1",
        role: "host",
      });
      await setDoc(doc(db, "rooms", "room-webrtc-1", "webrtc_calls", "call-1"), {
        viewerId: "viewer-1",
        broadcasterId: "broadcaster-1",
        viewerUid: 101,
        broadcasterUid: 202,
        offer: {type: "offer", sdp: "seed"},
        createdAt: Timestamp.now(),
      });
    });

    const viewerDb = testEnv.authenticatedContext("viewer-1").firestore();
    const broadcasterDb = testEnv.authenticatedContext("broadcaster-1").firestore();
    const outsiderDb = testEnv.authenticatedContext("outsider-1").firestore();

    await assertSucceeds(setDoc(doc(
        viewerDb,
        "rooms",
        "room-webrtc-1",
        "webrtc_calls",
        "call-1",
        "viewer_ice",
        "ice-1",
    ), {
      candidate: "cand-a",
      sdpMid: "0",
      sdpMLineIndex: 0,
      createdAt: serverTimestamp(),
    }));

    await assertSucceeds(setDoc(doc(
        broadcasterDb,
        "rooms",
        "room-webrtc-1",
        "webrtc_calls",
        "call-1",
        "broadcaster_ice",
        "ice-2",
    ), {
      candidate: "cand-b",
      sdpMid: "0",
      sdpMLineIndex: 0,
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(
        outsiderDb,
        "rooms",
        "room-webrtc-1",
        "webrtc_calls",
        "call-1",
        "viewer_ice",
        "ice-3",
    ), {
      candidate: "cand-c",
      sdpMid: "0",
      sdpMLineIndex: 0,
      createdAt: serverTimestamp(),
    }));
  });

  it("enforces notifications actor trust and target-recipient model", async () => {
    const actorDb = testEnv.authenticatedContext("user-1").firestore();
    const spoofDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(actorDb, "notifications", "notif-p0-1"), {
      userId: "user-3",
      actorId: "user-1",
      type: "follow",
      content: "hello",
      isRead: false,
      createdAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(spoofDb, "notifications", "notif-p0-spoof"), {
      userId: "user-3",
      actorId: "user-1",
      type: "follow",
      content: "spoof",
      isRead: false,
      createdAt: serverTimestamp(),
    }));
  });

  it("enforces friend_links and friendships users[] actor ownership", async () => {
    const userDb = testEnv.authenticatedContext("user-1").firestore();
    const outsiderDb = testEnv.authenticatedContext("user-3").firestore();

    await assertSucceeds(setDoc(doc(userDb, "friend_links", "u1_u2"), {
      users: ["user-1", "user-2"],
      status: "pending",
      requestedBy: "user-1",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));

    await assertSucceeds(setDoc(doc(userDb, "friendships", "u1_u2"), {
      users: ["user-1", "user-2"],
      status: "pending",
      requestedBy: "user-1",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(outsiderDb, "friend_links", "u1_u2_bad"), {
      users: ["user-1", "user-2"],
      status: "pending",
      requestedBy: "user-1",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(outsiderDb, "friendships", "u1_u2_bad"), {
      users: ["user-1", "user-2"],
      status: "pending",
      requestedBy: "user-1",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
  });

  it("enforces profile_public and preferences self ownership", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "profile_public", "user-1"), {
      userId: "user-1",
      displayName: "User 1",
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(setDoc(doc(selfDb, "preferences", "user-1"), {
      userId: "user-1",
      language: "en",
      updatedAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(otherDb, "profile_public", "user-1"), {
      userId: "user-1",
      displayName: "spoof",
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(otherDb, "preferences", "user-1"), {
      userId: "user-1",
      language: "xx",
      updatedAt: serverTimestamp(),
    }));
  });

  it("allows room host to create mod_log entries and denies non-host", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-mod-1"), {
        hostId: "host-1",
        isAdult: false,
      });
    });

    const hostDb = testEnv.authenticatedContext("host-1").firestore();
    const userDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(setDoc(doc(hostDb, "rooms", "room-mod-1", "mod_log", "entry-1"), {
      action: "mute",
      actorId: "host-1",
      ts: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(userDb, "rooms", "room-mod-1", "mod_log", "entry-2"), {
      action: "mute",
      actorId: "user-1",
      ts: serverTimestamp(),
    }));
  });

  it("enforces webrtc_peers self lifecycle and denies cross-user writes", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-peers-1"), {
        hostId: "host-1",
        isAdult: false,
      });
      await setDoc(doc(db, "rooms", "room-peers-1", "participants", "user-1"), {
        userId: "user-1",
        role: "audience",
      });
      await setDoc(doc(db, "rooms", "room-peers-1", "participants", "user-2"), {
        userId: "user-2",
        role: "audience",
      });
    });

    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "rooms", "room-peers-1", "webrtc_peers", "user-1"), {
      uid: 101,
      isBroadcasting: false,
      cameraActive: false,
      joinedAt: serverTimestamp(),
      lastHeartbeatAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(otherDb, "rooms", "room-peers-1", "webrtc_peers", "user-1"), {
      uid: 202,
      isBroadcasting: false,
      cameraActive: false,
      joinedAt: serverTimestamp(),
      lastHeartbeatAt: serverTimestamp(),
    }));

    await assertSucceeds(deleteDoc(doc(selfDb, "rooms", "room-peers-1", "webrtc_peers", "user-1")));
  });

  it("enforces room delete host-or-admin only", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-delete-1"), {
        hostId: "host-1",
        isAdult: false,
      });
    });

    const hostDb = testEnv.authenticatedContext("host-1").firestore();
    const userDb = testEnv.authenticatedContext("user-1").firestore();
    const adminDb = testEnv.authenticatedContext("admin-1", {admin: true}).firestore();

    await assertFails(deleteDoc(doc(userDb, "rooms", "room-delete-1")));
    await assertSucceeds(deleteDoc(doc(hostDb, "rooms", "room-delete-1")));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-delete-2"), {
        hostId: "host-2",
        isAdult: false,
      });
    });

    await assertSucceeds(deleteDoc(doc(adminDb, "rooms", "room-delete-2")));
  });

  it("enforces cam_view_requests requester create and target resolve", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-cvr-1"), {hostId: "host-1", isAdult: false});
      await setDoc(doc(db, "rooms", "room-cvr-1", "participants", "user-1"), {userId: "user-1", role: "audience"});
      await setDoc(doc(db, "rooms", "room-cvr-1", "participants", "user-2"), {userId: "user-2", role: "audience"});
    });

    const requesterDb = testEnv.authenticatedContext("user-1").firestore();
    const targetDb = testEnv.authenticatedContext("user-2").firestore();
    const otherDb = testEnv.authenticatedContext("user-3").firestore();

    // Requester creates
    const reqRef = doc(requesterDb, "rooms", "room-cvr-1", "cam_view_requests", "req-1");
    await assertSucceeds(setDoc(reqRef, {
      id: "req-1", roomId: "room-cvr-1", requesterId: "user-1", targetId: "user-2",
      requesterName: "User1", requestKey: "user-1:user-2", status: "pending",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));

    // Non-requester cannot create spoofing another's requesterId
    await assertFails(setDoc(doc(otherDb, "rooms", "room-cvr-1", "cam_view_requests", "req-bad"), {
      id: "req-bad", roomId: "room-cvr-1", requesterId: "user-1", targetId: "user-2",
      requesterName: "User3", requestKey: "user-1:user-2", status: "pending",
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));

    // Target resolves
    await assertSucceeds(updateDoc(doc(targetDb, "rooms", "room-cvr-1", "cam_view_requests", "req-1"), {
      status: "approved", resolvedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));

    // Requester cannot resolve (wrong affectedKeys)
    await assertFails(updateDoc(doc(requesterDb, "rooms", "room-cvr-1", "cam_view_requests", "req-1"), {
      status: "denied", resolvedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });

  it("enforces mic_access_requests self create and host update", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-mic-1"), {hostId: "host-1", isAdult: false});
      await setDoc(doc(db, "rooms", "room-mic-1", "participants", "user-1"), {userId: "user-1", role: "audience"});
    });

    const userDb = testEnv.authenticatedContext("user-1").firestore();
    const hostDb = testEnv.authenticatedContext("host-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    // Self can create request
    await assertSucceeds(setDoc(doc(userDb, "rooms", "room-mic-1", "mic_access_requests", "mic-req-1"), {
      id: "mic-req-1", roomId: "room-mic-1", requesterId: "user-1", hostId: "host-1",
      status: "pending", priority: 1,
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 60000)),
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));

    // Cannot spoof another user's requesterId
    await assertFails(setDoc(doc(otherDb, "rooms", "room-mic-1", "mic_access_requests", "mic-req-bad"), {
      id: "mic-req-bad", roomId: "room-mic-1", requesterId: "user-1", hostId: "host-1",
      status: "pending", priority: 2,
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 60000)),
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));

    // Host can update status
    await assertSucceeds(updateDoc(doc(hostDb, "rooms", "room-mic-1", "mic_access_requests", "mic-req-1"), {
      status: "approved", updatedAt: serverTimestamp(),
    }));
  });

  it("enforces room policies host-only write", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-pol-1"), {hostId: "host-1", isAdult: false});
    });

    const hostDb = testEnv.authenticatedContext("host-1").firestore();
    const userDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(setDoc(doc(hostDb, "rooms", "room-pol-1", "policies", "settings"), {
      allowChat: true, allowGifts: true, updatedAt: serverTimestamp(),
    }, {merge: true}));

    await assertFails(setDoc(doc(userDb, "rooms", "room-pol-1", "policies", "settings"), {
      allowChat: false,
    }, {merge: true}));
  });

  it("enforces room slots self-claim and delete", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-slots-1"), {hostId: "host-1", isAdult: false});
      await setDoc(doc(db, "rooms", "room-slots-1", "participants", "user-1"), {userId: "user-1", role: "audience"});
    });

    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    // Self can claim slot (set with own userId)
    const slotRef = doc(selfDb, "rooms", "room-slots-1", "slots", "1");
    await assertSucceeds(setDoc(slotRef, {userId: "user-1"}));

    // Another user cannot set userId of someone else
    await assertFails(setDoc(doc(otherDb, "rooms", "room-slots-1", "slots", "2"), {userId: "user-1"}));

    // Self can delete own slot
    await assertSucceeds(deleteDoc(slotRef));
  });

  it("enforces buzz_events participant self-send", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-buzz-1"), {hostId: "host-1", isAdult: false});
      await setDoc(doc(db, "rooms", "room-buzz-1", "participants", "user-1"), {userId: "user-1", role: "audience"});
    });

    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "rooms", "room-buzz-1", "buzz_events", "buzz-1"), {
      fromUserId: "user-1", toUserId: "host-1", sentAt: serverTimestamp(),
    }));

    // Cannot send on behalf of another user
    await assertFails(setDoc(doc(otherDb, "rooms", "room-buzz-1", "buzz_events", "buzz-2"), {
      fromUserId: "user-1", toUserId: "host-1", sentAt: serverTimestamp(),
    }));
  });

  it("enforces room message reactions participant self-write", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-react-1"), {hostId: "host-1", isAdult: false});
      await setDoc(doc(db, "rooms", "room-react-1", "participants", "user-1"), {userId: "user-1", role: "audience"});
      await setDoc(doc(db, "rooms", "room-react-1", "messages", "msg-1"), {
        senderId: "host-1", roomId: "room-react-1", content: "hello",
      });
    });

    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    // Participant can add own reaction (reactionId == uid)
    const reactionRef = doc(selfDb, "rooms", "room-react-1", "messages", "msg-1", "reactions", "user-1");
    await assertSucceeds(setDoc(reactionRef, {
      userId: "user-1", emoji: "👏", timestamp: serverTimestamp(),
    }));

    // Non-participant or spoofed reactionId is rejected
    await assertFails(setDoc(doc(otherDb, "rooms", "room-react-1", "messages", "msg-1", "reactions", "user-1"), {
      userId: "user-2", emoji: "👎", timestamp: serverTimestamp(),
    }));

    // Self can delete own reaction
    await assertSucceeds(deleteDoc(reactionRef));
  });

  it("enforces user bookmarks self-only create and delete", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "users", "user-1", "bookmarks", "bm-1"), {
      postId: "post-abc", savedAt: serverTimestamp(),
    }));

    await assertFails(setDoc(doc(otherDb, "users", "user-1", "bookmarks", "bm-bad"), {
      postId: "post-xyz", savedAt: serverTimestamp(),
    }));

    await assertSucceeds(deleteDoc(doc(selfDb, "users", "user-1", "bookmarks", "bm-1")));
  });

  it("enforces user privacy self-only write", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "users", "user-1", "privacy", "settings"), {
      isPrivate: false, updatedAt: serverTimestamp(),
    }, {merge: true}));

    await assertFails(setDoc(doc(otherDb, "users", "user-1", "privacy", "settings"), {
      isPrivate: true,
    }, {merge: true}));
  });

  it("enforces activity_feed self-userId create", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "activity_feed", "af-1"), {
      userId: "user-1", type: "joined_room", targetId: "room-1",
      timestamp: serverTimestamp(), metadata: {},
    }));

    // Cannot create activity with someone else's userId
    await assertFails(setDoc(doc(otherDb, "activity_feed", "af-bad"), {
      userId: "user-1", type: "joined_room", targetId: "room-1",
      timestamp: serverTimestamp(), metadata: {},
    }));
  });

  it("enforces groups creator-only create and member join/leave", async () => {
    const creatorDb = testEnv.authenticatedContext("creator-1").firestore();
    const memberDb = testEnv.authenticatedContext("member-1").firestore();

    // Creator creates group with self in members
    await assertSucceeds(setDoc(doc(creatorDb, "groups", "grp-1"), {
      name: "Test Group", description: "desc",
      creatorId: "creator-1", adminId: "creator-1",
      memberIds: ["creator-1"], memberCount: 1,
      createdAt: serverTimestamp(),
    }));

    // Cannot spoof creatorId
    await assertFails(setDoc(doc(memberDb, "groups", "grp-bad"), {
      name: "Hacked", description: "hack",
      creatorId: "creator-1", adminId: "member-1",
      memberIds: ["member-1"], memberCount: 1,
      createdAt: serverTimestamp(),
    }));

    // Member can join (only memberIds/memberCount change)
    await assertSucceeds(updateDoc(doc(memberDb, "groups", "grp-1"), {
      memberIds: ["creator-1", "member-1"], memberCount: 2,
    }));
  });

  it("enforces group posts author identity", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "groups", "grp-post-1"), {
        creatorId: "creator-1", adminId: "creator-1",
        memberIds: ["creator-1", "author-1"], memberCount: 2,
      });
    });

    const authorDb = testEnv.authenticatedContext("author-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-99").firestore();

    await assertSucceeds(setDoc(doc(authorDb, "groups", "grp-post-1", "posts", "post-1"), {
      groupId: "grp-post-1", authorId: "author-1", authorName: "Author",
      authorAvatarUrl: null, content: "hello group",
      tags: [], createdAt: serverTimestamp(), likeCount: 0, likedBy: [],
    }));

    // Cannot forge authorId
    await assertFails(setDoc(doc(otherDb, "groups", "grp-post-1", "posts", "post-bad"), {
      groupId: "grp-post-1", authorId: "author-1", authorName: "Hacker",
      authorAvatarUrl: null, content: "injected",
      tags: [], createdAt: serverTimestamp(), likeCount: 0, likedBy: [],
    }));
  });

  it("enforces userCamPermissions self-only write", async () => {
    const selfDb = testEnv.authenticatedContext("user-1").firestore();
    const otherDb = testEnv.authenticatedContext("user-2").firestore();

    await assertSucceeds(setDoc(doc(selfDb, "userCamPermissions", "user-1"), {
      allowedViewers: ["user-2"], updatedAt: serverTimestamp(),
    }, {merge: true}));

    // Cannot write to another user's cam permissions
    await assertFails(setDoc(doc(otherDb, "userCamPermissions", "user-1"), {
      allowedViewers: [], updatedAt: serverTimestamp(),
    }, {merge: true}));
  });

  it("enforces posts like update allows only likes and likeCount fields", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "posts", "post-like-1"), {
        authorId: "author-1", content: "test post", likes: [], likeCount: 0,
      });
    });

    const userDb = testEnv.authenticatedContext("user-1").firestore();

    // Signed-in user can update only likes/likeCount
    await assertSucceeds(updateDoc(doc(userDb, "posts", "post-like-1"), {
      likes: ["user-1"], likeCount: 1,
    }));

    // Cannot update other fields (e.g. content)
    await assertFails(updateDoc(doc(userDb, "posts", "post-like-1"), {
      content: "hacked content",
    }));
  });

  it("enforces friendships update requires existing actor ownership", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // friendship between user-A and user-B — user-3 is a stranger
      await setDoc(doc(db, "friendships", "fs-stranger-1"), {
        userA: "user-A", userB: "user-B", users: ["user-A", "user-B"],
      });
    });

    const strangerDb = testEnv.authenticatedContext("user-3").firestore();
    const participantDb = testEnv.authenticatedContext("user-A").firestore();

    // Stranger cannot update even if they set userA in payload
    await assertFails(updateDoc(doc(strangerDb, "friendships", "fs-stranger-1"), {
      userA: "user-3", userB: "user-B",
    }));

    // Participant (existing userA) can update
    await assertSucceeds(updateDoc(doc(participantDb, "friendships", "fs-stranger-1"), {
      userA: "user-A", userB: "user-B", status: "active",
    }));
  });

  it("enforces friend_links update requires existing actor ownership", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "friend_links", "fl-stranger-1"), {
        users: ["user-A", "user-B"], status: "pending",
      });
    });

    const strangerDb = testEnv.authenticatedContext("user-3").firestore();
    const participantDb = testEnv.authenticatedContext("user-A").firestore();

    // Stranger cannot update
    await assertFails(updateDoc(doc(strangerDb, "friend_links", "fl-stranger-1"), {
      users: ["user-3", "user-B"], status: "accepted",
    }));

    // Participant can update
    await assertSucceeds(updateDoc(doc(participantDb, "friend_links", "fl-stranger-1"), {
      users: ["user-A", "user-B"], status: "accepted",
    }));
  });
});
