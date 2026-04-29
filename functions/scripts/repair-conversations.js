/* eslint-disable no-console */
/**
 * repair-conversations.js
 *
 * Normalizes every document in the `conversations` collection:
 *   - participantIds: [] — guaranteed to be a non-null array
 *   - lastMessageAt    — if missing, falls back to createdAt or FieldValue.delete()
 *   - lastMessagePreview — if missing, defaults to ''
 *   - status           — if missing, defaults to 'active'
 *
 * Dry-run by default. Pass --apply to write.
 *
 * Usage:
 *   node scripts/repair-conversations.js
 *   node scripts/repair-conversations.js --apply
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const APPLY = process.argv.includes("--apply");
const PAGE_SIZE = 400;

/**
 * Returns true if value is a non-null Firestore Timestamp or a Date.
 */
function isValidTimestamp(value) {
  if (value == null) return false;
  if (value instanceof admin.firestore.Timestamp) return true;
  if (value instanceof Date) return true;
  return false;
}

/**
 * Coerce raw Firestore value to a clean string array (deduped, non-empty).
 */
function toStringArray(raw) {
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.filter((v) => typeof v === "string" && v.trim().length > 0).map((v) => v.trim()))];
}

async function run() {
  const col = db.collection("conversations");
  let lastDoc = null;
  let scanned = 0;
  let patched = 0;
  let skipped = 0;

  console.log(`[repair-conversations] mode=${APPLY ? "APPLY" : "DRY-RUN"} pageSize=${PAGE_SIZE}`);

  while (true) {
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};

      const updates = {};

      // ── participantIds ───────────────────────────────────────────────────────
      // Must be a non-null array. Derive from participantNames keys if available.
      const rawParticipants = data.participantIds;
      if (!Array.isArray(rawParticipants)) {
        const derived = toStringArray(
          data.participantNames ? Object.keys(data.participantNames) : [],
        );
        updates.participantIds = derived;
      }

      // ── lastMessageAt ────────────────────────────────────────────────────────
      // If missing, fall back to createdAt. If createdAt also missing, leave null
      // (safe — queries sort descending by this field; null sinks to the bottom).
      if (!isValidTimestamp(data.lastMessageAt)) {
        if (isValidTimestamp(data.createdAt)) {
          updates.lastMessageAt = data.createdAt;
        }
        // else: leave absent — the live write path will populate it on next message
      }

      // ── lastMessagePreview ───────────────────────────────────────────────────
      if (typeof data.lastMessagePreview !== "string") {
        updates.lastMessagePreview = "";
      }

      // ── status ───────────────────────────────────────────────────────────────
      if (typeof data.status !== "string" || data.status.trim() === "") {
        updates.status = "active";
      }

      if (Object.keys(updates).length === 0) {
        skipped++;
        continue;
      }

      patched++;
      console.log(`  [patch] conversations/${doc.id}`, updates);
      if (APPLY) {
        batch.update(doc.ref, updates);
        batchCount++;
      }
    }

    if (APPLY && batchCount > 0) {
      await batch.commit();
      console.log(`  [commit] ${batchCount} writes committed`);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(`\n[repair-conversations] done — scanned=${scanned} patched=${patched} skipped=${skipped}`);
  if (!APPLY && patched > 0) {
    console.log("[repair-conversations] Re-run with --apply to write changes.");
  }
}

run().catch((err) => {
  console.error("[repair-conversations] fatal:", err);
  process.exit(1);
});
