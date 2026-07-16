#!/usr/bin/env node

/**
 * Create Test User Accounts via Firebase Admin SDK
 *
 * This script creates test user accounts in Firebase Auth and initializes
 * their Firestore user documents. Useful for manual testing and QA.
 *
 * Usage:
 *   node scripts/create-test-accounts.js [--count=5] [--prefix=testuser]
 *
 * Examples:
 *   node scripts/create-test-accounts.js                    # Creates 1 test user
 *   node scripts/create-test-accounts.js --count=10         # Creates 10 test users
 *   node scripts/create-test-accounts.js --prefix=qa-user   # Uses custom email prefix
 *
 * Requires:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to service account JSON
 *   - Or run from Firebase Hosting with automatic credentials
 */

const admin = require("firebase-admin");
const path = require("path");

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.join(__dirname, "../functions/service-account-key.json");

try {
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccountPath),
            projectId: "mix-and-mingle-v2"
        });
    }
} catch (error) {
    console.error("Failed to initialize Firebase Admin SDK:", error.message);
    console.error("Ensure GOOGLE_APPLICATION_CREDENTIALS is set or service-account-key.json exists");
    process.exit(1);
}

// Parse command line arguments
function parseArgs() {
    const args = process.argv.slice(2);
    const config = {
        count: 1,
        prefix: "testuser"
    };

    for (const arg of args) {
        if (arg.startsWith("--count=")) {
            config.count = parseInt(arg.split("=")[1], 10);
        } else if (arg.startsWith("--prefix=")) {
            config.prefix = arg.split("=")[1];
        }
    }

    return config;
}

/**
 * Create a test user account with Firestore document
 */
async function createTestUser(email, password) {
    try {
        // Create auth account
        const userRecord = await admin.auth().createUser({
            email,
            password,
            emailVerified: false
        });

        // Create Firestore user document
        const userDoc = {
            uid: userRecord.uid,
            email: userRecord.email,
            username: email.split("@")[0].substring(0, 20),
            avatarUrl: "",
            coinBalance: 50,  // Give test users some coins
            membershipLevel: "Free",
            followers: [],
            createdAt: new Date().toISOString(),
            betaTester: true,
            testAccount: true
        };

        await admin.firestore().collection("users").doc(userRecord.uid).set(userDoc);

        return {
            success: true,
            uid: userRecord.uid,
            email: userRecord.email,
            password
        };
    } catch (error) {
        return {
            success: false,
            email,
            error: error.message
        };
    }
}

/**
 * Main function
 */
async function main() {
    const config = parseArgs();

    console.log("🚀 MixVy Test Account Creator");
    console.log(`Creating ${config.count} test account(s)...`);
    console.log("");

    const timestamp = Date.now();
    const results = [];

    for (let i = 1; i <= config.count; i++) {
        const email = `${config.prefix}-${timestamp}-${i}@mixvy.dev`;
        const password = "TestPassword123!";

        process.stdout.write(`[${i}/${config.count}] Creating ${email}... `);

        const result = await createTestUser(email, password);

        if (result.success) {
            console.log("✓");
            results.push(result);
        } else {
            console.log(`✗ ${result.error}`);
            results.push(result);
        }
    }

    console.log("");
    console.log("📊 Results Summary");
    console.log("─".repeat(60));

    const successful = results.filter(r => r.success);
    const failed = results.filter(r => !r.success);

    console.log(`✓ Successful: ${successful.length}/${config.count}`);
    console.log(`✗ Failed: ${failed.length}/${config.count}`);

    if (successful.length > 0) {
        console.log("");
        console.log("📋 Test Accounts Created");
        console.log("─".repeat(60));

        successful.forEach((result, index) => {
            console.log(`\n[${index + 1}] ${result.email}`);
            console.log(`    UID:      ${result.uid}`);
            console.log(`    Password: ${result.password}`);
            console.log(`    Status:   Ready for testing`);
        });

        console.log("");
        console.log("🔗 Login URL: https://mixvy-v2.web.app/auth");
    }

    if (failed.length > 0) {
        console.log("");
        console.log("⚠️  Failed Accounts");
        console.log("─".repeat(60));

        failed.forEach((result, index) => {
            console.log(`[${index + 1}] ${result.email}`);
            console.log(`    Error: ${result.error}`);
        });
    }

    console.log("");
    console.log("✅ Process complete");

    // Exit with appropriate code
    process.exit(failed.length > 0 ? 1 : 0);
}

// Run main function
main().catch(error => {
    console.error("Fatal error:", error);
    process.exit(1);
});
