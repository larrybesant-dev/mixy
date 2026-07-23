// params.js: Exports secrets from environment variables for Firebase Functions v7+

const { defineSecret } = require("firebase-functions/params");

// Define secrets (these must be set via Firebase CLI or Console)
const STRIPE_SECRET = defineSecret("STRIPE_SECRET");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");
const AGORA_APP_ID = defineSecret("AGORA_APP_ID");
const AGORA_APP_CERTIFICATE = defineSecret("AGORA_APP_CERTIFICATE");
const METERED_API_KEY = defineSecret("METERED_API_KEY");

module.exports = {
  STRIPE_SECRET,
  STRIPE_WEBHOOK_SECRET,
  AGORA_APP_ID,
  AGORA_APP_CERTIFICATE,
  METERED_API_KEY,
};
