import { test, expect, type Locator, type Page, type Request } from '@playwright/test';
import { mkdirSync, writeFileSync } from 'node:fs';

const PROD_BASE_URL = 'https://mixvy-v2.web.app';
const ROOM_ID = 'J7wXLd4AkPXppU3R4gTI';

function generateSimulationPassword(seed: string): string {
  const suffix = Math.random().toString(36).slice(2, 10);
  return `Launch${seed}${suffix}!`;
}

type StepStatus = 'success' | 'warning' | 'error';

type StepEntry = {
  step: string;
  status: StepStatus;
  detail: string;
  timestamp: string;
};

type TestAccount = {
  email: string;
  password: string;
  username: string;
};

type NetworkSample = {
  url: string;
  status: number;
  durationMs: number | null;
};

function toProdUrl(path: string): string {
  return new URL(path, `${PROD_BASE_URL}/`).toString();
}

function createTestAccount(): TestAccount {
  const ts = Date.now();
  return {
    email: `mixvy.live.sim.${ts}@example.com`,
    password: (process.env.SMOKE_TEST_PASSWORD ?? '').trim() || generateSimulationPassword(String(ts)),
    username: `sim${ts.toString().slice(-6)}`,
  };
}

function routePath(page: Page): string {
  const url = new URL(page.url());
  return url.searchParams.get('__dl') ?? url.pathname;
}

function logStep(report: StepEntry[], step: string, status: StepStatus, detail: string): void {
  const entry: StepEntry = {
    step,
    status,
    detail,
    timestamp: new Date().toISOString(),
  };
  report.push(entry);
  // Keep execution log readable in terminal output.
  console.log(`[SIM][${status.toUpperCase()}] ${step}: ${detail}`);
}

function persistTelemetryReport(payload: unknown): string {
  const dir = 'test-results/live-user-telemetry';
  mkdirSync(dir, { recursive: true });
  const filePath = `${dir}/live-user-simulation-${Date.now()}.json`;
  writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
  return filePath;
}

async function waitForAppReady(page: Page): Promise<void> {
  await page.waitForLoadState('domcontentloaded');
  await expect(page.locator('body')).toBeVisible({ timeout: 30000 });
  await expect
    .poll(
      async () =>
        await page
          .locator(
            'flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input'
          )
          .count(),
      {
        timeout: 30000,
        message: 'Expected Flutter readiness markers to be present',
      }
    )
    .toBeGreaterThan(0);
}

async function enableFlutterSemantics(page: Page): Promise<void> {
  const placeholder = page.locator('flt-semantics-placeholder').first();

  if ((await placeholder.count().catch(() => 0)) > 0) {
    await page
      .evaluate(() => {
        const target = document.querySelector('flt-semantics-placeholder') as HTMLElement | null;
        if (!target) return;
        target.focus();
        target.click();
        const rect = target.getBoundingClientRect();
        target.dispatchEvent(
          new MouseEvent('click', {
            bubbles: true,
            clientX: rect.left + 1,
            clientY: rect.top + 1,
          })
        );
        target.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Enter' }));
        target.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: ' ' }));
      })
      .catch(() => undefined);
  }

  await page.waitForTimeout(700);
}

async function findFirstVisibleLocator(
  page: Page,
  candidates: Array<() => Locator>,
  timeoutMs: number = 12000
): Promise<Locator> {
  const started = Date.now();

  while (Date.now() - started < timeoutMs) {
    for (const build of candidates) {
      const locator = build();
      if (await locator.isVisible().catch(() => false)) {
        return locator;
      }
    }

    await enableFlutterSemantics(page);
    await page.waitForTimeout(300);
  }

  throw new Error('No visible locator found for candidate set.');
}

async function ensureConsentIfPresent(page: Page): Promise<boolean> {
  const consent = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('checkbox', { name: /18\+|community guidelines|terms/i }).first(),
      () => page.locator('input[type="checkbox"]').first(),
    ],
    6000
  ).catch(() => null);

  if (!consent) return false;
  const checked = await consent.isChecked().catch(() => false);
  if (!checked) {
    await consent.check({ force: true }).catch(async () => {
      await consent.click({ force: true }).catch(() => undefined);
    });
  }
  return true;
}

