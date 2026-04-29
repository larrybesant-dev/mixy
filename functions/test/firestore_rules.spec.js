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

  it("allows signed-in room message writes with the current client payload", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms", "room-chat-1"), {
        hostId: "host-1",
        ownerId: "host-1",
        isLocked: false,
      });
    });

    const senderDb = testEnv.authenticatedContext("user-1").firestore();

    await assertSucceeds(setDoc(doc(senderDb, "rooms", "room-chat-1", "messages", "message-1"), {
      id: "message-1",
      senderId: "user-1",
      roomId: "room-chat-1",
      content: "hello room",
      sentAt: Timestamp.now(),
      clientSentAt: Timestamp.now(),
    }));

    await assertFails(setDoc(doc(senderDb, "rooms", "room-chat-1", "messages", "message-2"), {
      id: "message-2",
      senderId: "user-1",
      roomId: "other-room",
      content: "wrong room",
      sentAt: Timestamp.now(),
      clientSentAt: Timestamp.now(),
    }));
  });
});