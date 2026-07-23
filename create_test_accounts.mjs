import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

// Initialize Firebase with GOOGLE_APPLICATION_CREDENTIALS if available
const app = initializeApp();
const auth = getAuth();

const testAccounts = [
  { email: 'test_a_prod@example.com', password: 'ProdTest@2026!' },
  { email: 'test_b_prod@example.com', password: 'ProdTest@2026!' },
  { email: 'test_c_prod@example.com', password: 'ProdTest@2026!' }
];

async function createTestAccounts() {
  console.log('🔧 Creating test accounts...\n');
  const uids = [];
  
  for (const account of testAccounts) {
    try {
      const userRecord = await auth.createUser({
        email: account.email,
        password: account.password
      });
      uids.push({ email: account.email, uid: userRecord.uid });
      console.log(`✅ Created: ${account.email}`);
      console.log(`   UID: ${userRecord.uid}\n`);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        console.log(`⚠️  Already exists: ${account.email}`);
        // Try to get the user
        try {
          const user = await auth.getUserByEmail(account.email);
          uids.push({ email: account.email, uid: user.uid });
          console.log(`   UID: ${user.uid}\n`);
        } catch (e) {
          console.log(`   Could not retrieve UID\n`);
        }
      } else {
        console.log(`❌ Error creating ${account.email}: ${error.message}\n`);
      }
    }
  }
  
  console.log('\n📋 Test Accounts Summary:');
  console.log('='.repeat(50));
  uids.forEach((acc, idx) => {
    console.log(`${['A', 'B', 'C'][idx]}: ${acc.email} (UID: ${acc.uid})`);
  });
  console.log('='.repeat(50));
  console.log('\n✅ Test accounts ready for health checks');
}

createTestAccounts().catch(error => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});
