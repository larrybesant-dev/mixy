import { randomBytes } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const firebaseOptionsPath = resolve(root, 'lib', 'firebase_options.dart');
const credentialsPath = resolve(root, '.playwright', 'e2e-credentials.json');

function readCount() {
  const raw = process.argv.find((argument) => argument.startsWith('--count='))
    ?.slice('--count='.length) ?? '3';
  const count = Number.parseInt(raw, 10);
  if (!Number.isInteger(count) || count < 1 || count > 20) {
    throw new Error('--count must be an integer between 1 and 20');
  }
  return count;
}

function readWebApiKey(source) {
  const webOptions = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/,
  )?.[1];
  const apiKey = webOptions?.match(/apiKey:\s*'([^']+)'/)?.[1];
  if (!apiKey) {
    throw new Error(`Could not read the Firebase web API key from ${firebaseOptionsPath}`);
  }
  return apiKey;
}

async function callFirebaseAuth(apiKey, operation, body) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${operation}?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.error?.message ?? `Firebase Auth returned HTTP ${response.status}`);
  }
  return result;
}

async function main() {
  const firebaseOptions = await readFile(firebaseOptionsPath, 'utf8');
  const apiKey = readWebApiKey(firebaseOptions);
  const count = readCount();
  const runId = `${Date.now()}-${randomBytes(3).toString('hex')}`;
  const accounts = [];

  for (let index = 0; index < count; index += 1) {
    const email = `mixvy-e2e-${runId}-w${index}@example.com`;
    const password = `Mx!${randomBytes(18).toString('base64url')}9a`;
    const created = await callFirebaseAuth(apiKey, 'signUp', {
      email,
      password,
      returnSecureToken: true,
    });
    await callFirebaseAuth(apiKey, 'signInWithPassword', {
      email,
      password,
      returnSecureToken: true,
    });
    accounts.push({ email, password, uid: created.localId, workerIndex: index });
    console.log(`Created and verified Firebase test account ${index + 1}/${count}: ${email}`);
  }

  await mkdir(dirname(credentialsPath), { recursive: true });
  await writeFile(
    credentialsPath,
    `${JSON.stringify({ version: 2, runId, accounts }, null, 2)}\n`,
    { encoding: 'utf8', mode: 0o600 },
  );

  console.log(`Created and verified ${count} isolated Firebase test accounts.`);
  console.log(`Credentials saved locally: ${credentialsPath}`);
  console.log('Passwords and Firebase tokens were not printed.');
}

main().catch((error) => {
  console.error(`Could not provision Firebase test account: ${error.message}`);
  process.exitCode = 1;
});