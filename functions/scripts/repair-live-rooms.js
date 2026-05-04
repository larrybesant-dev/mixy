const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const APPLY = process.argv.includes('--apply');
const now = Date.now();
const GRACE_MS = 6 * 60 * 60 * 1000;

function normalizeEndedAt(endedAt) {
  if (!endedAt) return null;
  if (endedAt === '' || endedAt === 'null') return null;
  if (endedAt instanceof admin.firestore.Timestamp) return endedAt;
  return null;
}

function getReason(room) {
  if (!room.isLive) return 'NOT_LIVE';

  const ownerOk = !!(room.ownerId || room.hostId);
  if (!ownerOk) return 'MISSING_OWNER';

  if (room.endedAt && normalizeEndedAt(room.endedAt) !== null) {
    return 'ENDED';
  }

  const createdAt = room.createdAt?.toMillis?.() || 0;
  const ageMs = now - createdAt;

  if (ageMs > GRACE_MS) return 'STALE';

  return 'OK';
}

async function run() {
  const snapshot = await db.collection('rooms').get();

  let total = 0;
  let visible = 0;

  const reasons = {
    OK: 0,
    MISSING_OWNER: 0,
    ENDED: 0,
    STALE: 0,
    NOT_LIVE: 0,
  };

  console.log('\nSCANNING LIVE ROOMS...\n');

  for (const doc of snapshot.docs) {
    const room = doc.data();
    total += 1;

    const reason = getReason(room);
    reasons[reason] += 1;

    const visibleRoom = reason === 'OK';

    console.log(
      `${doc.id} -> ${reason} | live=${room.isLive} ownerId=${room.ownerId || null} hostId=${room.hostId || null}`,
    );

    if (visibleRoom) {
      visible += 1;
    }

    if (APPLY) {
      const updates = {};

      if (room.endedAt !== undefined) {
        const normalized = normalizeEndedAt(room.endedAt);
        if (normalized === null && room.endedAt !== null) {
          updates.endedAt = null;
        }
      }

      if (!room.ownerId && room.hostId) {
        updates.ownerId = room.hostId;
      }

      if (!room.createdAt) {
        updates.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      if (Object.keys(updates).length > 0) {
        await db.collection('rooms').doc(doc.id).update(updates);
      }
    }
  }

  console.log('\nSUMMARY');
  console.log('----------------------------');
  console.log('Total rooms:', total);
  console.log('Visible (OK):', visible);
  console.log('Dropped - MISSING_OWNER:', reasons.MISSING_OWNER);
  console.log('Dropped - ENDED:', reasons.ENDED);
  console.log('Dropped - STALE:', reasons.STALE);
  console.log('Dropped - NOT_LIVE:', reasons.NOT_LIVE);

  if (!APPLY) {
    console.log('\nDRY RUN ONLY - no changes made');
    console.log('Run with --apply to fix schema drift');
  } else {
    console.log('\nAPPLY MODE COMPLETE - Firestore normalized');
  }
}

run().catch((e) => {
  console.error('FAILED:', e);
  process.exit(1);
});
