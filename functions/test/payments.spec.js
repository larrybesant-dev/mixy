const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const paymentFunctions = require("../index");

const {
  createPaymentIntentHandler,
  recordStripePaymentSuccessHandler,
  claimDailyCheckinHandler,
  sendCoinTransferHandler,
  requestCoinTransferHandler,
  generateReferralCodeHandler,
  redeemReferralCodeHandler,
  getStripeConnectStatusHandler,
  createStripeConnectOnboardingLinkHandler,
  createStripeConnectDashboardLinkHandler,
  generateAgoraTokenHandler,
  sendRoomGiftHandler,
  requestRefundHandler,
  cleanupDeletedUserData,
  createCheckoutSessionHandler,
  handleCheckoutSessionCompleted,
  handleChargeRefunded,
  adminSetEntitlementHandler,
  getCheckoutBaseUrl,
  stripeWebhookHandler,
  grabMicHandler,
  inviteToMicHandler,
  dropFromMicHandler,
  generateTurnCredentialsHandler,
  requestCashOutHandler,
} = paymentFunctions.__testing;

function makeRequest(data, authUid = "user-1") {
  return {
    data,
    auth: authUid ? {uid: authUid} : null,
  };
}

// Apply Firestore FieldValue sentinels during a merge-set or update.
function applyFieldValues(prev, data) {
  const result = {...prev};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === "object" && value.methodName === "FieldValue.delete") {
      delete result[key];
    } else if (value && typeof value === "object" && value.methodName === "FieldValue.serverTimestamp") {
      const now = Date.now();
      result[key] = {toMillis: () => now, _isMockTimestamp: true};
    } else if (value && typeof value === "object" && value.methodName === "FieldValue.increment") {
      const operand = typeof value.operand === "number" ? value.operand : 0;
      const previous = typeof result[key] === "number" ? result[key] : 0;
      result[key] = previous + operand;
    } else {
      result[key] = value;
    }
  }
  return result;
}