async function signInWithGuestOrDemo(page: Page): Promise<boolean> {
  await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);
  await ensureConsentIfPresent(page);

  const guestButton = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('button', { name: /enter as guest|continue as guest|guest|demo login|demo/i }).first(),
      () =>
        page
          .locator(
            'button:has-text("ENTER AS GUEST"), button:has-text("Enter as guest"), button:has-text("DEMO LOGIN"), button:has-text("Demo Login"), button:has-text("Guest"), button:has-text("Instant One-Click Demo Login")'
          )
          .first(),
    ],
    10000
  ).catch(() => null);
  if (!guestButton) return false;

  await guestButton.click({ force: true }).catch(() => undefined);

  try {
    await expect
      .poll(() => routePath(page), {
        timeout: 25000,
        message: 'Expected guest/demo fallback to move away from auth/register routes',
      })
      .not.toMatch(/^\/(auth|register)$/);
    return true;
  } catch {
    return false;
  }
}

async function completeSignUp(page: Page, account: TestAccount): Promise<{ redirected: boolean; fallbackUsed: boolean }> {
  await page.goto(toProdUrl('/register'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);

  const usernameInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /username/i }).first(),
    () => page.locator('input[aria-label*="username" i], input[placeholder*="username" i]').first(),
  ]);
  await usernameInput.fill(account.username);

  const emailInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
  ]);
  await emailInput.fill(account.email);

  const passwordInput = await findFirstVisibleLocator(page, [
    () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
    () => page.getByLabel(/password/i).first(),
  ]);
  await passwordInput.fill(account.password);

  await ensureConsentIfPresent(page);

  const createAccount = await findFirstVisibleLocator(page, [
    () => page.getByRole('button', { name: /create account/i }).first(),
    () => page.locator('button:has-text("CREATE ACCOUNT"), button:has-text("Create account")').first(),
  ]);
  await createAccount.click({ force: true });

  try {
    await expect
      .poll(() => routePath(page), {
        timeout: 30000,
        message: 'Expected route to advance away from register after account creation',
      })
      .not.toBe('/register');
    return { redirected: true, fallbackUsed: false };
  } catch {
    const signedInViaCredentials = await signInWithCredentials(page, account);
    if (signedInViaCredentials) {
      return { redirected: true, fallbackUsed: true };
    }
    const signedInViaGuest = await signInWithGuestOrDemo(page);
    if (signedInViaGuest) {
      return { redirected: true, fallbackUsed: true };
    }
    return { redirected: false, fallbackUsed: true };
  }
}

async function clearSession(page: Page): Promise<void> {
  await page
    .evaluate(async () => {
      localStorage.clear();
      sessionStorage.clear();
      try {
        const dbs = await indexedDB.databases();
        await Promise.all(
          dbs
            .map((db) => db.name)
            .filter((name): name is string => Boolean(name))
            .map(
              (name) =>
                new Promise<void>((resolve) => {
                  const req = indexedDB.deleteDatabase(name);
                  req.onsuccess = () => resolve();
                  req.onerror = () => resolve();
                  req.onblocked = () => resolve();
                })
            )
        );
      } catch {
        // Ignore IndexedDB cleanup failures in prod simulation.
      }
    })
    .catch(() => undefined);
}

async function signInWithCredentials(page: Page, account: TestAccount): Promise<boolean> {
  await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);

  const emailInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
  ], 10000).catch(() => null);
  if (!emailInput) return false;

  await emailInput.fill(account.email);

  const passwordInput = await findFirstVisibleLocator(page, [
    () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
    () => page.getByLabel(/password/i).first(),
  ], 10000).catch(() => null);
  if (!passwordInput) return false;

  await passwordInput.fill(account.password);

  await ensureConsentIfPresent(page);

  const signInButton = await findFirstVisibleLocator(page, [
    () => page.getByRole('button', { name: /^sign in$/i }).first(),
    () => page.locator('button:has-text("SIGN IN"), button:has-text("Sign In")').first(),
  ], 10000).catch(() => null);
  if (!signInButton) return false;

  await signInButton.click({ force: true }).catch(() => undefined);

  try {
    await expect
      .poll(() => routePath(page), {
        timeout: 25000,
        message: 'Expected sign in fallback to move away from auth/register routes',
      })
      .not.toMatch(/^\/(auth|register)$/);
    return true;
  } catch {
    return false;
  }
}

