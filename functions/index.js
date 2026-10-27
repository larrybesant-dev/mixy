const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest: onRequestV1} = require("firebase-functions/v1/https");
const functionsV1 = require("firebase-functions/v1");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const {RtcTokenBuilder, RtcRole} = require("agora-access-token");
const nodeFetch = require("node-fetch");
const {
  STRIPE_SECRET,
  STRIPE_WEBHOOK_SECRET,
  AGORA_APP_ID,
  AGORA_APP_CERTIFICATE,
  METERED_API_KEY,
} = require("./params");
const {
  buildDatingProfile,
  distanceBetweenKm,
  isCompatiblePair,
} = require("./dating_matching");

admin.initializeApp();

// firebase-tools may provide FIREBASE_CONFIG without databaseURL in some
// deploy/analyze contexts. RTDB trigger registration requires this value.
(() => {
  try {
    const rawConfig = process.env.FIREBASE_CONFIG || "{}";
    const parsedConfig = JSON.parse(rawConfig);
    const projectId = parsedConfig.projectId || process.env.GCLOUD_PROJECT;
    if (!parsedConfig.databaseURL && projectId) {
      parsedConfig.databaseURL =
        `https://${projectId}-default-rtdb.firebaseio.com`;
      process.env.FIREBASE_CONFIG = JSON.stringify(parsedConfig);
    }
  } catch (error) {
    logger.warn("Unable to normalize FIREBASE_CONFIG for RTDB triggers", {
      error: String(error),
    });
  }
})();

const ENABLE_RTDB_PRESENCE_SYNC =
  String(process.env.ENABLE_RTDB_PRESENCE_SYNC || "").toLowerCase() === "true";

const DEFAULT_ICE_SERVERS = [
  {
    urls: [
      "stun:stun.l.google.com:19302",
      "stun:stun1.l.google.com:19302",
    ],
  },
];
const TURN_CACHE_TTL_MS = 60 * 1000;
let cachedTurnIceServers = null;
let cachedTurnIceServersFetchedAt = 0;

let _stripe;
function getStripe() {
  if (!_stripe) {
    const key = process.env.STRIPE_SECRET;
    if (!key) throw new HttpsError("internal", "Stripe is not configured.");
    _stripe = new Stripe(key);
  }
  return _stripe;
}

const CHECKOUT_PRODUCTS = {
  premium_access: {
    unitAmount: 500,
    currency: "usd",
    name: "MixVy Premium",
    metadata: {
      productType: "premium_access",
    },
  },
  coins_70: {
    unitAmount: 99,
    currency: "usd",
    name: "MixVy Coins - 70",
    metadata: {
      productType: "coin_package",
      packageId: "coins_70",
      coins: "70",
    },
  },
  coins_350: {
    unitAmount: 499,
    currency: "usd",
    name: "MixVy Coins - 350",
    metadata: {
      productType: "coin_package",
      packageId: "coins_350",
      coins: "350",
    },
  },
  coins_1400: {
    unitAmount: 1999,
    currency: "usd",
    name: "MixVy Coins - 1500",
    metadata: {
      productType: "coin_package",
      packageId: "coins_1400",
      coins: "1500",
    },
  },
  coins_3500: {
    unitAmount: 4999,
    currency: "usd",
    name: "MixVy Coins - 4000",
    metadata: {
      productType: "coin_package",
      packageId: "coins_3500",
      coins: "4000",
    },
  },
};
const CREATOR_SUBSCRIPTION_MIN_PRICE_CENTS = 299;
const CREATOR_SUBSCRIPTION_MAX_PRICE_CENTS = 999;
const CREATOR_SUBSCRIPTION_PLATFORM_FEE_PERCENT = 15;
const ACTIVE_CREATOR_SUBSCRIPTION_STATUSES = new Set(["active", "trialing"]);
const TERMINAL_CREATOR_SUBSCRIPTION_STATUSES = new Set([
  "canceled",
  "incomplete_expired",
  "unpaid",
]);
const NONTERMINAL_CREATOR_SUBSCRIPTION_STATUSES = [
  "active",
  "trialing",
  "past_due",
  "incomplete",
  "paused",
];

const db = admin.firestore();
const CHAT_RETENTION_BATCH_LIMIT = 400;
const OPERATIONAL_SIGNAL_CODES = new Set([
  "launch_auth_failure",
  "launch_stale_room_navigation",
  "launch_messaging_freshness",
  "launch_rtc_recovery_exhausted",
  "launch_payment_entitlement_mismatch",
  "launch_uncaught_error",
]);

function sanitizeOperationalMetadata(metadata) {
  if (!metadata || typeof metadata !== "object" || Array.isArray(metadata)) return {};
  return Object.fromEntries(Object.entries(metadata).slice(0, 10).map(([key, value]) => {
    const safeKey = String(key).replace(/[^a-zA-Z0-9_]/g, "_").slice(0, 40);
    const safeValue = ["string", "number", "boolean"].includes(typeof value) ? value : String(value);
    return [safeKey, typeof safeValue === "string" ? safeValue.slice(0, 120) : safeValue];
  }));
}

async function recordOperationalSignalHandler(request) {
  const code = typeof request.data?.code === "string" ? request.data.code.trim() : "";
  if (!OPERATIONAL_SIGNAL_CODES.has(code)) {
    throw new HttpsError("invalid-argument", "Unknown operational signal code.");
  }
  if (!request.auth && !["launch_auth_failure", "launch_uncaught_error"].includes(code)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const actor = request.auth?.uid || request.rawRequest?.ip || "anonymous";
  enforceRateLimit("recordOperationalSignal", actor);
  logger.warn("mixvy_launch_signal", {
    code,
    result: typeof request.data?.result === "string" ? request.data.result.slice(0, 80) : null,
    authenticated: Boolean(request.auth),
    uid: request.auth?.uid || null,
    metadata: sanitizeOperationalMetadata(request.data?.metadata),
  });
  return {accepted: true};
}

exports.recordOperationalSignal = onCall(async (request) =>
  recordOperationalSignalHandler(request));

function buildMessagePreview(content) {
  const normalized = typeof content === "string" ? content.trim() : "";
  if (!normalized) return null;
  return normalized.length <= 140 ? normalized : `${normalized.slice(0, 137)}...`;
}

async function rebuildConversationSummary(conversationId) {
  const conversationRef = db.collection("conversations").doc(conversationId);
  const conversationSnap = await conversationRef.get();
  if (!conversationSnap.exists) return;

  let query = conversationRef
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(50);

  let latestMessage = null;
  let pageSnap = await query.get();
  while (!pageSnap.empty && latestMessage == null) {
    for (const doc of pageSnap.docs) {
      const data = doc.data() || {};
      if (data.isDeleted === true) continue;
      latestMessage = {id: doc.id, data};
      break;
    }

    if (latestMessage != null) break;

    query = conversationRef
      .collection("messages")
      .orderBy("createdAt", "desc")
      .startAfter(pageSnap.docs[pageSnap.docs.length - 1])
      .limit(50);
    pageSnap = await query.get();
  }

  if (latestMessage == null) {
    await conversationRef.update({
      lastMessageId: null,
      lastMessagePreview: null,
      lastMessageSenderId: null,
      lastMessageAt: null,
    });
    return;
  }

  const data = latestMessage.data;
  const previewSource = typeof data.content === "string" ? data.content : data.text;
  await conversationRef.update({
    lastMessageId: latestMessage.id,
    lastMessagePreview: buildMessagePreview(previewSource),
    lastMessageSenderId: data.senderId || null,
    lastMessageAt: data.createdAt || data.sentAt || null,
  });
}

const RATE_LIMITS = {
  createPaymentIntent: {windowMs: 60 * 1000, maxRequests: 12},
  recordStripePaymentSuccess: {windowMs: 60 * 1000, maxRequests: 20},
  generateReferralCode: {windowMs: 60 * 1000, maxRequests: 12},
  redeemReferralCode: {windowMs: 60 * 1000, maxRequests: 12},
  sendCoinTransfer: {windowMs: 60 * 1000, maxRequests: 18},
  requestCoinTransfer: {windowMs: 60 * 1000, maxRequests: 18},
  sendRoomGift: {windowMs: 60 * 1000, maxRequests: 30},
  getStripeConnectStatus: {windowMs: 60 * 1000, maxRequests: 40},
  createStripeConnectOnboardingLink: {windowMs: 60 * 1000, maxRequests: 10},
  createStripeConnectDashboardLink: {windowMs: 60 * 1000, maxRequests: 20},
  getCreatorSubscriptionOverview: {windowMs: 60 * 1000, maxRequests: 40},
  saveCreatorSubscriptionOffer: {windowMs: 60 * 1000, maxRequests: 12},
  createCreatorSubscriptionCheckout: {windowMs: 60 * 1000, maxRequests: 12},
  cancelCreatorSubscription: {windowMs: 60 * 1000, maxRequests: 12},
  listCreatorSubscriptionMarketplace: {windowMs: 60 * 1000, maxRequests: 30},
  publishCreatorSubscriberUpdate: {windowMs: 60 * 1000, maxRequests: 8},
  listCreatorSubscriberUpdates: {windowMs: 60 * 1000, maxRequests: 30},
  reportCreatorSubscriberUpdate: {windowMs: 60 * 1000, maxRequests: 12},
  generateAgoraToken: {windowMs: 60 * 1000, maxRequests: 30},
  generateTurnCredentials: {windowMs: 60 * 1000, maxRequests: 30},
  requestRefund: {windowMs: 60 * 1000, maxRequests: 12},
  grabMic: {windowMs: 60 * 1000, maxRequests: 20},
  inviteToMic: {windowMs: 60 * 1000, maxRequests: 30},
};

const rateLimitState = new Map();

const HIGH_RISK_TERMS = [
  "scam",
  "fraud",
  "chargeback",
  "threat",
  "kill",
  "blackmail",
  "extort",
  "hate",
  "violent",
  "weapon",
  "underage",
  "exploit",
  "abuse",
];

const MEDIUM_RISK_TERMS = [
  "spam",
  "harass",
  "bully",
  "nsfw",
  "bot",
  "fake",
  "impersonat",
  "offensive",
  "slur",
];

const REFERRAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function enforceRateLimit(functionName, uid) {
  const config = RATE_LIMITS[functionName];
  if (!config) {
    return;
  }

  const now = Date.now();
  const key = `${functionName}:${uid}`;
  const entry = rateLimitState.get(key);

  if (!entry || now - entry.windowStart >= config.windowMs) {
    rateLimitState.set(key, {windowStart: now, count: 1});
    return;
  }

  if (entry.count >= config.maxRequests) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many requests. Please wait a moment and try again.",
    );
  }

  entry.count += 1;
}

function parseIdField(value, fieldName) {
  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  if (normalized.length > 128) {
    throw new HttpsError("invalid-argument", `${fieldName} is too long.`);
  }
  return normalized;
}

function classifyModerationText(reason = "", details = "") {
  const sourceText = `${reason} ${details}`.toLowerCase();
  const matchedHigh = HIGH_RISK_TERMS.filter((term) => sourceText.includes(term));
  const matchedMedium = MEDIUM_RISK_TERMS.filter((term) => sourceText.includes(term));

  const score = matchedHigh.length * 3 + matchedMedium.length;
  let riskLevel = "low";
  if (matchedHigh.length > 0 || score >= 5) {
    riskLevel = "high";
  } else if (matchedMedium.length > 0 || score >= 2) {
    riskLevel = "medium";
  }

  return {
    riskLevel,
    score,
    matchedTerms: [...new Set([...matchedHigh, ...matchedMedium])],
    needsManualReview: riskLevel !== "low",
  };
}

function buildModerationReviewPayload(reportData = {}) {
  const reason = typeof reportData.reason === "string" ? reportData.reason : "";
  const details = typeof reportData.details === "string" ? reportData.details : "";
  const classification = classifyModerationText(reason, details);

  return {
    moderationReview: {
      riskLevel: classification.riskLevel,
      score: classification.score,
      matchedTerms: classification.matchedTerms,
      needsManualReview: classification.needsManualReview,
      classifiedAt: new Date().toISOString(),
      classifierVersion: "v1-baseline",
    },
  };
}

function getCheckoutBaseUrl() {
  const baseUrl = process.env.CHECKOUT_BASE_URL ||
    process.env.PUBLIC_APP_URL ||
    "https://mixvy.app";
  return baseUrl.endsWith("/") ? baseUrl.slice(0, -1) : baseUrl;
}

function resolveCheckoutProduct(value, fallbackKey = "premium_access") {
  if (value == null) {
    return CHECKOUT_PRODUCTS[fallbackKey];
  }

  const normalized = typeof value === "string" ? value.trim() : "";
  if (!normalized) {
    return CHECKOUT_PRODUCTS[fallbackKey];
  }

  const product = CHECKOUT_PRODUCTS[normalized];
  if (!product) {
    throw new HttpsError("invalid-argument", "Unknown checkout package.");
  }

  return product;
}

function buildCheckoutSessionPayload({uid, packageId}) {
  const product = resolveCheckoutProduct(packageId);
  const checkoutBaseUrl = getCheckoutBaseUrl();

  return {
    payment_method_types: ["card"],
    mode: "payment",
    line_items: [
      {
        price_data: {
          currency: product.currency,
          product_data: {name: product.name},
          unit_amount: product.unitAmount,
        },
        quantity: 1,
      },
    ],
    metadata: {
      userId: uid,
      ...product.metadata,
    },
    success_url: `${checkoutBaseUrl}/vip?checkout=success&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${checkoutBaseUrl}/vip?checkout=cancel`,
  };
}

function mapStripeConnectAccount(account) {
  const chargesEnabled = !!account.charges_enabled;
  const payoutsEnabled = !!account.payouts_enabled;
  const detailsSubmitted = !!account.details_submitted;

  return {
    accountId: account.id,
    chargesEnabled,
    payoutsEnabled,
    detailsSubmitted,
    onboardingComplete: chargesEnabled && payoutsEnabled && detailsSubmitted,
    country: account.country || "US",
  };
}

async function ensureStripeConnectAccount(uid, deps = {}) {
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const accountRef = firestore.collection("stripe_connect_accounts").doc(uid);
  const accountSnap = await accountRef.get();

  let accountId = accountSnap.exists ? accountSnap.data().accountId : null;
  let account;

  if (accountId) {
    account = await stripeClient.accounts.retrieve(accountId);
  } else {
    account = await stripeClient.accounts.create({
      type: "express",
      country: process.env.STRIPE_CONNECT_COUNTRY || "US",
      capabilities: {
        card_payments: {requested: true},
        transfers: {requested: true},
      },
      business_type: "individual",
      metadata: {
        firebaseUid: uid,
      },
    });
    accountId = account.id;
  }

  const mapped = mapStripeConnectAccount(account);
  const payload = {
    ...mapped,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!accountSnap.exists) {
    payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await accountRef.set(payload, {merge: true});

  return mapped;
}

async function createCheckoutSessionHandler(req, res, deps = {}) {
  const stripeClient = deps.stripeClient || getStripe();

  const authHeader = req.headers && req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).send("Unauthorized - missing auth token");
  }

  let uid;
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.substring(7));
    uid = decoded.uid;
  } catch (error) {
    return res.status(401).send("Unauthorized - invalid auth token");
  }

  try {
    const session = await stripeClient.checkout.sessions.create(
      buildCheckoutSessionPayload({
        uid,
        packageId: req.body && req.body.packageId,
      }),
    );
    return res.json({url: session.url});
  } catch (error) {
    console.error(error);
    return res.status(500).send("Checkout session could not be created.");
  }
}

async function createCheckoutSessionCallableHandler(request, deps = {}) {
  const uid = requireAuth(request);
  const stripeClient = deps.stripeClient || getStripe();

  const session = await stripeClient.checkout.sessions.create(
    buildCheckoutSessionPayload({
      uid,
      packageId: request.data && request.data.packageId,
    }),
  );

  return {url: session.url};
}