function createFirestoreDouble(initialUsers = {}) {
  let idCounter = 0;
  const users = new Map(
    Object.entries(initialUsers).map(([id, value]) => [id, {...value}]),
  );
  const wallets = new Map();
  const walletLedger = new Map();
  const transactions = new Map();
  const logs = new Map();
  const stripeConnectAccounts = new Map();
  const stripeWebhookEvents = new Map();
  const entitlementEvents = new Map();
  const refundRequests = new Map();
  const cashOutRequests = new Map();
  const referralCodes = new Map();
  const referrals = new Map();
  const rooms = new Map();
  const profilePublic = new Map();
  const preferences = new Map();
  const verification = new Map();
  const presence = new Map();

  // ✅ FIX: missing shared subcollections registry (CRITICAL BUG)
  const subcollections = new Map();

  function storeFor(name) {
    switch (name) {
      case "users": return users;
      case "wallets": return wallets;
      case "wallet_ledger": return walletLedger;
      case "transactions": return transactions;
      case "logs": return logs;
      case "stripe_connect_accounts": return stripeConnectAccounts;
      case "stripe_webhook_events": return stripeWebhookEvents;
      case "entitlement_events": return entitlementEvents;
      case "refund_requests": return refundRequests;
      case "cash_out_requests": return cashOutRequests;
      case "referral_codes": return referralCodes;
      case "referrals": return referrals;
      case "rooms": return rooms;
      case "profile_public": return profilePublic;
      case "preferences": return preferences;
      case "verification": return verification;
      case "presence": return presence;
      default:
        throw new Error(`Unsupported collection ${name}`);
    }
  }

  function createDocRef(name, id) {
    const store = storeFor(name);
    return {
      id,
      async get() {
        const data = store.get(id);
        return {
          exists: data !== undefined,
          data: () => (data === undefined ? undefined : {...data}),
        };
      },
      async set(data, options = {}) {
        const previous = store.get(id) || {};
        store.set(
          id,
          options.merge ? applyFieldValues(previous, data) : applyFieldValues({}, data),
        );
      },
      async update(data) {
        const previous = store.get(id);
        if (previous === undefined) {
          throw new Error(`Missing document ${name}/${id}`);
        }
        store.set(id, applyFieldValues(previous, data));
      },
      async delete() {
        store.delete(id);
      },
      collection(subName) {
        const subKey = `${name}/${id}/${subName}`;

        if (!subcollections.has(subKey)) {
          subcollections.set(subKey, new Map());
        }

        const subStore = subcollections.get(subKey);

        return {
          doc(subId) {
            const resolvedId = subId || `${subName}-${++idCounter}`;
            return {
              id: resolvedId,
              async get() {
                const d = subStore.get(resolvedId);
                return {exists: d !== undefined, data: () => d && {...d}};
              },
              async set(data, opts = {}) {
                const prev = subStore.get(resolvedId) || {};
                subStore.set(resolvedId, opts.merge ? applyFieldValues(prev, data) : {...data});
              },
              async update(data) {
                const prev = subStore.get(resolvedId) || {};
                subStore.set(resolvedId, applyFieldValues(prev, data));
              },
              async delete() {
                subStore.delete(resolvedId);
              },
            };
          },
          where(field, op, value) {
            return {
              async get() {
                const entries = [...subStore.entries()].filter(([_, d]) => {
                  switch (op) {
                    case "==": return d[field] === value;
                    case "!=": return d[field] !== value;
                    case ">": return d[field] > value;
                    case "<": return d[field] < value;
                    case ">=": return d[field] >= value;
                    case "<=": return d[field] <= value;
                    default: return true;
                  }
                });

                const docs = entries.map(([k, v]) => ({
                  id: k,
                  ref: {
                    async set(data, opts = {}) {
                      const prev = subStore.get(k) || {};
                      subStore.set(k, opts.merge ? applyFieldValues(prev, data) : {...data});
                    },
                    async update(data) {
                      const prev = subStore.get(k) || {};
                      subStore.set(k, applyFieldValues(prev, data));
                    },
                    async delete() {
                      subStore.delete(k);
                    },
                  },
                  data: () => ({...v}),
                }));

                return {empty: docs.length === 0, docs, size: docs.length};
              },
            };
          },
          limit(n) {
            return {
              async get() {
                const docs = [...subStore.entries()].slice(0, n).map(([k, v]) => ({
                  id: k,
                  ref: {async delete() { subStore.delete(k); }},
                  data: () => ({...v}),
                }));
                return {empty: docs.length === 0, docs, size: docs.length};
              },
            };
          },
          async get() {
            const docs = [...subStore.entries()].map(([k, v]) => ({
              id: k,
              ref: {async delete() { subStore.delete(k); }},
              data: () => ({...v}),
            }));
            return {empty: docs.length === 0, docs, size: docs.length};
          },
          __subStore: subStore,
        };
      },
    };
  }

  const firestore = {
    collection(name) {
      return {
        doc(id) {
          return createDocRef(name, id || `${name}-${++idCounter}`);
        },
        async add(data) {
          const ref = createDocRef(name, `${name}-${++idCounter}`);
          await ref.set(data);
          return ref;
        },
        where(field, op, value) {
          const store = storeFor(name);

          const buildSnapshot = (entries) => {
            const docs = entries.map(([k, v]) => ({
              id: k,
              ref: createDocRef(name, k),
              data: () => ({...v}),
            }));
            return {empty: docs.length === 0, docs, size: docs.length};
          };

          const filters = [{field, op, value}];

          const applyFilter = (data, filter) => {
            switch (filter.op) {
              case "==": return data[filter.field] === filter.value;
              case "!=": return data[filter.field] !== filter.value;
              case ">": return data[filter.field] > filter.value;
              case "<": return data[filter.field] < filter.value;
              case ">=": return data[filter.field] >= filter.value;
              case "<=": return data[filter.field] <= filter.value;
              default: return true;
            }
          };

          const query = {
            where(nextField, nextOp, nextValue) {
              filters.push({field: nextField, op: nextOp, value: nextValue});
              return query;
            },
            async get() {
              const entries = [...store.entries()].filter(([_, data]) =>
                filters.every((filter) => applyFilter(data, filter)),
              );
              return buildSnapshot(entries);
            },
          };

          return query;
        },
      };
    },
    async runTransaction(worker) {
      const tx = {
        async get(ref) {
          return ref.get();
        },
        set(ref, data, options) {
          return ref.set(data, options);
        },
        update(ref, data) {
          return ref.update(data);
        },
        delete(ref) {
          return ref.delete();
        },
      };
      return worker(tx);
    },
  };

  return firestore;
}

function createResponseDouble() {
  return {
    statusCode: 200,
    jsonBody: null,
    textBody: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.jsonBody = body;
      return this;
    },
    send(body) {
      this.textBody = body;
      return this;
    },
  };
}

