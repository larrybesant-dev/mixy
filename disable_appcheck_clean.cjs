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
    
    console.log(`[API] Disabling enforcement for: ${serviceName}`);
    
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
        reject(error);
      });

      req.write(data);
      req.end();
    });
  } catch (error) {
    console.error('[Error]', error.message);
    return false;
  }
}

// Run
disableAppCheckEnforcement()
  .then((success) => {
    console.log('[Done] AppCheck enforcement disable attempt complete');
    process.exit(success ? 0 : 1);
  })
  .catch(err => {
    console.error('[Fatal] Unexpected error:', err.message);
    process.exit(1);
  });