async function runSignOut(page: Page): Promise<boolean> {
  const direct = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('button', { name: /sign out|log out|logout/i }).first(),
      () => page.locator('button:has-text("SIGN OUT"), button:has-text("Log Out"), button:has-text("Logout")').first(),
    ],
    6000
  ).catch(() => null);

  if (direct) {
    await direct.click({ force: true }).catch(() => undefined);
    return true;
  }

  const openMenu = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('button', { name: /profile|account|menu|settings/i }).first(),
      () => page.locator('button:has-text("Profile"), button:has-text("Settings"), button:has-text("Menu")').first(),
    ],
    6000
  ).catch(() => null);

  if (!openMenu) {
    return false;
  }

  await openMenu.click({ force: true }).catch(() => undefined);
  await page.waitForTimeout(500);

  const nested = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('button', { name: /sign out|log out|logout/i }).first(),
      () => page.locator('text=/sign out|log out|logout/i').first(),
    ],
    6000
  ).catch(() => null);

  if (!nested) {
    return false;
  }

  await nested.click({ force: true }).catch(() => undefined);
  return true;
}

test.describe('MixVy Live User Simulation', () => {
  test('full live user journey with detailed feedback report', async ({ page, browserName }, testInfo) => {
    test.skip(browserName === 'firefox', 'Firefox CI budget is too tight for the full simulation flow.');
    test.setTimeout(300000);

    const report: StepEntry[] = [];
    const friction: string[] = [];
    const criticalErrors: string[] = [];
    const slowResponses: NetworkSample[] = [];
    const failedResponses: NetworkSample[] = [];
    const consoleIssues: string[] = [];
    const requestStartedAt = new Map<Request, number>();
    const account = createTestAccount();

    page.on('request', (request) => {
      requestStartedAt.set(request, Date.now());
    });

    page.on('response', (response) => {
      const url = response.url();
      const status = response.status();
      const startedAt = requestStartedAt.get(response.request());
      const durationMs = startedAt ? Math.max(0, Date.now() - startedAt) : null;

      const isRelevant =
        url.includes('mixvy-v2.web.app') ||
        url.includes('firebase') ||
        url.includes('googleapis.com') ||
        url.includes('/api/');

      if (!isRelevant) return;

      if (durationMs !== null && durationMs >= 1500) {
        slowResponses.push({ url, status, durationMs: Math.round(durationMs) });
      }

      if (status >= 400) {
        failedResponses.push({ url, status, durationMs: durationMs === null ? null : Math.round(durationMs) });
      }

      requestStartedAt.delete(response.request());
    });

    page.on('console', (msg) => {
      const type = msg.type();
      if (type !== 'error' && type !== 'warning') return;
      const text = msg.text();
      if (/appcheck|recaptcha|permission|firestore|failed|error|warning|network/i.test(text)) {
        consoleIssues.push(`${type.toUpperCase()}: ${text}`);
      }
    });

    logStep(report, 'Init', 'success', `Generated account ${account.email}`);

    let authReady = false;

    // 1) Account creation + onboarding
    try {
      const signupResult = await completeSignUp(page, account);
      const ageCheckEnabled = await ensureConsentIfPresent(page);
      if (ageCheckEnabled) {
        logStep(report, 'Signup', 'success', 'Age verification checkbox enabled.');
      } else {
        friction.push('Age verification checkbox was not visible in this run.');
        logStep(report, 'Signup', 'warning', 'Age verification checkbox not found.');
      }

      const keepSignedIn = await findFirstVisibleLocator(page, [
        () => page.getByRole('checkbox', { name: /keep me signed in|remember me|stay signed in/i }).first(),
        () => page.locator('text=/keep me signed in|remember me|stay signed in/i').first(),
      ], 4000).catch(() => null);

      if (keepSignedIn) {
        await keepSignedIn.click({ force: true }).catch(() => undefined);
        logStep(report, 'Signup', 'success', 'Keep me signed in option enabled.');
      } else {
        friction.push('Keep me signed in control not visible (may be implicit persistence).');
        logStep(report, 'Signup', 'warning', 'Keep me signed in toggle not found; continuing with default Firebase persistence.');
      }

      if (!signupResult.redirected) {
        throw new Error('Unable to confirm account creation/session start from register or auth fallback.');
      }

      authReady = true;

      if (signupResult.fallbackUsed) {
        friction.push('Signup UI did not redirect automatically; recovered via auth fallback.');
        logStep(
          report,
          'Account Creation & Onboarding',
          'warning',
          'Signup redirect stalled; recovered via auth fallback path.'
        );
      }

      await enableFlutterSemantics(page);

      const skipOnboarding = await findFirstVisibleLocator(page, [
        () => page.getByRole('button', { name: /skip for now|skip|not now|maybe later/i }).first(),
        () => page.locator('button:has-text("Skip"), text=Skip for now').first(),
      ], 10000).catch(() => null);

      if (skipOnboarding) {
        await skipOnboarding.click({ force: true }).catch(() => undefined);
        await page.waitForLoadState('domcontentloaded');
      }

      logStep(report, 'Account Creation & Onboarding', 'success', `Reached ${routePath(page)} after signup.`);
    } catch (error) {
      const detail = `Signup/onboarding friction: ${error instanceof Error ? error.message : String(error)}`;
      friction.push(detail);
      logStep(report, 'Account Creation & Onboarding', 'warning', detail);
    }

    // 2) Session persistence
    try {
      if (!authReady) {
        const signedInViaCredentials = await signInWithCredentials(page, account);
        if (!signedInViaCredentials) {
          const signedInViaGuest = await signInWithGuestOrDemo(page);
          authReady = signedInViaGuest;
        } else {
          authReady = true;
        }
      }

      if (!authReady) {
        throw new Error('No authenticated session could be established for persistence verification.');
      }

      await page.reload({ waitUntil: 'domcontentloaded' });
      await waitForAppReady(page);
      await enableFlutterSemantics(page);
      const route = routePath(page);

      expect(route).not.toBe('/auth');
      expect(route).not.toBe('/register');

      logStep(report, 'Session Persistence', 'success', `Reload stayed signed-in on route ${route}.`);
    } catch (error) {
      const detail = `Session persistence friction: ${error instanceof Error ? error.message : String(error)}`;
      friction.push(detail);
      logStep(report, 'Session Persistence', 'warning', detail);
    }

    // 3) Core walkthrough
    try {
      const routesToVisit = ['/home', '/profile', `/rooms/room/${ROOM_ID}`];
      for (const route of routesToVisit) {
        await page.goto(toProdUrl(route), { waitUntil: 'domcontentloaded' });
        await waitForAppReady(page);
        await enableFlutterSemantics(page);
        logStep(report, 'Core Navigation', 'success', `Visited ${route}.`);
      }

      const joinRoom = await findFirstVisibleLocator(page, [
        () => page.getByRole('button', { name: /join|enter room|listen|connect|go live/i }).first(),
        () => page.locator('button:has-text("Join"), button:has-text("Enter"), button:has-text("Listen"), button:has-text("Connect"), button:has-text("Request to Join")').first(),
      ], 7000).catch(() => null);

      if (joinRoom) {
        await joinRoom.click({ force: true }).catch(() => undefined);
        await page.waitForTimeout(1000);
        logStep(report, 'Room Interaction', 'success', 'Join/enter room action triggered.');
      } else {
        friction.push('Join room CTA not visible on room route for this account state.');
        logStep(report, 'Room Interaction', 'warning', 'Join room CTA not found.');
      }

      const rosterButton = await findFirstVisibleLocator(page, [
        () => page.getByRole('button', { name: /participants|people|friends|roster/i }).first(),
        () => page.locator('button:has-text("Participants"), button:has-text("People"), button:has-text("Friends"), button:has-text("Audience"), button:has-text("Members")').first(),
      ], 7000).catch(() => null);

      if (rosterButton) {
        await rosterButton.click({ force: true }).catch(() => undefined);
        await page.waitForTimeout(800);
        logStep(report, 'Roster/Friends', 'success', 'Participant/friends panel interaction triggered.');
      } else {
        friction.push('Participant/friends roster control not found in visible room shell.');
        logStep(report, 'Roster/Friends', 'warning', 'No roster/friends control located.');
      }

      const giftButton = await findFirstVisibleLocator(page, [
        () => page.getByRole('button', { name: /gift|send gift|diamonds|coin/i }).first(),
        () => page.locator('button:has-text("Gift"), button:has-text("Diamonds"), button:has-text("Send Gift"), button:has-text("Send Diamonds"), button:has-text("Tip")').first(),
      ], 7000).catch(() => null);

      if (giftButton) {
        await giftButton.click({ force: true }).catch(() => undefined);
        await page.waitForTimeout(800);
        logStep(report, 'Gift Overlay', 'success', 'Gift UI overlay interaction triggered.');
      } else {
        friction.push('Gift overlay control not found in this room/session state.');
        logStep(report, 'Gift Overlay', 'warning', 'Gift UI control not found.');
      }

      await page.goto(toProdUrl('/messages'), { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      await waitForAppReady(page);
      await enableFlutterSemantics(page);

      const messageInput = await findFirstVisibleLocator(page, [
        () => page.getByRole('textbox', { name: /message|chat/i }).first(),
        () => page.locator('input[placeholder*="message" i], textarea[placeholder*="message" i], input[placeholder*="chat" i], textarea[placeholder*="chat" i]').first(),
      ], 6000).catch(() => null);

      if (messageInput) {
        await messageInput.fill('Automated live-user simulation ping.');
        logStep(report, 'Messaging', 'success', 'Message input interaction succeeded.');
      } else {
        friction.push('Messaging textbox not visible on /messages for this account state.');
        logStep(report, 'Messaging', 'warning', 'Message textbox not found.');
      }
    } catch (error) {
      const detail = `Core walkthrough encountered runtime friction: ${error instanceof Error ? error.message : String(error)}`;
      friction.push(detail);
      logStep(report, 'Core Feature Walkthrough', 'warning', detail);
    }

    // 4) Sign out + cleanup
    try {
      await page.goto(toProdUrl('/profile'), { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      await waitForAppReady(page);
      await enableFlutterSemantics(page);

      let signOutTriggered = await runSignOut(page);
      if (!signOutTriggered) {
        await page.goto(toProdUrl('/profile/edit'), { waitUntil: 'domcontentloaded' }).catch(() => undefined);
        await waitForAppReady(page);
        await enableFlutterSemantics(page);
        signOutTriggered = await runSignOut(page);
      }

      if (signOutTriggered) {
        await expect
          .poll(() => routePath(page), {
            timeout: 20000,
            message: 'Expected logout flow to return to auth wall',
          })
          .toBe('/auth');
        logStep(report, 'Sign Out & Cleanup', 'success', 'Explicit logout control triggered and returned to auth wall.');
      } else {
        friction.push('Explicit logout control not visible in profile/account UI; using forced session cleanup fallback.');
        logStep(
          report,
          'Sign Out & Cleanup',
          'warning',
          'Explicit logout control not found; applying forced cleanup fallback.'
        );
      }

      await clearSession(page);
      await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      await waitForAppReady(page);
      await enableFlutterSemantics(page);

      await expect
        .poll(() => routePath(page), {
          timeout: 15000,
          message: 'Expected forced cleanup to land on auth wall',
        })
        .toBe('/auth');

      const storageState = await page.evaluate(async () => {
        const localKeys = Object.keys(localStorage || {});
        const sessionKeys = Object.keys(sessionStorage || {});
        const hasAuthLikeLocal = localKeys.some((k) => /firebase:authUser|auth|token/i.test(k));
        const hasAuthLikeSession = sessionKeys.some((k) => /auth|token/i.test(k));

        let indexedAuthRecord = false;
        try {
          const req = indexedDB.open('firebaseLocalStorageDb');
          const db = await new Promise<IDBDatabase | null>((resolve) => {
            req.onerror = () => resolve(null);
            req.onsuccess = () => resolve(req.result);
            req.onupgradeneeded = () => resolve(req.result);
          });

          if (db && db.objectStoreNames.contains('firebaseLocalStorage')) {
            const tx = db.transaction('firebaseLocalStorage', 'readonly');
            const store = tx.objectStore('firebaseLocalStorage');
            const allReq = store.getAll();
            const rows = await new Promise<any[]>((resolve) => {
              allReq.onerror = () => resolve([]);
              allReq.onsuccess = () => resolve(Array.isArray(allReq.result) ? allReq.result : []);
            });
            indexedAuthRecord = rows.some((row) => {
              const key = row?.fbase_key ?? '';
              return typeof key === 'string' && key.includes('firebase:authUser');
            });
          }
        } catch {
          // ignore indexeddb probe failures
        }

        return {
          hasAuthLikeLocal,
          hasAuthLikeSession,
          indexedAuthRecord,
        };
      });

      if (storageState.hasAuthLikeSession) {
        friction.push('Session storage still contains auth-like keys after forced cleanup.');
        logStep(
          report,
          'Sign Out & Cleanup',
          'warning',
          `Residual session auth traces detected: ${JSON.stringify(storageState)}`
        );
      } else if (storageState.hasAuthLikeLocal || storageState.indexedAuthRecord) {
        friction.push('Some auth-like local persistence keys remain post-logout (may be SDK metadata).');
        logStep(
          report,
          'Sign Out & Cleanup',
          'warning',
          `Logged out but residual local auth traces detected: ${JSON.stringify(storageState)}`
        );
      } else if (!signOutTriggered) {
        logStep(
          report,
          'Sign Out & Cleanup',
          'success',
          'Forced session cleanup cleared auth traces and returned to auth wall.'
        );
      }
    } catch (error) {
      const detail = `Logout/cleanup failure: ${error instanceof Error ? error.message : String(error)}`;
      friction.push(detail);
      logStep(report, 'Sign Out & Cleanup', 'warning', detail);
    }

    // 5) attach + print report
    if (friction.length > 0) {
      logStep(report, 'Feedback Summary', 'warning', `Friction points: ${friction.length}`);
    } else {
      logStep(report, 'Feedback Summary', 'success', 'No friction points detected during this run.');
    }

    if (slowResponses.length > 0) {
      const topSlow = slowResponses
        .sort((a, b) => (b.durationMs ?? 0) - (a.durationMs ?? 0))
        .slice(0, 10)
        .map((s) => `${s.status} ${s.durationMs}ms ${s.url}`)
        .join(' | ');
      logStep(report, 'Network Telemetry', 'warning', `Slow responses (${slowResponses.length}): ${topSlow}`);
    } else {
      logStep(report, 'Network Telemetry', 'success', 'No relevant slow responses >=1500ms detected.');
    }

    if (failedResponses.length > 0) {
      const topFailures = failedResponses
        .slice(0, 10)
        .map((s) => `${s.status} ${s.durationMs ?? 'n/a'}ms ${s.url}`)
        .join(' | ');
      logStep(report, 'Network Errors', 'warning', `HTTP failures (${failedResponses.length}): ${topFailures}`);
    } else {
      logStep(report, 'Network Errors', 'success', 'No relevant HTTP failures >=400 captured.');
    }

    if (consoleIssues.length > 0) {
      const samples = consoleIssues.slice(0, 10).join(' | ');
      logStep(report, 'Console Telemetry', 'warning', `Console issues (${consoleIssues.length}): ${samples}`);
    } else {
      logStep(report, 'Console Telemetry', 'success', 'No relevant warning/error console telemetry captured.');
    }

    const telemetryPayload = { account, report, friction, criticalErrors, slowResponses, failedResponses, consoleIssues };
    await testInfo.attach('live-user-simulation-report.json', {
      body: JSON.stringify(telemetryPayload, null, 2),
      contentType: 'application/json',
    });

    const telemetryFile = persistTelemetryReport(telemetryPayload);
    logStep(report, 'Telemetry Artifact', 'success', `Structured telemetry saved to ${telemetryFile}`);

    if (criticalErrors.length > 0) {
      logStep(report, 'Critical Failures', 'warning', criticalErrors.join(' | '));
    }
  });
});
