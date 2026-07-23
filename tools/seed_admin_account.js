/**
 * seed_admin_account.js
 *
 * One-time script to grant full admin/owner access to a specific account.
 * Sets admin: true, betaTester: true, membershipLevel: 'Gold', and a large
 * starting coin balance so the account has no payments or feature limits.
 *
 * Usage (from the project root):
 *   node tools/seed_admin_account.js
 *
 * Prerequisites:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account key
 *     that has Firestore write permission, OR run inside a GCP environment.
 *   - npm install firebase-admin (or: node --require module from functions/)
 *
 * The script can safely be re-run; it uses set+merge so existing fields are
 * preserved and only the listed flags are added/updated.
 */

const admin = require("firebase-admin");

// ── Configuration ─────────────────────────────────────────────────────────────
const ADMIN_EMAIL = "larrybesant@gmail.com";

// ─────────────────────────────────────────────────────────────────────────────

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

async function main() {
  console.log(`Looking up Firebase Auth user for ${ADMIN_EMAIL}…`);

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(ADMIN_EMAIL);
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      console.error(
        `No Firebase Auth user found for ${ADMIN_EMAIL}.\n` +
          "Make sure the account has been created (sign-up) before running this script.",
      );
      process.exit(1);
    }
    throw err;
  }

  const uid = userRecord.uid;
  console.log(`Found user: uid=${uid}`);

  const adminFlags = {
    admin: true,
    betaTester: true,
    membershipLevel: "Gold",
    membershipSince: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Stamp the user doc with admin flags.
  await db.collection("users").doc(uid).set(adminFlags, { merge: true });
  console.log("users doc updated with admin flags.");

  // Also ensure the wallet has a large starting balance so UI checks pass
  // even before any real top-up.
  await db
    .collection("wallets")
    .doc(uid)
    .set(
      {
        userId: uid,
        balance: 999999,
        coinBalance: 999999,
        cashBalance: 9999.99,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  console.log("wallets doc updated with large starting balance.");

  console.log(`\nDone. ${ADMIN_EMAIL} now has full admin access.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
