import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// Load service account
const serviceAccount = JSON.parse(
  readFileSync('./functions/credentials/prod-service-account.json', 'utf8')
);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id
});

async function createTestAccounts() {
  const auth = admin.auth();
  const timestamp = Date.now().toString().slice(-6);
  
  const accounts = [
    {
      name: 'Test User A (Blocker)',
      email: `test_a_${timestamp}@mixvy-prod.com`,
      password: 'ProdTest@2026!'
    },
    {
      name: 'Test User B (Blocked)',
      email: `test_b_${timestamp}@mixvy-prod.com`,
      password: 'ProdTest@2026!'
    },
    {
      name: 'Test User C (For Gifts)',
      email: `test_c_${timestamp}@mixvy-prod.com`,
      password: 'ProdTest@2026!'
    }
  ];

  console.log('🔐 Creating test accounts for production health checks...\n');

  for (const account of accounts) {
    try {
      const userRecord = await auth.createUser({
        email: account.email,
        password: account.password,
        displayName: account.name
      });
      
      console.log(`✅ ${account.name}`);
      console.log(`   Email: ${account.email}`);
      console.log(`   UID: ${userRecord.uid}\n`);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        console.log(`⚠️  ${account.name} already exists: ${account.email}\n`);
      } else {
        console.log(`❌ Error creating ${account.name}: ${error.message}\n`);
      }
    }
  }

  await admin.app().delete();
  console.log('✅ Test accounts ready!');
}

createTestAccounts().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
