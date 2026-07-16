#!/usr/bin/env node
/**
 * Disable App Check enforcement for Firebase project.
 * This allows requests to Firestore without valid App Check tokens.
 * 
 * Usage: node disable_appcheck_enforcement.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with service account
// The service account key must be in GOOGLE_APPLICATION_CREDENTIALS env var
// or explicitly loaded here

const projectId = 'mixvy-v2';

async function disableAppCheckEnforcement() {
  try {
    // Initialize if not already done
    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: projectId,
      });
    }

    console.log(`[AppCheck] Attempting to disable enforcement for project: ${projectId}`);

    // Get the App Check management API endpoint
    const firebaseSecurityRulesApi = admin.firestore();
    const client = admin.appCheck();

    // Unfortunately, the Firebase Admin SDK doesn't have a direct method to disable
    // App Check enforcement. We need to use the REST API instead.
    
    // The Firebase REST API endpoint for App Check enforcement:
    // PATCH /v1beta1/projects/{projectId}/apps/{appId}/appCheckConfig
    // with request body: { enforcementMode: "UNENFORCED" }

    console.log('[AppCheck] Cannot disable via Admin SDK - Firebase Admin SDK lacks App Check management');
    console.log('[AppCheck] Alternative: Disable via Firebase Console or use REST API');
    console.log(`[AppCheck] URL: https://console.firebase.google.com/project/${projectId}/appcheck`);
    
    process.exit(0);
  } catch (error) {
    console.error('[AppCheck] Error:', error);
    process.exit(1);
  }
}

disableAppCheckEnforcement();
