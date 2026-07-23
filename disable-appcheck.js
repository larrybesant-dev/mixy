/**
 * Disable AppCheck enforcement for Firestore
 * Uses Firebase Admin SDK
 */
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with default credentials
admin.initializeApp({
  projectId: 'mix-and-mingle-v2',
});

async function disableAppCheckEnforcement() {
  try {
    console.log('Attempting to disable AppCheck enforcement for Firestore...');
    
    // Try using the Firestore Admin API client
    const firestore = admin.firestore();
    
    // Get the underlying gRPC client
    const client = firestore._client;
    console.log('Firestore client:', client?.constructor?.name);
    
    // Alternative: Try to call the Firebase API directly
    // The endpoint should be: 
    // PATCH /v1/projects/{projectId}/services/{serviceName}/enforcement
    // For Firestore: /v1/projects/mix-and-mingle-v2/services/firestore.googleapis.com/enforcement
    
    const projectId = 'mix-and-mingle-v2';
    const serviceName = 'firestore.googleapis.com';
    
    // Get the auth token
    const token = await admin.credential.applicationDefault().getAccessToken();
    console.log('Access token obtained:', token.access_token ? 'yes' : 'no');
    
    // Make a REST API call to disable enforcement
    const https = require('https');
    const url = `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}/services/${serviceName}/enforcement`;
    
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
    
    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let responseData = '';
        res.on('data', chunk => responseData += chunk);
        res.on('end', () => {
          console.log('Response status:', res.statusCode);
          console.log('Response headers:', res.headers);
          console.log('Response body:', responseData);
          resolve(responseData);
        });
      });
      
      req.on('error', err => {
        console.error('Request error:', err);
        reject(err);
      });
      
      req.write(data);
      req.end();
    });
    
  } catch (error) {
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response body:', error.response.data);
    }
    throw error;
  }
}

disableAppCheckEnforcement()
  .then(result => {
    console.log('Success!', result);
    process.exit(0);
  })
  .catch(error => {
    console.error('Failed:', error.message);
    process.exit(1);
  });
