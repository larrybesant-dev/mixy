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

/* --- REST OF YOUR TESTS UNCHANGED --- */