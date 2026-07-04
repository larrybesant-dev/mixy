/**
 * Disable AppCheck enforcement for Firestore
 * Uses Firebase Admin SDK
 */
const admin = require('firebase-admin');
const https = require('https');

// Initialize Firebase Admin SDK with default credentials
admin.initializeApp({
  projectId: 'mix-and-mingle-v2',
});

async function disableAppCheckEnforcement() {
  try {
    console.log('Attempting to disable AppCheck enforcement for Firestore...');
    
    const projectId = 'mix-and-mingle-v2';
    const serviceName = 'firestore.googleapis.com';
    
    // Get the auth credential
    const credential = admin.credential.applicationDefault();
    const token = await credential.getAccessToken();
    console.log('Access token obtained');
    
    // Make a REST API call to disable enforcement
    const data = JSON.stringify({
      enforcementMode: 'UNENFORCED'
    });
    
    const options = {
      hostname: 'firebaseappcheck.googleapis.com',
      path: `/v1/projects/${projectId}/services/${serviceName}/enforcement`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
        'Authorization': `Bearer ${token.access_token}`
      }
    };
    
    console.log(`Sending PATCH request to ${options.hostname}${options.path}`);
    
    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let responseData = '';
        res.on('data', chunk => responseData += chunk);
        res.on('end', () => {
          console.log('Response status:', res.statusCode);
          if (res.statusCode >= 400) {
            console.error('Error response:', responseData);
            reject(new Error(`API returned ${res.statusCode}`));
          } else {
            console.log('Response body:', responseData);
            resolve(responseData);
          }
        });
      });
      
      req.on('error', err => {
        console.error('Request error:', err.message);
        reject(err);
      });
      
      req.write(data);
      req.end();
    });
    
  } catch (error) {
    console.error('Error:', error.message);
    throw error;
  }
}

disableAppCheckEnforcement()
  .then(result => {
    console.log('✅ Success! AppCheck enforcement disabled.');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Failed:', error.message);
    process.exit(1);
  });
