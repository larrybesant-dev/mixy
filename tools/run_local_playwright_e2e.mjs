import { spawnSync } from 'node:child_process';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.GCLOUD_PROJECT || 'mixvy-v2';
const app = initializeApp({
  projectId,
});
const auth = getAuth(app);
const firestore = getFirestore(app);
const password = 'LocalE2E!2026';
const accounts = [
  {
    uid: 'local-e2e-user-a',
    email: 'local-e2e-a@example.test',
    password,
    username: 'LocalAlpha',
  },
  {
    uid: 'local-e2e-user-b',
    email: 'local-e2e-b@example.test',
    password,
    username: 'LocalBeta',
  },
];

for (const account of accounts) {
  await auth.createUser({
    uid: account.uid,
    email: account.email,
    password: account.password,
    displayName: account.username,
    emailVerified: true,
  });
  await firestore.collection('users').doc(account.uid).set({
    userId: account.uid,
    uid: account.uid,
    email: account.email,
    username: account.username,
    displayName: account.username,
    avatarUrl: '',
    photoUrl: '',
    age: 30,
    isAdult: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

const conversationId = 'local-e2e-conversation';
await firestore.collection('conversations').doc(conversationId).set({
  type: 'direct',
  groupName: null,
  groupAvatarUrl: null,
  participantIds: accounts.map((account) => account.uid),
  participantNames: Object.fromEntries(
    accounts.map((account) => [account.uid, account.username]),
  ),
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
  lastMessageAt: FieldValue.serverTimestamp(),
  lastMessagePreview: 'Local emulator conversation',
  lastMessageSenderId: accounts[0].uid,
  lastReadAt: {},
  isArchived: false,
  status: 'active',
});

const result = spawnSync(
  process.execPath,
  [
    'node_modules/@playwright/test/cli.js',
    'test',
    'e2e/10-local-emulator-flows.spec.ts',
    '--project=chromium',
    '--workers=1',
  ],
  {
    env: {
      ...process.env,
      AUTH_REQUIRED: '1',
      FIREBASE_EMULATOR_E2E: '1',
      LOCAL_E2E_CONVERSATION_ID: conversationId,
      PLAYWRIGHT_BASE_URL: 'http://127.0.0.1:5000',
      PLAYWRIGHT_WORKERS: '1',
      TEST_ACCOUNTS_JSON: JSON.stringify({
        accounts: accounts.map(({ email, password: accountPassword }) => ({
          email,
          password: accountPassword,
        })),
      }),
    },
    stdio: 'inherit',
  },
);

if (result.error) {
  throw result.error;
}
process.exit(result.status ?? 1);
