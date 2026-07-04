#!/usr/bin/env node
/**
 * Disable AppCheck enforcement on Firestore for soft-launch testing
 * Uses REST API with gcloud authentication
 */

const { execSync } = require('child_process');
const https = require('https');

async function disableAppCheckEnforcement() {
  try {
    // Get access token from gcloud
    console.log('[Auth] Getting access token from gcloud...');
    let accessToken;
    try {
      accessToken = execSync('gcloud auth print-access-token', { 
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe']
      }).trim();
      console.log('[Auth] ✅ Access token obtained');
    } catch (e) {
      throw new Error('Failed to get gcloud access token: ' + e.message);
    }

    // Make REST API call
    const projectNumber = '980846719834';
    const serviceName = 'firestore.googleapis.com';
    const url = `https://firebaseappcheck.googleapis.com/v1/projects/${projectNumber}/services/${serviceName}?updateMask=enforcementMode`;
    
    console.log(`[API] Calling: ${url}`);
    
    const data = JSON.stringify({
      enforcementMode: 'UNENFORCED'
    });
    
    return new Promise((resolve, reject) => {
      const options = {
        hostname: 'firebaseappcheck.googleapis.com',
        path: `/v1/projects/${projectNumber}/services/${serviceName}?updateMask=enforcementMode`,
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': data.length
        }
      };

      const req = https.request(options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          console.log(`[API] Response Status: ${res.statusCode}`);
          try {
            const parsed = JSON.parse(responseData);
            console.log('[API] Response:', JSON.stringify(parsed, null, 2));
            if (res.statusCode === 200 || res.statusCode === 201) {
              console.log('\n✅ SUCCESS: AppCheck enforcement disabled for Cloud Firestore!');
              console.log('The app should now work. Refresh https://mixvy-v2.web.app/ to verify.');
              resolve(true);
            } else {
              console.log('\n❌ ERROR: Failed to disable enforcement');
              resolve(false);
            }
          } catch (e) {
            console.log('[API] Raw response:', responseData);
            resolve(false);
          }
        });
      });

      req.on('error', (error) => {
        console.error('[API] Request error:', error.message);
    console.error('[AppCheck API] Details:', error.errors || error.response?.data || '');
    
    // If Google API fails, try direct REST call
    console.log('[Fallback] Attempting direct REST API call...');
    try {
      const { google } = require('googleapis');
      const auth = google.auth.getApplicationDefault();
      const authClient = await auth.getClient();
      const token = await authClient.getAccessToken();
      
      const fetch = require('node-fetch');
      const url = `https://firebaseappcheck.googleapis.com/v1/projects/mix-and-mingle-v2/services/firestore.googleapis.com/enforcement`;
      
      const res = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          enforceAppCheckProvider: false
        })
      });
      
      console.log('[REST API] Status:', res.status);
      const data = await res.text();
      console.log('[REST API] Response:', data);
      
    } catch (fallbackError) {
      console.error('[Fallback] Error:', fallbackError.message);
    }
  }
}

// Run
disableAppCheckEnforcement()
  .then(() => {
    console.log('[Done] AppCheck enforcement disable attempt complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('[Fatal] Unexpected error:', err);
    process.exit(1);
  });
