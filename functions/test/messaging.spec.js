const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {createDirectConversationHandler} = require("../index").__testing;

function createFirestoreDouble() {
  const conversations = new Map();
  const users = new Map([
    ["user-a", {username: "Alpha"}],
    ["user-b", {username: "Beta"}],
  ]);
  const blocks = new Set();

  function doc(collection, id) {
    return {collection, id};
  }

  return {
    conversations,
    collection(name) {
      return {doc: (id) => doc(name, id)};
    },
    async getAll(...refs) {
      return refs.map((ref) => {
        const store = ref.collection === "users" ? users : blocks;
        const value = ref.collection === "users"
          ? store.get(ref.id)
          : store.has(ref.id);
        return {
          id: ref.id,
          exists: ref.collection === "users" ? value !== undefined : value,
          data: () => value || {},
        };
      });
    },
    async runTransaction(callback) {
      return callback({
        get: async (ref) => ({
          exists: conversations.has(ref.id),
          data: () => conversations.get(ref.id),
        }),
        create: (ref, data) => {
          if (conversations.has(ref.id)) {
            throw new Error("already exists");
          }
          conversations.set(ref.id, data);
        },
      });
    },
  };
}

describe("createDirectConversationHandler", () => {
  it("creates once and reopens the deterministic conversation", async () => {
    const firestore = createFirestoreDouble();
    const first = await createDirectConversationHandler(
      {auth: {uid: "user-a"}, data: {targetUserId: "user-b"}},
      {firestore},
    );
    const second = await createDirectConversationHandler(
      {auth: {uid: "user-b"}, data: {targetUserId: "user-a"}},
      {firestore},
    );

    assert.equal(first.conversationId, "dm_user-a_user-b");
    assert.equal(second.conversationId, first.conversationId);
    assert.equal(firestore.conversations.size, 1);
    assert.deepEqual(
      firestore.conversations.get(first.conversationId).participantNames,
      {"user-a": "Alpha", "user-b": "Beta"},
    );
  });

  it("requires authentication", async () => {
    await assert.rejects(
      createDirectConversationHandler(
        {auth: null, data: {targetUserId: "user-b"}},
        {firestore: createFirestoreDouble()},
      ),
      (error) => error.code === "unauthenticated",
    );
  });
});
