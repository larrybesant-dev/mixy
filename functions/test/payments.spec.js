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
// - FieldValue.delete()  → removes the key
// - FieldValue.serverTimestamp() → stores a mock {toMillis:()=>now} object
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
  // Shared subcollection storage: "col/id/sub" → Map<subId, data>
  const subcollections = new Map();

  function storeFor(name) {
    switch (name) {
      case "users":
        return users;
      case "wallets":
        return wallets;
        case "wallet_ledger":
          return walletLedger;
      case "transactions":
        return transactions;
      case "logs":
        return logs;
      case "stripe_connect_accounts":
        return stripeConnectAccounts;
      case "stripe_webhook_events":
        return stripeWebhookEvents;
      case "entitlement_events":
        return entitlementEvents;
      case "refund_requests":
        return refundRequests;
      case "referral_codes":
        return referralCodes;
      case "referrals":
        return referrals;
      case "rooms":
        return rooms;
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
          subcollections.set(subKey, new Map()); // shared across all doc() calls
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
              async delete() { subStore.delete(resolvedId); },
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
                    async delete() { subStore.delete(k); },
                  },
                  data: () => ({...v}),
                }));
                return {empty: docs.length === 0, docs, size: docs.length};
              },
            };
          },
          limit(n) {
            // Return a query-like object; .get() returns first n docs.
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
          // Support chaining: .limit(n).get() by returning the snapshot directly
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
          const filterEntries = () => [...store.entries()].filter(([_, data]) => {
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
            where(nextField, nextOp, nextValue) {
              return firestore.collection(name).where(field, op, value).getChained().where(nextField, nextOp, nextValue);
            },
            limit(n) {
              return {
                async get() {
                  return buildSnapshot(filterEntries().slice(0, n));
                },
              };
            },
            async get() {
              return buildSnapshot(filterEntries());
            },
            getChained() {
              const currentEntries = filterEntries();
              return {
                where(nextField, nextOp, nextValue) {
                  const chainedEntries = currentEntries.filter(([_, data]) => {
                    switch (nextOp) {
                      case "==": return data[nextField] === nextValue;
                      case "!=": return data[nextField] !== nextValue;
                      case ">": return data[nextField] > nextValue;
                      case "<": return data[nextField] < nextValue;
                      case ">=": return data[nextField] >= nextValue;
                      case "<=": return data[nextField] <= nextValue;
                      default: return true;
                    }
                  });
                  return {
                    limit(n) {
                      return {
                        async get() {
                          return buildSnapshot(chainedEntries.slice(0, n));
                        },
                      };
                    },
                    async get() {
                      return buildSnapshot(chainedEntries);
                    },
                  };
                },
                limit(n) {
                  return {
                    async get() {
                      return buildSnapshot(currentEntries.slice(0, n));
                    },
                  };
                },
                async get() {
                  return buildSnapshot(currentEntries);
                },
              };
            },
          };
        },
        limit(n) {
          const store = storeFor(name);
          return {
            async get() {
              const docs = [...store.entries()].slice(0, n).map(([k, v]) => ({
                id: k,
                ref: createDocRef(name, k),
                data: () => ({...v}),
              }));
              return {empty: docs.length === 0, docs, size: docs.length};
            },
          };
        },
        async get() {
          const store = storeFor(name);
          const docs = [...store.entries()].map(([k, v]) => ({
            id: k,
            ref: createDocRef(name, k),
            data: () => ({...v}),
          }));
          return {empty: docs.length === 0, docs, size: docs.length};
        },
      };
    },
    async runTransaction(handler) {
      const operations = [];
      const transaction = {
        get: async (ref) => ref.get(),
        update: (ref, data) => operations.push(() => ref.update(data)),
        set: (ref, data, opts = {}) => operations.push(() => ref.set(data, opts)),
      };
      const result = await handler(transaction);
      for (const operation of operations) {
        await operation();
      }
      return result;
    },
    batch() {
      const ops = [];
      return {
        delete(ref) { ops.push(() => ref.delete()); return this; },
        set(ref, data, opts) { ops.push(() => ref.set(data, opts)); return this; },
        update(ref, data) { ops.push(() => ref.update(data)); return this; },
        async commit() { for (const op of ops) await op(); },
      };
    },
    __state: {
      users,
      wallets,
      walletLedger,
      transactions,
      logs,
      stripeConnectAccounts,
      stripeWebhookEvents,
      entitlementEvents,
      refundRequests,
      referralCodes,
      referrals,
      rooms,
      subcollections,
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

describe("payment callable handlers", () => {
  it("createPaymentIntentHandler rejects unauthenticated calls", async () => {
    await assert.rejects(
        () => createPaymentIntentHandler(makeRequest({}, null)),
        (error) => error.code === "unauthenticated",
    );
  });

  it("createPaymentIntentHandler validates payload and creates Stripe intent", async () => {
    let capturedPayload;
    let capturedOptions;
    const stripeClient = {
      paymentIntents: {
        create: async (payload, options) => {
          capturedPayload = payload;
          capturedOptions = options;
          return {client_secret: "pi_secret_123", id: "pi_123"};
        },
      },
    };

    const response = await createPaymentIntentHandler(
        makeRequest({
          amount: 12.34,
          currency: "USD",
          recipientId: "user-2",
          idempotencyKey: "idem-key-0001",
        }),
        {stripeClient},
    );

    assert.deepEqual(response, {
      clientSecret: "pi_secret_123",
      paymentIntentId: "pi_123",
      idempotencyKey: "idem-key-0001",
    });
    assert.equal(capturedPayload.amount, 1234);
    assert.equal(capturedPayload.currency, "usd");
    assert.equal(capturedPayload.metadata.senderId, "user-1");
    assert.equal(capturedPayload.metadata.recipientId, "user-2");
    assert.equal(capturedOptions.idempotencyKey, "idem-key-0001");
  });

  it("recordStripePaymentSuccessHandler records a completed transaction", async () => {
    const firestore = createFirestoreDouble();
    const stripeClient = {
      paymentIntents: {
        retrieve: async () => ({
          id: "pi_777",
          status: "succeeded",
          amount: 700,
          metadata: {
            senderId: "user-1",
            recipientId: "user-2",
            amount: "7",
          },
        }),
      },
    };

    const response = await recordStripePaymentSuccessHandler(
        makeRequest({
          recipientId: "user-2",
          amount: 7,
          paymentIntentId: "pi_777",
        }),
        {firestore, stripeClient, forceStripeVerification: true},
    );

    const recorded = firestore.__state.transactions.get(response.transactionId);
    assert.equal(recorded.senderId, "user-1");
    assert.equal(recorded.receiverId, "user-2");
    assert.deepEqual(recorded.participants, ["user-1", "user-2"]);
    assert.equal(recorded.amount, 7);
    assert.equal(recorded.status, "completed");
    assert.equal(recorded.paymentIntentId, "pi_777");
  });

  it("recordStripePaymentSuccessHandler rejects mismatched stripe metadata", async () => {
    const firestore = createFirestoreDouble();
    const stripeClient = {
      paymentIntents: {
        retrieve: async () => ({
          id: "pi_bad",
          status: "succeeded",
          amount: 500,
          metadata: {
            senderId: "other-user",
            recipientId: "user-2",
            amount: "5",
          },
        }),
      },
    };

    await assert.rejects(
        () => recordStripePaymentSuccessHandler(
            makeRequest({
              recipientId: "user-2",
              amount: 5,
              paymentIntentId: "pi_bad",
            }),
            {firestore, stripeClient, forceStripeVerification: true},
        ),
        (error) => error.code === "permission-denied",
    );
  });

  it("sendCoinTransferHandler rejects insufficient balance", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 2},
      "user-2": {balance: 4},
    });

    await assert.rejects(
        () => sendCoinTransferHandler(
            makeRequest({receiverId: "user-2", amount: 5}),
            {firestore},
        ),
        (error) => error.code === "failed-precondition",
    );
  });

  it("sendCoinTransferHandler updates balances and records transaction", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 20},
      "user-2": {balance: 3},
    });

    const response = await sendCoinTransferHandler(
        makeRequest({receiverId: "user-2", amount: 5}),
        {firestore},
    );

    assert.equal(firestore.__state.users.get("user-1").balance, 15);
    assert.equal(firestore.__state.users.get("user-2").balance, 8);
  assert.equal(firestore.__state.wallets.get("user-1").coinBalance, 15);
  assert.equal(firestore.__state.wallets.get("user-2").coinBalance, 8);
    assert.equal(
        firestore.__state.transactions.get(response.transactionId).status,
        "sent",
    );
    assert.deepEqual(
      firestore.__state.transactions.get(response.transactionId).participants,
      ["user-1", "user-2"],
    );
  });

  it("sendCoinTransferHandler deduplicates repeated idempotent calls", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 20},
      "user-2": {balance: 3},
    });

    const first = await sendCoinTransferHandler(
        makeRequest({receiverId: "user-2", amount: 5, idempotencyKey: "send-replay-1"}),
        {firestore},
    );
    const second = await sendCoinTransferHandler(
        makeRequest({receiverId: "user-2", amount: 5, idempotencyKey: "send-replay-1"}),
        {firestore},
    );

    assert.equal(first.transactionId, second.transactionId);
    assert.equal(firestore.__state.users.get("user-1").balance, 15);
    assert.equal(firestore.__state.users.get("user-2").balance, 8);
    assert.equal(firestore.__state.transactions.size, 1);
  });

  it("handleCheckoutSessionCompleted credits coin purchases once", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 10},
    });

    const session = {
      id: "cs_test_123",
      payment_status: "paid",
      metadata: {
        userId: "user-1",
        productType: "coin_package",
        coins: "70",
      },
    };

    const first = await handleCheckoutSessionCompleted(session, {firestore});
    const second = await handleCheckoutSessionCompleted(session, {firestore});

    assert.equal(first.creditedCoins, 70);
    assert.equal(second.deduplicated, true);
    assert.equal(firestore.__state.users.get("user-1").balance, 80);
    assert.equal(firestore.__state.users.get("user-1").coinBalance, 80);
    assert.equal(firestore.__state.wallets.get("user-1").coinBalance, 80);
  });

  it("handleCheckoutSessionCompleted writes authoritative VIP entitlement", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 10, membershipLevel: "basic"},
    });

    const session = {
      id: "cs_vip_123",
      payment_status: "paid",
      amount_total: 500,
      currency: "usd",
      metadata: {
        userId: "user-1",
        productType: "premium_access",
      },
    };

    const first = await handleCheckoutSessionCompleted(session, {firestore});
    const second = await handleCheckoutSessionCompleted(session, {firestore});

    const user = firestore.__state.users.get("user-1");
    assert.equal(first.premiumApplied, true);
    assert.equal(second.deduplicated, true);
    assert.equal(user.entitlement, "vip");
    assert.equal(user.isPremium, true);
    assert.equal(user.vipLevel, 1);
    assert.equal(user.membershipLevel, "vip");
    assert.equal(user.entitlements.vip.active, true);
    assert.equal(user.entitlements.vip.source, "stripe_checkout");
    assert.equal(user.entitlements.vip.sessionId, "cs_vip_123");
    assert.equal(firestore.__state.entitlementEvents.size, 1);
    const entitlementEvent = firestore.__state.entitlementEvents.get("stripe_cs_vip_123");
    assert.equal(entitlementEvent.type, "vip_purchase");
    assert.equal(entitlementEvent.paymentStatus, "paid");
    assert.equal(entitlementEvent.amountTotal, 500);
    assert.equal(entitlementEvent.currency, "usd");
  });

  it("handleCheckoutSessionCompleted does not unlock premium when payment is not paid", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {membershipLevel: "basic", vipLevel: 0},
    });

    const session = {
      id: "cs_vip_unpaid",
      payment_status: "unpaid",
      metadata: {
        userId: "user-1",
        productType: "premium_access",
      },
    };

    const result = await handleCheckoutSessionCompleted(session, {firestore});
    const user = firestore.__state.users.get("user-1");

    assert.equal(result.premiumApplied, false);
    assert.equal(user.entitlement, undefined);
    assert.equal(user.membershipLevel, "basic");
    assert.equal(firestore.__state.entitlementEvents.size, 0);
  });

  it("stripeWebhookHandler credits checkout.session.completed only once during replay", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 10, coinBalance: 10},
    });
    const stripeClient = {
      webhooks: {
        constructEvent: () => ({
          type: "checkout.session.completed",
          data: {
            object: {
              id: "cs_replay_1",
              payment_status: "paid",
              metadata: {
                userId: "user-1",
                productType: "coin_package",
                coins: "70",
              },
            },
          },
        }),
      },
    };

    const firstRes = createResponseDouble();
    const secondRes = createResponseDouble();
    const req = {
      rawBody: Buffer.from("{}"),
      headers: {"stripe-signature": "sig_test"},
    };

    await stripeWebhookHandler(req, firstRes, {firestore, stripeClient});
    await stripeWebhookHandler(req, secondRes, {firestore, stripeClient});

    assert.equal(firstRes.statusCode, 200);
    assert.equal(secondRes.statusCode, 200);
    assert.equal(firestore.__state.users.get("user-1").balance, 80);
    assert.equal(firestore.__state.users.get("user-1").coinBalance, 80);
    assert.equal(firestore.__state.wallets.get("user-1").coinBalance, 80);
    assert.equal(firestore.__state.stripeWebhookEvents.size, 1);
  });

  it("stripeWebhookHandler ignores out-of-order unrelated webhook events", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 10, coinBalance: 10},
    });
    const stripeClient = {
      webhooks: {
        constructEvent: () => ({
          type: "payment_intent.succeeded",
          data: {object: {id: "pi_ignored"}},
        }),
      },
    };

    const res = createResponseDouble();
    const req = {
      rawBody: Buffer.from("{}"),
      headers: {"stripe-signature": "sig_test"},
    };

    await stripeWebhookHandler(req, res, {firestore, stripeClient});

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.jsonBody, {received: true});
    assert.equal(firestore.__state.users.get("user-1").balance, 10);
    assert.equal(firestore.__state.stripeWebhookEvents.size, 0);
  });

  it("stripeWebhookHandler returns 400 and logs when signature verification fails", async () => {
    const firestore = createFirestoreDouble();
    const stripeClient = {
      webhooks: {
        constructEvent: () => {
          throw new Error("bad signature");
        },
      },
    };

    const res = createResponseDouble();
    const req = {
      rawBody: Buffer.from("{}"),
      headers: {"stripe-signature": "sig_bad"},
    };

    await stripeWebhookHandler(req, res, {firestore, stripeClient});

    assert.equal(res.statusCode, 400);
    assert.equal(res.textBody, "Webhook Error: bad signature");
    assert.equal(firestore.__state.logs.size, 1);
    const loggedError = [...firestore.__state.logs.values()][0];
    assert.equal(loggedError.type, "stripe_webhook_error");
    assert.equal(loggedError.message, "bad signature");
  });

  it("claimDailyCheckinHandler increments balance once per day", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 40, coinBalance: 40, checkinStreak: 0},
    });

    const response = await claimDailyCheckinHandler(
        makeRequest({}, "user-1"),
        {firestore},
    );

    assert.equal(response.reward, 10);
    assert.equal(response.streak, 1);
    assert.equal(firestore.__state.users.get("user-1").balance, 50);
    assert.equal(firestore.__state.users.get("user-1").coinBalance, 50);
  });

  it("claimDailyCheckinHandler rejects duplicate same-day claims", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {
        balance: 40,
        coinBalance: 40,
        checkinStreak: 3,
        lastCheckinDate: {toDate: () => new Date()},
      },
    });

    await assert.rejects(
        () => claimDailyCheckinHandler(makeRequest({}, "user-1"), {firestore}),
        (error) => error.code === "already-exists",
    );
  });

  it("generateReferralCodeHandler reuses an active code for the same user", async () => {
    const firestore = createFirestoreDouble();
    firestore.__state.referralCodes.set("MXVY-ABC123", {
      code: "MXVY-ABC123",
      ownerUserId: "user-1",
      isActive: true,
    });

    const response = await generateReferralCodeHandler(makeRequest({}), {firestore});

    assert.equal(response.code, "MXVY-ABC123");
  });

  it("redeemReferralCodeHandler creates a referral record", async () => {
    const firestore = createFirestoreDouble();
    firestore.__state.referralCodes.set("MXVY-ABCD23", {
      code: "MXVY-ABCD23",
      ownerUserId: "user-9",
      isActive: true,
    });

    const response = await redeemReferralCodeHandler(
        makeRequest({code: "mxvy-abcd23"}, "user-2"),
        {firestore},
    );

    assert.equal(response.redeemed, true);
    const storedReferral = firestore.__state.referrals.get(response.referralId);
    assert.equal(storedReferral.referrerUserId, "user-9");
    assert.equal(storedReferral.referredUserId, "user-2");
    assert.equal(storedReferral.referralCode, "MXVY-ABCD23");
  });

  it("requestCoinTransferHandler rejects self-targeted requests", async () => {
    const firestore = createFirestoreDouble();

    await assert.rejects(
        () => requestCoinTransferHandler(
            makeRequest({targetId: "user-1", amount: 5}),
            {firestore},
        ),
        (error) => error.code === "invalid-argument",
    );
  });

  it("requestCoinTransferHandler records requested transaction", async () => {
    const firestore = createFirestoreDouble();

    const response = await requestCoinTransferHandler(
        makeRequest({targetId: "user-3", amount: 9}),
        {firestore},
    );

    const recorded = firestore.__state.transactions.get(response.transactionId);
    assert.equal(recorded.senderId, "user-1");
    assert.equal(recorded.receiverId, "user-3");
    assert.deepEqual(recorded.participants, ["user-1", "user-3"]);
    assert.equal(recorded.status, "requested");
  });

  it("getStripeConnectStatusHandler returns not-started status without an account", async () => {
    const firestore = createFirestoreDouble();
    const response = await getStripeConnectStatusHandler(makeRequest({}), {
      firestore,
      stripeClient: {
        accounts: {
          retrieve: async () => {
            throw new Error("should not retrieve");
          },
        },
      },
    });

    assert.equal(response.hasAccount, false);
    assert.equal(response.onboardingComplete, false);
  });

  it("createStripeConnectOnboardingLinkHandler creates account, stores status, and returns link", async () => {
    const firestore = createFirestoreDouble();
    let createdAccountPayload;
    let createdLinkPayload;
    const stripeClient = {
      accounts: {
        create: async (payload) => {
          createdAccountPayload = payload;
          return {
            id: "acct_123",
            charges_enabled: false,
            payouts_enabled: false,
            details_submitted: false,
            country: "US",
          };
        },
        retrieve: async () => {
          throw new Error("should not retrieve before create");
        },
        createLoginLink: async () => ({url: "https://stripe.test/dashboard"}),
      },
      accountLinks: {
        create: async (payload) => {
          createdLinkPayload = payload;
          return {url: "https://stripe.test/onboarding"};
        },
      },
    };

    const response = await createStripeConnectOnboardingLinkHandler(makeRequest({}), {
      firestore,
      stripeClient,
      publicAppUrl: "https://mixvy.app",
    });

    assert.equal(response.url, "https://stripe.test/onboarding");
    assert.equal(response.accountId, "acct_123");
    assert.equal(createdAccountPayload.type, "express");
    assert.equal(createdLinkPayload.account, "acct_123");
    assert.equal(createdLinkPayload.refresh_url, "https://mixvy.app/payments?connect=refresh");
    assert.equal(createdLinkPayload.return_url, "https://mixvy.app/payments?connect=return");
    assert.equal(
        firestore.__state.stripeConnectAccounts.get("user-1").accountId,
        "acct_123",
    );
  });

  it("createStripeConnectDashboardLinkHandler creates a dashboard login link", async () => {
    const firestore = createFirestoreDouble();
    firestore.__state.stripeConnectAccounts.set("user-1", {accountId: "acct_saved"});
    let retrievedAccountId;
    let loginLinkAccountId;
    const stripeClient = {
      accounts: {
        retrieve: async (accountId) => {
          retrievedAccountId = accountId;
          return {
            id: accountId,
            charges_enabled: true,
            payouts_enabled: true,
            details_submitted: true,
            country: "US",
          };
        },
        create: async () => {
          throw new Error("should not create new account");
        },
        createLoginLink: async (accountId) => {
          loginLinkAccountId = accountId;
          return {url: "https://stripe.test/dashboard"};
        },
      },
    };

    const response = await createStripeConnectDashboardLinkHandler(makeRequest({}), {
      firestore,
      stripeClient,
    });

    assert.equal(response.url, "https://stripe.test/dashboard");
    assert.equal(retrievedAccountId, "acct_saved");
    assert.equal(loginLinkAccountId, "acct_saved");
  });

  it("requestRefundHandler records a pending refund request", async () => {
    const firestore = createFirestoreDouble();
    firestore.__state.transactions.set("tx_1", {
      id: "tx_1",
      senderId: "user-1",
      receiverId: "user-2",
      participants: ["user-1", "user-2"],
      amount: 14,
      status: "completed",
      source: "stripe",
    });

    const response = await requestRefundHandler(
        makeRequest({transactionId: "tx_1", reason: "Duplicate charge on checkout."}),
        {firestore},
    );

    assert.equal(response.status, "pending");
    const refund = firestore.__state.refundRequests.get("tx_1_user-1");
    assert.equal(refund.requesterId, "user-1");
    assert.equal(refund.transactionId, "tx_1");
    assert.equal(refund.status, "pending");
  });

  it("requestRefundHandler rejects non-participants", async () => {
    const firestore = createFirestoreDouble();
    firestore.__state.transactions.set("tx_2", {
      id: "tx_2",
      senderId: "user-1",
      receiverId: "user-2",
      participants: ["user-1", "user-2"],
      amount: 10,
      status: "completed",
      source: "stripe",
    });

    await assert.rejects(
        () => requestRefundHandler(
            makeRequest({transactionId: "tx_2", reason: "Charge dispute reason here."}, "user-9"),
            {firestore},
        ),
        (error) => error.code === "permission-denied",
    );
  });

  it("cleanupDeletedUserData removes user profile and stripe connect docs", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 100, displayName: "User One"},
    });
    firestore.__state.stripeConnectAccounts.set("user-1", {
      accountId: "acct_123",
      chargesEnabled: true,
    });

    // Seed a notification token to verify it gets cleaned up.
    const userDocRef = firestore.collection("users").doc("user-1");
    const tokenSubcol = userDocRef.collection("notification_tokens");
    await tokenSubcol.doc("tok_abc").set({token: "tok_abc", userId: "user-1"});
    assert.equal(tokenSubcol.__subStore.has("tok_abc"), true);

    await cleanupDeletedUserData("user-1", {firestore});

    assert.equal(firestore.__state.users.has("user-1"), false);
    assert.equal(firestore.__state.stripeConnectAccounts.has("user-1"), false);
    // Notification tokens must be deleted on account deletion (privacy / GDPR).
    assert.equal(tokenSubcol.__subStore.has("tok_abc"), false);
  });

  it("getCheckoutBaseUrl prefers CHECKOUT_BASE_URL and trims trailing slash", () => {
    const previousCheckoutBaseUrl = process.env.CHECKOUT_BASE_URL;
    const previousPublicAppUrl = process.env.PUBLIC_APP_URL;

    process.env.CHECKOUT_BASE_URL = "https://beta.mixvy.app/";
    process.env.PUBLIC_APP_URL = "https://fallback.mixvy.app";

    assert.equal(getCheckoutBaseUrl(), "https://beta.mixvy.app");

    if (previousCheckoutBaseUrl === undefined) {
      delete process.env.CHECKOUT_BASE_URL;
    } else {
      process.env.CHECKOUT_BASE_URL = previousCheckoutBaseUrl;
    }
    if (previousPublicAppUrl === undefined) {
      delete process.env.PUBLIC_APP_URL;
    } else {
      process.env.PUBLIC_APP_URL = previousPublicAppUrl;
    }
  });

  it("createCheckoutSessionHandler uses resolved success/cancel URLs", async () => {
    const previousCheckoutBaseUrl = process.env.CHECKOUT_BASE_URL;
    const previousPublicAppUrl = process.env.PUBLIC_APP_URL;
    process.env.CHECKOUT_BASE_URL = "https://beta.mixvy.app";
    delete process.env.PUBLIC_APP_URL;

    let capturedPayload;
    const stripeClient = {
      checkout: {
        sessions: {
          create: async (payload) => {
            capturedPayload = payload;
            return {url: "https://checkout.stripe.test/session_123"};
          },
        },
      },
    };

    const req = {body: {userId: "user-9"}};
    const res = createResponseDouble();

    await createCheckoutSessionHandler(req, res, {stripeClient});

    assert.equal(
      capturedPayload.success_url,
      "https://beta.mixvy.app/vip?checkout=success&session_id={CHECKOUT_SESSION_ID}",
    );
    assert.equal(capturedPayload.cancel_url, "https://beta.mixvy.app/vip?checkout=cancel");
    assert.deepEqual(res.jsonBody, {url: "https://checkout.stripe.test/session_123"});

    if (previousCheckoutBaseUrl === undefined) {
      delete process.env.CHECKOUT_BASE_URL;
    } else {
      process.env.CHECKOUT_BASE_URL = previousCheckoutBaseUrl;
    }
    if (previousPublicAppUrl === undefined) {
      delete process.env.PUBLIC_APP_URL;
    } else {
      process.env.PUBLIC_APP_URL = previousPublicAppUrl;
    }
  });

  it("createCheckoutSessionCallableHandler maps coin package ids server-side", async () => {
    let capturedPayload;
    const stripeClient = {
      checkout: {
        sessions: {
          create: async (payload) => {
            capturedPayload = payload;
            return {url: "https://checkout.stripe.test/coins_3500"};
          },
        },
      },
    };

    const response = await paymentFunctions.__testing.createCheckoutSessionCallableHandler(
      makeRequest({packageId: "coins_3500"}),
      {stripeClient},
    );

    assert.equal(response.url, "https://checkout.stripe.test/coins_3500");
    assert.equal(capturedPayload.line_items[0].price_data.unit_amount, 4999);
    assert.equal(capturedPayload.line_items[0].price_data.product_data.name, "MixVy Coins - 4000");
    assert.equal(capturedPayload.metadata.packageId, "coins_3500");
    assert.equal(capturedPayload.metadata.coins, "4000");
    assert.equal(capturedPayload.metadata.userId, "user-1");
  });

  it("createCheckoutSessionCallableHandler rejects unknown package ids", async () => {
    const stripeClient = {
      checkout: {
        sessions: {
          create: async () => {
            throw new Error("should not create session");
          },
        },
      },
    };

    await assert.rejects(
      () => paymentFunctions.__testing.createCheckoutSessionCallableHandler(
        makeRequest({packageId: "coins_fake"}),
        {stripeClient},
      ),
      (error) => error.code === "invalid-argument",
    );
  });

  // sendRoomGift ------------------------------------------------------------

  it("sendRoomGiftHandler rejects sender who is not a room participant", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 100},
      "user-2": {balance: 0},
    });
    // Room exists and is live, but sender has no participant doc.
    await firestore.collection("rooms").doc("room-1").set({isLive: true});

    await assert.rejects(
      () => sendRoomGiftHandler(
        makeRequest({roomId: "room-1", receiverId: "user-2", giftId: "g1", coinCost: 10}, "user-1"),
        {firestore},
      ),
      (err) => err.code === "permission-denied",
    );
  });

  it("sendRoomGiftHandler rejects gift when room is not active", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 100},
      "user-2": {balance: 0},
    });
    // Room doc exists but isLive=false.
    await firestore.collection("rooms").doc("room-1").set({isLive: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: false});

    await assert.rejects(
      () => sendRoomGiftHandler(
        makeRequest({roomId: "room-1", receiverId: "user-2", giftId: "g1", coinCost: 10}, "user-1"),
        {firestore},
      ),
      (err) => err.code === "failed-precondition",
    );
  });

  it("sendRoomGiftHandler transfers coins and creates gift event for valid participant", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 100},
      "user-2": {balance: 0},
    });
    await firestore.collection("rooms").doc("room-1").set({isLive: true});
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: false});

    const result = await sendRoomGiftHandler(
      makeRequest({roomId: "room-1", receiverId: "user-2", giftId: "g1", coinCost: 10}, "user-1"),
      {firestore},
    );

    assert.ok(typeof result.giftEventId === "string" && result.giftEventId.length > 0);
    const senderSnap = await firestore.collection("users").doc("user-1").get();
    assert.equal(senderSnap.data().balance, 90);
    const receiverSnap = await firestore.collection("users").doc("user-2").get();
    // Receiver gets coinCost * 0.85 = 8 (floored).
    assert.equal(receiverSnap.data().balance, 8);
    const giftEvents = firestore.__state.subcollections.get("rooms/room-1/gift_events");
    const giftEvent = giftEvents.get(result.giftEventId);
    assert.equal(giftEvent.receiverAmount, 8);
    assert.equal(giftEvent.platformFeeAmount, 2);
    const ledgerEntries = [...firestore.__state.walletLedger.values()];
    assert.equal(ledgerEntries.some((entry) => entry.type === "gift_platform_fee" && entry.amount === -2), true);
  });

  it("sendRoomGiftHandler rejects banned participant", async () => {
    const firestore = createFirestoreDouble({
      "user-1": {balance: 100},
      "user-2": {balance: 0},
    });
    await firestore.collection("rooms").doc("room-1").set({isLive: true});
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: true});

    await assert.rejects(
      () => sendRoomGiftHandler(
        makeRequest({roomId: "room-1", receiverId: "user-2", giftId: "g1", coinCost: 10}, "user-1"),
        {firestore},
      ),
      (err) => err.code === "permission-denied",
    );
  });

  // generateAgoraToken -------------------------------------------------------

  it("generateAgoraTokenHandler rejects non-participants", async () => {
    const firestore = createFirestoreDouble();
    // No participant doc → should be rejected.
    const previousAppId = process.env.AGORA_APP_ID;
    const previousCert = process.env.AGORA_APP_CERTIFICATE;
    process.env.AGORA_APP_ID = "a".repeat(32);
    process.env.AGORA_APP_CERTIFICATE = "b".repeat(32);

    await assert.rejects(
      () => generateAgoraTokenHandler(
        makeRequest({channelName: "room-1", rtcUid: 42}, "user-1"),
        {firestore},
      ),
      (error) => error.code === "permission-denied",
    );

    // Restore env vars.
    if (previousAppId === undefined) delete process.env.AGORA_APP_ID;
    else process.env.AGORA_APP_ID = previousAppId;
    if (previousCert === undefined) delete process.env.AGORA_APP_CERTIFICATE;
    else process.env.AGORA_APP_CERTIFICATE = previousCert;
  });

  it("generateAgoraTokenHandler rejects banned participants", async () => {
    const firestore = createFirestoreDouble();
    // Write a banned participant doc.
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: true});

    const previousAppId = process.env.AGORA_APP_ID;
    const previousCert = process.env.AGORA_APP_CERTIFICATE;
    process.env.AGORA_APP_ID = "a".repeat(32);
    process.env.AGORA_APP_CERTIFICATE = "b".repeat(32);

    await assert.rejects(
      () => generateAgoraTokenHandler(
        makeRequest({channelName: "room-1", rtcUid: 42}, "user-1"),
        {firestore},
      ),
      (error) => error.code === "permission-denied",
    );

    if (previousAppId === undefined) delete process.env.AGORA_APP_ID;
    else process.env.AGORA_APP_ID = previousAppId;
    if (previousCert === undefined) delete process.env.AGORA_APP_CERTIFICATE;
    else process.env.AGORA_APP_CERTIFICATE = previousCert;
  });

  it("generateAgoraTokenHandler issues a token for a valid participant", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: false});

    const previousAppId = process.env.AGORA_APP_ID;
    const previousCert = process.env.AGORA_APP_CERTIFICATE;
    process.env.AGORA_APP_ID = "a".repeat(32);
    process.env.AGORA_APP_CERTIFICATE = "b".repeat(32);

    const result = await generateAgoraTokenHandler(
      makeRequest({channelName: "room-1", rtcUid: 42}, "user-1"),
      {firestore},
    );

    assert.equal(typeof result.token, "string");
    assert.ok(result.token.length > 0);
    assert.equal(result.issuedForUid, "user-1");

    if (previousAppId === undefined) delete process.env.AGORA_APP_ID;
    else process.env.AGORA_APP_ID = previousAppId;
    if (previousCert === undefined) delete process.env.AGORA_APP_CERTIFICATE;
    else process.env.AGORA_APP_CERTIFICATE = previousCert;
  });

  // grabMic -----------------------------------------------------------------

  it("grabMicHandler rejects unauthenticated caller", async () => {
    await assert.rejects(
      () => grabMicHandler(makeRequest({roomId: "room-1"}, null)),
      (err) => err.code === "unauthenticated",
    );
  });

  it("grabMicHandler rejects caller who is not a room participant", async () => {
    const firestore = createFirestoreDouble();
    await assert.rejects(
      () => grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore}),
      (err) => err.code === "permission-denied",
    );
  });

  it("grabMicHandler rejects banned participant", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: true});
    await assert.rejects(
      () => grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore}),
      (err) => err.code === "permission-denied",
    );
  });

  it("grabMicHandler returns early for host without promoting", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "host", isBanned: false});
    const result = await grabMicHandler(
      makeRequest({roomId: "room-1"}, "user-1"), {firestore},
    );
    assert.deepEqual(result, {success: true});
    // Role should still be host — nothing changed.
    const snap = await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1").get();
    assert.equal(snap.data().role, "host");
  });

  it("grabMicHandler promotes caller to stage with no timer when policy is unlimited", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    await participantsCol.doc("user-1").set({userId: "user-1", role: "audience", isBanned: false});
    // No micTimerSeconds in policy → unlimited.
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1});

    await grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore});

    const snap = await participantsCol.doc("user-1").get();
    const data = snap.data();
    assert.equal(data.role, "stage");
    // micExpiresAt must be absent (deleted by FieldValue.delete()).
    assert.ok(data.micExpiresAt === undefined);
  });

  it("grabMicHandler stamps micExpiresAt when micTimerSeconds=30", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    await participantsCol.doc("user-1").set({userId: "user-1", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1, micTimerSeconds: 30});

    const before = Date.now();
    await grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore});
    const after = Date.now();

    const snap = await participantsCol.doc("user-1").get();
    const data = snap.data();
    assert.equal(data.role, "stage");
    assert.ok(data.micExpiresAt !== undefined && data.micExpiresAt !== null,
      "micExpiresAt should be set");
    const expiresMs = data.micExpiresAt.toMillis();
    assert.ok(expiresMs >= before + 30000, "micExpiresAt should be at least 30s in the future");
    assert.ok(expiresMs <= after + 30000 + 500, "micExpiresAt should not be more than ~30s in the future");
  });

  it("grabMicHandler stamps micExpiresAt when micTimerSeconds=60", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    await participantsCol.doc("user-1").set({userId: "user-1", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1, micTimerSeconds: 60});

    const before = Date.now();
    await grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore});
    const after = Date.now();

    const snap = await participantsCol.doc("user-1").get();
    const expiresMs = snap.data().micExpiresAt.toMillis();
    assert.ok(expiresMs >= before + 60000);
    assert.ok(expiresMs <= after + 60000 + 500);
  });

  it("grabMicHandler demotes existing stage holder when at micLimit", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    const activeMs = Date.now();
    // user-2 is current stage holder with a recent lastActiveAt.
    await participantsCol.doc("user-2").set({
      userId: "user-2", role: "stage", isBanned: false,
      lastActiveAt: {toMillis: () => activeMs},
    });
    await participantsCol.doc("user-1").set({userId: "user-1", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1});

    await grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore});

    const holderSnap = await participantsCol.doc("user-2").get();
    assert.equal(holderSnap.data().role, "member", "existing stage holder should be demoted");
    const callerSnap = await participantsCol.doc("user-1").get();
    assert.equal(callerSnap.data().role, "stage", "caller should be promoted");
  });

  it("grabMicHandler treats micExpiresAt-expired stage doc as stale and does not count it against the limit", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    const recentMs = Date.now();
    // user-2 is on stage but their timer expired.
    await participantsCol.doc("user-2").set({
      userId: "user-2", role: "stage", isBanned: false,
      lastActiveAt: {toMillis: () => recentMs},   // recent — not stale by time
      micExpiresAt: {toMillis: () => recentMs - 5000}, // expired 5 s ago
    });
    await participantsCol.doc("user-1").set({userId: "user-1", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1});

    await grabMicHandler(makeRequest({roomId: "room-1"}, "user-1"), {firestore});

    // Both users end up on stage is fine (user-2 is stale but still gets demoted in cleanup).
    // The important assertion: user-1 was promoted without being blocked.
    const callerSnap = await participantsCol.doc("user-1").get();
    assert.equal(callerSnap.data().role, "stage");
    // And user-2 should have been demoted as stale.
    const staleSnap = await participantsCol.doc("user-2").get();
    assert.equal(staleSnap.data().role, "member");
  });

  // inviteToMic -------------------------------------------------------------

  it("inviteToMicHandler rejects non-host caller", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("rooms").doc("room-1")
      .collection("participants").doc("user-1")
      .set({userId: "user-1", role: "audience", isBanned: false});
    await assert.rejects(
      () => inviteToMicHandler(
        makeRequest({roomId: "room-1", targetId: "user-2"}, "user-1"), {firestore},
      ),
      (err) => err.code === "permission-denied",
    );
  });

  it("inviteToMicHandler stamps micExpiresAt when micTimerSeconds is set", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    await participantsCol.doc("host-1").set({userId: "host-1", role: "host", isBanned: false});
    await participantsCol.doc("user-2").set({userId: "user-2", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1, micTimerSeconds: 30});

    const before = Date.now();
    await inviteToMicHandler(
      makeRequest({roomId: "room-1", targetId: "user-2"}, "host-1"), {firestore},
    );
    const after = Date.now();

    const snap = await participantsCol.doc("user-2").get();
    const data = snap.data();
    assert.equal(data.role, "stage");
    assert.ok(data.micExpiresAt !== undefined && data.micExpiresAt !== null);
    const expiresMs = data.micExpiresAt.toMillis();
    assert.ok(expiresMs >= before + 30000);
    assert.ok(expiresMs <= after + 30000 + 500);
  });

  it("inviteToMicHandler removes micExpiresAt when policy is unlimited", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    await participantsCol.doc("host-1").set({userId: "host-1", role: "host", isBanned: false});
    // user-2 had a previous timer — should be cleared.
    await participantsCol.doc("user-2").set({
      userId: "user-2", role: "audience", isBanned: false,
      micExpiresAt: {toMillis: () => Date.now() + 99999},
    });
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1}); // no micTimerSeconds

    await inviteToMicHandler(
      makeRequest({roomId: "room-1", targetId: "user-2"}, "host-1"), {firestore},
    );

    const snap = await participantsCol.doc("user-2").get();
    const data = snap.data();
    assert.equal(data.role, "stage");
    assert.ok(data.micExpiresAt === undefined, "micExpiresAt should be deleted for unlimited policy");
  });

  it("inviteToMicHandler treats micExpired stage doc as stale", async () => {
    const firestore = createFirestoreDouble();
    const participantsCol = firestore.collection("rooms").doc("room-1")
      .collection("participants");
    const recentMs = Date.now();
    await participantsCol.doc("host-1").set({userId: "host-1", role: "host", isBanned: false});
    await participantsCol.doc("user-3").set({
      userId: "user-3", role: "stage", isBanned: false,
      lastActiveAt: {toMillis: () => recentMs},
      micExpiresAt: {toMillis: () => recentMs - 1000}, // expired 1 s ago
    });
    await participantsCol.doc("user-2").set({userId: "user-2", role: "audience", isBanned: false});
    await firestore.collection("rooms").doc("room-1")
      .collection("policies").doc("settings").set({micLimit: 1});

    await inviteToMicHandler(
      makeRequest({roomId: "room-1", targetId: "user-2"}, "host-1"), {firestore},
    );

    const targetSnap = await participantsCol.doc("user-2").get();
    assert.equal(targetSnap.data().role, "stage");
    const staleSnap = await participantsCol.doc("user-3").get();
    assert.equal(staleSnap.data().role, "member", "expired stage holder should be demoted");
  });
});