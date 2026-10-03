import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const credentialsPath = resolve('.playwright', 'e2e-credentials.json');

type TestCredentials = {
  email?: string;
  password?: string;
};

function parseAccountPool(raw: string): TestCredentials[] {
  const parsed = JSON.parse(raw) as
    | TestCredentials[]
    | { accounts?: TestCredentials[] };
  return Array.isArray(parsed) ? parsed : parsed.accounts ?? [];
}

function selectedAccountIndex(): number {
  const rawIndex =
    process.env.E2E_ACCOUNT_INDEX ??
    process.env.TEST_PARALLEL_INDEX ??
    process.env.TEST_WORKER_INDEX ??
    '0';
  const index = Number.parseInt(rawIndex, 10);
  return Number.isInteger(index) && index >= 0 ? index : 0;
}

function credentialPool(): TestCredentials[] {
  let accounts: TestCredentials[] = [];
  if (process.env.TEST_ACCOUNTS_JSON) {
    accounts = parseAccountPool(process.env.TEST_ACCOUNTS_JSON);
  } else if (existsSync(credentialsPath)) {
    const raw = readFileSync(credentialsPath, 'utf8');
    const parsed = JSON.parse(raw) as TestCredentials & {
      accounts?: TestCredentials[];
    };
    accounts = parsed.accounts ?? [parsed];
  }

  return accounts;
}

export function loadTestCredentials(): boolean {
  return credentialPool().length > 0 ||
    Boolean(process.env.TEST_EMAIL && process.env.TEST_PASSWORD);
}

export function activateWorkerCredentials(): boolean {
  const accounts = credentialPool();
  if (accounts.length > 0) {
    const index = selectedAccountIndex();
    const credentials = accounts[index];
    if (!credentials?.email || !credentials.password) {
      throw new Error(
        `No E2E account is configured for worker index ${index}; pool size is ${accounts.length}.`,
      );
    }
    process.env.TEST_EMAIL = credentials.email;
    process.env.TEST_PASSWORD = credentials.password;
    return true;
  }

  return Boolean(process.env.TEST_EMAIL && process.env.TEST_PASSWORD);
}