describe("grabMicHandler", () => {
  it("allows member-only callers and backfills participant doc", async () => {
    const firestore = createFirestoreDouble();

    await firestore.collection("rooms").doc("room-member-fallback").set({
      isLive: true,
    });
    await firestore
        .collection("rooms")
        .doc("room-member-fallback")
        .collection("members")
        .doc("user-1")
        .set({
          role: "member",
          isBanned: false,
        });

    const result = await grabMicHandler(makeRequest({
      roomId: "room-member-fallback",
    }, "user-1"), {firestore});

    assert.equal(result.success, true);

    const participantSnap = await firestore
        .collection("rooms")
        .doc("room-member-fallback")
        .collection("participants")
        .doc("user-1")
        .get();

    assert.equal(participantSnap.exists, true);
    assert.equal(participantSnap.data().userId, "user-1");
    assert.equal(participantSnap.data().role, "stage");
  });

  it("rejects banned member-only callers", async () => {
    const firestore = createFirestoreDouble();

    await firestore.collection("rooms").doc("room-banned-member").set({
      isLive: true,
    });
    await firestore
        .collection("rooms")
        .doc("room-banned-member")
        .collection("members")
        .doc("user-1")
        .set({
          role: "member",
          isBanned: true,
        });

    await assert.rejects(
        () => grabMicHandler(makeRequest({
          roomId: "room-banned-member",
        }, "user-1"), {firestore}),
        (error) => error && error.code === "permission-denied",
    );
  });
});

describe("dropFromMicHandler", () => {
  it("allows host-like caller to demote a stage participant", async () => {
    const firestore = createFirestoreDouble();

    await firestore.collection("rooms").doc("room-drop-ok").set({
      isLive: true,
    });

    await firestore
        .collection("rooms")
        .doc("room-drop-ok")
        .collection("participants")
        .doc("host-1")
        .set({
          userId: "host-1",
          role: "host",
        });

    await firestore
        .collection("rooms")
        .doc("room-drop-ok")
        .collection("participants")
        .doc("user-2")
        .set({
          userId: "user-2",
          role: "stage",
          micOn: true,
          isMuted: true,
        });

    const result = await dropFromMicHandler(makeRequest({
      roomId: "room-drop-ok",
      targetUserId: "user-2",
    }, "host-1"), {firestore});

    assert.equal(result.success, true);

    const targetSnap = await firestore
        .collection("rooms")
        .doc("room-drop-ok")
        .collection("participants")
        .doc("user-2")
        .get();

    assert.equal(targetSnap.exists, true);
    assert.equal(targetSnap.data().role, "member");
    assert.equal(targetSnap.data().micOn, false);
    assert.equal(targetSnap.data().isMuted, false);
  });

  it("rejects non-moderator callers", async () => {
    const firestore = createFirestoreDouble();

    await firestore.collection("rooms").doc("room-drop-deny").set({
      isLive: true,
    });

    await firestore
        .collection("rooms")
        .doc("room-drop-deny")
        .collection("participants")
        .doc("audience-1")
        .set({
          userId: "audience-1",
          role: "audience",
        });

    await firestore
        .collection("rooms")
        .doc("room-drop-deny")
        .collection("participants")
        .doc("user-2")
        .set({
          userId: "user-2",
          role: "stage",
        });

    await assert.rejects(
        () => dropFromMicHandler(makeRequest({
          roomId: "room-drop-deny",
          targetUserId: "user-2",
        }, "audience-1"), {firestore}),
        (error) => error && error.code === "permission-denied",
    );
  });
});

describe("generateTurnCredentialsHandler", () => {
  it("returns fallback ICE server structure when TURN secret is unavailable", async () => {
    const originalApiKey = process.env.METERED_API_KEY;
    delete process.env.METERED_API_KEY;

    try {
      const result = await generateTurnCredentialsHandler(makeRequest({}, "user-turn-1"));

      assert.equal(result.fallback, true);
      assert.ok(Array.isArray(result.iceServers));
      assert.ok(result.iceServers.length > 0);
      assert.ok(Array.isArray(result.iceServers[0].urls));
    } finally {
      if (originalApiKey === undefined) {
        delete process.env.METERED_API_KEY;
      } else {
        process.env.METERED_API_KEY = originalApiKey;
      }
    }
  });
});

describe("requestCashOutHandler", () => {
  it("creates cash_out_requests doc and returns requestId", async () => {
    const firestore = createFirestoreDouble();

    await firestore.collection("wallets").doc("test-user-123").set({
      cashBalance: 200,
    });

    const result = await requestCashOutHandler(makeRequest({
      amount: 50.0,
      paymentMethod: "stripe",
    }, "test-user-123"), {firestore});

    assert.equal(typeof result.requestId, "string");
    assert.ok(result.requestId.length > 0);

    const docSnapshot = await firestore
        .collection("cash_out_requests")
        .doc(result.requestId)
        .get();

    assert.equal(docSnapshot.exists, true);
    assert.equal(docSnapshot.data().userId, "test-user-123");
    assert.equal(docSnapshot.data().amount, 50.0);
    assert.equal(docSnapshot.data().status, "pending");
  });
});