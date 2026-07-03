#!/usr/bin/env node

/**
 * Soft Launch Health Monitor
 * Runs periodic checks during the 24-hour monitoring period
 * Alerts on critical issues
 */

import admin from "firebase-admin";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp({
  projectId: "mixvy-v2",
});

const firestore = getFirestore();

// Monitoring configuration
const CHECK_INTERVAL = 5 * 60 * 1000; // Check every 5 minutes
const ALERT_THRESHOLDS = {
  errorRate: 0.01, // 1% error rate
  blockEnforcementFailure: 0, // Any failure is critical
  paymentFailure: 0, // Any payment failure is critical
  avgLatency: 2000, // 2 seconds is warning
};

// Alert severity levels
const SEVERITY = {
  CRITICAL: "🔴 CRITICAL",
  WARNING: "🟡 WARNING",
  INFO: "🟢 INFO",
};

function log(severity, component, message, details = {}) {
  const timestamp = new Date().toISOString();
  console.log(`${timestamp} | ${severity} | ${component} | ${message}`);
  if (Object.keys(details).length > 0) {
    console.log(`  Details:`, JSON.stringify(details, null, 2));
  }
}

async function checkBlockEnforcement() {
  try {
    // Query for recent block enforcement checks
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    
    const query = firestore
      .collectionGroup("messages")
      .where("createdAt", ">=", thirtyMinutesAgo)
      .limit(100);

    const snapshot = await query.get();
    
    if (snapshot.empty) {
      log(
        SEVERITY.INFO,
        "BlockEnforcement",
        "No recent messages to check"
      );
      return true;
    }

    // Check if any messages have block enforcement violations
    let violations = 0;
    snapshot.forEach((doc) => {
      const data = doc.data();
      if (data.isFromBlockedUser === true) {
        violations++;
        log(
          SEVERITY.CRITICAL,
          "BlockEnforcement",
          "Block enforcement violation detected",
          {
            docId: doc.id,
            message: data.content,
            senderId: data.senderId,
            conversationId: data.conversationId,
          }
        );
      }
    });

    if (violations === 0) {
      log(
        SEVERITY.INFO,
        "BlockEnforcement",
        `✅ No block enforcement violations detected (${snapshot.size} messages checked)`
      );
      return true;
    }

    return false;
  } catch (error) {
    log(SEVERITY.WARNING, "BlockEnforcement", `Error checking: ${error.message}`);
    return null; // Unable to determine
  }
}

async function checkPaymentStatus() {
  try {
    // Query for recent payments
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    const failedPayments = await firestore
      .collection("payments")
      .where("createdAt", ">=", fiveMinutesAgo)
      .where("status", "==", "failed")
      .get();

    if (!failedPayments.empty) {
      log(
        SEVERITY.CRITICAL,
        "Payments",
        `${failedPayments.size} failed payment(s) detected`,
        { count: failedPayments.size }
      );
      
      failedPayments.forEach((doc) => {
        const data = doc.data();
        console.log(`  - ${data.userId}: $${data.amount} (${data.reason})`);
      });
      
      return false;
    }

    // Count successful payments
    const successfulPayments = await firestore
      .collection("payments")
      .where("createdAt", ">=", fiveMinutesAgo)
      .where("status", "==", "success")
      .get();

    if (successfulPayments.size > 0) {
      log(
        SEVERITY.INFO,
        "Payments",
        `✅ ${successfulPayments.size} successful payment(s) in last 5 minutes`
      );
    }

    return true;
  } catch (error) {
    log(SEVERITY.WARNING, "Payments", `Error checking: ${error.message}`);
    return null;
  }
}

async function checkUserGrowth() {
  try {
    // Count active users in last hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    
    const activeUsers = await firestore
      .collection("users")
      .where("lastActive", ">=", oneHourAgo)
      .get();

    if (activeUsers.size > 0) {
      log(
        SEVERITY.INFO,
        "UserGrowth",
        `${activeUsers.size} active users in last hour`
      );
    }

    return true;
  } catch (error) {
    log(SEVERITY.WARNING, "UserGrowth", `Error checking: ${error.message}`);
    return null;
  }
}

async function checkFirestoreHealth() {
  try {
    // Simple health check: can we read/write
    const testDocId = `health_check_${Date.now()}`;
    
    // Write
    await firestore.collection("_health").doc(testDocId).set({
      timestamp: new Date(),
      status: "ok",
    });

    // Read
    const doc = await firestore.collection("_health").doc(testDocId).get();
    
    if (!doc.exists) {
      log(SEVERITY.CRITICAL, "Firestore", "Health check write/read failed");
      return false;
    }

    // Delete
    await firestore.collection("_health").doc(testDocId).delete();

    log(SEVERITY.INFO, "Firestore", "✅ Database health check passed");
    return true;
  } catch (error) {
    log(
      SEVERITY.CRITICAL,
      "Firestore",
      `Database error: ${error.message}`
    );
    return false;
  }
}

async function runAllChecks() {
  console.log("\n" + "=".repeat(70));
  console.log("SOFT LAUNCH HEALTH CHECK");
  console.log("=".repeat(70));
  console.log(`Timestamp: ${new Date().toISOString()}\n`);

  const results = {};
  
  results.firestore = await checkFirestoreHealth();
  results.blockEnforcement = await checkBlockEnforcement();
  results.payments = await checkPaymentStatus();
  results.userGrowth = await checkUserGrowth();

  // Summary
  console.log("\n" + "-".repeat(70));
  console.log("SUMMARY");
  console.log("-".repeat(70));

  const allPassed = Object.values(results).every((r) => r !== false);

  for (const [check, result] of Object.entries(results)) {
    let status = "?";
    if (result === true) status = "✅ PASS";
    else if (result === false) status = "❌ FAIL";
    else if (result === null) status = "⚠️  UNKNOWN";

    console.log(`${status} - ${check}`);
  }

  if (allPassed) {
    console.log("\n✅ All checks passed");
  } else {
    console.log("\n❌ Some checks failed - Review logs above");
  }

  console.log("=".repeat(70) + "\n");
}

async function startMonitoring() {
  console.log(
    "🔍 Starting Soft Launch Health Monitoring (runs every 5 minutes)"
  );
  console.log(`Start time: ${new Date().toISOString()}`);
  console.log('Press Ctrl+C to stop\n');

  // Run immediately
  await runAllChecks();

  // Then run at interval
  setInterval(runAllChecks, CHECK_INTERVAL);
}

startMonitoring().catch(console.error);
