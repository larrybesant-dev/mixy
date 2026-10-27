const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  blockedUserIdsFromRows,
  claimSpeedDatingMatch,
  existingSpeedDatingMatch,
} = require("../index").__testing;

function ref(path) {
  return {path, id: path.split("/").at(-1)};
}

function transactionStore(initial) {
  const documents = new Map(Object.entries(initial));
  const writes = [];
  const firestore = {
    async runTransaction(callback) {
      const tx = {
        async get(documentRef) {
          const data = documents.get(documentRef.path);
          return {
            exists: data !== undefined,
            data: () => data,
          };
        },
        set(documentRef, data) {
          writes.push({type: "set", path: documentRef.path});
          documents.set(documentRef.path, data);
        },
        update(documentRef, data) {
          writes.push({type: "update", path: documentRef.path});
          documents.set(documentRef.path, {
            ...documents.get(documentRef.path),
            ...data,
          });
        },
      };
      return callback(tx);
    },
  };
  return {firestore, documents, writes};
}

describe("speed dating queue claims", () => {
  it("recognizes an existing match without requiring a partner id", () => {
    assert.deepEqual(
      existingSpeedDatingMatch({matched: true, sessionId: "session-1"}),
      {
        matched: true,
        sessionId: "session-1",
        partnerId: undefined,
      },
    );
    assert.equal(existingSpeedDatingMatch({matched: false}), null);
  });

  it("creates one atomic session and marks both queue entries", async () => {
    const ownRef = ref("speed_dating_queue/user-1");
    const partnerRef = ref("speed_dating_queue/user-2");
    const sessionRef = ref("speed_dating_sessions/session-1");
    const store = transactionStore({
      [ownRef.path]: {uid: "user-1", matched: false},
      [partnerRef.path]: {uid: "user-2", matched: false},
    });

    const result = await claimSpeedDatingMatch({
      firestore: store.firestore,
      queueRef: ownRef,
      partnerRef,
      sessionRef,
      uid: "user-1",
      partnerId: "user-2",
      expiresAt: "later",
    });

    assert.deepEqual(result, {
      matched: true,
      sessionId: "session-1",
      partnerId: "user-2",
    });
    assert.equal(store.documents.get(ownRef.path).matched, true);
    assert.equal(store.documents.get(partnerRef.path).matched, true);
    assert.equal(store.documents.get(ownRef.path).partnerId, "user-2");
    assert.equal(store.documents.get(partnerRef.path).partnerId, "user-1");
    assert.equal(
      store.writes.filter((write) => write.path === sessionRef.path).length,
      1,
    );
  });

  it("returns the original session for a duplicate concurrent claim", async () => {
    const ownRef = ref("speed_dating_queue/user-1");
    const partnerRef = ref("speed_dating_queue/user-2");
    const firstSessionRef = ref("speed_dating_sessions/session-1");
    const duplicateSessionRef = ref("speed_dating_sessions/session-2");
    const store = transactionStore({
      [ownRef.path]: {uid: "user-1", matched: false},
      [partnerRef.path]: {uid: "user-2", matched: false},
    });

    const first = await claimSpeedDatingMatch({
      firestore: store.firestore,
      queueRef: ownRef,
      partnerRef,
      sessionRef: firstSessionRef,
      uid: "user-1",
      partnerId: "user-2",
      expiresAt: "later",
    });
    const duplicate = await claimSpeedDatingMatch({
      firestore: store.firestore,
      queueRef: ownRef,
      partnerRef,
      sessionRef: duplicateSessionRef,
      uid: "user-1",
      partnerId: "user-2",
      expiresAt: "later",
    });

    assert.deepEqual(duplicate, first);
    assert.equal(store.documents.has(duplicateSessionRef.path), false);
  });

  it("does not claim a partner that another request already matched", async () => {
    const ownRef = ref("speed_dating_queue/user-1");
    const partnerRef = ref("speed_dating_queue/user-2");
    const store = transactionStore({
      [ownRef.path]: {uid: "user-1", matched: false},
      [partnerRef.path]: {
        uid: "user-2",
        matched: true,
        sessionId: "other-session",
      },
    });

    const result = await claimSpeedDatingMatch({
      firestore: store.firestore,
      queueRef: ownRef,
      partnerRef,
      sessionRef: ref("speed_dating_sessions/session-1"),
      uid: "user-1",
      partnerId: "user-2",
      expiresAt: "later",
    });

    assert.equal(result, null);
    assert.deepEqual(store.writes, []);
  });
});

describe("speed dating block filtering", () => {
  it("excludes blocks in either direction", () => {
    const blocked = blockedUserIdsFromRows("user-1", [
      {blockerUserId: "user-1", blockedUserId: "user-2"},
      {blockerUserId: "user-3", blockedUserId: "user-1"},
      {blockerUserId: "user-4", blockedUserId: "user-5"},
    ]);

    assert.deepEqual([...blocked].sort(), ["user-2", "user-3"]);
  });
});
