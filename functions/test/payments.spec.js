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
  getCreatorSubscriptionOverviewHandler,
  saveCreatorSubscriptionOfferHandler,
  createCreatorSubscriptionCheckoutHandler,
  cancelCreatorSubscriptionHandler,
  handleCreatorSubscriptionCheckoutCompleted,
  handleCreatorSubscriptionChanged,
  handleCreatorSubscriptionInvoice,
  listCreatorSubscriptionMarketplaceHandler,
  publishCreatorSubscriberUpdateHandler,
  listCreatorSubscriberUpdatesHandler,
  reportCreatorSubscriberUpdateHandler,
  reconcileCreatorSubscriptionsHandler,
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
  const creatorSubscriptionSettings = new Map();
  const creatorSubscriptions = new Map();
  const creatorSubscriberUpdates = new Map();
  const creatorSubscriberUpdateReports = new Map();
  const notifications = new Map();
  const reports = new Map();

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
      case "creator_subscription_settings": return creatorSubscriptionSettings;
      case "creator_subscriptions": return creatorSubscriptions;
      case "creator_subscriber_updates": return creatorSubscriberUpdates;
      case "creator_subscriber_update_reports": return creatorSubscriberUpdateReports;
      case "notifications": return notifications;
      case "reports": return reports;
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
                case "in": return Array.isArray(value) && value.includes(data[field]);
                default: return true;
              }
            });

          return {
            async get() {
              return buildSnapshot(filterEntries());
            },
            limit(count) {
              return {
                async get() {
                  return buildSnapshot(filterEntries().slice(0, count));
                },
              };
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

describe("Creator subscriptions", () => {
  it("uses a production-safe checkout URL fallback while preserving overrides", () => {
    const originalCheckoutBaseUrl = process.env.CHECKOUT_BASE_URL;
    const originalPublicAppUrl = process.env.PUBLIC_APP_URL;
    try {
      delete process.env.CHECKOUT_BASE_URL;
      delete process.env.PUBLIC_APP_URL;
      assert.equal(getCheckoutBaseUrl(), "https://mixvy.app");

      process.env.PUBLIC_APP_URL = "https://public.example/";
      assert.equal(getCheckoutBaseUrl(), "https://public.example");

      process.env.CHECKOUT_BASE_URL = "https://checkout.example/";
      assert.equal(getCheckoutBaseUrl(), "https://checkout.example");
    } finally {
      if (originalCheckoutBaseUrl === undefined) {
        delete process.env.CHECKOUT_BASE_URL;
      } else {
        process.env.CHECKOUT_BASE_URL = originalCheckoutBaseUrl;
      }
      if (originalPublicAppUrl === undefined) {
        delete process.env.PUBLIC_APP_URL;
      } else {
        process.env.PUBLIC_APP_URL = originalPublicAppUrl;
      }
    }
  });

  function completeConnectStripe() {
    return {
      accounts: {
        async retrieve(accountId) {
          return {
            id: accountId,
            charges_enabled: true,
            payouts_enabled: true,
            details_submitted: true,
            country: "US",
          };
        },
      },
    };
  }

  async function seedCreatorOffer(firestore, creatorId = "creator-1") {
    await firestore.collection("stripe_connect_accounts").doc(creatorId).set({
      accountId: "acct_creator",
      chargesEnabled: true,
      payoutsEnabled: true,
      detailsSubmitted: true,
      onboardingComplete: true,
      country: "US",
    });
    await firestore.collection("creator_subscription_settings").doc(creatorId).set({
      creatorId,
      enabled: true,
      monthlyPriceCents: 599,
      currency: "usd",
      benefits: ["Subscriber badge", "Exclusive posts"],
    });
  }

  it("validates pricing and requires completed Connect onboarding when enabling", async () => {
    const firestore = createFirestoreDouble();

    await assert.rejects(
        () => saveCreatorSubscriptionOfferHandler(makeRequest({
          enabled: true,
          monthlyPriceCents: 298,
          benefits: [],
        }, "creator-price"), {firestore, stripeClient: completeConnectStripe()}),
        (error) => error?.code === "invalid-argument",
    );

    await firestore.collection("stripe_connect_accounts").doc("creator-incomplete").set({
      accountId: "acct_incomplete",
    });
    const incompleteStripe = {
      accounts: {
        async retrieve(accountId) {
          return {
            id: accountId,
            charges_enabled: true,
            payouts_enabled: false,
            details_submitted: true,
          };
        },
      },
    };
    await assert.rejects(
        () => saveCreatorSubscriptionOfferHandler(makeRequest({
          enabled: true,
          monthlyPriceCents: 299,
          benefits: ["Thanks"],
        }, "creator-incomplete"), {firestore, stripeClient: incompleteStripe}),
        (error) => error?.code === "failed-precondition",
    );
  });

  it("saves a normalized creator offer after Connect onboarding", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("stripe_connect_accounts").doc("creator-save").set({
      accountId: "acct_save",
    });

    const result = await saveCreatorSubscriptionOfferHandler(makeRequest({
      enabled: true,
      monthlyPriceCents: 999,
      benefits: ["  Exclusive posts  ", "Subscriber badge"],
    }, "creator-save"), {
      firestore,
      stripeClient: completeConnectStripe(),
    });

    assert.deepEqual(Object.keys(result).sort(), [
      "analytics",
      "connectStatus",
      "isOwner",
      "offer",
      "subscriberCount",
      "subscription",
    ]);
    assert.deepEqual(result.offer, {
      creatorId: "creator-save",
      enabled: true,
      monthlyPriceCents: 999,
      currency: "usd",
      benefits: ["Exclusive posts", "Subscriber badge"],
    });
    assert.equal(result.isOwner, true);
    assert.equal(result.connectStatus.onboardingComplete, true);
    assert.equal(result.subscription, null);
    assert.equal(result.subscriberCount, 0);
    const stored = await firestore.collection("creator_subscription_settings")
        .doc("creator-save").get();
    assert.equal(stored.data().platformFeePercent, 15);
    assert.equal(stored.data().currency, "usd");
  });

  it("creates monthly destination Checkout with a 15 percent fee", async () => {
    const firestore = createFirestoreDouble();
    await seedCreatorOffer(firestore);
    let capturedPayload;
    let capturedOptions;
    const stripeClient = {
      ...completeConnectStripe(),
      checkout: {
        sessions: {
          async create(payload, options) {
            capturedPayload = payload;
            capturedOptions = options;
            return {url: "https://checkout.stripe.test/session"};
          },
        },
      },
    };

    const result = await createCreatorSubscriptionCheckoutHandler(makeRequest({
      creatorId: "creator-1",
      idempotencyKey: "checkout-attempt-1",
    }, "subscriber-checkout"), {firestore, stripeClient});

    assert.equal(result.url, "https://checkout.stripe.test/session");
    assert.equal(capturedPayload.mode, "subscription");
    assert.equal(capturedPayload.line_items[0].price_data.unit_amount, 599);
    assert.deepEqual(capturedPayload.line_items[0].price_data.recurring, {
      interval: "month",
    });
    assert.equal(capturedPayload.subscription_data.application_fee_percent, 15);
    assert.equal(
        capturedPayload.subscription_data.transfer_data.destination,
        "acct_creator",
    );
    assert.deepEqual(capturedPayload.subscription_data.metadata, {
      productType: "creator_subscription",
      subscriberId: "subscriber-checkout",
      creatorId: "creator-1",
    });
    assert.match(capturedOptions.idempotencyKey, /checkout-attempt-1$/);
  });

  it("rejects self-subscription and duplicate active subscriptions", async () => {
    const firestore = createFirestoreDouble();
    await seedCreatorOffer(firestore, "creator-duplicate");

    await assert.rejects(
        () => createCreatorSubscriptionCheckoutHandler(makeRequest({
          creatorId: "creator-duplicate",
        }, "creator-duplicate"), {
          firestore,
          stripeClient: completeConnectStripe(),
        }),
        (error) => error?.code === "invalid-argument",
    );

    await firestore.collection("creator_subscriptions")
        .doc("subscriber-duplicate_creator-duplicate").set({
          subscriberId: "subscriber-duplicate",
          creatorId: "creator-duplicate",
          status: "active",
        });
    await assert.rejects(
        () => createCreatorSubscriptionCheckoutHandler(makeRequest({
          creatorId: "creator-duplicate",
        }, "subscriber-duplicate"), {
          firestore,
          stripeClient: completeConnectStripe(),
        }),
        (error) => error?.code === "already-exists",
    );
  });

  it("writes checkout lifecycle state once and applies subscription updates", async () => {
    const firestore = createFirestoreDouble();
    const subscription = {
      id: "sub_lifecycle",
      customer: "cus_lifecycle",
      status: "active",
      current_period_end: 1800000000,
      cancel_at_period_end: false,
      metadata: {
        productType: "creator_subscription",
        subscriberId: "subscriber-life",
        creatorId: "creator-life",
      },
    };
    const stripeClient = {
      subscriptions: {
        async retrieve() {
          return subscription;
        },
      },
    };
    const session = {
      id: "cs_lifecycle",
      subscription: "sub_lifecycle",
      customer: "cus_lifecycle",
      metadata: subscription.metadata,
    };

    const first = await handleCreatorSubscriptionCheckoutCompleted(session, {
      firestore,
      stripeClient,
      eventId: "evt_creator_checkout",
      eventType: "checkout.session.completed",
    });
    const replay = await handleCreatorSubscriptionCheckoutCompleted(session, {
      firestore,
      stripeClient,
      eventId: "evt_creator_checkout",
      eventType: "checkout.session.completed",
    });
    assert.equal(first.updated, true);
    assert.deepEqual(replay, {updated: false, reason: "deduplicated"});
    const startedNotification = await firestore.collection("notifications")
        .doc("evt_creator_checkout_creator_subscription_started_subscriber-life")
        .get();
    assert.equal(startedNotification.exists, true);

    const changed = await handleCreatorSubscriptionChanged({
      ...subscription,
      status: "canceled",
      cancel_at_period_end: false,
    }, {
      firestore,
      eventId: "evt_creator_deleted",
      eventType: "customer.subscription.deleted",
    });
    assert.equal(changed.updated, true);
    const stored = await firestore.collection("creator_subscriptions")
        .doc("subscriber-life_creator-life").get();
    assert.equal(stored.data().status, "canceled");
    assert.equal(stored.data().stripeCheckoutSessionId, "cs_lifecycle");
    const endedNotification = await firestore.collection("notifications")
        .doc("evt_creator_deleted_creator_subscription_ended_subscriber-life")
        .get();
    assert.equal(endedNotification.exists, true);
  });

  it("ignores unrelated subscription webhook objects", async () => {
    const result = await handleCreatorSubscriptionChanged({
      id: "sub_other",
      metadata: {productType: "premium_access"},
    }, {firestore: createFirestoreDouble(), eventId: "evt_other"});
    assert.deepEqual(result, {
      updated: false,
      reason: "not_creator_subscription",
    });
  });

  it("schedules safe cancellation only for the owning subscriber", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-cancel_creator-cancel").set({
          subscriberId: "subscriber-cancel",
          creatorId: "creator-cancel",
          stripeSubscriptionId: "sub_cancel",
          status: "active",
        });
    let updatePayload;
    const stripeClient = {
      subscriptions: {
        async retrieve() {
          return {
            id: "sub_cancel",
            customer: "cus_cancel",
            status: "active",
            current_period_end: 1800000100,
            cancel_at_period_end: false,
            metadata: {
              productType: "creator_subscription",
              subscriberId: "subscriber-cancel",
              creatorId: "creator-cancel",
            },
          };
        },
        async update(id, payload) {
          updatePayload = {id, ...payload};
          return {
            id,
            customer: "cus_cancel",
            status: "active",
            current_period_end: 1800000100,
            cancel_at_period_end: true,
            metadata: {
              productType: "creator_subscription",
              subscriberId: "subscriber-cancel",
              creatorId: "creator-cancel",
            },
          };
        },
      },
    };

    const result = await cancelCreatorSubscriptionHandler(makeRequest({
      creatorId: "creator-cancel",
    }, "subscriber-cancel"), {firestore, stripeClient});
    assert.deepEqual(Object.keys(result).sort(), [
      "analytics",
      "connectStatus",
      "isOwner",
      "offer",
      "subscriberCount",
      "subscription",
    ]);
    assert.equal(result.isOwner, false);
    assert.deepEqual(result.subscription, {
      status: "active",
      currentPeriodEnd: 1800000100,
      cancelAtPeriodEnd: true,
    });
    assert.equal(result.subscriberCount, 1);
    assert.deepEqual(updatePayload, {
      id: "sub_cancel",
      cancel_at_period_end: true,
    });
    const cancelNotification = await firestore.collection("notifications")
        .doc("creator_subscription_cancel_sub_cancel_subscriber-cancel").get();
    assert.equal(cancelNotification.exists, true);

    await assert.rejects(
        () => cancelCreatorSubscriptionHandler(makeRequest({
          creatorId: "creator-cancel",
        }, "other-subscriber"), {firestore, stripeClient}),
        (error) => error?.code === "not-found",
    );
  });

  it("returns the stable overview contract and hides account IDs from subscribers", async () => {
    const firestore = createFirestoreDouble();
    await seedCreatorOffer(firestore, "creator-overview");
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-overview_creator-overview").set({
          subscriberId: "subscriber-overview",
          creatorId: "creator-overview",
          status: "active",
          currentPeriodEnd: 1800000200,
          cancelAtPeriodEnd: false,
        });
    await firestore.collection("creator_subscriptions")
        .doc("former-subscriber_creator-overview").set({
          subscriberId: "former-subscriber",
          creatorId: "creator-overview",
          status: "canceled",
        });

    const overview = await getCreatorSubscriptionOverviewHandler(makeRequest({
      creatorId: "creator-overview",
    }, "subscriber-overview"), {firestore});

    assert.equal(overview.isOwner, false);
    assert.equal(overview.offer.monthlyPriceCents, 599);
    assert.equal(overview.connectStatus.onboardingComplete, true);
    assert.equal("accountId" in overview.connectStatus, false);
    assert.deepEqual(overview.subscription, {
      status: "active",
      currentPeriodEnd: 1800000200,
      cancelAtPeriodEnd: false,
    });
    assert.equal(overview.subscriberCount, 1);
    assert.equal(overview.analytics, null);
  });

  it("lists filtered marketplace offers with only safe creator identity", async () => {
    const firestore = createFirestoreDouble({
      "creator-market": {
        displayName: "Market Creator",
        username: "market",
        photoUrl: "https://images.example/creator.png",
      },
      "creator-disabled": {displayName: "Hidden Creator"},
    });
    await seedCreatorOffer(firestore, "creator-market");
    await firestore.collection("creator_subscription_settings")
        .doc("creator-disabled").set({
          creatorId: "creator-disabled",
          enabled: false,
          monthlyPriceCents: 499,
          benefits: ["Hidden"],
        });

    const result = await listCreatorSubscriptionMarketplaceHandler(makeRequest({
      search: "exclusive",
      minPriceCents: 500,
      maxPriceCents: 700,
    }, "market-browser"), {firestore});

    assert.deepEqual(Object.keys(result), ["creators"]);
    assert.equal(result.creators.length, 1);
    assert.deepEqual(Object.keys(result.creators[0]).sort(), [
      "avatarUrl",
      "creatorId",
      "displayName",
      "offer",
      "subscriberCount",
    ]);
    assert.equal(result.creators[0].displayName, "Market Creator");
    assert.equal(result.creators[0].offer.monthlyPriceCents, 599);
    assert.deepEqual(Object.keys(result.creators[0].offer).sort(), [
      "benefits",
      "creatorId",
      "currency",
      "enabled",
      "monthlyPriceCents",
    ]);
    assert.equal("accountId" in result.creators[0], false);
    assert.equal(JSON.stringify(result).includes("acct_creator"), false);
  });

  it("returns owner-only subscription analytics with safe recent activity", async () => {
    const firestore = createFirestoreDouble({
      "subscriber-analytics": {
        displayName: "Subscriber One",
        username: "subscriber_one",
      },
    });
    await seedCreatorOffer(firestore, "creator-analytics");
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-analytics_creator-analytics").set({
          subscriberId: "subscriber-analytics",
          creatorId: "creator-analytics",
          status: "active",
          cancelAtPeriodEnd: true,
          currentPeriodEnd: 1800000300,
          updatedAt: 200,
        });
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-trial_creator-analytics").set({
          subscriberId: "subscriber-trial",
          creatorId: "creator-analytics",
          status: "trialing",
          cancelAtPeriodEnd: false,
          updatedAt: 100,
        });

    const overview = await getCreatorSubscriptionOverviewHandler(makeRequest({
      creatorId: "creator-analytics",
    }, "creator-analytics"), {
      firestore,
      stripeClient: completeConnectStripe(),
    });

    assert.deepEqual({
      activeCount: overview.analytics.activeCount,
      cancelingCount: overview.analytics.cancelingCount,
      monthlyGrossCents: overview.analytics.monthlyGrossCents,
      estimatedPlatformFeeCents: overview.analytics.estimatedPlatformFeeCents,
      estimatedCreatorNetBeforeStripeCents:
        overview.analytics.estimatedCreatorNetBeforeStripeCents,
    }, {
      activeCount: 2,
      cancelingCount: 1,
      monthlyGrossCents: 1198,
      estimatedPlatformFeeCents: 180,
      estimatedCreatorNetBeforeStripeCents: 1018,
    });
    assert.deepEqual(Object.keys(overview.analytics).sort(), [
      "activeCount",
      "cancelingCount",
      "estimatedCreatorNetBeforeStripeCents",
      "estimatedPlatformFeeCents",
      "monthlyGrossCents",
      "recentSubscriberActivity",
    ]);
    assert.equal(
        overview.analytics.recentSubscriberActivity[0].subscriber.displayName,
        "Subscriber One",
    );
    assert.equal(
        "stripeSubscriptionId" in overview.analytics.recentSubscriberActivity[0],
        false,
    );
  });

  it("publishes, gates, lists, and reports subscriber updates", async () => {
    const firestore = createFirestoreDouble({
      "creator-updates": {displayName: "Update Creator"},
    });
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-updates_creator-updates").set({
          subscriberId: "subscriber-updates",
          creatorId: "creator-updates",
          status: "active",
        });

    await assert.rejects(
        () => publishCreatorSubscriberUpdateHandler(makeRequest({
          text: "spam offer",
        }, "creator-updates"), {firestore}),
        (error) => error?.code === "invalid-argument",
    );

    const published = await publishCreatorSubscriberUpdateHandler(makeRequest({
      text: "New behind-the-scenes post is ready.",
    }, "creator-updates"), {firestore});
    assert.deepEqual(Object.keys(published.update).sort(), [
      "createdAt",
      "creatorId",
      "id",
      "text",
    ]);
    assert.equal(typeof published.update.createdAt, "string");
    const updateId = published.update.id;
    const notification = await firestore.collection("notifications")
        .doc(`creator_update_${updateId}_subscriber-updates`).get();
    assert.equal(notification.exists, true);
    assert.equal(notification.data().type, "creator_subscriber_update");

    const listed = await listCreatorSubscriberUpdatesHandler(makeRequest({
      creatorId: "creator-updates",
    }, "subscriber-updates"), {firestore});
    assert.equal(listed.updates.length, 1);
    assert.deepEqual(Object.keys(listed.updates[0]).sort(), [
      "createdAt",
      "creatorId",
      "id",
      "text",
    ]);
    assert.equal(listed.updates[0].id, updateId);
    assert.equal(listed.updates[0].text, "New behind-the-scenes post is ready.");
    assert.equal(typeof listed.updates[0].createdAt, "string");

    await assert.rejects(
        () => listCreatorSubscriberUpdatesHandler(makeRequest({
          creatorId: "creator-updates",
        }, "non-subscriber"), {firestore}),
        (error) => error?.code === "permission-denied",
    );

    const report = await reportCreatorSubscriberUpdateHandler(makeRequest({
      updateId,
      reason: "Misleading",
      details: "Please review the claim.",
    }, "subscriber-updates"), {firestore});
    const duplicate = await reportCreatorSubscriberUpdateHandler(makeRequest({
      updateId,
      reason: "Misleading",
      details: "Please review the claim.",
    }, "subscriber-updates"), {firestore});
    assert.deepEqual(report, {reported: true, deduplicated: false});
    assert.deepEqual(duplicate, {reported: true, deduplicated: true});
    const moderationReport = await firestore.collection("reports")
        .doc(`${updateId}_subscriber-updates`).get();
    assert.deepEqual(moderationReport.data(), {
      id: `${updateId}_subscriber-updates`,
      reporterUserId: "subscriber-updates",
      targetId: updateId,
      targetType: "message",
      reason: "Misleading",
      details: "Please review the claim.",
      status: "open",
      createdAt: moderationReport.data().createdAt,
    });
    assert.equal(typeof moderationReport.data().createdAt, "string");
  });

  it("handles invoice failures idempotently and emits lifecycle notifications", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-invoice_creator-invoice").set({
          subscriberId: "subscriber-invoice",
          creatorId: "creator-invoice",
          stripeSubscriptionId: "sub_invoice",
          status: "active",
          terminal: false,
        });
    let stripeStatus = "past_due";
    const stripeClient = {
      subscriptions: {
        async retrieve() {
          return {
            id: "sub_invoice",
            customer: "cus_invoice",
            status: stripeStatus,
            current_period_end: 1800000400,
            cancel_at_period_end: false,
            metadata: {
              productType: "creator_subscription",
              subscriberId: "subscriber-invoice",
              creatorId: "creator-invoice",
            },
          };
        },
      },
    };
    const deps = {
      firestore,
      stripeClient,
      eventId: "evt_invoice_failed",
      eventType: "invoice.payment_failed",
    };
    const first = await handleCreatorSubscriptionInvoice({
      subscription: "sub_invoice",
    }, deps);
    const replay = await handleCreatorSubscriptionInvoice({
      subscription: "sub_invoice",
    }, deps);
    assert.equal(first.updated, true);
    assert.deepEqual(replay, {updated: false, reason: "deduplicated"});
    const stored = await firestore.collection("creator_subscriptions")
        .doc("subscriber-invoice_creator-invoice").get();
    assert.equal(stored.data().status, "past_due");
    const notification = await firestore.collection("notifications")
        .doc("evt_invoice_failed_creator_subscription_payment_failed_subscriber-invoice")
        .get();
    assert.equal(notification.exists, true);

    stripeStatus = "active";
    const paid = await handleCreatorSubscriptionInvoice({
      subscription: "sub_invoice",
    }, {
      firestore,
      stripeClient,
      eventId: "evt_invoice_paid",
      eventType: "invoice.paid",
    });
    assert.equal(paid.updated, true);
    const restored = await firestore.collection("creator_subscriptions")
        .doc("subscriber-invoice_creator-invoice").get();
    assert.equal(restored.data().status, "active");
    const restoredNotification = await firestore.collection("notifications")
        .doc("evt_invoice_paid_creator_subscription_payment_restored_subscriber-invoice")
        .get();
    assert.equal(restoredNotification.exists, true);
  });

  it("reconciles only nonterminal subscriptions without granting on lookup failure", async () => {
    const firestore = createFirestoreDouble();
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-drift_creator-drift").set({
          subscriberId: "subscriber-drift",
          creatorId: "creator-drift",
          stripeSubscriptionId: "sub_drift",
          status: "active",
          terminal: false,
        });
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-failed_creator-failed").set({
          subscriberId: "subscriber-failed",
          creatorId: "creator-failed",
          stripeSubscriptionId: "sub_failed",
          status: "past_due",
          terminal: false,
        });
    await firestore.collection("creator_subscriptions")
        .doc("subscriber-terminal_creator-terminal").set({
          subscriberId: "subscriber-terminal",
          creatorId: "creator-terminal",
          stripeSubscriptionId: "sub_terminal",
          status: "canceled",
          terminal: true,
        });
    const retrieved = [];
    const stripeClient = {
      subscriptions: {
        async retrieve(subscriptionId) {
          retrieved.push(subscriptionId);
          if (subscriptionId === "sub_failed") throw new Error("Stripe unavailable");
          return {
            id: subscriptionId,
            customer: "cus_drift",
            status: "canceled",
            current_period_end: 1800000500,
            cancel_at_period_end: false,
            metadata: {
              productType: "creator_subscription",
              subscriberId: "subscriber-drift",
              creatorId: "creator-drift",
            },
          };
        },
      },
    };

    const result = await reconcileCreatorSubscriptionsHandler({
      firestore,
      stripeClient,
    });
    assert.deepEqual(result, {checked: 2, updated: 1, failed: 1});
    assert.deepEqual(retrieved.sort(), ["sub_drift", "sub_failed"]);
    const drifted = await firestore.collection("creator_subscriptions")
        .doc("subscriber-drift_creator-drift").get();
    assert.equal(drifted.data().status, "canceled");
    assert.equal(drifted.data().terminal, true);
    const failed = await firestore.collection("creator_subscriptions")
        .doc("subscriber-failed_creator-failed").get();
    assert.equal(failed.data().status, "past_due");
  });
});