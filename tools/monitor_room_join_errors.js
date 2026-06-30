#!/usr/bin/env node

/**
 * MIXVY Room Join Permission Monitoring Script
 * 
 * Monitors Firebase Cloud Logs for permission-denied errors related to room joining.
 * Usage: node tools/monitor_room_join_errors.js
 * 
 * This script can be run in CI/CD or as a monitoring daemon to track:
 * - Permission-denied errors on participant collection writes
 * - Failed room join attempts
 * - Permission violations for group room joins
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '../functions/service-account-key.json');
if (!process.env.FIREBASE_SERVICE_ACCOUNT_PATH && !admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(require(serviceAccountPath)),
    });
  } catch (err) {
    console.warn('⚠️  Could not load service account. Ensure GOOGLE_APPLICATION_CREDENTIALS is set.');
  }
}

const logging = require('@google-cloud/logging');
const client = new logging.Logging();

async function monitorPermissionErrors() {
  console.log('🔍 Monitoring Firebase Logs for Permission-Denied Errors...\n');

  const filter = `
    resource.type="cloud_firestore"
    AND severity="ERROR"
    AND (
      textPayload=~"permission-denied"
      OR textPayload=~"Permission denied"
      OR textPayload=~"PERMISSION_DENIED"
    )
    AND (
      textPayload=~"participants"
      OR textPayload=~"members"
      OR textPayload=~"groups"
    )
  `;

  try {
    const [entries] = await client.getEntries({
      filter: filter,
      pageSize: 100,
      orderBy: 'timestamp desc',
    });

    if (entries.length === 0) {
      console.log('✅ No permission-denied errors found in recent logs!\n');
      printSummary();
      return;
    }

    console.log(`⚠️  Found ${entries.length} permission-denied errors:\n`);
    printErrors(entries);
    printSummary(entries);
  } catch (error) {
    console.error('❌ Error querying logs:', error.message);
    console.log('\n📝 To use this monitoring script:');
    console.log('1. Set GOOGLE_APPLICATION_CREDENTIALS to point to a service account key');
    console.log('2. Or configure Firebase Admin SDK with proper credentials');
    console.log('3. Install @google-cloud/logging: npm install @google-cloud/logging\n');
  }
}

function printErrors(entries) {
  entries.slice(0, 10).forEach((entry, idx) => {
    const timestamp = entry.metadata.timestamp;
    const payload = entry.data.textPayload || JSON.stringify(entry.data);
    console.log(`${idx + 1}. [${timestamp}]`);
    console.log(`   ${payload.substring(0, 120)}...`);
    console.log('');
  });

  if (entries.length > 10) {
    console.log(`... and ${entries.length - 10} more errors\n`);
  }
}

function printSummary(entries = []) {
  console.log('═══════════════════════════════════════════════════════');
  console.log('📊 ROOM JOIN PERMISSION ERROR SUMMARY');
  console.log('═══════════════════════════════════════════════════════\n');

  if (entries.length === 0) {
    console.log('Status: ✅ HEALTHY - No permission errors detected\n');
    console.log('Monitoring Actions:');
    console.log('  • Check Firestore rules deployed successfully');
    console.log('  • Verify participant docs are being created');
    console.log('  • Test room join flow end-to-end\n');
    return;
  }

  const participantErrors = entries.filter(e => 
    e.data.textPayload?.includes('participants')
  ).length;
  const memberErrors = entries.filter(e => 
    e.data.textPayload?.includes('members')
  ).length;
  const groupErrors = entries.filter(e => 
    e.data.textPayload?.includes('groups')
  ).length;

  console.log(`Total Errors: ${entries.length}`);
  console.log(`  • Participant Collection: ${participantErrors}`);
  console.log(`  • Members Collection: ${memberErrors}`);
  console.log(`  • Groups Collection: ${groupErrors}\n`);

  console.log('⚠️  ACTION ITEMS:');
  if (participantErrors > 0) {
    console.log('  1. Check firestore.rules participant create rule');
    console.log('     • Verify exists() check passes');
    console.log('     • Ensure canReadRoomById() logic is correct');
  }
  if (memberErrors > 0) {
    console.log('  2. Check firestore.rules members create rule');
    console.log('     • Verify exists() check on room document');
  }
  if (groupErrors > 0) {
    console.log('  3. Check firestore.rules groups update rule');
    console.log('     • Verify self-join and self-leave logic');
  }
  console.log('\n');
}

async function monitorRealtime() {
  console.log('🚀 Starting Real-Time Permission Error Monitoring...');
  console.log('Press Ctrl+C to stop\n');

  // Poll every 30 seconds
  setInterval(async () => {
    const filter = `
      resource.type="cloud_firestore"
      AND severity="ERROR"
      AND (
        textPayload=~"permission-denied"
        OR textPayload=~"PERMISSION_DENIED"
      )
      AND timestamp>="${new Date(Date.now() - 30000).toISOString()}"
    `;

    try {
      const [entries] = await client.getEntries({
        filter: filter,
        pageSize: 5,
        orderBy: 'timestamp desc',
      });

      if (entries.length > 0) {
        console.log(`[${new Date().toISOString()}] ⚠️  Found ${entries.length} new permission errors:`);
        entries.forEach(entry => {
          console.log(`  - ${entry.data.textPayload?.substring(0, 80)}`);
        });
      }
    } catch (error) {
      // Silently skip polling errors
    }
  }, 30000);
}

// Parse command line arguments
const args = process.argv.slice(2);
if (args.includes('--realtime')) {
  monitorRealtime();
} else {
  monitorPermissionErrors();
}