async function ensureUserExists(uid, firestore = db, defaultBalance = 100) {
  const userRef = firestore.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    await userRef.set({
      uid,
      username: null,
      displayName: null,
      photoUrl: null,
      balance: defaultBalance,
      isComplete: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await firestore.collection("wallets").doc(uid).set({
    userId: uid,
    coinBalance: defaultBalance,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return userRef;
}

function getCoinBalance(data) {
  return Number((data && (data.balance ?? data.coinBalance)) || 0);
}

function syncWalletCoinBalance(txn, firestore, uid, coinBalance) {
  const walletRef = firestore.collection("wallets").doc(uid);
  txn.set(walletRef, {
    userId: uid,
    coinBalance,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

function writeWalletLedgerEntry(txn, firestore, payload) {
  const entryRef = firestore.collection("wallet_ledger").doc();
  txn.set(entryRef, {
    id: entryRef.id,
    ...payload,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return entryRef;
}

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const uid = request.auth.uid;
  if (typeof uid !== "string" || uid.trim().length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid.trim();
}

function parsePositiveAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Amount must be greater than zero.");
  }
  if (amount > 50000) {
    throw new HttpsError("invalid-argument", "Amount exceeds the maximum allowed value.");
  }
  return amount;
}

function buildReferralCode() {
  let suffix = "";
  for (let index = 0; index < 6; index += 1) {
    const randomIndex = Math.floor(Math.random() * REFERRAL_ALPHABET.length);
    suffix += REFERRAL_ALPHABET[randomIndex];
  }
  return `MXVY-${suffix}`;
}

function parseOptionalIdempotencyKey(value) {
  if (value == null) {
    return null;
  }
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "idempotencyKey must be a string when provided.",
    );
  }
  const normalized = value.trim();
  if (!normalized) {
    return null;
  }
  if (!/^[a-zA-Z0-9_\-:.]{8,120}$/.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "idempotencyKey format is invalid.",
    );
  }
  return normalized;
}

function buildIdempotentTransactionDocId(prefix, uid, idempotencyKey) {
  const raw = `${prefix}_${uid}_${idempotencyKey}`;
  return raw.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 180);
}

async function createPaymentIntentHandler(request, deps = {}) {
  const senderId = requireAuth(request);
  enforceRateLimit("createPaymentIntent", senderId);
  const recipientId = parseIdField(
    request.data && request.data.recipientId,
    "recipientId",
  );
  const currency = request.data && request.data.currency;
  const amount = parsePositiveAmount(request.data && request.data.amount);
  const idempotencyKey = parseOptionalIdempotencyKey(
    request.data && request.data.idempotencyKey,
  );
  const stripeClient = deps.stripeClient || getStripe();

  const normalizedCurrency = typeof currency === "string" ? currency.toLowerCase() : "usd";
  const paymentIntentRequest = {
    amount: Math.round(amount * 100),
    currency: normalizedCurrency,
    metadata: {
      senderId,
      recipientId,
      amount: amount.toString(),
      kind: "mixvy_coin_payment",
      idempotencyKey: idempotencyKey || "",
    },
    automatic_payment_methods: {
      enabled: true,
    },
  };
  const stripeRequestOptions = idempotencyKey ? {idempotencyKey} : undefined;
  const paymentIntent = await stripeClient.paymentIntents.create(
    paymentIntentRequest,
    stripeRequestOptions,
  );

  return {
    clientSecret: paymentIntent.client_secret,
    paymentIntentId: paymentIntent.id,
    idempotencyKey,
  };
}

exports.createPaymentIntent = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  createPaymentIntentHandler(request),
);

function shouldSkipStripePaymentVerification(deps = {}) {
  if (deps.forceStripeVerification === true) {
    return false;
  }

  if (deps.skipStripeVerification === true) {
    return true;
  }

  const configuredSecret = process.env.STRIPE_SECRET;
  return !configuredSecret || configuredSecret === "sk_test_dummy";
}

async function validateStripePaymentIntent({
  stripeClient,
  paymentIntentId,
  senderId,
  recipientId,
  amount,
}) {
  const paymentIntent = await stripeClient.paymentIntents.retrieve(paymentIntentId);
  if (!paymentIntent || !paymentIntent.id) {
    throw new HttpsError("failed-precondition", "Payment intent not found.");
  }

  const status = String(paymentIntent.status || "");
  if (
    status !== "succeeded" &&
    status !== "processing" &&
    status !== "requires_capture"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Payment intent is not in a payable state.",
    );
  }

  const metadata = paymentIntent.metadata || {};
  const metadataSender = typeof metadata.senderId === "string" ? metadata.senderId : "";
  const metadataRecipient =
    typeof metadata.recipientId === "string" ? metadata.recipientId : "";
  const metadataAmount = Number(metadata.amount || 0);

  if (metadataSender !== senderId || metadataRecipient !== recipientId) {
    throw new HttpsError(
      "permission-denied",
      "Payment intent participants do not match authenticated request.",
    );
  }

  if (Math.abs(metadataAmount - amount) > 0.0001) {
    throw new HttpsError(
      "failed-precondition",
      "Payment amount does not match payment intent metadata.",
    );
  }

  const expectedAmountCents = Math.round(amount * 100);
  const intentAmountCents = Number(paymentIntent.amount || 0);
  if (intentAmountCents !== expectedAmountCents) {
    throw new HttpsError(
      "failed-precondition",
      "Payment amount does not match payment intent amount.",
    );
  }
}

async function recordStripePaymentSuccessHandler(request, deps = {}) {
  const senderId = requireAuth(request);
  enforceRateLimit("recordStripePaymentSuccess", senderId);
  const recipientId = parseIdField(
    request.data && request.data.recipientId,
    "recipientId",
  );
  const amount = parsePositiveAmount(request.data && request.data.amount);
  const paymentIntentId = parseIdField(
    request.data && request.data.paymentIntentId,
    "paymentIntentId",
  );
  const idempotencyKey = parseOptionalIdempotencyKey(
    request.data && request.data.idempotencyKey,
  );
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();

  const transactionRef = idempotencyKey
    ? firestore.collection("transactions").doc(
      buildIdempotentTransactionDocId("stripe", senderId, idempotencyKey),
    )
    : firestore.collection("transactions").doc();

  const existingSnap = await transactionRef.get();
  if (existingSnap.exists) {
    return {transactionId: transactionRef.id, deduplicated: true};
  }

  if (!shouldSkipStripePaymentVerification(deps)) {
    await validateStripePaymentIntent({
      stripeClient,
      paymentIntentId,
      senderId,
      recipientId,
      amount,
    });
  }

  await transactionRef.set({
    id: transactionRef.id,
    senderId,
    receiverId: recipientId,
    participants: [senderId, recipientId],
    amount,
    timestamp: new Date().toISOString(),
    status: "completed",
    source: "stripe",
    paymentIntentId,
    idempotencyKey,
  });

  return {transactionId: transactionRef.id, deduplicated: false};
}

async function handleCheckoutSessionCompleted(session, deps = {}) {
  const firestore = deps.firestore || db;
  const eventId = typeof deps.eventId === "string" ? deps.eventId : null;
  const eventType = typeof deps.eventType === "string" ? deps.eventType : null;
  const paymentStatus = String(session.payment_status || "").toLowerCase();
  const userId = session.metadata && session.metadata.userId;
  if (!userId || !session.id) {
    return {creditedCoins: 0, premiumApplied: false, deduplicated: false};
  }

  const productType = session.metadata && session.metadata.productType;
  const coins = Number((session.metadata && session.metadata.coins) || 0);
  const webhookEventRef = firestore.collection("stripe_webhook_events").doc(session.id);
  // Secondary dedup keyed on Stripe event ID so that replays carrying a
  // different event.id but the same session.id are caught in both directions.
  const eventDedupRef = eventId
    ? firestore.collection("stripe_webhook_events").doc(`event_${eventId}`)
    : null;
  const entitlementEventRef = firestore.collection("entitlement_events").doc(`stripe_${session.id}`);

  return firestore.runTransaction(async (txn) => {
    const reads = [txn.get(webhookEventRef)];
    if (eventDedupRef) reads.push(txn.get(eventDedupRef));
    const [eventSnap, eventDedupSnap] = await Promise.all(reads);
    if (eventSnap.exists || (eventDedupSnap && eventDedupSnap.exists)) {
      return {creditedCoins: 0, premiumApplied: false, deduplicated: true};
    }

    const userRef = firestore.collection("users").doc(userId);
    const userSnap = await txn.get(userRef);
    const currentBalance = getCoinBalance(userSnap.data());
    let creditedCoins = 0;
    let premiumApplied = false;

    if (productType === "coin_package" && coins > 0 && paymentStatus === "paid") {
      const nextBalance = currentBalance + coins;
      creditedCoins = coins;
      txn.set(userRef, {
        uid: userId,
        balance: nextBalance,
        coinBalance: nextBalance,
      }, {merge: true});
      syncWalletCoinBalance(txn, firestore, userId, nextBalance);
    } else if (productType === "premium_access" && paymentStatus === "paid") {
      premiumApplied = true;
      txn.set(userRef, {
        entitlement: "vip",
        entitlements: {
          vip: {
            active: true,
            source: "stripe_checkout",
            sessionId: session.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        isPremium: true,
        vipLevel: 1,
        membershipLevel: "vip",
        premiumSince: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      txn.set(entitlementEventRef, {
        id: entitlementEventRef.id,
        userId,
        sessionId: session.id,
        type: "vip_purchase",
        source: "stripe_checkout",
        productType: productType || null,
        paymentStatus,
        eventId,
        eventType,
        amountTotal: Number(session.amount_total || 0),
        currency: typeof session.currency === "string" ? session.currency : null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    txn.set(webhookEventRef, {
      sessionId: session.id,
      userId,
      productType: productType || null,
      paymentStatus: paymentStatus || null,
      creditedCoins,
      premiumApplied,
      eventId,
      eventType,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Write secondary event-level dedup record so Stripe retries carrying the
    // same event.id are caught even if the session-level doc is somehow absent.
    if (eventDedupRef) {
      txn.set(eventDedupRef, {
        sessionId: session.id,
        eventId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {creditedCoins, premiumApplied, deduplicated: false};
  });
}

exports.recordStripePaymentSuccess = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  recordStripePaymentSuccessHandler(request),
);

async function sendCoinTransferHandler(request, deps = {}) {
  const senderId = requireAuth(request);
  enforceRateLimit("sendCoinTransfer", senderId);
  const receiverId = parseIdField(
    request.data && request.data.receiverId,
    "receiverId",
  );
  const amount = parsePositiveAmount(request.data && request.data.amount);
  const idempotencyKey = parseOptionalIdempotencyKey(
    request.data && request.data.idempotencyKey,
  );
  const firestore = deps.firestore || db;

  if (receiverId === senderId) {
    throw new HttpsError("invalid-argument", "Cannot send a payment to yourself.");
  }

  await ensureUserExists(senderId, firestore);
  await ensureUserExists(receiverId, firestore);

  const transactionRef = idempotencyKey
    ? firestore.collection("transactions").doc(
      buildIdempotentTransactionDocId("balance", senderId, idempotencyKey),
    )
    : firestore.collection("transactions").doc();

  const transactionId = await firestore.runTransaction(async (txn) => {
    const senderRef = firestore.collection("users").doc(senderId);
    const receiverRef = firestore.collection("users").doc(receiverId);

    const existingTransaction = await txn.get(transactionRef);
    if (existingTransaction.exists) {
      return transactionRef.id;
    }

    const [senderSnap, receiverSnap] = await Promise.all([
      txn.get(senderRef),
      txn.get(receiverRef),
    ]);

    const isAdminSender = senderSnap.data()?.admin === true;
    const senderBalance = getCoinBalance(senderSnap.data());
    const receiverBalance = getCoinBalance(receiverSnap.data());

    if (!isAdminSender && senderBalance < amount) {
      throw new HttpsError("failed-precondition", "Insufficient balance.");
    }

    if (!isAdminSender) {
      const nextSenderBalance = senderBalance - amount;
      txn.update(senderRef, {balance: nextSenderBalance, coinBalance: nextSenderBalance});
      syncWalletCoinBalance(txn, firestore, senderId, nextSenderBalance);
    }
    const nextReceiverBalance = receiverBalance + amount;
    txn.update(receiverRef, {balance: nextReceiverBalance, coinBalance: nextReceiverBalance});
    syncWalletCoinBalance(txn, firestore, receiverId, nextReceiverBalance);
    txn.set(transactionRef, {
      id: transactionRef.id,
      senderId,
      receiverId,
      participants: [senderId, receiverId],
      amount,
      timestamp: new Date().toISOString(),
      status: "sent",
      source: "balance",
      idempotencyKey,
    });

    return transactionRef.id;
  });

  return {transactionId};
}

exports.sendCoinTransfer = onCall(async (request) => sendCoinTransferHandler(request));

async function requestCoinTransferHandler(request, deps = {}) {
  const requesterId = requireAuth(request);
  enforceRateLimit("requestCoinTransfer", requesterId);
  const targetId = parseIdField(
    request.data && request.data.targetId,
    "targetId",
  );
  const amount = parsePositiveAmount(request.data && request.data.amount);
  const idempotencyKey = parseOptionalIdempotencyKey(
    request.data && request.data.idempotencyKey,
  );
  const firestore = deps.firestore || db;

  if (targetId === requesterId) {
    throw new HttpsError("invalid-argument", "Cannot request a payment from yourself.");
  }

  const transactionRef = idempotencyKey
    ? firestore.collection("transactions").doc(
      buildIdempotentTransactionDocId("request", requesterId, idempotencyKey),
    )
    : firestore.collection("transactions").doc();

  const existingSnap = await transactionRef.get();
  if (existingSnap.exists) {
    return {transactionId: transactionRef.id, deduplicated: true};
  }

  await transactionRef.set({
    id: transactionRef.id,
    senderId: requesterId,
    receiverId: targetId,
    participants: [requesterId, targetId],
    amount,
    timestamp: new Date().toISOString(),
    status: "requested",
    source: "request",
    idempotencyKey,
  });

  return {transactionId: transactionRef.id, deduplicated: false};
}

exports.requestCoinTransfer = onCall(async (request) =>
  requestCoinTransferHandler(request),
);

async function generateReferralCodeHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("generateReferralCode", userId);
  const firestore = deps.firestore || db;

  const existing = await firestore
    .collection("referral_codes")
    .where("ownerUserId", "==", userId)
    .where("isActive", "==", true)
    .limit(1)
    .get();

  if (!existing.empty) {
    return {code: existing.docs[0].id};
  }

  for (let attempt = 0; attempt < 8; attempt += 1) {
    const candidate = buildReferralCode();
    const codeRef = firestore.collection("referral_codes").doc(candidate);
    const snapshot = await codeRef.get();
    if (snapshot.exists) {
      continue;
    }

    await codeRef.set({
      code: candidate,
      ownerUserId: userId,
      isActive: true,
      createdAt: new Date().toISOString(),
    }, {merge: true});
    return {code: candidate};
  }

  throw new HttpsError("aborted", "Could not generate referral code. Please retry.");
}

exports.generateReferralCode = onCall(async (request) =>
  generateReferralCodeHandler(request),
);

async function redeemReferralCodeHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("redeemReferralCode", userId);
  const firestore = deps.firestore || db;
  const code = parseIdField(request.data && request.data.code, "code").toUpperCase();

  const codeRef = firestore.collection("referral_codes").doc(code);
  const codeSnapshot = await codeRef.get();
  if (!codeSnapshot.exists) {
    return {redeemed: false, reason: "not-found"};
  }

  const codeData = codeSnapshot.data() || {};
  const ownerUserId = typeof codeData.ownerUserId === "string" ? codeData.ownerUserId.trim() : "";
  const isActive = codeData.isActive !== false;
  if (!isActive || !ownerUserId || ownerUserId === userId) {
    return {redeemed: false, reason: "invalid"};
  }

  const existing = await firestore
    .collection("referrals")
    .where("referredUserId", "==", userId)
    .limit(1)
    .get();
  if (!existing.empty) {
    return {redeemed: false, reason: "already-redeemed"};
  }

  const referralRef = firestore.collection("referrals").doc();
  await referralRef.set({
    id: referralRef.id,
    referrerUserId: ownerUserId,
    referredUserId: userId,
    referralCode: code,
    subscriptionStatus: "pending",
    rewardStatus: "pending",
    createdAt: new Date().toISOString(),
    participantIds: [ownerUserId, userId],
  });

  return {redeemed: true, referralId: referralRef.id};
}

exports.redeemReferralCode = onCall(async (request) =>
  redeemReferralCodeHandler(request),
);

async function registerFcmTokenHandler(request, deps = {}) {
  const uid = requireAuth(request);
  // FCM tokens can be 150-500+ characters; parseIdField's 128-char cap is too short.
  const rawToken = request.data && request.data.token;
  const token = typeof rawToken === "string" ? rawToken.trim() : "";
  if (!token) throw new HttpsError("invalid-argument", "token is required.");
  if (token.length > 4096) throw new HttpsError("invalid-argument", "token is too long.");
  const platform =
    typeof (request.data && request.data.platform) === "string"
      ? request.data.platform.trim().slice(0, 32)
      : "unknown";
  const firestore = deps.firestore || db;

  const tokenRef = firestore
    .collection("users")
    .doc(uid)
    .collection("notification_tokens")
    .doc(token);

  await tokenRef.set({
    token,
    userId: uid,
    platform,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {ok: true};
}

exports.registerFcmToken = onCall(async (request) =>
  registerFcmTokenHandler(request),
);

async function unregisterFcmTokenHandler(request, deps = {}) {
  const uid = requireAuth(request);
  const firestore = deps.firestore || db;
  const rawToken = request.data && request.data.token;
  const token = typeof rawToken === "string" ? rawToken.trim() : "";

  const tokensRef = firestore
    .collection("users")
    .doc(uid)
    .collection("notification_tokens");

  if (token) {
    await tokensRef.doc(token).delete();
    return {ok: true, deleted: 1};
  }

  const snapshot = await tokensRef.limit(200).get();
  if (snapshot.empty) {
    return {ok: true, deleted: 0};
  }

  const batch = firestore.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();
  return {ok: true, deleted: snapshot.size};
}

exports.unregisterFcmToken = onCall(async (request) =>
  unregisterFcmTokenHandler(request),
);

async function sendPushForNotification(event, deps = {}) {
  if (!event.data) {
    return;
  }

  const firestore = deps.firestore || db;
  const messaging = deps.messaging || admin.messaging();
  const notificationData = event.data.data() || {};
  const userId = typeof notificationData.userId === "string"
    ? notificationData.userId.trim()
    : "";
  if (!userId) {
    return;
  }

  const tokenSnapshot = await firestore
    .collection("users")
    .doc(userId)
    .collection("notification_tokens")
    .limit(200)
    .get();

  const tokens = tokenSnapshot.docs
    .map((doc) => (doc.data().token || "").trim())
    .filter((value) => value.length > 0);

  if (tokens.length === 0) {
    return;
  }

  const payload = {
    notification: {
      title: "MixVy",
      body: typeof notificationData.content === "string"
        ? notificationData.content.slice(0, 180)
        : "You have a new notification.",
    },
    data: {
      type: String(notificationData.type || "in_app"),
      notificationId: event.data.id,
      userId,
    },
    tokens,
  };

  const result = await messaging.sendEachForMulticast(payload);
  const invalidTokens = [];
  result.responses.forEach((response, index) => {
    if (response.success) {
      return;
    }
    const code = response.error && response.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-argument"
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    const batch = firestore.batch();
    invalidTokens.forEach((token) => {
      const tokenRef = firestore
        .collection("users")
        .doc(userId)
        .collection("notification_tokens")
        .doc(token);
      batch.delete(tokenRef);
    });
    await batch.commit();
  }
}

exports.sendPushForNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => sendPushForNotification(event),
);

// ── Incoming video call push notification ────────────────────────────────────
// Fires when a new room document is created with isDirectCall == true.
// Sends an FCM push to the callee so they see the call even when the app is
// in the background or closed.
async function sendIncomingCallPushHandler(event, deps = {}) {
  if (!event.data) return;
  const roomData = event.data.data() || {};
  if (!roomData.isDirectCall) return;

  const calleeId = typeof roomData.calleeId === "string" ? roomData.calleeId.trim() : "";
  const callerId = typeof roomData.ownerId === "string" ? roomData.ownerId.trim() : "";
  const roomId = event.params && event.params.roomId;
  if (!calleeId || !callerId || !roomId) return;

  const firestore = deps.firestore || db;
  const messaging = deps.messaging || admin.messaging();

  // Fetch caller's display name.
  const callerSnap = await firestore.collection("users").doc(callerId).get();
  const callerName = callerSnap.exists
    ? (callerSnap.data().displayName || callerSnap.data().username || "Someone")
    : "Someone";

  // Fetch callee's FCM tokens.
  const tokenSnapshot = await firestore
    .collection("users")
    .doc(calleeId)
    .collection("notification_tokens")
    .limit(200)
    .get();

  const tokens = tokenSnapshot.docs
    .map((doc) => (doc.data().token || "").trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) return;

  const payload = {
    notification: {
      title: "Incoming video call",
      body: `${callerName} is calling you on MixVy`,
    },
    data: {
      type: "incoming_call",
      roomId,
      callerId,
    },
    tokens,
  };

  const result = await messaging.sendEachForMulticast(payload);
  const invalidTokens = [];
  result.responses.forEach((response, index) => {
    if (!response.success) {
      const code = response.error && response.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        invalidTokens.push(tokens[index]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    const batch = firestore.batch();
    invalidTokens.forEach((token) => {
      batch.delete(
        firestore
          .collection("users")
          .doc(calleeId)
          .collection("notification_tokens")
          .doc(token),
      );
    });
    await batch.commit();
  }
}

exports.sendIncomingCallPush = onDocumentCreated(
  "rooms/{roomId}",
  async (event) => sendIncomingCallPushHandler(event),
);

async function sendRoomGiftHandler(request, deps = {}) {
  const senderId = requireAuth(request);
  enforceRateLimit("sendRoomGift", senderId);
  const roomId = parseIdField(request.data && request.data.roomId, "roomId");
  const receiverId = parseIdField(
    request.data && request.data.receiverId,
    "receiverId",
  );
  const giftId = parseIdField(request.data && request.data.giftId, "giftId");
  const coinCost = parsePositiveAmount(request.data && request.data.coinCost);
  const senderName =
    typeof (request.data && request.data.senderName) === "string"
      ? request.data.senderName.trim().slice(0, 64)
      : "";
  const receiverName =
    typeof (request.data && request.data.receiverName) === "string"
      ? request.data.receiverName.trim().slice(0, 64)
      : "";
  const firestore = deps.firestore || db;

  if (receiverId === senderId) {
    throw new HttpsError(
      "invalid-argument",
      "Cannot send a gift to yourself.",
    );
  }

  const PLATFORM_FEE = 0.15;
  const receiverAmount = Math.max(1, Math.floor(coinCost * (1 - PLATFORM_FEE)));
  const platformFeeAmount = Math.max(0, coinCost - receiverAmount);

  const giftEventId = await firestore.runTransaction(async (txn) => {
    const senderRef = firestore.collection("users").doc(senderId);
    const receiverRef = firestore.collection("users").doc(receiverId);
    const roomRef = firestore.collection("rooms").doc(roomId);
    const senderParticipantRef = roomRef
      .collection("participants")
      .doc(senderId);
    const allowanceRef = firestore
      .collection("users")
      .doc(senderId)
      .collection("gift_tracking")
      .doc("allowance");
    const giftEventRef = firestore
      .collection("rooms")
      .doc(roomId)
      .collection("gift_events")
      .doc();

    const [senderSnap, receiverSnap, roomSnap, senderParticipantSnap, allowanceSnap] =
      await Promise.all([
        txn.get(senderRef),
        txn.get(receiverRef),
        txn.get(roomRef),
        txn.get(senderParticipantRef),
        txn.get(allowanceRef),
      ]);

    if (!roomSnap.exists || roomSnap.data().isLive === false) {
      throw new HttpsError(
        "failed-precondition",
        "The room is not currently active.",
      );
    }
    if (!senderParticipantSnap.exists ||
        senderParticipantSnap.data().isBanned === true) {
      throw new HttpsError(
        "permission-denied",
        "You must be an active participant in the room to send gifts.",
      );
    }

    // Check free gift allowance
    const DAILY_FREE_LIMIT = 5;
    const allowanceData = allowanceSnap.exists ? allowanceSnap.data() : {};
    const lastReset = allowanceData.lastReset?.toDate?.() || new Date(0);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const lastResetDate = new Date(lastReset.getFullYear(), lastReset.getMonth(), lastReset.getDate());
    
    let remainingFreeGifts = DAILY_FREE_LIMIT;
    if (lastResetDate.getTime() === today.getTime()) {
      remainingFreeGifts = Math.max(0, allowanceData.remainingToday || DAILY_FREE_LIMIT);
    }

    const senderBalance = getCoinBalance(senderSnap.data());
    const isAdminSender = senderSnap.data()?.admin === true;
    
    // Check if user can send gift (has allowance or has coins)
    const hasFreeGifts = remainingFreeGifts > 0;
    const hasCoins = senderBalance >= coinCost;
    const canSendGift = isAdminSender || hasFreeGifts || hasCoins;
    
    if (!canSendGift) {
      throw new HttpsError(
        "failed-precondition",
        hasFreeGifts ? "Insufficient coin balance." : "No free gifts remaining. Buy coins to send gifts.",
      );
    }

    const receiverBalance = getCoinBalance(receiverSnap.data());

    if (!isAdminSender && !hasFreeGifts && hasCoins) {
      // Use coins instead of free gift
      const nextSenderBalance = senderBalance - coinCost;
      txn.update(senderRef, {balance: nextSenderBalance, coinBalance: nextSenderBalance});
      syncWalletCoinBalance(txn, firestore, senderId, nextSenderBalance);
      writeWalletLedgerEntry(txn, firestore, {
        userId: senderId,
        type: "gift_sent",
        amount: -coinCost,
        currency: "coin",
        status: "completed",
        metadata: {roomId, giftId, receiverId},
      });
    } else if (hasFreeGifts) {
      // Decrement free gift allowance
      txn.set(allowanceRef, {
        remainingToday: remainingFreeGifts - 1,
        lastReset: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const nextReceiverBalance = receiverBalance + receiverAmount;
    txn.update(receiverRef, {balance: nextReceiverBalance, coinBalance: nextReceiverBalance});
    syncWalletCoinBalance(txn, firestore, receiverId, nextReceiverBalance);
    writeWalletLedgerEntry(txn, firestore, {
      userId: receiverId,
      type: "gift_received",
      amount: receiverAmount,
      currency: "coin",
      status: "completed",
      metadata: {roomId, giftId, senderId},
    });
    if (platformFeeAmount > 0) {
      writeWalletLedgerEntry(txn, firestore, {
        userId: senderId,
        type: "gift_platform_fee",
        amount: -platformFeeAmount,
        currency: "coin",
        status: "completed",
        metadata: {roomId, giftId, receiverId},
      });
    }
    txn.set(giftEventRef, {
      id: giftEventRef.id,
      senderId,
      senderName,
      receiverId,
      receiverName,
      roomId,
      giftId,
      coinCost,
      receiverAmount,
      platformFeeAmount,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      emoji: request.data?.emoji || "🎁",
    });

    return giftEventRef.id;
  });

  return {giftEventId};
}

exports.sendRoomGift = onCall(async (request) => sendRoomGiftHandler(request));

// ---------------------------------------------------------------------------
// sendDirectGift — send a gift from one user to another outside of a room.
// ---------------------------------------------------------------------------
async function sendDirectGiftHandler(request, deps = {}) {
  const senderId = requireAuth(request);
  enforceRateLimit("sendRoomGift", senderId); // reuse same rate-limit bucket
  const receiverId = parseIdField(
    request.data && request.data.receiverId,
    "receiverId",
  );
  const giftId = parseIdField(request.data && request.data.giftId, "giftId");
  const coinCost = parsePositiveAmount(request.data && request.data.coinCost);
  const senderName =
    typeof (request.data && request.data.senderName) === "string"
      ? request.data.senderName.trim().slice(0, 64)
      : "";
  const firestore = deps.firestore || db;

  if (receiverId === senderId) {
    throw new HttpsError(
      "invalid-argument",
      "Cannot send a gift to yourself.",
    );
  }

  const PLATFORM_FEE = 0.15;
  const receiverAmount = Math.max(1, Math.floor(coinCost * (1 - PLATFORM_FEE)));
  const platformFeeAmount = Math.max(0, coinCost - receiverAmount);

  const giftEventId = await firestore.runTransaction(async (txn) => {
    const senderRef = firestore.collection("users").doc(senderId);
    const receiverRef = firestore.collection("users").doc(receiverId);
    const giftEventRef = firestore.collection("gift_events").doc();

    const [senderSnap, receiverSnap] = await Promise.all([
      txn.get(senderRef),
      txn.get(receiverRef),
    ]);

    if (!receiverSnap.exists) {
      throw new HttpsError("not-found", "Recipient user not found.");
    }

    const senderBalance = getCoinBalance(senderSnap.data());
    const isAdminSender = senderSnap.data()?.admin === true;
    if (!isAdminSender && senderBalance < coinCost) {
      throw new HttpsError("failed-precondition", "Insufficient coin balance.");
    }

    const receiverBalance = getCoinBalance(receiverSnap.data());

    if (!isAdminSender) {
      const nextSenderBalance = senderBalance - coinCost;
      txn.update(senderRef, {balance: nextSenderBalance, coinBalance: nextSenderBalance});
      syncWalletCoinBalance(txn, firestore, senderId, nextSenderBalance);
      writeWalletLedgerEntry(txn, firestore, {
        userId: senderId,
        type: "direct_gift_sent",
        amount: -coinCost,
        currency: "coin",
        status: "completed",
        metadata: {giftId, receiverId},
      });
    }
    const nextReceiverBalance = receiverBalance + receiverAmount;
    txn.update(receiverRef, {balance: nextReceiverBalance, coinBalance: nextReceiverBalance});
    syncWalletCoinBalance(txn, firestore, receiverId, nextReceiverBalance);
    writeWalletLedgerEntry(txn, firestore, {
      userId: receiverId,
      type: "direct_gift_received",
      amount: receiverAmount,
      currency: "coin",
      status: "completed",
      metadata: {giftId, senderId},
    });
    if (platformFeeAmount > 0) {
      writeWalletLedgerEntry(txn, firestore, {
        userId: senderId,
        type: "direct_gift_platform_fee",
        amount: -platformFeeAmount,
        currency: "coin",
        status: "completed",
        metadata: {giftId, receiverId},
      });
    }
    txn.set(giftEventRef, {
      id: giftEventRef.id,
      senderId,
      senderName,
      receiverId,
      giftId,
      coinCost,
      receiverAmount,
      platformFeeAmount,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return giftEventRef.id;
  });

  return {giftEventId};
}

exports.sendDirectGift = onCall(async (request) =>
  sendDirectGiftHandler(request),
);

async function getStripeConnectStatusHandler(request, deps = {}) {
  const uid = requireAuth(request);
  enforceRateLimit("getStripeConnectStatus", uid);
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const accountRef = firestore.collection("stripe_connect_accounts").doc(uid);
  const accountSnap = await accountRef.get();

  if (!accountSnap.exists || !accountSnap.data().accountId) {
    return {
      hasAccount: false,
      accountId: null,
      chargesEnabled: false,
      payoutsEnabled: false,
      detailsSubmitted: false,
      onboardingComplete: false,
      country: process.env.STRIPE_CONNECT_COUNTRY || "US",
    };
  }

  const account = await stripeClient.accounts.retrieve(accountSnap.data().accountId);
  const mapped = mapStripeConnectAccount(account);
  await accountRef.set({
    ...mapped,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    hasAccount: true,
    ...mapped,
  };
}

exports.getStripeConnectStatus = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  getStripeConnectStatusHandler(request),
);

async function createStripeConnectOnboardingLinkHandler(request, deps = {}) {
  const uid = requireAuth(request);
  enforceRateLimit("createStripeConnectOnboardingLink", uid);
  const stripeClient = deps.stripeClient || getStripe();
  const publicAppUrl = deps.publicAppUrl || getCheckoutBaseUrl();

  const mapped = await ensureStripeConnectAccount(uid, deps);
  const accountLink = await stripeClient.accountLinks.create({
    account: mapped.accountId,
    refresh_url: `${publicAppUrl}/payments?connect=refresh`,
    return_url: `${publicAppUrl}/payments?connect=return`,
    type: "account_onboarding",
  });

  return {
    url: accountLink.url,
    hasAccount: true,
    ...mapped,
  };
}

exports.createStripeConnectOnboardingLink = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  createStripeConnectOnboardingLinkHandler(request),
);

async function createStripeConnectDashboardLinkHandler(request, deps = {}) {
  const uid = requireAuth(request);
  enforceRateLimit("createStripeConnectDashboardLink", uid);
  const stripeClient = deps.stripeClient || getStripe();
  const status = await ensureStripeConnectAccount(uid, deps);

  const loginLink = await stripeClient.accounts.createLoginLink(status.accountId);
  return {
    url: loginLink.url,
  };
}

exports.createStripeConnectDashboardLink = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  createStripeConnectDashboardLinkHandler(request),
);

function creatorSubscriptionDocId(subscriberId, creatorId) {
  return `${subscriberId}_${creatorId}`;
}

function validateCreatorSubscriptionOffer(data = {}) {
  if (typeof data.enabled !== "boolean") {
    throw new HttpsError("invalid-argument", "enabled must be a boolean.");
  }
  const monthlyPriceCents = Number(data.monthlyPriceCents);
  if (!Number.isInteger(monthlyPriceCents) ||
      monthlyPriceCents < CREATOR_SUBSCRIPTION_MIN_PRICE_CENTS ||
      monthlyPriceCents > CREATOR_SUBSCRIPTION_MAX_PRICE_CENTS) {
    throw new HttpsError(
      "invalid-argument",
      "monthlyPriceCents must be an integer from 299 through 999.",
    );
  }
  if (!Array.isArray(data.benefits) || data.benefits.length > 10) {
    throw new HttpsError("invalid-argument", "benefits must contain at most 10 items.");
  }
  const benefits = data.benefits.map((benefit) => {
    if (typeof benefit !== "string") {
      throw new HttpsError("invalid-argument", "Each benefit must be a string.");
    }
    const normalized = benefit.trim();
    if (!normalized || normalized.length > 120) {
      throw new HttpsError(
        "invalid-argument",
        "Each benefit must be between 1 and 120 characters.",
      );
    }
    return normalized;
  });
  if (new Set(benefits).size !== benefits.length) {
    throw new HttpsError("invalid-argument", "benefits must not contain duplicates.");
  }
  return {enabled: data.enabled, monthlyPriceCents, benefits};
}

function creatorSubscriptionSummary(data) {
  if (!data) return null;
  return {
    status: typeof data.status === "string" ? data.status : "incomplete",
    currentPeriodEnd: Number.isFinite(Number(data.currentPeriodEnd)) ?
      Number(data.currentPeriodEnd) : null,
    cancelAtPeriodEnd: data.cancelAtPeriodEnd === true,
  };
}

function creatorOffer(creatorId, data) {
  return {
    creatorId,
    enabled: data?.enabled === true,
    monthlyPriceCents: Number.isInteger(data?.monthlyPriceCents) ?
      data.monthlyPriceCents : null,
    currency: "usd",
    benefits: Array.isArray(data?.benefits) ? data.benefits : [],
  };
}

function safeDisplayIdentity(userId, data) {
  const displayName = typeof data?.displayName === "string" ?
    data.displayName.trim().slice(0, 80) : "";
  const username = typeof data?.username === "string" ?
    data.username.trim().slice(0, 40) : "";
  const photoUrl = typeof data?.photoUrl === "string" ?
    data.photoUrl.trim().slice(0, 1000) : null;
  return {
    userId,
    displayName: displayName || username || "MixVy creator",
    username: username || null,
    photoUrl: photoUrl || null,
  };
}

function timestampMillis(value) {
  if (value?.toMillis) return value.toMillis();
  if (typeof value === "string") return Date.parse(value) || 0;
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

function callableTimestamp(value) {
  const milliseconds = timestampMillis(value);
  return milliseconds > 0 ? new Date(milliseconds).toISOString() : null;
}

async function listCreatorSubscriptionMarketplaceHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("listCreatorSubscriptionMarketplace", userId);
  const firestore = deps.firestore || db;
  const rawSearch = request.data?.search;
  const search = typeof rawSearch === "string" ? rawSearch.trim().toLowerCase() : "";
  if (search.length > 80) {
    throw new HttpsError("invalid-argument", "search must not exceed 80 characters.");
  }
  const minPriceCents = request.data?.minPriceCents == null ?
    CREATOR_SUBSCRIPTION_MIN_PRICE_CENTS : Number(request.data.minPriceCents);
  const maxPriceCents = request.data?.maxPriceCents == null ?
    CREATOR_SUBSCRIPTION_MAX_PRICE_CENTS : Number(request.data.maxPriceCents);
  if (!Number.isInteger(minPriceCents) || !Number.isInteger(maxPriceCents) ||
      minPriceCents < CREATOR_SUBSCRIPTION_MIN_PRICE_CENTS ||
      maxPriceCents > CREATOR_SUBSCRIPTION_MAX_PRICE_CENTS ||
      minPriceCents > maxPriceCents) {
    throw new HttpsError("invalid-argument", "The marketplace price filter is invalid.");
  }

  const settingsSnap = await firestore.collection("creator_subscription_settings")
    .where("enabled", "==", true).limit(100).get();
  const candidates = settingsSnap.docs.filter((doc) => {
    const price = doc.data().monthlyPriceCents;
    return Number.isInteger(price) && price >= minPriceCents && price <= maxPriceCents;
  });
  const creatorsWithSearch = await Promise.all(candidates.map(async (doc) => {
    const data = doc.data();
    const creatorId = data.creatorId || doc.id;
    const [userSnap, subscriptionsSnap] = await Promise.all([
      firestore.collection("users").doc(creatorId).get(),
      firestore.collection("creator_subscriptions")
        .where("creatorId", "==", creatorId).get(),
    ]);
    const identity = safeDisplayIdentity(
      creatorId,
      userSnap.exists ? userSnap.data() : null,
    );
    const benefits = Array.isArray(data.benefits) ? data.benefits : [];
    const searchText = [
      identity.displayName,
      identity.username,
      ...benefits,
    ].filter(Boolean).join(" ").toLowerCase();
    return {
      creator: {
        creatorId,
        displayName: identity.displayName,
        avatarUrl: identity.photoUrl,
        subscriberCount: subscriptionsSnap.docs.reduce(
          (count, subscriptionDoc) => count +
            (ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(
              subscriptionDoc.data().status,
            ) ? 1 : 0),
          0,
        ),
        offer: creatorOffer(creatorId, data),
      },
      searchText,
    };
  }));

  return {
    creators: creatorsWithSearch
      .filter((entry) => !search || entry.searchText.includes(search))
      .map((entry) => entry.creator),
  };
}

exports.listCreatorSubscriptionMarketplace = onCall(async (request) =>
  listCreatorSubscriptionMarketplaceHandler(request),
);

function publicConnectStatus(data, isOwner) {
  const status = {
    hasAccount: Boolean(data?.accountId),
    chargesEnabled: data?.chargesEnabled === true,
    payoutsEnabled: data?.payoutsEnabled === true,
    detailsSubmitted: data?.detailsSubmitted === true,
    onboardingComplete: data?.onboardingComplete === true,
    country: data?.country || process.env.STRIPE_CONNECT_COUNTRY || "US",
  };
  if (isOwner) status.accountId = data?.accountId || null;
  return status;
}

async function retrieveCreatorConnectStatus(creatorId, deps = {}) {
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const accountRef = firestore.collection("stripe_connect_accounts").doc(creatorId);
  const accountSnap = await accountRef.get();
  const stored = accountSnap.exists ? accountSnap.data() : null;
  if (!stored?.accountId) return publicConnectStatus(null, true);

  const mapped = mapStripeConnectAccount(
    await stripeClient.accounts.retrieve(stored.accountId),
  );
  await accountRef.set({
    ...mapped,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {hasAccount: true, ...mapped};
}

async function getCreatorSubscriptionOverviewHandler(request, deps = {}) {
  const subscriberId = requireAuth(request);
  enforceRateLimit("getCreatorSubscriptionOverview", subscriberId);
  const creatorId = parseIdField(request.data?.creatorId, "creatorId");
  const firestore = deps.firestore || db;
  const isOwner = subscriberId === creatorId;

  const [offerSnap, connectResult, subscriptionSnap, subscriptionsSnap] =
    await Promise.all([
      firestore.collection("creator_subscription_settings").doc(creatorId).get(),
      isOwner ?
        retrieveCreatorConnectStatus(creatorId, deps) :
        firestore.collection("stripe_connect_accounts").doc(creatorId).get(),
      firestore.collection("creator_subscriptions")
        .doc(creatorSubscriptionDocId(subscriberId, creatorId)).get(),
      firestore.collection("creator_subscriptions")
        .where("creatorId", "==", creatorId).get(),
    ]);
  const subscriberCount = subscriptionsSnap.docs.reduce(
    (count, doc) => count +
      (ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(doc.data().status) ? 1 : 0),
    0,
  );
  let analytics = null;
  if (isOwner) {
    const activeRows = subscriptionsSnap.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .filter((row) => ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(row.status));
    const cancelingCount = activeRows.filter(
      (row) => row.cancelAtPeriodEnd === true,
    ).length;
    const monthlyPriceCents = offerSnap.exists &&
      Number.isInteger(offerSnap.data().monthlyPriceCents) ?
      offerSnap.data().monthlyPriceCents : 0;
    const monthlyGrossCents = activeRows.length * monthlyPriceCents;
    const estimatedPlatformFeeCents = Math.round(
      monthlyGrossCents * CREATOR_SUBSCRIPTION_PLATFORM_FEE_PERCENT / 100,
    );
    const recentRows = subscriptionsSnap.docs
      .map((doc) => ({id: doc.id, ...doc.data()}))
      .filter((row) =>
        typeof row.subscriberId === "string" && row.subscriberId.trim())
      .sort((left, right) =>
        timestampMillis(right.updatedAt) - timestampMillis(left.updatedAt))
      .slice(0, 10);
    const recentSubscriberActivity = await Promise.all(recentRows.map(async (row) => {
      const userSnap = await firestore.collection("users").doc(row.subscriberId).get();
      return {
        subscriber: safeDisplayIdentity(
          row.subscriberId,
          userSnap.exists ? userSnap.data() : null,
        ),
        status: row.status,
        cancelAtPeriodEnd: row.cancelAtPeriodEnd === true,
        currentPeriodEnd: Number.isFinite(Number(row.currentPeriodEnd)) ?
          Number(row.currentPeriodEnd) : null,
        updatedAt: row.updatedAt || null,
      };
    }));
    analytics = {
      activeCount: activeRows.length,
      cancelingCount,
      monthlyGrossCents,
      estimatedPlatformFeeCents,
      estimatedCreatorNetBeforeStripeCents:
        monthlyGrossCents - estimatedPlatformFeeCents,
      recentSubscriberActivity,
    };
  }

  return {
    isOwner,
    offer: creatorOffer(creatorId, offerSnap.exists ? offerSnap.data() : null),
    connectStatus: isOwner ?
      publicConnectStatus(connectResult, true) :
      publicConnectStatus(connectResult.exists ? connectResult.data() : null, false),
    subscription: subscriptionSnap.exists ?
      creatorSubscriptionSummary(subscriptionSnap.data()) : null,
    subscriberCount,
    analytics,
  };
}

exports.getCreatorSubscriptionOverview = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  getCreatorSubscriptionOverviewHandler(request),
);

async function saveCreatorSubscriptionOfferHandler(request, deps = {}) {
  const creatorId = requireAuth(request);
  enforceRateLimit("saveCreatorSubscriptionOffer", creatorId);
  const firestore = deps.firestore || db;
  const validated = validateCreatorSubscriptionOffer(request.data);

  let connectStatus;
  if (validated.enabled) {
    connectStatus = await retrieveCreatorConnectStatus(creatorId, deps);
    if (!connectStatus.onboardingComplete) {
      throw new HttpsError(
        "failed-precondition",
        "Complete Stripe Connect onboarding before enabling subscriptions.",
      );
    }
  } else {
    const connectSnap = await firestore
      .collection("stripe_connect_accounts").doc(creatorId).get();
    connectStatus = publicConnectStatus(
      connectSnap.exists ? connectSnap.data() : null,
      true,
    );
  }

  const offerRef = firestore.collection("creator_subscription_settings").doc(creatorId);
  const existing = await offerRef.get();
  await offerRef.set({
    creatorId,
    ...validated,
    currency: "usd",
    platformFeePercent: CREATOR_SUBSCRIPTION_PLATFORM_FEE_PERCENT,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(!existing.exists && {
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  }, {merge: true});

  return getCreatorSubscriptionOverviewHandler({
    auth: request.auth,
    data: {creatorId},
  }, deps);
}

exports.saveCreatorSubscriptionOffer = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  saveCreatorSubscriptionOfferHandler(request),
);

function buildCreatorSubscriptionCheckoutPayload({
  subscriberId,
  creatorId,
  offer,
  destinationAccountId,
}) {
  const checkoutBaseUrl = getCheckoutBaseUrl();
  const metadata = {
    productType: "creator_subscription",
    subscriberId,
    creatorId,
  };
  return {
    mode: "subscription",
    payment_method_types: ["card"],
    client_reference_id: subscriberId,
    line_items: [{
      quantity: 1,
      price_data: {
        currency: "usd",
        unit_amount: offer.monthlyPriceCents,
        recurring: {interval: "month"},
        product_data: {
          name: "MixVy Creator Subscription",
          metadata: {creatorId},
        },
      },
    }],
    metadata,
    subscription_data: {
      metadata,
      application_fee_percent: CREATOR_SUBSCRIPTION_PLATFORM_FEE_PERCENT,
      transfer_data: {destination: destinationAccountId},
    },
    success_url:
      `${checkoutBaseUrl}/creator/${encodeURIComponent(creatorId)}` +
      "?subscription=success&session_id={CHECKOUT_SESSION_ID}",
    cancel_url:
      `${checkoutBaseUrl}/creator/${encodeURIComponent(creatorId)}` +
      "?subscription=cancel",
  };
}

async function createCreatorSubscriptionCheckoutHandler(request, deps = {}) {
  const subscriberId = requireAuth(request);
  enforceRateLimit("createCreatorSubscriptionCheckout", subscriberId);
  const creatorId = parseIdField(request.data?.creatorId, "creatorId");
  if (subscriberId === creatorId) {
    throw new HttpsError("invalid-argument", "You cannot subscribe to yourself.");
  }
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const [offerSnap, existingSnap] = await Promise.all([
    firestore.collection("creator_subscription_settings").doc(creatorId).get(),
    firestore.collection("creator_subscriptions")
      .doc(creatorSubscriptionDocId(subscriberId, creatorId)).get(),
  ]);
  if (!offerSnap.exists || offerSnap.data().enabled !== true) {
    throw new HttpsError("failed-precondition", "This creator offer is not enabled.");
  }
  if (existingSnap.exists &&
      ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(existingSnap.data().status)) {
    throw new HttpsError("already-exists", "You already subscribe to this creator.");
  }

  const connectStatus = await retrieveCreatorConnectStatus(creatorId, deps);
  if (!connectStatus.onboardingComplete) {
    throw new HttpsError(
      "failed-precondition",
      "This creator cannot accept subscriptions yet.",
    );
  }
  const idempotencyKey = parseOptionalIdempotencyKey(request.data?.idempotencyKey);
  const payload = buildCreatorSubscriptionCheckoutPayload({
    subscriberId,
    creatorId,
    offer: offerSnap.data(),
    destinationAccountId: connectStatus.accountId,
  });
  const session = await stripeClient.checkout.sessions.create(
    payload,
    idempotencyKey ? {
      idempotencyKey: `creator_subscription_${subscriberId}_${creatorId}_${idempotencyKey}`,
    } : undefined,
  );
  return {url: session.url};
}

exports.createCreatorSubscriptionCheckout = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  createCreatorSubscriptionCheckoutHandler(request),
);

function subscriptionPeriodEnd(subscription) {
  const value = subscription.current_period_end ??
    subscription.items?.data?.[0]?.current_period_end;
  return Number.isFinite(Number(value)) ? Number(value) : null;
}

function creatorSubscriptionRecord(subscription, overrides = {}) {
  const status = subscription.status || overrides.status || "incomplete";
  return {
    subscriberId: subscription.metadata?.subscriberId || overrides.subscriberId,
    creatorId: subscription.metadata?.creatorId || overrides.creatorId,
    stripeSubscriptionId: subscription.id,
    stripeCustomerId: typeof subscription.customer === "string" ?
      subscription.customer : subscription.customer?.id || overrides.stripeCustomerId || null,
    status,
    currentPeriodEnd: subscriptionPeriodEnd(subscription),
    cancelAtPeriodEnd: subscription.cancel_at_period_end === true,
    terminal: TERMINAL_CREATOR_SUBSCRIPTION_STATUSES.has(status),
  };
}

async function cancelCreatorSubscriptionHandler(request, deps = {}) {
  const subscriberId = requireAuth(request);
  enforceRateLimit("cancelCreatorSubscription", subscriberId);
  const creatorId = parseIdField(request.data?.creatorId, "creatorId");
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const subscriptionRef = firestore.collection("creator_subscriptions")
    .doc(creatorSubscriptionDocId(subscriberId, creatorId));
  const subscriptionSnap = await subscriptionRef.get();
  if (!subscriptionSnap.exists || !subscriptionSnap.data().stripeSubscriptionId) {
    throw new HttpsError("not-found", "Subscription not found.");
  }

  const stored = subscriptionSnap.data();
  const stripeSubscription = await stripeClient.subscriptions.retrieve(
    stored.stripeSubscriptionId,
  );
  if (stripeSubscription.metadata?.subscriberId !== subscriberId ||
      stripeSubscription.metadata?.creatorId !== creatorId) {
    throw new HttpsError("permission-denied", "Subscription ownership could not be verified.");
  }
  const updated = stripeSubscription.cancel_at_period_end ?
    stripeSubscription :
    await stripeClient.subscriptions.update(stripeSubscription.id, {
      cancel_at_period_end: true,
    });
  const record = creatorSubscriptionRecord(updated);
  const shouldNotify = stored.cancelAtPeriodEnd !== true &&
    record.cancelAtPeriodEnd;
  await firestore.runTransaction(async (txn) => {
    txn.set(subscriptionRef, {
      ...record,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (!shouldNotify) return;
    const eventKey = `creator_subscription_cancel_${updated.id}`;
    const notifications = [
      {
        userId: subscriberId,
        actorId: creatorId,
        creatorId,
        type: "creator_subscription_cancel_scheduled",
        content: "Your creator subscription will cancel at the end of the billing period.",
      },
      {
        userId: creatorId,
        actorId: subscriberId,
        creatorId,
        type: "creator_subscription_cancel_scheduled",
        content: "A subscriber scheduled their creator subscription to end.",
      },
    ];
    notifications.forEach((payload) => {
      const notificationRef = firestore.collection("notifications")
        .doc(notificationDocId(eventKey, payload.userId));
      txn.set(notificationRef, {
        ...payload,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  });
  return getCreatorSubscriptionOverviewHandler({
    auth: request.auth,
    data: {creatorId},
  }, deps);
}

exports.cancelCreatorSubscription = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  cancelCreatorSubscriptionHandler(request),
);

async function requireCreatorSubscriberAccess(userId, creatorId, firestore) {
  if (userId === creatorId) return {isCreator: true, subscription: null};
  const subscriptionSnap = await firestore.collection("creator_subscriptions")
    .doc(creatorSubscriptionDocId(userId, creatorId)).get();
  if (!subscriptionSnap.exists ||
      !ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(subscriptionSnap.data().status)) {
    throw new HttpsError(
      "permission-denied",
      "An active creator subscription is required.",
    );
  }
  return {isCreator: false, subscription: subscriptionSnap.data()};
}

function validateCreatorUpdateText(value) {
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length < 1 || text.length > 1000) {
    throw new HttpsError(
      "invalid-argument",
      "text must be between 1 and 1000 characters.",
    );
  }
  const moderation = classifyModerationText("", text);
  if (moderation.needsManualReview) {
    throw new HttpsError(
      "invalid-argument",
      "This update requires moderation review and cannot be published.",
    );
  }
  return {text, moderation};
}

function notificationDocId(eventKey, userId) {
  return `${eventKey}_${userId}`.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 500);
}

async function writeNotificationOnce(firestore, eventKey, payload) {
  const ref = firestore.collection("notifications")
    .doc(notificationDocId(eventKey, payload.userId));
  await ref.set({
    ...payload,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: false});
  return ref.id;
}

async function publishCreatorSubscriberUpdateHandler(request, deps = {}) {
  const creatorId = requireAuth(request);
  enforceRateLimit("publishCreatorSubscriberUpdate", creatorId);
  const firestore = deps.firestore || db;
  const {text, moderation} = validateCreatorUpdateText(request.data?.text);
  const updateRef = firestore.collection("creator_subscriber_updates").doc();
  const publishedAt = new Date().toISOString();
  await updateRef.set({
    updateId: updateRef.id,
    creatorId,
    text,
    status: "published",
    moderation: {
      riskLevel: moderation.riskLevel,
      score: moderation.score,
      classifierVersion: "v1-baseline",
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const subscriptionsSnap = await firestore.collection("creator_subscriptions")
    .where("creatorId", "==", creatorId).get();
  const activeSubscriberIds = [...new Set(subscriptionsSnap.docs
    .map((doc) => doc.data())
    .filter((row) => ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(row.status))
    .map((row) => row.subscriberId)
    .filter(Boolean))];
  await Promise.all(activeSubscriberIds.map((subscriberId) =>
    writeNotificationOnce(firestore, `creator_update_${updateRef.id}`, {
      userId: subscriberId,
      actorId: creatorId,
      creatorId,
      updateId: updateRef.id,
      type: "creator_subscriber_update",
      content: "A creator you subscribe to posted a new subscriber update.",
    })));

  return {
    update: {
      id: updateRef.id,
      creatorId,
      text,
      createdAt: publishedAt,
    },
  };
}

exports.publishCreatorSubscriberUpdate = onCall(async (request) =>
  publishCreatorSubscriberUpdateHandler(request),
);

function publicCreatorUpdate(data) {
  return {
    id: data.updateId,
    creatorId: data.creatorId,
    text: data.text,
    createdAt: callableTimestamp(data.createdAt),
  };
}

async function listCreatorSubscriberUpdatesHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("listCreatorSubscriberUpdates", userId);
  const creatorId = parseIdField(request.data?.creatorId, "creatorId");
  const firestore = deps.firestore || db;
  await requireCreatorSubscriberAccess(userId, creatorId, firestore);

  const updatesSnap = await firestore.collection("creator_subscriber_updates")
    .where("creatorId", "==", creatorId).limit(100).get();
  const updates = updatesSnap.docs
    .map((doc) => ({updateId: doc.id, ...doc.data()}))
    .filter((update) => update.status === "published")
    .sort((left, right) =>
      timestampMillis(right.createdAt) - timestampMillis(left.createdAt))
    .slice(0, 50)
    .map((update) => publicCreatorUpdate(update));
  return {updates};
}

exports.listCreatorSubscriberUpdates = onCall(async (request) =>
  listCreatorSubscriberUpdatesHandler(request),
);

function validateCreatorUpdateReport(data = {}) {
  if (typeof data.reason !== "string" ||
      (data.details != null && typeof data.details !== "string")) {
    throw new HttpsError(
      "invalid-argument",
      "reason and details must be text.",
    );
  }
  const reason = typeof data.reason === "string" ? data.reason.trim() : "";
  const details = typeof data.details === "string" ? data.details.trim() : "";
  if (reason.length < 3 || reason.length > 80) {
    throw new HttpsError(
      "invalid-argument",
      "reason must be between 3 and 80 characters.",
    );
  }
  if (details.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "details must not exceed 500 characters.",
    );
  }
  return {reason, details};
}

async function reportCreatorSubscriberUpdateHandler(request, deps = {}) {
  const reporterId = requireAuth(request);
  enforceRateLimit("reportCreatorSubscriberUpdate", reporterId);
  const updateId = parseIdField(request.data?.updateId, "updateId");
  const {reason, details} = validateCreatorUpdateReport(request.data);
  const firestore = deps.firestore || db;
  const updateSnap = await firestore.collection("creator_subscriber_updates")
    .doc(updateId).get();
  if (!updateSnap.exists || updateSnap.data().status !== "published") {
    throw new HttpsError("not-found", "Subscriber update not found.");
  }
  const creatorId = updateSnap.data().creatorId;
  await requireCreatorSubscriberAccess(reporterId, creatorId, firestore);
  const reportRef = firestore.collection("creator_subscriber_update_reports")
    .doc(`${updateId}_${reporterId}`);
  const moderationReportRef = firestore.collection("reports").doc(reportRef.id);
  const createdAtIso = new Date().toISOString();
  return firestore.runTransaction(async (txn) => {
    const [existing, moderationReport] = await Promise.all([
      txn.get(reportRef),
      txn.get(moderationReportRef),
    ]);
    const existingModerationData = moderationReport.exists ?
      moderationReport.data() : null;
    txn.set(moderationReportRef, {
      id: reportRef.id,
      reporterUserId: reporterId,
      targetId: updateId,
      targetType: "message",
      reason,
      details,
      status: "open",
      createdAt: typeof existingModerationData?.createdAt === "string" ?
        existingModerationData.createdAt : createdAtIso,
    }, {merge: true});
    if (existing.exists) return {reported: true, deduplicated: true};

    txn.set(reportRef, {
      reportId: reportRef.id,
      updateId,
      creatorId,
      reporterId,
      reason,
      details,
      status: "pending",
      ...buildModerationReviewPayload({reason, details}),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {reported: true, deduplicated: false};
  });
}

exports.reportCreatorSubscriberUpdate = onCall(async (request) =>
  reportCreatorSubscriberUpdateHandler(request),
);

async function generateAgoraTokenHandler(request, deps = {}) {
  const authUid = requireAuth(request);
  enforceRateLimit("generateAgoraToken", authUid);
  const channelName = parseIdField(
    request.data && request.data.channelName,
    "channelName",
  );
  const rtcUidValue = request.data && request.data.rtcUid;

  const rtcUid = Number(rtcUidValue);
  if (!Number.isFinite(rtcUid) || rtcUid <= 0) {
    throw new HttpsError("invalid-argument", "rtcUid must be a positive integer.");
  }

  // Only issue a token to users who have actually joined the room as a
  // participant.  This prevents unauthenticated spectators who merely know
  // a room ID from joining the Agora channel directly.
  const firestore = deps.firestore || db;
  const participantSnap = await firestore
    .collection("rooms")
    .doc(channelName)
    .collection("participants")
    .doc(authUid)
    .get();
  if (!participantSnap.exists) {
    throw new HttpsError(
      "permission-denied",
      "You must join the room before requesting a media token.",
    );
  }
  if (participantSnap.data().isBanned === true) {
    throw new HttpsError(
      "permission-denied",
      "You are not allowed to join this room.",
    );
  }

  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;
  if (!appId || !appCertificate) {
    throw new HttpsError(
      "failed-precondition",
      "Agora server credentials are not configured.",
    );
  }

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const expirationTimeInSeconds = 3600;
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    Math.floor(rtcUid),
    RtcRole.PUBLISHER,
    privilegeExpiredTs,
  );

  return {
    token,
    appId,
    expiresAt: privilegeExpiredTs,
    issuedForUid: authUid,
  };
}

exports.generateAgoraToken = onCall({secrets: [AGORA_APP_ID, AGORA_APP_CERTIFICATE]}, async (request) => generateAgoraTokenHandler(request));

async function generateTurnCredentialsHandler(request) {
  const authUid = requireAuth(request);
  enforceRateLimit("generateTurnCredentials", authUid);

  const apiKey = process.env.METERED_API_KEY;
  if (!apiKey) {
    logger.warn("generateTurnCredentials missing METERED_API_KEY; returning STUN fallback", {
      authUid,
    });
    return {iceServers: DEFAULT_ICE_SERVERS, fallback: true};
  }

  const url = `https://mixvy.metered.live/api/v1/turn/credentials?apiKey=${encodeURIComponent(apiKey)}`;
  try {
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), 5000);
    const response = await nodeFetch(url, {signal: ac.signal});
    clearTimeout(timer);
    if (!response.ok) {
      throw new Error(`TURN service returned ${response.status}.`);
    }

    const iceServers = await response.json();
    if (!Array.isArray(iceServers) || iceServers.length === 0) {
      throw new Error("TURN service returned empty credentials.");
    }

    cachedTurnIceServers = iceServers;
    cachedTurnIceServersFetchedAt = Date.now();
    return {iceServers};
  } catch (err) {
    logger.warn("generateTurnCredentials upstream unavailable; serving fallback", {
      authUid,
      error: err instanceof Error ? err.message : String(err),
      hasCachedIceServers: cachedTurnIceServers != null,
    });

    if (
      cachedTurnIceServers != null &&
      Date.now() - cachedTurnIceServersFetchedAt <= TURN_CACHE_TTL_MS
    ) {
      return {iceServers: cachedTurnIceServers, fallback: true, cached: true};
    }

    return {iceServers: DEFAULT_ICE_SERVERS, fallback: true};
  }
}

exports.generateTurnCredentials = onCall({secrets: [METERED_API_KEY]}, async (request) => generateTurnCredentialsHandler(request));

async function requestRefundHandler(request, deps = {}) {
  const requesterId = requireAuth(request);
  enforceRateLimit("requestRefund", requesterId);
  const transactionId = parseIdField(
    request.data && request.data.transactionId,
    "transactionId",
  );
  const reasonRaw = request.data && request.data.reason;
  const reason = typeof reasonRaw === "string" ? reasonRaw.trim() : "";
  const firestore = deps.firestore || db;

  if (reason.length < 10 || reason.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "reason must be between 10 and 500 characters.",
    );
  }

  const txRef = firestore.collection("transactions").doc(transactionId);
  const txSnap = await txRef.get();
  if (!txSnap.exists) {
    throw new HttpsError("not-found", "Transaction not found.");
  }

  const txData = txSnap.data() || {};
  const participants = Array.isArray(txData.participants) ? txData.participants : [];
  const senderId = typeof txData.senderId === "string" ? txData.senderId : "";
  const receiverId = typeof txData.receiverId === "string" ? txData.receiverId : "";
  const isParticipant = participants.includes(requesterId) ||
    senderId === requesterId || receiverId === requesterId;

  if (!isParticipant) {
    throw new HttpsError(
      "permission-denied",
      "You are not allowed to request a refund for this transaction.",
    );
  }

  const refundRef = firestore
      .collection("refund_requests")
      .doc(`${transactionId}_${requesterId}`);
  const refundSnap = await refundRef.get();
  const existing = refundSnap.exists ? refundSnap.data() : null;
  if (existing && (existing.status === "pending" || existing.status === "under_review")) {
    throw new HttpsError(
      "already-exists",
      "A refund request is already open for this transaction.",
    );
  }

  await refundRef.set({
    id: refundRef.id,
    transactionId,
    requesterId,
    senderId,
    receiverId,
    amount: Number(txData.amount || 0),
    status: "pending",
    reason,
    sourceStatus: txData.status || "unknown",
    sourceType: txData.source || "unknown",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    refundRequestId: refundRef.id,
    status: "pending",
  };
}

exports.requestRefund = onCall(async (request) => requestRefundHandler(request));

async function cleanupDeletedUserData(uid, deps = {}) {
  const firestore = deps.firestore || db;
  const bucket = deps.bucket || admin.storage().bucket();

  if (!uid || typeof uid !== "string") {
    throw new HttpsError("invalid-argument", "A valid user ID is required.");
  }

  const recursiveDelete = async (documentRef) => {
    if (typeof firestore.recursiveDelete === "function") {
      await firestore.recursiveDelete(documentRef);
      return;
    }
    await documentRef.delete();
  };

  const deleteMatchingDocuments = async (collection, field, operator = "==") => {
    const pageSize = 100;
    let snapshot;
    do {
      snapshot = await firestore
          .collection(collection)
          .where(field, operator, uid)
          .limit(pageSize)
          .get();
      await Promise.all(snapshot.docs.map((doc) => recursiveDelete(doc.ref)));
    } while (snapshot.size === pageSize);
  };

  const directDocuments = [
    ["users", uid],
    ["profile_public", uid],
    ["preferences", uid],
    ["verification", uid],
    ["wallets", uid],
    ["presence", uid],
    ["stripe_connect_accounts", uid],
    ["beta_feedback", uid],
    ["speed_dating_queue", uid],
  ];

  await Promise.all(directDocuments.map(([collection, documentId]) =>
    recursiveDelete(firestore.collection(collection).doc(documentId))));

  await Promise.all([
    deleteMatchingDocuments("posts", "authorId"),
    deleteMatchingDocuments("blocks", "blockerUserId"),
    deleteMatchingDocuments("blocks", "blockedUserId"),
    deleteMatchingDocuments("friendships", "userA"),
    deleteMatchingDocuments("friendships", "userB"),
    deleteMatchingDocuments("notifications", "userId"),
    deleteMatchingDocuments("notifications", "actorId"),
  ]);

  await bucket.deleteFiles({prefix: `users/${uid}/`, force: true});

  logger.info(`Cleanup complete for deleted user: ${uid}`);
}

exports.cleanupDeletedUser = functionsV1.auth.user().onDelete(async (user) => {
  if (!user || !user.uid) {
    return;
  }
  await cleanupDeletedUserData(user.uid);
});

async function deleteCurrentUserAccountHandler(request, deps = {}) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const nowSeconds = Math.floor((deps.now?.() || Date.now()) / 1000);
  const authTimeSeconds = Number(request.auth?.token?.auth_time);
  const authenticationAge = nowSeconds - authTimeSeconds;
  if (!Number.isFinite(authTimeSeconds) ||
      authenticationAge < 0 ||
      authenticationAge > 5 * 60) {
    throw new HttpsError(
        "failed-precondition",
        "Sign in again before deleting your account.",
        {reason: "requires-recent-login"},
    );
  }

  const cleanup = deps.cleanup || cleanupDeletedUserData;
  const auth = deps.auth || admin.auth();

  await cleanup(uid, deps);
  await auth.deleteUser(uid);

  logger.info("User account deleted", {uid});
  return {deleted: true};
}

exports.deleteCurrentUserAccount = onCall({invoker: "public"}, async (request) =>
  deleteCurrentUserAccountHandler(request));

exports.classifyNewReport = onDocumentCreated("reports/{reportId}", async (event) => {
  if (!event.data) {
    return;
  }

  const snapshot = event.data;
  const reportData = snapshot.data() || {};
  if (reportData.moderationReview && reportData.moderationReview.classifiedAt) {
    return;
  }

  const payload = buildModerationReviewPayload(reportData);
  await snapshot.ref.set(payload, {merge: true});
});

// HTTP Endpoint for checking block status (client-side validation before message send)
// This is a workaround for Firestore event trigger delays/issues
exports.checkBlockStatus = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const {conversationId} = request.data;
  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required");
  }

  const firestore = admin.firestore();
  try {
    // Get conversation and check if user is a participant
    const convRef = firestore.collection("conversations").doc(conversationId);
    const convSnap = await convRef.get();
    
    if (!convSnap.exists) {
      throw new HttpsError("not-found", "Conversation not found");
    }

    const convData = convSnap.data() || {};
    const participantIds = Array.isArray(convData.participantIds) ? convData.participantIds : [];
    const userId = auth.uid;

    if (!participantIds.includes(userId)) {
      throw new HttpsError("permission-denied", "User is not a participant in this conversation");
    }

    // Check if sender (userId) is blocked by ANY participant
    const otherParticipants = participantIds.filter(id => id !== userId);
    
    for (const participantId of otherParticipants) {
      // Check if this participant has blocked the sender
      const blockRef = firestore.collection("blocks").doc(`${participantId}_${userId}`);
      const blockSnap = await blockRef.get();

      if (blockSnap.exists) {
        logger.info(`Block check: ${userId} is blocked by ${participantId}`);
        return {
          canSend: false,
          blockedBy: participantId,
          message: "You are blocked by a conversation participant"
        };
      }

      // Also check if sender has blocked this participant (prevent communication both ways)
      const reverseBlockRef = firestore.collection("blocks").doc(`${userId}_${participantId}`);
      const reverseBlockSnap = await reverseBlockRef.get();

      if (reverseBlockSnap.exists) {
        logger.info(`Block check: ${userId} has blocked ${participantId}`);
        return {
          canSend: false,
          blockedBy: participantId,
          message: "You have blocked this conversation participant"
        };
      }
    }

    logger.info(`Block check: ${userId} can send message to conversation ${conversationId}`);
    return {
      canSend: true,
      message: "Message can be sent"
    };
  } catch (error) {
    logger.error("Error checking block status:", error);
    throw new HttpsError("internal", "Error checking block status");
  }
});

// Validate block enforcement for messages
// Reject messages from users who are blocked by conversation participants
exports.validateMessageBlockEnforcement = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    if (!event.data) {
      return;
    }

    const messageData = event.data.data() || {};
    const senderId = typeof messageData.senderId === "string" ? messageData.senderId.trim() : "";
    if (!senderId) {
      return;
    }

    const conversationId = event.params && event.params.conversationId;
    if (!conversationId) {
      return;
    }

    const firestore = admin.firestore();
    try {
      // Get the conversation to find all participants
      const convRef = firestore.collection("conversations").doc(conversationId);
      const convSnap = await convRef.get();
      
      if (!convSnap.exists) {
        // Conversation doesn't exist, let the message be (Firestore rules will reject)
        return;
      }

      const convData = convSnap.data() || {};
      const participantIds = Array.isArray(convData.participantIds) ? convData.participantIds : [];

      // Check if sender is blocked by any other participant
      for (const participantId of participantIds) {
        if (participantId === senderId) {
          continue; // Skip self
        }

        // Check if this participant has blocked the sender
        // Block document ID format: participantId_senderId (participant blocks sender)
        const blockRef = firestore.collection("blocks").doc(`${participantId}_${senderId}`);
        const blockSnap = await blockRef.get();

        if (blockSnap.exists) {
          // Sender is blocked by a participant, delete the message
          await event.data.ref.delete();
          logger.warn(`Message from blocked user deleted. Sender: ${senderId}, Participant: ${participantId}, Conv: ${conversationId}`);
          return;
        }
      }
    } catch (error) {
      logger.error("Error validating message block enforcement:", error);
      // Don't delete the message if there's an error - let Firestore rules handle it
    }
  }
);

// Validate block enforcement for conversations
// Prevent blocked users from creating conversations with their blockers
exports.validateConversationBlockEnforcement = onDocumentCreated(
  "conversations/{conversationId}",
  async (event) => {
    if (!event.data) {
      return;
    }

    const convData = event.data.data() || {};
    const creatorId = typeof convData.creatorId === "string" ? convData.creatorId.trim() : "";
    const participantIds = Array.isArray(convData.participantIds) ? convData.participantIds : [];

    if (!creatorId || participantIds.length === 0) {
      return;
    }

    const firestore = admin.firestore();
    try {
      // Check if creator is blocked by any other participant
      for (const participantId of participantIds) {
        if (participantId === creatorId) {
          continue; // Skip self
        }

        // Check if this participant has blocked the creator
        const blockRef = firestore.collection("blocks").doc(`${participantId}_${creatorId}`);
        const blockSnap = await blockRef.get();

        if (blockSnap.exists) {
          // Creator is blocked by a participant, delete the conversation
          await event.data.ref.delete();
          logger.warn(`Conversation from blocked user deleted. Creator: ${creatorId}, Participant: ${participantId}`);
          return;
        }
      }
    } catch (error) {
      logger.error("Error validating conversation block enforcement:", error);
      // Don't delete the conversation if there's an error
    }
  }
);

// Create Stripe Checkout Session
exports.createCheckoutSession = onRequest({secrets: [STRIPE_SECRET]}, async (req, res) =>
  createCheckoutSessionHandler(req, res),
);

exports.createCheckoutSessionCallable = onCall({secrets: [STRIPE_SECRET]}, async (request) =>
  createCheckoutSessionCallableHandler(request),
);

// Stripe Webhook
async function stripeWebhookHandler(req, res, deps = {}) {
  const sig = req.headers["stripe-signature"];
  let event;
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  try {
    event = stripeClient.webhooks.constructEvent(
      req.rawBody,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET,
    );
  } catch (err) {
    console.error("Webhook signature failed:", err.message);
    try {
      await firestore.collection("logs").add({
        type: "stripe_webhook_error",
        message: err.message,
        time: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (logErr) {
      console.error("Failed to log webhook error:", logErr.message);
    }
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    if (session.metadata?.productType === "creator_subscription") {
      await handleCreatorSubscriptionCheckoutCompleted(session, {
        firestore,
        stripeClient,
        eventId: event.id,
        eventType: event.type,
      });
    } else {
      await handleCheckoutSessionCompleted(session, {
        firestore,
        eventId: event.id,
        eventType: event.type,
      });
    }
  }

  if (event.type === "customer.subscription.updated" ||
      event.type === "customer.subscription.deleted") {
    await handleCreatorSubscriptionChanged(event.data.object, {
      firestore,
      eventId: event.id,
      eventType: event.type,
    });
  }

  if (event.type === "invoice.payment_failed" ||
      event.type === "invoice.paid") {
    await handleCreatorSubscriptionInvoice(event.data.object, {
      firestore,
      stripeClient,
      eventId: event.id,
      eventType: event.type,
    });
  }

  if (event.type === "charge.refunded") {
    const charge = event.data.object;
    await handleChargeRefunded(charge, {firestore, eventId: event.id, eventType: event.type});
  }

  return res.json({received: true});
}

function lifecycleNotificationPayloads(record, previous, eventType) {
  const payloads = [];
  const common = {creatorId: record.creatorId};
  const add = (userId, actorId, type, content) => payloads.push({
    userId,
    actorId,
    ...common,
    type,
    content,
  });
  if (eventType === "checkout.session.completed") {
    add(
      record.subscriberId,
      record.creatorId,
      "creator_subscription_started",
      "Your creator subscription is active.",
    );
    add(
      record.creatorId,
      record.subscriberId,
      "creator_subscription_started",
      "You have a new creator subscriber.",
    );
  }
  if (record.status === "past_due" && previous?.status !== "past_due") {
    add(
      record.subscriberId,
      record.creatorId,
      "creator_subscription_payment_failed",
      "A creator subscription payment failed. Update your payment method.",
    );
    add(
      record.creatorId,
      record.subscriberId,
      "creator_subscription_payment_failed",
      "A subscriber payment is past due.",
    );
  }
  if (eventType === "invoice.paid" && previous?.status === "past_due" &&
      ACTIVE_CREATOR_SUBSCRIPTION_STATUSES.has(record.status)) {
    add(
      record.subscriberId,
      record.creatorId,
      "creator_subscription_payment_restored",
      "Your creator subscription payment succeeded.",
    );
  }
  if (record.cancelAtPeriodEnd && previous?.cancelAtPeriodEnd !== true) {
    add(
      record.subscriberId,
      record.creatorId,
      "creator_subscription_cancel_scheduled",
      "Your creator subscription will cancel at the end of the billing period.",
    );
    add(
      record.creatorId,
      record.subscriberId,
      "creator_subscription_cancel_scheduled",
      "A subscriber scheduled their creator subscription to end.",
    );
  }
  if (record.terminal && previous?.status !== record.status) {
    add(
      record.subscriberId,
      record.creatorId,
      "creator_subscription_ended",
      "Your creator subscription has ended.",
    );
    add(
      record.creatorId,
      record.subscriberId,
      "creator_subscription_ended",
      "A creator subscription has ended.",
    );
  }
  return payloads;
}

async function writeCreatorSubscriptionEvent(record, deps = {}) {
  const firestore = deps.firestore || db;
  const eventId = typeof deps.eventId === "string" ? deps.eventId : null;
  if (!record.subscriberId || !record.creatorId || !record.stripeSubscriptionId) {
    return {updated: false, reason: "missing_metadata"};
  }
  const subscriptionRef = firestore.collection("creator_subscriptions")
    .doc(creatorSubscriptionDocId(record.subscriberId, record.creatorId));
  const eventRef = eventId ?
    firestore.collection("stripe_webhook_events").doc(`event_${eventId}`) : null;

  return firestore.runTransaction(async (txn) => {
    const previousSnap = await txn.get(subscriptionRef);
    if (eventRef) {
      const eventSnap = await txn.get(eventRef);
      if (eventSnap.exists) return {updated: false, reason: "deduplicated"};
    }
    const previous = previousSnap.exists ? previousSnap.data() : null;
    txn.set(subscriptionRef, {
      ...record,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (eventRef) {
      txn.set(eventRef, {
        eventId,
        eventType: deps.eventType || null,
        creatorId: record.creatorId,
        subscriberId: record.subscriberId,
        stripeSubscriptionId: record.stripeSubscriptionId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    const eventKey = eventId ||
      `${record.stripeSubscriptionId}_${deps.eventType || record.status}`;
    const notifications = lifecycleNotificationPayloads(
      record,
      previous,
      deps.eventType,
    );
    notifications.forEach((payload) => {
      const notificationRef = firestore.collection("notifications")
        .doc(notificationDocId(
          `${eventKey}_${payload.type}`,
          payload.userId,
        ));
      txn.set(notificationRef, {
        ...payload,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return {updated: true, subscription: creatorSubscriptionSummary(record)};
  });
}

async function handleCreatorSubscriptionCheckoutCompleted(session, deps = {}) {
  const subscriberId = session.metadata?.subscriberId;
  const creatorId = session.metadata?.creatorId;
  const subscriptionId = typeof session.subscription === "string" ?
    session.subscription : session.subscription?.id;
  if (!subscriberId || !creatorId || !subscriptionId) {
    return {updated: false, reason: "missing_metadata"};
  }
  const stripeClient = deps.stripeClient || getStripe();
  const subscription = await stripeClient.subscriptions.retrieve(subscriptionId);
  const record = creatorSubscriptionRecord(subscription, {
    subscriberId,
    creatorId,
    stripeCustomerId: typeof session.customer === "string" ? session.customer : null,
  });
  if (record.subscriberId !== subscriberId || record.creatorId !== creatorId) {
    return {updated: false, reason: "metadata_mismatch"};
  }
  return writeCreatorSubscriptionEvent({
    ...record,
    stripeCheckoutSessionId: session.id,
  }, deps);
}

async function handleCreatorSubscriptionChanged(subscription, deps = {}) {
  if (subscription.metadata?.productType !== "creator_subscription") {
    return {updated: false, reason: "not_creator_subscription"};
  }
  return writeCreatorSubscriptionEvent(
    creatorSubscriptionRecord(subscription),
    deps,
  );
}

async function handleCreatorSubscriptionInvoice(invoice, deps = {}) {
  const subscriptionId = typeof invoice.subscription === "string" ?
    invoice.subscription :
    invoice.subscription?.id ||
      invoice.parent?.subscription_details?.subscription;
  if (!subscriptionId) return {updated: false, reason: "no_subscription"};
  const stripeClient = deps.stripeClient || getStripe();
  const subscription = await stripeClient.subscriptions.retrieve(subscriptionId);
  if (subscription.metadata?.productType !== "creator_subscription") {
    return {updated: false, reason: "not_creator_subscription"};
  }
  const record = creatorSubscriptionRecord(subscription);
  return writeCreatorSubscriptionEvent(record, deps);
}

async function reconcileCreatorSubscriptionsHandler(deps = {}) {
  const firestore = deps.firestore || db;
  const stripeClient = deps.stripeClient || getStripe();
  const subscriptionsSnap = await firestore.collection("creator_subscriptions")
    .where("status", "in", NONTERMINAL_CREATOR_SUBSCRIPTION_STATUSES)
    .limit(100).get();
  let checked = 0;
  let updated = 0;
  let failed = 0;

  for (const doc of subscriptionsSnap.docs) {
    const stored = doc.data();
    if (!stored.stripeSubscriptionId) continue;
    checked += 1;
    try {
      const subscription = await stripeClient.subscriptions.retrieve(
        stored.stripeSubscriptionId,
      );
      if (subscription.metadata?.productType !== "creator_subscription" ||
          subscription.metadata?.subscriberId !== stored.subscriberId ||
          subscription.metadata?.creatorId !== stored.creatorId) {
        throw new Error("Stripe subscription metadata mismatch");
      }
      const record = creatorSubscriptionRecord(subscription);
      const hasDrift =
        stored.status !== record.status ||
        Number(stored.currentPeriodEnd || 0) !== Number(record.currentPeriodEnd || 0) ||
        stored.cancelAtPeriodEnd !== record.cancelAtPeriodEnd ||
        stored.terminal !== record.terminal ||
        stored.stripeCustomerId !== record.stripeCustomerId;
      if (!hasDrift) continue;
      const eventId = [
        "reconcile",
        record.stripeSubscriptionId,
        record.status,
        record.currentPeriodEnd || "none",
        record.cancelAtPeriodEnd ? "canceling" : "renewing",
      ].join("_");
      const result = await writeCreatorSubscriptionEvent(record, {
        firestore,
        eventId,
        eventType: "creator.subscription.reconciled",
      });
      if (result.updated) updated += 1;
    } catch (error) {
      failed += 1;
      await firestore.collection("logs").add({
        type: "creator_subscription_reconciliation_error",
        subscriptionDocId: doc.id,
        stripeSubscriptionId: stored.stripeSubscriptionId,
        message: String(error?.message || error).slice(0, 500),
        time: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.error("Creator subscription reconciliation failed", {
        subscriptionDocId: doc.id,
        error: String(error?.message || error),
      });
    }
  }
  return {checked, updated, failed};
}

exports.reconcileCreatorSubscriptions = onSchedule({
  schedule: "every 6 hours",
  secrets: [STRIPE_SECRET],
}, async () => reconcileCreatorSubscriptionsHandler());

// Revoke entitlement when Stripe confirms a full refund. Uses the stored
// sessionId on the charge to find the right user and writes an audit event.
async function handleChargeRefunded(charge, deps = {}) {
  const firestore = deps.firestore || db;
  const eventId = typeof deps.eventId === "string" ? deps.eventId : null;
  const eventType = typeof deps.eventType === "string" ? deps.eventType : null;
  const sessionId = charge.payment_intent ? null : charge.id;
  // Stripe attaches the Checkout session ID in metadata when a session is used.
  const metaSessionId = charge.metadata && charge.metadata.checkoutSessionId;
  const resolvedSessionId = metaSessionId || sessionId;
  if (!resolvedSessionId) {
    return {revoked: false, reason: "no_session_id"};
  }

  // Find the original entitlement event to resolve the userId.
  const entitlementEventRef = firestore.collection("entitlement_events").doc(`stripe_${resolvedSessionId}`);
  const entitlementSnap = await entitlementEventRef.get();
  if (!entitlementSnap.exists) {
    return {revoked: false, reason: "no_entitlement_event"};
  }
  const {userId} = entitlementSnap.data();
  if (!userId) {
    return {revoked: false, reason: "no_user_id"};
  }

  // Dedup: do not revoke twice for the same event.
  const dedupRef = firestore.collection("stripe_webhook_events").doc(`event_${eventId}`);
  if (eventId) {
    const dedupSnap = await dedupRef.get();
    if (dedupSnap.exists) {
      return {revoked: false, reason: "deduplicated"};
    }
  }

  const userRef = firestore.collection("users").doc(userId);
  const revokeEventRef = firestore.collection("entitlement_events").doc(`refund_${resolvedSessionId}`);

  await firestore.runTransaction(async (txn) => {
    txn.set(userRef, {
      entitlements: {
        vip: {
          active: false,
          revokedAt: admin.firestore.FieldValue.serverTimestamp(),
          revokeReason: "refund",
          sessionId: resolvedSessionId,
        },
      },
    }, {merge: true});

    txn.set(revokeEventRef, {
      id: revokeEventRef.id,
      userId,
      sessionId: resolvedSessionId,
      type: "vip_revoked",
      source: "stripe_refund",
      eventId,
      eventType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    if (eventId) {
      txn.set(dedupRef, {
        sessionId: resolvedSessionId,
        eventId,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return {revoked: true, userId};
}

exports.stripeWebhook = functionsV1.runWith({secrets: ["STRIPE_WEBHOOK_SECRET"]}).https.onRequest(async (req, res) => {
  return stripeWebhookHandler(req, res);
});

// Admin callable: grant or revoke a VIP entitlement manually.
// Only callable by users with admin: true on their Firestore user doc.
async function adminSetEntitlementHandler(request, deps = {}) {
  const callerId = requireAuth(request);
  const firestore = deps.firestore || db;

  // Verify caller is admin.
  const callerSnap = await firestore.collection("users").doc(callerId).get();
  if (!callerSnap.exists || callerSnap.data().admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const targetUserId = parseIdField(request.data && request.data.userId, "userId");
  const active = request.data && request.data.active;
  if (typeof active !== "boolean") {
    throw new HttpsError("invalid-argument", "active must be a boolean.");
  }
  const reason = typeof (request.data && request.data.reason) === "string"
    ? request.data.reason.trim().slice(0, 256)
    : (active ? "admin_grant" : "admin_revoke");

  const userRef = firestore.collection("users").doc(targetUserId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError("not-found", "Target user not found.");
  }

  const auditRef = firestore.collection("entitlement_events").doc();
  await firestore.runTransaction(async (txn) => {
    txn.set(userRef, {
      entitlements: {
        vip: {
          active,
          source: "admin_override",
          adminId: callerId,
          reason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
    }, {merge: true});

    txn.set(auditRef, {
      id: auditRef.id,
      userId: targetUserId,
      type: active ? "vip_admin_granted" : "vip_admin_revoked",
      source: "admin_override",
      adminId: callerId,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {success: true, userId: targetUserId, active};
}

exports.adminSetEntitlement = onCall(async (request) => adminSetEntitlementHandler(request));

// ---------------------------------------------------------------------------
// Beta feedback
// ---------------------------------------------------------------------------

/**
 * submitBetaFeedback – callable function that writes a beta tester's checklist
 * result to Firestore.
 *
 * Expected payload:
 *   { sections: [{ title: string, items: [{ label: string, status: 'pass'|'fail'|'partial', note: string }] }] }
 *
 * Writes to:  beta_feedback/{uid}/submissions/{autoId}
 */
async function submitBetaFeedbackHandler(request) {
  const { auth, data } = request;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");

  const uid = auth.uid;
  const sections = data?.sections;
  if (!Array.isArray(sections) || sections.length === 0) {
    throw new HttpsError("invalid-argument", "sections must be a non-empty array.");
  }

  // Validate + sanitise each section
  const sanitised = sections.map((section) => {
    if (typeof section.title !== "string") throw new HttpsError("invalid-argument", "section.title must be a string.");
    const items = Array.isArray(section.items) ? section.items.map((item) => {
      const validStatuses = ["pass", "fail", "partial", "untested"];
      const status = validStatuses.includes(item.status) ? item.status : "untested";
      return {
        label: String(item.label ?? "").slice(0, 200),
        status,
        note: String(item.note ?? "").slice(0, 1000),
      };
    }) : [];
    return { title: String(section.title).slice(0, 100), items };
  });

  await db.collection("beta_feedback").doc(uid).collection("submissions").add({
    uid,
    sections: sanitised,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    appVersion: data?.appVersion ?? null,
    platform: data?.platform ?? null,
  });
}

exports.submitBetaFeedback = onCall(async (request) => {
  return submitBetaFeedbackHandler(request);
});

// ── claimDailyCheckin ───────────────────────────────────────────────────────
// Server-authoritative daily check-in reward. Client must NOT write coin
// balances directly; this function is the only path that increments coins.
async function claimDailyCheckinHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("claimDailyCheckin", userId);

  const firestore = deps.firestore || db;
  const userRef = firestore.collection("users").doc(userId);

  return await firestore.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const data = userSnap.data();

    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10); // YYYY-MM-DD

    const lastCheckinRaw = data.lastCheckinDate;
    let lastDate = null;
    if (lastCheckinRaw && lastCheckinRaw.toDate) {
      lastDate = lastCheckinRaw.toDate();
    } else if (typeof lastCheckinRaw === "string") {
      lastDate = new Date(lastCheckinRaw);
    }

    const lastDateStr = lastDate ? lastDate.toISOString().slice(0, 10) : null;

    if (lastDateStr === todayStr) {
      throw new HttpsError("already-exists", "Daily reward already claimed today.");
    }

    // Calculate streak
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().slice(0, 10);

    const currentStreak = (typeof data.checkinStreak === "number") ? data.checkinStreak : 0;
    const newStreak = (lastDateStr === yesterdayStr) ? currentStreak + 1 : 1;

    // Reward: streak day clamped to 1–7, then × 10 coins
    const rewardDay = Math.min(Math.max(newStreak, 1), 7);
    const reward = rewardDay * 10;

    tx.update(userRef, {
      lastCheckinDate: admin.firestore.FieldValue.serverTimestamp(),
      checkinStreak: newStreak,
      balance: admin.firestore.FieldValue.increment(reward),
      coinBalance: admin.firestore.FieldValue.increment(reward),
    });

    return { reward, streak: newStreak };
  });
}

exports.claimDailyCheckin = onCall(async (request) => claimDailyCheckinHandler(request));

exports.syncPostCommentCount = onDocumentWritten(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const beforeExists = !!(event.data && event.data.before && event.data.before.exists);
    const afterExists = !!(event.data && event.data.after && event.data.after.exists);

    if (beforeExists === afterExists) {
      return;
    }

    const delta = afterExists ? 1 : -1;
    const postId = event.params && event.params.postId;
    if (!postId) {
      return;
    }

    await db.collection("posts").doc(postId).set({
      commentCount: admin.firestore.FieldValue.increment(delta),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  },
);

/**
 * promoteToBetaTester – admin-only callable that stamps betaTester:true on a
 * specific user doc (or all users when uid is omitted).
 *
 * Payload: { uid?: string }
 * Requires the caller to have  admin:true  on their Firestore user doc.
 */
exports.promoteToBetaTester = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");

  // Verify caller is admin
  const callerDoc = await db.collection("users").doc(auth.uid).get();
  if (callerDoc.data()?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const targetUid = data?.uid;
  if (targetUid) {
    // Promote a single user
    await db.collection("users").doc(String(targetUid)).set(
      { betaTester: true },
      { merge: true },
    );
    return { promoted: 1 };
  }

  // Promote ALL users in batches of 500
  let promoted = 0;
  let lastDoc = null;
  do {
    let query = db.collection("users").limit(500);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.set(doc.ref, { betaTester: true }, { merge: true });
    });
    await batch.commit();
    promoted += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
  } while (lastDoc);

  return { promoted };
});

// ─────────────────────────────────────────────────────────────────────────────
// SPEED DATING
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sends an FCM push notification to a single user (best-effort; errors ignored).
 */
async function _sendPushToUser(userId, { title, body, data = {} }) {
  const tokenSnap = await db
    .collection("users")
    .doc(userId)
    .collection("notification_tokens")
    .limit(100)
    .get();

  const tokens = tokenSnap.docs
    .map((d) => (d.data().token || "").trim())
    .filter((t) => t.length > 0);

  if (tokens.length === 0) return;

  const payload = {
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)]),
    ),
    tokens,
  };

  try {
    await admin.messaging().sendEachForMulticast(payload);
  } catch (_) {
    // Best-effort — do not fail the calling function
  }
}

const SPEED_DATING_SESSION_SECONDS = 90;
const SPEED_DATING_QUEUE_SCAN_LIMIT = 30;
const SPEED_DATING_CANDIDATE_SCAN_LIMIT = 80;
const SPEED_DATING_CANDIDATE_RESULT_LIMIT = 40;
const SPEED_DATING_CANDIDATE_MAX_PAGES = 5;

function existingSpeedDatingMatch(queueData) {
  if (!queueData?.matched || typeof queueData.sessionId !== "string") {
    return null;
  }
  return {
    matched: true,
    sessionId: queueData.sessionId,
    partnerId: typeof queueData.partnerId === "string" ?
      queueData.partnerId :
      undefined,
  };
}

async function ensureSpeedDatingQueueEntry(firestore, uid) {
  const queueRef = firestore.collection("speed_dating_queue").doc(uid);
  const existingMatch = await firestore.runTransaction(async (tx) => {
    const snapshot = await tx.get(queueRef);
    const match = snapshot.exists ?
      existingSpeedDatingMatch(snapshot.data()) :
      null;
    if (match) return match;
    tx.set(queueRef, {
      uid,
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      matched: false,
    });
    return null;
  });
  return {queueRef, existingMatch};
}

async function claimSpeedDatingMatch({
  firestore,
  queueRef,
  partnerRef,
  sessionRef,
  uid,
  partnerId,
  expiresAt,
}) {
  return firestore.runTransaction(async (tx) => {
    const [ownQueue, partnerQueue] = await Promise.all([
      tx.get(queueRef),
      tx.get(partnerRef),
    ]);
    const ownMatch = ownQueue.exists ?
      existingSpeedDatingMatch(ownQueue.data()) :
      null;
    if (ownMatch) return ownMatch;
    if (!ownQueue.exists || !partnerQueue.exists || partnerQueue.data().matched) {
      return null;
    }

    tx.set(sessionRef, {
      participantIds: [uid, partnerId],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      active: true,
    });
    tx.update(queueRef, {
      matched: true,
      sessionId: sessionRef.id,
      partnerId,
    });
    tx.update(partnerRef, {
      matched: true,
      sessionId: sessionRef.id,
      partnerId: uid,
    });
    return {
      matched: true,
      sessionId: sessionRef.id,
      partnerId,
    };
  });
}

function blockedUserIdsFromRows(uid, rows) {
  const blocked = new Set();
  for (const row of rows) {
    if (row.blockerUserId === uid && typeof row.blockedUserId === "string") {
      blocked.add(row.blockedUserId);
    }
    if (row.blockedUserId === uid && typeof row.blockerUserId === "string") {
      blocked.add(row.blockerUserId);
    }
  }
  return blocked;
}

async function _readBlockedUserIds(uid) {
  const [outgoing, incoming] = await Promise.all([
    db.collection("blocks").where("blockerUserId", "==", uid).get(),
    db.collection("blocks").where("blockedUserId", "==", uid).get(),
  ]);
  return blockedUserIdsFromRows(uid, [
    ...outgoing.docs.map((doc) => doc.data()),
    ...incoming.docs.map((doc) => doc.data()),
  ]);
}

/** Reads the owner-only dating preference docs for the given uids in one batch. */
async function _readDatingPrivateDocs(uids) {
  const unique = [...new Set(uids)];
  const result = new Map();
  if (unique.length === 0) return result;
  const snaps = await db.getAll(
    ...unique.map((id) => db.doc(`users/${id}/private/dating`)),
  );
  snaps.forEach((snap, i) => result.set(unique[i], snap.exists ? snap.data() : {}));
  return result;
}

/**
 * joinSpeedDatingQueue – callable that places the authenticated user in the
 * speed_dating_queue collection and, if a waiting partner is found, creates
 * a matched session room in speed_dating_sessions.
 *
 * Only partners whose dating preferences are mutually compatible are matched.
 *
 * Returns: { matched: boolean, sessionId?: string, partnerId?: string }
 */
async function joinSpeedDatingQueueHandler(request) {
  const { auth } = request;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const {queueRef, existingMatch} =
    await ensureSpeedDatingQueueEntry(db, uid);
  if (existingMatch) return existingMatch;

  // Look for a waiting user who is compatible with this user's preferences
  const [waiting, blockedUserIds] = await Promise.all([
    db
      .collection("speed_dating_queue")
      .where("matched", "==", false)
      .limit(SPEED_DATING_QUEUE_SCAN_LIMIT)
      .get(),
    _readBlockedUserIds(uid),
  ]);

  const waitingDocs = waiting.docs.filter(
    (doc) => doc.id !== uid && !blockedUserIds.has(doc.id),
  );
  if (waitingDocs.length === 0) {
    return { matched: false };
  }

  const waitingIds = waitingDocs.map((doc) => doc.id);
  const [viewerSnap, partnerSnaps, privateDocs] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    db.getAll(...waitingIds.map((id) => db.doc(`users/${id}`))),
    _readDatingPrivateDocs([uid, ...waitingIds]),
  ]);
  if (!viewerSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Complete your profile before joining speed dating.",
    );
  }
  const viewerProfile = buildDatingProfile(
    viewerSnap.data() || {},
    privateDocs.get(uid),
  );
  const partnerIndex = waitingDocs.findIndex((doc, i) =>
    partnerSnaps[i].exists && isCompatiblePair(
      viewerProfile,
      buildDatingProfile(partnerSnaps[i].data() || {}, privateDocs.get(doc.id)),
    ),
  );
  if (partnerIndex === -1) {
    return { matched: false };
  }

  const partnerDoc = waitingDocs[partnerIndex];
  const partnerId = partnerDoc.id;

  // Create a session atomically
  const sessionRef = db.collection("speed_dating_sessions").doc();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + SPEED_DATING_SESSION_SECONDS * 1000,
  );

  const match = await claimSpeedDatingMatch({
    firestore: db,
    queueRef,
    partnerRef: partnerDoc.ref,
    sessionRef,
    uid,
    partnerId,
    expiresAt,
  });
  if (!match) return {matched: false};
  if (match.sessionId !== sessionRef.id) return match;

  // Notify both participants (best-effort, outside the transaction)
  const pushPayload = {
    title: "MixVy Speed Date 💘",
    body: "You've been matched! Your speed date is starting now.",
    data: { type: "speed_dating_match", sessionId: sessionRef.id },
  };
  await Promise.allSettled([
    _sendPushToUser(uid, pushPayload),
    _sendPushToUser(partnerId, pushPayload),
  ]);

  return match;
}

exports.joinSpeedDatingQueue = onCall(joinSpeedDatingQueueHandler);

/**
 * getSpeedDatingCandidates – returns up to 40 users the caller may be matched
 * with, after applying both sides' dating preferences. Private fields (race,
 * sexuality, coordinates) are read here with admin access and never returned.
 *
 * Returns: { candidates: [{ id, username, avatarUrl, bio, interests, distanceKm }] }
 */
exports.getSpeedDatingCandidates = onCall(async (request) => {
  const { auth } = request;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const [viewerSnap, viewerPrivateDocs, blockedUserIds] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    _readDatingPrivateDocs([uid]),
    _readBlockedUserIds(uid),
  ]);
  if (!viewerSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Complete your profile before browsing speed dating.",
    );
  }

  const viewerProfile = buildDatingProfile(
    viewerSnap.data() || {},
    viewerPrivateDocs.get(uid),
  );

  const candidates = [];
  let lastDocument = null;
  for (
    let page = 0;
    page < SPEED_DATING_CANDIDATE_MAX_PAGES &&
      candidates.length < SPEED_DATING_CANDIDATE_RESULT_LIMIT;
    page++
  ) {
    let query = db
      .collection("users")
      .where("username", ">", "")
      .orderBy("username")
      .limit(SPEED_DATING_CANDIDATE_SCAN_LIMIT);
    if (lastDocument) query = query.startAfter(lastDocument);

    const scan = await query.get();
    if (scan.empty) break;
    lastDocument = scan.docs.at(-1);
    const others = scan.docs.filter(
      (doc) => doc.id !== uid && !blockedUserIds.has(doc.id),
    );
    const privateDocs = await _readDatingPrivateDocs(
      others.map((doc) => doc.id),
    );

    for (const doc of others) {
      if (candidates.length >= SPEED_DATING_CANDIDATE_RESULT_LIMIT) break;
      const data = doc.data() || {};
      const profile = buildDatingProfile(data, privateDocs.get(doc.id));
      if (!isCompatiblePair(viewerProfile, profile)) continue;
      candidates.push({
        id: doc.id,
        username: typeof data.username === "string" ? data.username : "",
        avatarUrl: typeof data.avatarUrl === "string" ? data.avatarUrl : null,
        bio: typeof data.bio === "string" ? data.bio : null,
        interests: Array.isArray(data.interests)
          ? data.interests
            .filter((item) => typeof item === "string")
            .slice(0, 20) :
          [],
        distanceKm: distanceBetweenKm(viewerProfile, profile),
      });
    }
    if (scan.size < SPEED_DATING_CANDIDATE_SCAN_LIMIT) break;
  }

  return { candidates };
});

/**
 * leaveSpeedDatingQueue – callable that removes the caller from the queue.
 */
exports.leaveSpeedDatingQueue = onCall(async (request) => {
  const { auth } = request;
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  await db.collection("speed_dating_queue").doc(auth.uid).delete();
  return { ok: true };
});

/**
 * Helper function: Exponential backoff retry wrapper for Firestore operations.
 * Handles transient network errors, disconnections, and timeouts.
 *
 * @param {Function} operation - Async function that performs the Firestore operation
 * @param {number} maxAttempts - Maximum number of retry attempts (default: 3)
 * @param {number} initialDelayMs - Initial backoff delay in milliseconds (default: 100)
 * @returns {Promise} Result of the operation
 */
async function retryWithBackoff(
  operation,
  maxAttempts = 3,
  initialDelayMs = 100,
) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      console.log(`[Attempt ${attempt}/${maxAttempts}] Starting operation...`);
      return await Promise.race([
        operation(),
        new Promise((_, reject) =>
          setTimeout(
            () => reject(new Error("Operation timeout after 25s")),
            25000,
          ),
        ),
      ]);
    } catch (error) {
      lastError = error;
      const isTransientError =
        error.code === "UNAVAILABLE" ||
        error.code === "DEADLINE_EXCEEDED" ||
        error.code === "INTERNAL" ||
        error.message?.includes("ECONNREFUSED") ||
        error.message?.includes("timeout");

      if (attempt < maxAttempts && isTransientError) {
        const delayMs = initialDelayMs * Math.pow(2, attempt - 1);
        console.warn(
          `[Attempt ${attempt}/${maxAttempts}] Transient error: ${error.message}. ` +
          `Retrying in ${delayMs}ms...`,
        );
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      } else if (attempt === maxAttempts) {
        console.error(
          `[Attempt ${attempt}/${maxAttempts}] Final attempt failed: ${error.message}`,
        );
        throw error;
      } else {
        console.error(
          `[Attempt ${attempt}/${maxAttempts}] Non-transient error: ${error.message}`,
        );
        throw error;
      }
    }
  }
  throw lastError;
}

/**
 * cleanupExpiredSpeedDatingSessions – scheduled function that runs every
 * 5 minutes, marks expired sessions inactive, and removes matched queue
 * entries older than 10 minutes.
 *
 * HARDENED: Includes exponential backoff retry logic for transient network errors
 * and separate error handling for each cleanup phase so partial failures don't
 * cascade into full job failure.
 */
exports.cleanupExpiredSpeedDatingSessions = onSchedule(
  "every 5 minutes",
  async () => {
    const startTime = Date.now();
    let sessionsCleaned = 0;
    let roomsCleaned = 0;
    let queueEntriesRemoved = 0;
    const errors = [];

    try {
      const now = admin.firestore.Timestamp.now();

      // 1. Deactivate expired sessions
      try {
        console.log("[1/3] Starting speed_dating_sessions cleanup...");
        const result = await retryWithBackoff(
          async () => {
            const sessions = await db
              .collection("speed_dating_sessions")
              .where("active", "==", true)
              .where("expiresAt", "<=", now)
              .limit(200)
              .get();

            if (sessions.empty) {
              console.log("No expired sessions to clean.");
              return 0;
            }

            const batch = db.batch();
            sessions.docs.forEach((doc) => {
              batch.update(doc.ref, {active: false});
            });
            await batch.commit();
            return sessions.size;
          },
          3,
          100,
        );
        sessionsCleaned = result;
        console.log(`[1/3] Cleaned ${sessionsCleaned} expired sessions.`);
      } catch (error) {
        errors.push(
          `sessions cleanup failed: ${error.message}`,
        );
        console.error(
          `[1/3] ERROR: ${errors[errors.length - 1]}`,
        );
      }

      // 2. Deactivate expired rooms (speed dating category)
      try {
        console.log("[2/3] Starting speed_dating rooms cleanup...");
        const result = await retryWithBackoff(
          async () => {
            const rooms = await db
              .collection("rooms")
              .where("category", "==", "speed_dating")
              .where("isLive", "==", true)
              .where("expiresAt", "<=", now)
              .limit(200)
              .get();

            if (rooms.empty) {
              console.log("No expired rooms to clean.");
              return 0;
            }

            const batch = db.batch();
            rooms.docs.forEach((doc) => {
              batch.update(doc.ref, {
                isLive: false,
                endedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            });
            await batch.commit();
            return rooms.size;
          },
          3,
          100,
        );
        roomsCleaned = result;
        console.log(`[2/3] Cleaned ${roomsCleaned} expired rooms.`);
      } catch (error) {
        errors.push(
          `rooms cleanup failed: ${error.message}`,
        );
        console.error(
          `[2/3] ERROR: ${errors[errors.length - 1]}`,
        );
      }

      // 3. Remove stale queue entries (matched or joined > 10 min ago)
      try {
        console.log("[3/3] Starting stale queue cleanup...");
        const result = await retryWithBackoff(
          async () => {
            const staleCutoff = admin.firestore.Timestamp.fromMillis(
              Date.now() - 10 * 60 * 1000,
            );
            const queue = await db
              .collection("speed_dating_queue")
              .where("joinedAt", "<=", staleCutoff)
              .limit(200)
              .get();

            if (queue.empty) {
              console.log("No stale queue entries to remove.");
              return 0;
            }

            const batch = db.batch();
            queue.docs.forEach((doc) => {
              batch.delete(doc.ref);
            });
            await batch.commit();
            return queue.size;
          },
          3,
          100,
        );
        queueEntriesRemoved = result;
        console.log(
          `[3/3] Removed ${queueEntriesRemoved} stale queue entries.`,
        );
      } catch (error) {
        errors.push(
          `queue cleanup failed: ${error.message}`,
        );
        console.error(
          `[3/3] ERROR: ${errors[errors.length - 1]}`,
        );
      }

      const elapsedMs = Date.now() - startTime;
      const summary = `Cleanup complete: ${sessionsCleaned} sessions, ` +
        `${roomsCleaned} rooms, ${queueEntriesRemoved} queue entries (${elapsedMs}ms)`;

      if (errors.length > 0) {
        console.warn(
          `${summary}. PARTIAL FAILURE: ${errors.join("; ")}`,
        );
      } else {
        console.log(summary);
      }
    } catch (error) {
      console.error(
        `Cleanup job failed unexpectedly: ${error.message}`,
        error,
      );
      throw error;
    }
  },
);

/**
 * cleanupExpiredStories – daily scheduled function that hard-deletes story
 * documents in users/{userId}/stories where expiresAt has passed.
 * Stories are 24-hour ephemeral content, so we purge them server-side to
 * keep Firestore tidy and billing low.
 */
exports.cleanupExpiredStories = onSchedule("every 24 hours", async () => {
  const now = admin.firestore.Timestamp.now();

  // collectionGroup query across all users' stories sub-collections
  const expired = await db
    .collectionGroup("stories")
    .where("expiresAt", "<=", now)
    .where("isDeleted", "==", false)
    .limit(500)
    .get();

  if (expired.empty) return;

  // Batch deletes (max 500 per commit)
  const batch = db.batch();
  expired.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  logger.info(`cleanupExpiredStories: deleted ${expired.size} expired stories`);
});

/**
 * cleanupExpiredMessages – scheduled retention job that hard-deletes expired
 * conversation messages and repairs parent conversation preview metadata.
 */
exports.cleanupExpiredMessages = onSchedule("every 6 hours", async () => {
  const now = admin.firestore.Timestamp.now();
  const touchedConversationIds = new Set();
  let deletedCount = 0;

  while (true) {
    const expired = await db
      .collectionGroup("messages")
      .where("expiresAt", "<=", now)
      .limit(CHAT_RETENTION_BATCH_LIMIT)
      .get();

    if (expired.empty) break;

    const batch = db.batch();
    for (const doc of expired.docs) {
      const conversationRef = doc.ref.parent.parent;
      if (conversationRef) touchedConversationIds.add(conversationRef.id);
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedCount += expired.size;

    if (expired.size < CHAT_RETENTION_BATCH_LIMIT) break;
  }

  for (const conversationId of touchedConversationIds) {
    await rebuildConversationSummary(conversationId);
  }

  logger.info(
    `cleanupExpiredMessages: deleted ${deletedCount} messages across ${touchedConversationIds.size} conversations`,
  );
});

// ── Discovery Feed API (bypasses browser extension blocking) ─────────────────
/**
 * GET /api/feed – Server-side discovery feed endpoint that bypasses browser
 * extension blocking. Makes Firestore requests server-to-server instead of
 * client-to-server, so extensions cannot intercept the calls.
 *
 * Query parameters:
 *   - userId: optional, for personalized recommendations
 *
 * Returns: { liveRooms, upcomingRooms, trendingUsers, cachedAt }
 */
exports.feed = onRequest(
  { cors: true, region: "us-east1" },
  async (request, response) => {
    try {
      // Extract userId from query params (optional)
      const userId = request.query.userId || null;

      // Fetch live rooms (top 20 by activity)
      // Note: We fetch without ordering first, then sort in memory to avoid requiring
      // a composite index (isLive + participantCount). This is safe because active
      // rooms are typically < 500 docs, well within Firestore document limits.
      const liveRoomsSnap = await db
        .collection("rooms")
        .where("isLive", "==", true)
        .limit(200)  // Fetch more, then sort in memory for top 20
        .get();

      const activeParticipantCutoff = admin.firestore.Timestamp.fromMillis(
        Date.now() - 90 * 1000,
      );
      const activeParticipantsSnap = await db
        .collectionGroup("participants")
        .get();
      const activeParticipantsByRoom = new Map();
      const stageRoles = new Set([
        "host",
        "owner",
        "cohost",
        "moderator",
        "trusted_speaker",
        "stage",
      ]);

      for (const participantDoc of activeParticipantsSnap.docs) {
        const roomRef = participantDoc.ref.parent.parent;
        if (!roomRef) continue;

        const data = participantDoc.data();
        const lastActiveAt = data.lastActiveAt;
        if (!(lastActiveAt instanceof admin.firestore.Timestamp) ||
            lastActiveAt.toMillis() < activeParticipantCutoff.toMillis()) {
          continue;
        }
        if (String(data.userStatus || "").trim().toLowerCase() === "offline") {
          continue;
        }

        const roomId = roomRef.id;
        const participant = activeParticipantsByRoom.get(roomId) || {
          stageUserIds: [],
          audienceUserIds: [],
          stageUserAvatarUrls: [],
          audienceUserAvatarUrls: [],
        };
        const userId = String(data.userId || participantDoc.id).trim();
        if (!userId) continue;

        const role = String(data.role || "audience").trim().toLowerCase();
        const photoUrl = String(data.photoUrl || "").trim();
        if (stageRoles.has(role)) {
          participant.stageUserIds.push(userId);
          participant.stageUserAvatarUrls.push(photoUrl);
        } else {
          participant.audienceUserIds.push(userId);
          participant.audienceUserAvatarUrls.push(photoUrl);
        }
        activeParticipantsByRoom.set(roomId, participant);
      }

      const liveRooms = liveRoomsSnap.docs
        .map((doc) => {
          const data = doc.data();
          const active = activeParticipantsByRoom.get(doc.id) || {
            stageUserIds: [],
            audienceUserIds: [],
            stageUserAvatarUrls: [],
            audienceUserAvatarUrls: [],
          };
          return {
            id: doc.id,
            ...data,
            ...active,
            memberCount:
              active.stageUserIds.length + active.audienceUserIds.length,
            // Ensure serializable timestamps
            createdAt:
              data.createdAt instanceof admin.firestore.Timestamp
                ? data.createdAt.toMillis()
                : data.createdAt,
            updatedAt:
              data.updatedAt instanceof admin.firestore.Timestamp
                ? data.updatedAt.toMillis()
                : data.updatedAt,
          };
        })
        .sort((a, b) => b.memberCount - a.memberCount)
        .slice(0, 20);  // Take top 20 after sorting

      // Fetch upcoming rooms (next 48 hours)
      // Simplified to avoid composite index: fetch without date filtering, then filter in memory
      const nowTimestamp = admin.firestore.Timestamp.now();
      const in48Hours = admin.firestore.Timestamp.fromMillis(
        Date.now() + 48 * 60 * 60 * 1000
      );

      const upcomingRoomsSnap = await db
        .collection("rooms")
        .where("isLive", "==", false)
        .limit(100)  // Fetch extra, filter/sort in memory
        .get();

      const upcomingRooms = upcomingRoomsSnap.docs
        .map((doc) => ({
          id: doc.id,
          ...doc.data(),
          createdAt:
            doc.data().createdAt instanceof admin.firestore.Timestamp
              ? doc.data().createdAt.toMillis()
              : doc.data().createdAt,
          scheduledAt:
            doc.data().scheduledAt instanceof admin.firestore.Timestamp
              ? doc.data().scheduledAt.toMillis()
              : doc.data().scheduledAt,
        }))
        .filter((room) => {
          const scheduled = room.scheduledAt || 0;
          const nowMs = nowTimestamp.toMillis ? nowTimestamp.toMillis() : Date.now();
          const in48Ms = in48Hours.toMillis ? in48Hours.toMillis() : Date.now() + 48 * 60 * 60 * 1000;
          return scheduled >= nowMs && scheduled <= in48Ms;
        })
        .sort((a, b) => (a.scheduledAt || 0) - (b.scheduledAt || 0))
        .slice(0, 8);

      // Fetch trending users (top 10 by coin balance)
      // Simplified to avoid composite index: fetch without ordering, sort in memory
      const trendingUsersSnap = await db
        .collection("users")
        .where("isPrivate", "==", false)
        .limit(50)  // Fetch extra, sort in memory for top 10
        .get();

      const trendingUsers = trendingUsersSnap.docs
        .map((doc) => ({
          id: doc.id,
          ...doc.data(),
          // Convert timestamps
          createdAt:
            doc.data().createdAt instanceof admin.firestore.Timestamp
              ? doc.data().createdAt.toMillis()
              : doc.data().createdAt,
        }))
        .sort((a, b) => (b.coinBalance || 0) - (a.coinBalance || 0))
        .slice(0, 10);  // Take top 10 after sorting

      const responseData = {
        liveRooms,
        upcomingRooms,
        trendingUsers,
        cachedAt: new Date().toISOString(),
        success: true,
      };

      // Keep active presence counts responsive while still absorbing refresh bursts.
      response.set("Cache-Control", "public, max-age=15, s-maxage=15");
      response.set("Content-Type", "application/json");
      response.set("X-Feed-Timestamp", new Date().toISOString());

      return response.status(200).json(responseData);
    } catch (error) {
      logger.error(`Feed API error: ${error.message}`);
      return response.status(500).json({
        success: false,
        error: "Failed to load discovery feed",
        message: error.message,
      });
    }
  }
);

// ── PROFILE ENDPOINTS ──────────────────────────────────────────────────────────
// Provides server-side profile operations to bypass browser extension blocking.
// Endpoints:
//   GET /profile/{userId} - Fetch any user's profile
//   POST /profile/{userId} - Update profile (requires auth)
//   GET /profile/me - Get current user's profile (requires auth)

// Helper: Convert Firestore timestamps to milliseconds
function convertTimestamps(doc) {
  const data = { ...doc.data() };
  Object.keys(data).forEach((key) => {
    if (data[key] instanceof admin.firestore.Timestamp) {
      data[key] = data[key].toMillis();
    }
  });
  return data;
}

// Fields that must never be returned by the public profile endpoint.
const PRIVATE_PROFILE_FIELDS = [
  "admin", "isAdmin", "role", "roles", "membershipLevel", "vipLevel",
  "coins", "coinBalance", "cashBalance", "wallet", "security", "email",
  "phoneNumber", "phone", "fcmToken", "fcmTokens", "stripeCustomerId",
  "isVerified", "isAdultVerified", "adultVerified", "verificationStatus",
  "adultModeEnabled", "adultConsentAccepted", "adultModeEnabledAt",
];

function stripPrivateProfileFields(data) {
  const copy = {...data};
  for (const field of PRIVATE_PROFILE_FIELDS) {
    delete copy[field];
  }
  return copy;
}

// Returns the caller's uid when a valid Bearer ID token is present, otherwise null.
async function optionalViewerUid(request) {
  const authHeader = request.headers && request.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.substring(7));
    return decoded.uid;
  } catch (error) {
    return null;
  }
}

exports.getProfile = onRequest(
  { cors: true, region: "us-east1" },
  async (request, response) => {
    try {
      const userId = request.query.userId || request.params?.userId;

      if (!userId || userId.trim() === "") {
        return response.status(400).json({
          success: false,
          error: "userId parameter required",
        });
      }

      // Fetch user document
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        return response.status(404).json({
          success: false,
          error: "User not found",
        });
      }

      const userData = convertTimestamps(userDoc);

      // Fetch privacy settings
      let privacyData = {
        isPrivate: false,
        showAge: true,
        showGender: true,
        showLocation: true,
        showRelationshipStatus: true,
      };
      const privacyDoc = await db
        .collection("users")
        .doc(userId)
        .collection("privacy")
        .doc("settings")
        .get();
      if (privacyDoc.exists) {
        privacyData = convertTimestamps(privacyDoc);
      }

      // Fetch profile_public if it exists
      let profilePublicData = {};
      const profilePublicDoc = await db
        .collection("profile_public")
        .doc(userId)
        .get();
      if (profilePublicDoc.exists) {
        profilePublicData = convertTimestamps(profilePublicDoc);
      }

      // Fetch adult profile only for its owner. The viewer must present their own ID token.
      let adultProfileData = {
        enabled: false,
        adultConsentAccepted: false,
      };
      const viewerUid = await optionalViewerUid(request);
      if (viewerUid === userId) {
        const adultDoc = await db
          .collection("users")
          .doc(userId)
          .collection("adult_profile")
          .doc("details")
          .get();
        if (adultDoc.exists) {
          adultProfileData = convertTimestamps(adultDoc);
        }
      }

      // Combine all profile data
      const profileData = {
        ...stripPrivateProfileFields(userData),
        ...stripPrivateProfileFields(profilePublicData),
        privacy: privacyData,
        adultProfile: adultProfileData,
        success: true,
        loadedAt: new Date().toISOString(),
      };

      response.set("Cache-Control", "no-cache, no-store, must-revalidate");
      response.set("Content-Type", "application/json");
      return response.status(200).json(profileData);
    } catch (error) {
      logger.error(`Get profile error: ${error.message}`);
      return response.status(500).json({
        success: false,
        error: "Failed to load profile",
        message: error.message,
      });
    }
  }
);

exports.saveProfile = onRequest(
  { cors: true, region: "us-east1" },
  async (request, response) => {
    // Require authentication
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return response.status(401).json({
        success: false,
        error: "Unauthorized - missing auth token",
      });
    }

    try {
      const token = authHeader.substring(7);
      const decodedToken = await admin.auth().verifyIdToken(token);
      const userId = decodedToken.uid;

      const { userData, privacy, adultProfile } = request.body;

      if (!userData || typeof userData !== "object") {
        return response.status(400).json({
          success: false,
          error: "userData object required in request body",
        });
      }

      const batch = db.batch();

      // Update users/{userId} with identity fields
      const userRef = db.collection("users").doc(userId);
      const identityFields = {
        uid: userId,
        id: userId,
        username: userData.username || "",
        displayName: userData.username || "",
        email: userData.email || "",
        photoUrl: userData.avatarUrl || null,
        bio: userData.bio || null,
        age: userData.age || 0,
        gender: userData.gender || null,
        location: userData.location || null,
        relationshipStatus: userData.relationshipStatus || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      batch.set(userRef, identityFields, {merge: true});

      // Update profile_public/{userId} with public profile data
      const profilePublicRef = db.collection("profile_public").doc(userId);
      const profilePublicFields = {
        avatarUrl: userData.avatarUrl || null,
        coverPhotoUrl: userData.coverPhotoUrl || null,
        galleryUrls: userData.galleryUrls || [],
        introVideoUrl: userData.introVideoUrl || null,
        bio: userData.bio || null,
        aboutMe: userData.aboutMe || null,
        interests: userData.interests || [],
        vibePrompt: userData.vibePrompt || null,
        firstDatePrompt: userData.firstDatePrompt || null,
        musicTastePrompt: userData.musicTastePrompt || null,
        profileAccentColor: userData.profileAccentColor || null,
        profileBgGradientStart: userData.profileBgGradientStart || null,
        profileBgGradientEnd: userData.profileBgGradientEnd || null,
        profileMusicUrl: userData.profileMusicUrl || null,
        profileMusicTitle: userData.profileMusicTitle || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      batch.set(profilePublicRef, profilePublicFields, { merge: true });

      // Update privacy settings
      if (privacy && typeof privacy === "object") {
        const privacyRef = userRef.collection("privacy").doc("settings");
        batch.set(privacyRef, {
          isPrivate: privacy.isPrivate || false,
          showAge: privacy.showAge !== false,
          showGender: privacy.showGender !== false,
          showLocation: privacy.showLocation !== false,
          showRelationshipStatus: privacy.showRelationshipStatus !== false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Update adult profile if provided
      if (adultProfile && typeof adultProfile === "object") {
        const adultRef = userRef.collection("adult_profile").doc("details");
        batch.set(adultRef, {
          userId: userId,
          enabled: adultProfile.enabled || false,
          adultConsentAccepted: adultProfile.adultConsentAccepted || false,
          visibility: adultProfile.visibility || "privateOnly",
          kinks: adultProfile.kinks || [],
          preferences: adultProfile.preferences || [],
          boundaries: adultProfile.boundaries || [],
          lookingFor: adultProfile.lookingFor || [],
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // Commit batch
      await batch.commit();

      response.set("Cache-Control", "no-cache, no-store, must-revalidate");
      response.set("Content-Type", "application/json");
      return response.status(200).json({
        success: true,
        message: "Profile saved successfully",
        userId: userId,
      });
    } catch (error) {
      logger.error(`Save profile error: ${error.message}`);
      if (error.code === "auth/argument-error") {
        return response.status(401).json({
          success: false,
          error: "Invalid authentication token",
        });
      }
      return response.status(500).json({
        success: false,
        error: "Failed to save profile",
        message: error.message,
      });
    }
  }
);

exports.getCurrentUserProfile = onRequest(
  { cors: true, region: "us-east1" },
  async (request, response) => {
    // Require authentication
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return response.status(401).json({
        success: false,
        error: "Unauthorized - missing auth token",
      });
    }

    try {
      const token = authHeader.substring(7);
      const decodedToken = await admin.auth().verifyIdToken(token);
      const userId = decodedToken.uid;

      // Fetch user document
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        return response.status(404).json({
          success: false,
          error: "User profile not found",
        });
      }

      const userData = convertTimestamps(userDoc);

      // Fetch privacy settings
      let privacyData = {
        isPrivate: false,
        showAge: true,
        showGender: true,
        showLocation: true,
        showRelationshipStatus: true,
      };
      const privacyDoc = await db
        .collection("users")
        .doc(userId)
        .collection("privacy")
        .doc("settings")
        .get();
      if (privacyDoc.exists) {
        privacyData = convertTimestamps(privacyDoc);
      }

      // Fetch profile_public
      let profilePublicData = {};
      const profilePublicDoc = await db
        .collection("profile_public")
        .doc(userId)
        .get();
      if (profilePublicDoc.exists) {
        profilePublicData = convertTimestamps(profilePublicDoc);
      }

      // Fetch adult profile
      let adultProfileData = {
        enabled: false,
        adultConsentAccepted: false,
      };
      const adultDoc = await db
        .collection("users")
        .doc(userId)
        .collection("adult_profile")
        .doc("details")
        .get();
      if (adultDoc.exists) {
        adultProfileData = convertTimestamps(adultDoc);
      }

      // Combine all data
      const profileData = {
        ...userData,
        ...profilePublicData,
        privacy: privacyData,
        adultProfile: adultProfileData,
        success: true,
        loadedAt: new Date().toISOString(),
      };

      response.set("Cache-Control", "public, max-age=30, s-maxage=60");
      response.set("Content-Type", "application/json");
      return response.status(200).json(profileData);
    } catch (error) {
      logger.error(`Get current user profile error: ${error.message}`);
      if (error.code === "auth/argument-error") {
        return response.status(401).json({
          success: false,
          error: "Invalid authentication token",
        });
      }
      return response.status(500).json({
        success: false,
        error: "Failed to load user profile",
        message: error.message,
      });
    }
  }
);

// ── RTDB presence -> Firestore aggregate sync ───────────────────────────────
// Keeps Firestore `presence/{userId}` truthful using RTDB onDisconnect-driven
// session state. This is the canonical bridge from transport truth to UI truth.
if (ENABLE_RTDB_PRESENCE_SYNC) {
  exports.syncPresenceFromRtdbSessions = functionsV1.database
    .ref("/status/{userId}/sessions/{sessionId}")
    .onWrite(async (change, context) => {
    const userId = context.params && context.params.userId;
    if (!userId) return;

    const sessionsSnap = await admin
      .database()
      .ref(`/status/${userId}/sessions`)
      .get();

    const sessions = sessionsSnap.val() || {};
    const nowMs = Date.now();
    const staleMs = 60 * 1000;

    let isOnline = false;
    let inRoom = null;
    let camOn = false;
    let micOn = false;
    let latestSeenMs = 0;
    let activeSessionCount = 0;

    for (const value of Object.values(sessions)) {
      if (!value || typeof value !== "object") continue;

      const online = value.online === true;
      const lastSeenRaw = value.last_seen;
      const lastSeenMs = typeof lastSeenRaw === "number" ? lastSeenRaw : 0;
      const fresh = lastSeenMs > 0 && (nowMs - lastSeenMs) <= staleMs;
      const active = online && fresh;

      if (lastSeenMs > latestSeenMs) {
        latestSeenMs = lastSeenMs;
      }

      if (!active) continue;

      activeSessionCount += 1;
      isOnline = true;

      if (!inRoom && typeof value.in_room === "string" && value.in_room.trim()) {
        inRoom = value.in_room.trim();
      }
      if (value.cam_on === true) {
        camOn = true;
      }
      if (value.mic_on === true) {
        micOn = true;
      }
    }

    const presenceRef = db.collection("presence").doc(userId);
    const presenceSnap = await presenceRef.get();
    const oldInRoom = presenceSnap.exists ? presenceSnap.data().inRoom : null;

    // Hardening: if user is truly offline (no active sessions), clean up room membership.
    if (!isOnline && oldInRoom) {
      try {
        await db.collection("rooms").doc(oldInRoom).collection("participants").doc(userId).delete();
        await db.collection("rooms").doc(oldInRoom).collection("members").doc(userId).delete();
        logger.info(`Cleaned up ghost participant ${userId} from room ${oldInRoom}`);
      } catch (e) {
        logger.error(`Failed to cleanup ghost participant ${userId}: ${e.message}`);
      }
    }

      await presenceRef.set(
        {
          isOnline,
          online: isOnline,
          status: isOnline ? "online" : "offline",
          userStatus: isOnline ? "online" : "offline",
          appState: isOnline ? "foreground" : "detached",
          inRoom,
          roomId: inRoom,
          camOn,
          micOn,
          rtdbActiveSessionCount: activeSessionCount,
          rtdbUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastSeen: latestSeenMs > 0
            ? admin.firestore.Timestamp.fromMillis(latestSeenMs)
            : admin.firestore.FieldValue.serverTimestamp(),
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });
} else {
  logger.info(
    "RTDB presence sync is disabled (ENABLE_RTDB_PRESENCE_SYNC != true).",
  );
}

// ── Friend-online notification ────────────────────────────────────────────────
// Triggers whenever a presence document is written.  When ``isOnline`` flips
// from falsy → true we notify the user's friends (capped at 50, throttled to
// once per 30 minutes per user to avoid notification spam).
exports.notifyFriendsUserOnline = onDocumentWritten(
  "presence/{userId}",
  async (event) => {
    const userId = event.params && event.params.userId;
    if (!userId) return;

    const before = event.data && event.data.before && event.data.before.exists
      ? (event.data.before.data() || {})
      : null;
    const after = event.data && event.data.after && event.data.after.exists
      ? (event.data.after.data() || {})
      : null;

    if (!after) return; // document deleted

    const wasOnline = before ? !!(before.online ?? before.isOnline) : false;
    const isNowOnline = !!(after.online ?? after.isOnline);

    // Only fire when user *comes* online.
    if (wasOnline || !isNowOnline) return;

    // Throttle: skip if we already notified friends within the last 30 minutes.
    const THROTTLE_MS = 30 * 60 * 1000;
    const lastNotified = after.lastOnlineNotifiedAt
      ? (after.lastOnlineNotifiedAt.toMillis ? after.lastOnlineNotifiedAt.toMillis() : 0)
      : 0;
    if (Date.now() - lastNotified < THROTTLE_MS) return;

    // Stamp throttle timestamp before doing expensive reads so concurrent
    // invocations see it immediately.
    await event.data.after.ref.set(
      { lastOnlineNotifiedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const username = (userData.username || userData.displayName || "Someone").trim() || "Someone";

    const [userASnapshot, userBSnapshot] = await Promise.all([
      db.collection("friendships")
        .where("userA", "==", userId)
        .where("status", "==", "accepted")
        .limit(50)
        .get(),
      db.collection("friendships")
        .where("userB", "==", userId)
        .where("status", "==", "accepted")
        .limit(50)
        .get(),
    ]);

    const friendIds = [...userASnapshot.docs, ...userBSnapshot.docs]
      .map((doc) => doc.data() || {})
      .map((friendship) => friendship.userA === userId ? friendship.userB : friendship.userA)
      .filter((friendId) => typeof friendId === "string" && friendId.trim())
      .slice(0, 50);
    if (friendIds.length === 0) return;

    const batch = db.batch();
    friendIds.forEach((friendId) => {
      if (typeof friendId !== "string" || !friendId.trim()) return;
      const notifRef = db.collection("notifications").doc();
      batch.set(notifRef, {
        userId: friendId.trim(),
        actorId: userId,
        type: "friend_online",
        content: `${username} is now online.`,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  },
);

// ── grabMic ────────────────────────────────────────────────────────────────
// Atomically displaces any current stage user and promotes the caller.
// Co-hosts and hosts keep their mic regardless.
// Respects the room's micLimit policy (1 = exclusive, n = panel mode).
// Stale stage docs (lastActiveAt > 90 s) are cleaned up on every grab.
async function grabMicHandler(request, deps = {}) {
  const userId = requireAuth(request);
  enforceRateLimit("grabMic", userId);

  const roomId = parseIdField(request.data && request.data.roomId, "roomId");

  const firestore = deps.firestore || db;
  const participantsCol = firestore
    .collection("rooms")
    .doc(roomId)
    .collection("participants");
  const membersCol = firestore
    .collection("rooms")
    .doc(roomId)
    .collection("members");
  const policyRef = firestore
    .collection("rooms")
    .doc(roomId)
    .collection("policies")
    .doc("settings");

  await firestore.runTransaction(async (tx) => {
    // ── Verify caller is a live, non-banned participant ──────────────────
    const callerRef = participantsCol.doc(userId);
    const callerSnap = await tx.get(callerRef);
    let callerData = callerSnap.exists ? (callerSnap.data() || {}) : null;
    let membershipSource = "participants";

    // Backward-compat: some clients only wrote rooms/{roomId}/members.
    // If participant doc is missing but membership exists, self-heal now.
    if (!callerData) {
      const memberSnap = await tx.get(membersCol.doc(userId));
      if (!memberSnap.exists) {
        throw new HttpsError("permission-denied", "You are not in this room.");
      }
      const memberData = memberSnap.data() || {};
      membershipSource = "members";
      callerData = {
        userId,
        role: memberData.role || "audience",
        isBanned: memberData.isBanned === true,
      };

      tx.set(
        callerRef,
        {
          userId,
          role: callerData.role,
          isBanned: callerData.isBanned,
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      logger.info("grabMic participant self-healed from member", {
        roomId,
        userId,
        membershipSource,
      });
    }

    logger.info("grabMic caller membership resolved", {
      roomId,
      userId,
      membershipSource,
      callerRole: callerData.role || null,
      isBanned: callerData.isBanned === true,
    });

    if (callerData.isBanned === true) {
      throw new HttpsError("permission-denied", "You are banned from this room.");
    }
    // Hosts and co-hosts already have a permanent mic — nothing to do.
    const callerRole = callerData.role || "";
    if (["host", "owner", "cohost"].includes(callerRole)) {
      logger.info("grabMic skipped for host-like caller", {
        roomId,
        userId,
        callerRole,
      });
      return;
    }

    // ── Fetch policy (micLimit + micTimerSeconds) ──────────────────────────
    const policySnap = await tx.get(policyRef);
    const policyData = policySnap.exists ? policySnap.data() : {};
    const micLimit = (typeof policyData.micLimit === "number")
      ? Math.max(1, policyData.micLimit)
      : 1;                           // default: one exclusive stage speaker
    const micTimerSeconds = (typeof policyData.micTimerSeconds === "number" && policyData.micTimerSeconds > 0)
      ? policyData.micTimerSeconds
      : null;

    // ── Fetch current stage holders ──────────────────────────────────────
    const stageQuery = participantsCol.where("role", "==", "stage");
    const stageSnap = await tx.get(stageQuery);

    // Count non-stale stage holders (excluding caller if already on stage).
    const STALE_MS = 90 * 1000;
    const now = Date.now();
    const activeStageDocs = stageSnap.docs.filter((d) => {
      if (d.id === userId) return false;
      const data = d.data();
      // Treat doc as stale if lastActiveAt is old OR micExpiresAt has passed.
      const lat = data.lastActiveAt;
      if (!lat) return false;       // no timestamp → treat as stale
      const ms = lat.toMillis ? lat.toMillis() : Number(lat);
      if ((now - ms) >= STALE_MS) return false;
      const exp = data.micExpiresAt;
      if (exp) {
        const expMs = exp.toMillis ? exp.toMillis() : Number(exp);
        if (now >= expMs) return false; // timer expired → treat as stale
      }
      return true;
    });

    // ── Demote if we are at or above micLimit ────────────────────────────
    // Always demote stale docs. Demote active ones when at capacity.
    const toLimitDemoteCount = Math.max(0, activeStageDocs.length - (micLimit - 1));
    let demoted = 0;
    for (const doc of stageSnap.docs) {
      if (doc.id === userId) continue;
      const data = doc.data();
      const lat = data.lastActiveAt;
      const ms = lat ? (lat.toMillis ? lat.toMillis() : Number(lat)) : 0;
      const exp = data.micExpiresAt;
      const expMs = exp ? (exp.toMillis ? exp.toMillis() : Number(exp)) : Infinity;
      const isStale = (now - ms) >= STALE_MS || now >= expMs;
      if (isStale || demoted < toLimitDemoteCount) {
        tx.set(
          doc.ref,
          {role: "member", lastActiveAt: admin.firestore.FieldValue.serverTimestamp()},
          {merge: true},
        );
        if (!isStale) demoted++;
      }
    }

    // ── Promote caller to stage ──────────────────────────────────────────
    const promotionPayload = {
      userId,
      role: "stage",
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (micTimerSeconds !== null) {
      // Set expiry as a Firestore Timestamp
      const expiresAtMs = Date.now() + micTimerSeconds * 1000;
      promotionPayload.micExpiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMs);
    } else {
      // Remove any stale timer from a previous turn
      promotionPayload.micExpiresAt = admin.firestore.FieldValue.delete();
    }
    tx.set(
      participantsCol.doc(userId),
      promotionPayload,
      {merge: true},
    );

    logger.info("grabMic promoted caller", {
      roomId,
      userId,
      callerRole,
      micLimit,
      micTimerSeconds,
      activeStageCount: activeStageDocs.length,
    });
  });

  return {success: true};
}

exports.grabMic = onCall(async (request) => grabMicHandler(request));

// ── inviteToMic ────────────────────────────────────────────────────────────
// Host/co-host only: promotes a target participant to stage (displacing the
// current stage holder if at micLimit capacity, same logic as grabMic).
async function inviteToMicHandler(request, deps = {}) {
  const callerId = requireAuth(request);
  enforceRateLimit("inviteToMic", callerId);

  const roomId = parseIdField(request.data && request.data.roomId, "roomId");
  const targetId = parseIdField(request.data && request.data.targetId, "targetId");

  if (callerId === targetId) {
    throw new HttpsError("invalid-argument", "Use grabMic to promote yourself.");
  }

  const firestore = deps.firestore || db;
  const participantsCol = firestore
    .collection("rooms")
    .doc(roomId)
    .collection("participants");
  const policyRef = firestore
    .collection("rooms")
    .doc(roomId)
    .collection("policies")
    .doc("settings");

  await firestore.runTransaction(async (tx) => {
    // ── Verify caller is host/co-host ────────────────────────────────────
    const callerSnap = await tx.get(participantsCol.doc(callerId));
    if (!callerSnap.exists) {
      throw new HttpsError("permission-denied", "You are not in this room.");
    }
    const callerRole = callerSnap.data().role || "";
    if (!["host", "owner", "cohost"].includes(callerRole)) {
      throw new HttpsError("permission-denied", "Only the host or co-host can invite to mic.");
    }

    // ── Verify target is a live, non-banned participant ──────────────────
    const targetSnap = await tx.get(participantsCol.doc(targetId));
    if (!targetSnap.exists) {
      throw new HttpsError("not-found", "Target participant is not in this room.");
    }
    if (targetSnap.data().isBanned === true) {
      throw new HttpsError("permission-denied", "Cannot invite a banned participant.");
    }

    // ── Fetch policy + current stage holders (same as grabMic) ──────────
    const policySnap = await tx.get(policyRef);
    const policyData2 = policySnap.exists ? policySnap.data() : {};
    const micLimit = (typeof policyData2.micLimit === "number")
      ? Math.max(1, policyData2.micLimit)
      : 1;
    const micTimerSeconds2 = (typeof policyData2.micTimerSeconds === "number" && policyData2.micTimerSeconds > 0)
      ? policyData2.micTimerSeconds
      : null;

    const stageSnap = await tx.get(participantsCol.where("role", "==", "stage"));
    const STALE_MS = 90 * 1000;
    const now = Date.now();
    const activeStageDocs = stageSnap.docs.filter((d) => {
      if (d.id === targetId) return false;
      const data = d.data();
      const lat = data.lastActiveAt;
      if (!lat) return false;
      const ms = lat.toMillis ? lat.toMillis() : Number(lat);
      if ((now - ms) >= STALE_MS) return false;
      const exp = data.micExpiresAt;
      if (exp) {
        const expMs = exp.toMillis ? exp.toMillis() : Number(exp);
        if (now >= expMs) return false;
      }
      return true;
    });

    const toLimitDemoteCount = Math.max(0, activeStageDocs.length - (micLimit - 1));
    let demoted = 0;
    for (const doc of stageSnap.docs) {
      if (doc.id === targetId) continue;
      const data = doc.data();
      const lat = data.lastActiveAt;
      const ms = lat ? (lat.toMillis ? lat.toMillis() : Number(lat)) : 0;
      const exp = data.micExpiresAt;
      const expMs = exp ? (exp.toMillis ? exp.toMillis() : Number(exp)) : Infinity;
      const isStale = (now - ms) >= STALE_MS || now >= expMs;
      if (isStale || demoted < toLimitDemoteCount) {
        tx.set(
          doc.ref,
          {role: "member", lastActiveAt: admin.firestore.FieldValue.serverTimestamp()},
          {merge: true},
        );
        if (!isStale) demoted++;
      }
    }

    // ── Promote target ───────────────────────────────────────────────────
    const invitePayload = {
      userId: targetId,
      role: "stage",
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (micTimerSeconds2 !== null) {
      invitePayload.micExpiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + micTimerSeconds2 * 1000);
    } else {
      invitePayload.micExpiresAt = admin.firestore.FieldValue.delete();
    }
    tx.set(
      participantsCol.doc(targetId),
      invitePayload,
      {merge: true},
    );
  });

  return {success: true};
}

exports.inviteToMic = onCall(async (request) => inviteToMicHandler(request));

// ── Automatic Verification Document Creation on User Signup ───────────────────
// Triggers when a new user document is created in /users/{uid}.
// Automatically creates a /verifications/{uid} document with initial 'pending' status.
// This ensures all authenticated users have a verification record for rule evaluation.
exports.onUserCreated = onDocumentCreated("users/{uid}", async (event) => {
  const uid = event.params.uid;
  const firestore = admin.firestore();

  try {
    const verificationRef = firestore.collection("verification").doc(uid);
    const verificationDoc = await verificationRef.get();

    // Only create if it doesn't already exist
    if (!verificationDoc.exists) {
      await verificationRef.set({
        userId: uid,
        isAdultVerified: false,
        verificationStatus: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info(`Created verification doc for user ${uid}`);
    }
  } catch (error) {
    logger.error(`Failed to create verification doc for user ${uid}:`, error);
    // Don't throw - allow user creation to succeed even if verification doc fails
    // This prevents signup failures due to Cloud Function issues
  }
});

exports.__testing = {
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
  getCreatorSubscriptionOverviewHandler,
  saveCreatorSubscriptionOfferHandler,
  createCreatorSubscriptionCheckoutHandler,
  cancelCreatorSubscriptionHandler,
  validateCreatorSubscriptionOffer,
  buildCreatorSubscriptionCheckoutPayload,
  handleCreatorSubscriptionCheckoutCompleted,
  handleCreatorSubscriptionChanged,
  handleCreatorSubscriptionInvoice,
  reconcileCreatorSubscriptionsHandler,
  creatorSubscriptionDocId,
  listCreatorSubscriptionMarketplaceHandler,
  publishCreatorSubscriberUpdateHandler,
  listCreatorSubscriberUpdatesHandler,
  reportCreatorSubscriberUpdateHandler,
  validateCreatorUpdateText,
  generateAgoraTokenHandler,
  createCheckoutSessionHandler,
  createCheckoutSessionCallableHandler,
  requestRefundHandler,
  sendRoomGiftHandler,
  cleanupDeletedUserData,
  deleteCurrentUserAccountHandler,
  classifyModerationText,
  buildModerationReviewPayload,
  getCheckoutBaseUrl,
  mapStripeConnectAccount,
  ensureStripeConnectAccount,
  requireAuth,
  parsePositiveAmount,
  ensureUserExists,
  getCoinBalance,
  syncWalletCoinBalance,
  handleCheckoutSessionCompleted,
  enforceRateLimit,
  parseIdField,
  parseOptionalIdempotencyKey,
  buildIdempotentTransactionDocId,
  validateStripePaymentIntent,
  stripeWebhookHandler,
  handleChargeRefunded,
  adminSetEntitlementHandler,
  registerFcmTokenHandler,
  unregisterFcmTokenHandler,
  sendPushForNotification,
  sendIncomingCallPushHandler,
  grabMicHandler,
  inviteToMicHandler,
  buildCheckoutSessionPayload,
  resolveCheckoutProduct,
  recordOperationalSignalHandler,
  sanitizeOperationalMetadata,
  existingSpeedDatingMatch,
  ensureSpeedDatingQueueEntry,
  claimSpeedDatingMatch,
  blockedUserIdsFromRows,
  joinSpeedDatingQueueHandler,
};
