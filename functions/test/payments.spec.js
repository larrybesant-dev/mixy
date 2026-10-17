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

          const filterEntries = () =>
            [...store.entries()].filter(([_, data]) => {
              switch (op) {
                case "==": return data[field] === value;
                case "!=": return data[field] !== value;
                case ">": return data[field] > value;
                case "<": return data[field] < value;
                case ">=": return data[field] >= value;
                case "<=": return data[field] <= value;
                default: return true;
              }
            });

          return {
            async get() {
              return buildSnapshot(filterEntries());
            },
          };
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

describe("Stripe entitlement lifecycle", () => {
  it("grants VIP for a paid premium checkout", async () => {
    const firestore = createFirestoreDouble({"user-1": {uid: "user-1"}});
    const result = await handleCheckoutSessionCompleted({
      id: "cs_paid",
      payment_status: "paid",
      amount_total: 999,
      currency: "usd",
      metadata: {userId: "user-1", productType: "premium_access"},
    }, {firestore, eventId: "evt_paid", eventType: "checkout.session.completed"});

    assert.deepEqual(result, {
      creditedCoins: 0,
      premiumApplied: true,
      deduplicated: false,
    });
    const user = await firestore.collection("users").doc("user-1").get();
    assert.equal(user.data().entitlements.vip.active, true);
    assert.equal(user.data().entitlements.vip.source, "stripe_checkout");
  });

  it("does not grant VIP for an unpaid checkout", async () => {
    const firestore = createFirestoreDouble({"user-1": {uid: "user-1"}});
    const result = await handleCheckoutSessionCompleted({
      id: "cs_unpaid",
      payment_status: "unpaid",
      metadata: {userId: "user-1", productType: "premium_access"},
    }, {firestore, eventId: "evt_unpaid"});

    assert.equal(result.premiumApplied, false);
    const user = await firestore.collection("users").doc("user-1").get();
    assert.equal(user.data().entitlements, undefined);
  });

  it("deduplicates a replayed checkout session", async () => {
    const firestore = createFirestoreDouble({"user-1": {uid: "user-1"}});
    const session = {
      id: "cs_replayed",
      payment_status: "paid",
      metadata: {userId: "user-1", productType: "premium_access"},
    };

    await handleCheckoutSessionCompleted(session, {
      firestore,
      eventId: "evt_original",
    });
    const replay = await handleCheckoutSessionCompleted(session, {
      firestore,
      eventId: "evt_replay",
    });

    assert.deepEqual(replay, {
      creditedCoins: 0,
      premiumApplied: false,
      deduplicated: true,
    });
  });

  it("revokes VIP once for a fully refunded checkout", async () => {
    const firestore = createFirestoreDouble({"user-1": {uid: "user-1"}});
    await handleCheckoutSessionCompleted({
      id: "cs_refunded",
      payment_status: "paid",
      metadata: {userId: "user-1", productType: "premium_access"},
    }, {firestore, eventId: "evt_purchase"});

    const charge = {
      id: "ch_refunded",
      metadata: {checkoutSessionId: "cs_refunded"},
    };
    const refund = await handleChargeRefunded(charge, {
      firestore,
      eventId: "evt_refund",
      eventType: "charge.refunded",
    });
    const replay = await handleChargeRefunded(charge, {
      firestore,
      eventId: "evt_refund",
      eventType: "charge.refunded",
    });

    assert.deepEqual(refund, {revoked: true, userId: "user-1"});
    assert.deepEqual(replay, {revoked: false, reason: "deduplicated"});
    const user = await firestore.collection("users").doc("user-1").get();
    assert.equal(user.data().entitlements.vip.active, false);
    assert.equal(user.data().entitlements.vip.revokeReason, "refund");
  });
});

describe("adminSetEntitlementHandler", () => {
  it("requires an admin caller", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {uid: "user-1"},
      "target-1": {uid: "target-1"},
    });

    await assert.rejects(
        () => adminSetEntitlementHandler(makeRequest({
          userId: "target-1",
          active: true,
        }), {firestore}),
        (error) => error && error.code === "permission-denied",
    );
  });

  it("allows an admin to grant and revoke VIP", async () => {
    const firestore = createFirestoreDouble({
      "admin-1": {uid: "admin-1", admin: true},
      "target-1": {uid: "target-1"},
    });

    const grant = await adminSetEntitlementHandler(makeRequest({
      userId: "target-1",
      active: true,
      reason: "release audit",
    }, "admin-1"), {firestore});
    assert.deepEqual(grant, {success: true, userId: "target-1", active: true});

    let target = await firestore.collection("users").doc("target-1").get();
    assert.equal(target.data().entitlements.vip.active, true);
    assert.equal(target.data().entitlements.vip.source, "admin_override");

    const revoke = await adminSetEntitlementHandler(makeRequest({
      userId: "target-1",
      active: false,
      reason: "release audit cleanup",
    }, "admin-1"), {firestore});
    assert.deepEqual(revoke, {success: true, userId: "target-1", active: false});

    target = await firestore.collection("users").doc("target-1").get();
    assert.equal(target.data().entitlements.vip.active, false);
  });
});