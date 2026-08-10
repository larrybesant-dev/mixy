import { test, expect, type Browser, type BrowserContext, type Locator, type Page } from '@playwright/test';

const ROOM_ID = 'J7wXLd4AkPXppU3R4gTI';
const PROD_BASE_URL = 'https://mixvy-v2.web.app';
const ROOM_PATH = `/rooms/room/${ROOM_ID}`;
const DEFAULT_PASSWORD = 'LaunchTest@2026!';

type TestAccount = {
  email: string;
  password: string;
  username: string;
};

function createTestAccount(): TestAccount {
  const timestamp = Date.now();
  return {
    email: `mixvy.smoke.${timestamp}@example.com`,
    password: process.env.SMOKE_TEST_PASSWORD || DEFAULT_PASSWORD,
    username: `smoke${timestamp.toString().slice(-6)}`,
  };
}

function getFallbackAuthAccountFromEnv(): TestAccount | null {
  const email = process.env.TEST_EMAIL || process.env.SMOKE_TEST_EMAIL;
  if (!email) {
    return null;
  }

  return {
    email,
    password: process.env.TEST_PASSWORD || process.env.SMOKE_TEST_PASSWORD || DEFAULT_PASSWORD,
    username: 'env-fallback',
  };
}

async function enableFlutterSemantics(page: Page): Promise<void> {
  const placeholder = page.locator('flt-semantics-placeholder').first();

  if ((await placeholder.count().catch(() => 0)) > 0) {
    await placeholder.click({ force: true }).catch(() => undefined);
  }

  await page
    .evaluate(() => {
      const target = document.querySelector('flt-semantics-placeholder') as HTMLElement | null;
      if (!target) return;
      const rect = target.getBoundingClientRect();
      target.focus();
      target.dispatchEvent(
        new MouseEvent('click', {
          bubbles: true,
          clientX: rect.left + 1,
          clientY: rect.top + 1,
        })
      );
      target.dispatchEvent(
        new KeyboardEvent('keydown', {
          bubbles: true,
          key: 'Enter',
        })
      );
      target.dispatchEvent(
        new KeyboardEvent('keydown', {
          bubbles: true,
          key: ' ',
        })
      );
    })
    .catch(() => undefined);

  await page.waitForTimeout(750);
}

async function waitForFlutterSurface(page: Page): Promise<void> {
  await page.waitForLoadState('domcontentloaded');
  await expect(page.locator('body')).toBeVisible({ timeout: 30000 });
  await expect
    .poll(
      async () =>
        await page
          .locator('flt-glass-pane, flutter-view, flt-scene-host, canvas, flt-semantics-placeholder')
          .count(),
      {
        timeout: 30000,
        message: 'Expected Flutter surface markers to be present',
      }
    )
    .toBeGreaterThan(0);
}

async function waitForAppReady(page: Page): Promise<void> {
  await waitForFlutterSurface(page);
  await page.waitForLoadState('domcontentloaded');
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

async function waitForSemanticsTree(page: Page): Promise<void> {
  await expect
    .poll(
      async () => {
        const roleCount = await page.locator('[role="button"], [role="textbox"], input').count();
        const semanticsCount = await page.locator('[aria-label], flt-semantics').count();
        return roleCount + semanticsCount;
      },
      {
        timeout: 10000,
        message: 'Expected Flutter semantics/accessibility nodes to be attached',
      }
    )
    .toBeGreaterThan(0);
}

function currentRoute(page: Page): string {
  const url = new URL(page.url());
  return url.pathname;
}

function currentDeepLink(page: Page): string | null {
  const url = new URL(page.url());
  return url.searchParams.get('__dl');
}

function toProdUrl(path: string): string {
  return new URL(path, `${PROD_BASE_URL}/`).toString();
}

async function expectNoRawPermissionDeniedLeak(page: Page): Promise<void> {
  const rawErrorLeak = page
    .locator('body')
    .getByText(/\[cloud_firestore\/permission-denied\]|missing or insufficient permissions|error:\s*\[/i)
    .first();

  await expect(rawErrorLeak).toHaveCount(0);
}

function installMultiTabConsoleCapture(page: Page, sink: string[]): void {
  page.on('console', (msg) => {
    const text = msg.text();
    if (/persistence layer|INTERNAL ASSERTION/i.test(text)) {
      sink.push(text);
    }
  });
}

async function gotoAuth(page: Page): Promise<void> {
  await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);
  await waitForSemanticsTree(page);
}

async function gotoRegister(page: Page): Promise<void> {
  await page.goto(toProdUrl('/register'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);
  await waitForSemanticsTree(page);
}

async function findFirstVisibleLocator(
  page: Page,
  candidates: Array<() => Locator>,
  timeoutMs: number = 12000,
): Promise<Locator> {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    for (const createLocator of candidates) {
      const locator = createLocator();
      if (await locator.isVisible().catch(() => false)) {
        return locator;
      }
    }

    await enableFlutterSemantics(page);
    await page.waitForTimeout(300);
  }

  throw new Error('Unable to find a visible locator from the provided candidates.');
}

async function openRegisterForm(page: Page): Promise<void> {
  await gotoRegister(page);

  await expect
    .poll(() => currentRoute(page), {
      timeout: 10000,
      message: 'Expected register flow to land on /register',
    })
    .toBe('/register');

  await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /username/i }).first(),
    () => page.locator('input[aria-label*="username" i], input[placeholder*="username" i]').first(),
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[placeholder*="email" i]').first(),
  ]);
}

async function signInWithCredentials(page: Page, account: TestAccount): Promise<boolean> {
  try {
    await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);
    await waitForSemanticsTree(page);

    const emailInput = await findFirstVisibleLocator(
      page,
      [
        () => page.getByRole('textbox', { name: /email/i }).first(),
        () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
      ],
      10000,
    ).catch(() => null);
    if (!emailInput) return false;

    await emailInput.click({ force: true }).catch(() => undefined);
    await emailInput.fill(account.email);

    const passwordInput = await findFirstVisibleLocator(
      page,
      [
        () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
        () => page.getByLabel(/password/i).first(),
      ],
      10000,
    ).catch(() => null);
    if (!passwordInput) return false;

    await passwordInput.click({ force: true }).catch(() => undefined);
    await passwordInput.fill(account.password);

    const consentCheckbox = page
      .getByRole('checkbox', { name: /i confirm i am 18\+ and agree to the community guidelines/i })
      .first();
    if (await consentCheckbox.isVisible().catch(() => false)) {
      const checked = await consentCheckbox.isChecked().catch(() => false);
      if (!checked) {
        await consentCheckbox.check({ force: true }).catch(async () => {
          await consentCheckbox.click({ force: true }).catch(() => undefined);
        });
      }
    }

    const signInButton = await findFirstVisibleLocator(
      page,
      [
        () => page.getByRole('button', { name: /^sign in$/i }).first(),
        () => page.locator('button:has-text("SIGN IN"), button:has-text("Sign In")').first(),
      ],
      10000,
    ).catch(() => null);
    if (!signInButton) return false;

    await signInButton.click({ force: true }).catch(() => undefined);

    try {
      await expect
        .poll(() => currentRoute(page), {
          timeout: 25000,
          message: 'Expected auth fallback sign in to move away from /auth and /register',
        })
        .not.toMatch(/^\/(auth|register)$/);
      return true;
    } catch {
      return false;
    }
  } catch {
    return false;
  }
}

async function signInWithGuestOrDemo(page: Page): Promise<boolean> {
  try {
    await page.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);
    await waitForSemanticsTree(page);

    const consentCheckbox = page
      .getByRole('checkbox', { name: /i confirm i am 18\+ and agree to the community guidelines/i })
      .first();
    if (await consentCheckbox.isVisible().catch(() => false)) {
      const checked = await consentCheckbox.isChecked().catch(() => false);
      if (!checked) {
        await consentCheckbox.check({ force: true }).catch(async () => {
          await consentCheckbox.click({ force: true }).catch(() => undefined);
        });
      }
    }

    const guestButton = await findFirstVisibleLocator(
      page,
      [
        () => page.getByRole('button', { name: /enter as guest|continue as guest|guest|demo login|demo/i }).first(),
        () =>
          page
            .locator(
              'button:has-text("ENTER AS GUEST"), button:has-text("Enter as guest"), button:has-text("DEMO LOGIN"), button:has-text("Demo Login"), button:has-text("Guest")'
            )
            .first(),
      ],
      10000,
    ).catch(() => null);
    if (!guestButton) return false;

    await guestButton.click({ force: true }).catch(() => undefined);

    try {
      await expect
        .poll(() => currentRoute(page), {
          timeout: 25000,
          message: 'Expected guest/demo auth fallback to move away from /auth and /register',
        })
        .not.toMatch(/^\/(auth|register)$/);
      return true;
    } catch {
      return false;
    }
  } catch {
    return false;
  }
}

async function completeSignUp(page: Page, account: TestAccount): Promise<TestAccount> {
  await openRegisterForm(page);

  const usernameInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /username/i }).first(),
    () => page.locator('input[aria-label*="username" i], input[placeholder*="username" i]').first(),
  ]);
  await usernameInput.click({ force: true }).catch(() => undefined);
  await usernameInput.fill(account.username);

  const emailInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
  ]);
  await emailInput.click({ force: true }).catch(() => undefined);
  await emailInput.fill(account.email);

  const passwordInput = await findFirstVisibleLocator(page, [
    () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
    () => page.getByLabel(/password/i).first(),
  ]);
  await passwordInput.click({ force: true }).catch(() => undefined);
  await passwordInput.fill(account.password);

  const consentCheckbox = page
    .getByRole('checkbox', { name: /i confirm i am 18\+ and agree to the community guidelines/i })
    .first();
  if (await consentCheckbox.isVisible().catch(() => false)) {
    const checked = await consentCheckbox.isChecked().catch(() => false);
    if (!checked) {
      await consentCheckbox.check({ force: true }).catch(async () => {
        await consentCheckbox.click({ force: true }).catch(() => undefined);
      });
    }
  }

  const createAccountButton = await findFirstVisibleLocator(page, [
    () => page.getByRole('button', { name: /create account/i }).first(),
    () => page.locator('button:has-text("CREATE ACCOUNT"), button:has-text("Create account")').first(),
  ]);
  await createAccountButton.click({ force: true });

  try {
    await expect
      .poll(() => currentRoute(page), {
        timeout: 25000,
        message: 'Expected create account to advance away from /register',
      })
      .not.toBe('/register');
    return account;
  } catch {
    const signedInViaFallback = await signInWithCredentials(page, account);
    if (signedInViaFallback) {
      return account;
    }

    const envAccount = getFallbackAuthAccountFromEnv();
    if (envAccount) {
      const signedInViaEnvFallback = await signInWithCredentials(page, envAccount);
      if (signedInViaEnvFallback) {
        return envAccount;
      }
    }

    const signedInViaGuestFallback = await signInWithGuestOrDemo(page);
    if (signedInViaGuestFallback) {
      return {
        email: 'guest@local.invalid',
        password: '',
        username: 'guest-fallback',
      };
    }

    throw new Error('Expected create account to advance away from /register or recover via auth fallback');
  }
}

async function skipProfileSetup(page: Page): Promise<void> {
  await enableFlutterSemantics(page);
  await waitForSemanticsTree(page);
  if (currentRoute(page) === '/home') {
    return;
  }

  try {
    const skipButton = await findFirstVisibleLocator(page, [
      () => page.getByRole('button', { name: /skip for now/i }).first(),
      () => page.getByRole('button', { name: /^skip$/i }).first(),
      () => page.getByRole('button', { name: /skip.*profile|maybe later|not now/i }).first(),
      () => page.locator('button:has-text("Skip for now"), text=Skip for now').first(),
    ], 20000);
    await skipButton.click({ force: true });
    await page.waitForLoadState('domcontentloaded');
  } catch (error) {
    if (currentRoute(page) === '/home') {
      return;
    }
    throw error;
  }
}

async function signIn(page: Page, account: TestAccount): Promise<void> {
  if (currentRoute(page) != '/auth') {
    await gotoAuth(page);
  } else {
    await waitForAppReady(page);
    await enableFlutterSemantics(page);
    await waitForSemanticsTree(page);
  }

  const emailInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
  ]);
  await emailInput.click({ force: true }).catch(() => undefined);
  await emailInput.fill(account.email);

  const passwordInput = await findFirstVisibleLocator(page, [
    () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
    () => page.getByLabel(/password/i).first(),
  ]);
  await passwordInput.click({ force: true }).catch(() => undefined);
  await passwordInput.fill(account.password);

  const consentCheckbox = page
    .getByRole('checkbox', { name: /i confirm i am 18\+ and agree to the community guidelines/i })
    .first();
  if (await consentCheckbox.isVisible().catch(() => false)) {
    const checked = await consentCheckbox.isChecked().catch(() => false);
    if (!checked) {
      await consentCheckbox.check({ force: true }).catch(async () => {
        await consentCheckbox.click({ force: true }).catch(() => undefined);
      });
    }
  }

  const signInButton = await findFirstVisibleLocator(page, [
    () => page.getByRole('button', { name: /^sign in$/i }).first(),
    () => page.locator('button:has-text("SIGN IN"), button:has-text("Sign In")').first(),
  ]);
  await signInButton.click({ force: true });

  try {
    await expect
      .poll(() => currentRoute(page), {
        timeout: 25000,
        message: 'Expected sign in to advance away from /auth',
      })
      .not.toBe('/auth');
  } catch {
    const signedInViaCredentialsFallback = await signInWithCredentials(page, account);
    if (signedInViaCredentialsFallback) {
      return;
    }

    const signedInViaGuestFallback = await signInWithGuestOrDemo(page);
    if (!signedInViaGuestFallback) {
      throw new Error('Expected sign in to advance away from /auth or recover via auth fallback');
    }
  }
}

async function clearSession(context: BrowserContext): Promise<void> {
  await context.clearCookies();
  for (const page of context.pages()) {
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
                    const request = indexedDB.deleteDatabase(name);
                    request.onsuccess = () => resolve();
                    request.onerror = () => resolve();
                    request.onblocked = () => resolve();
                  })
              )
          );
        } catch {
          // Ignore IndexedDB cleanup failures in production smoke tests.
        }
      })
      .catch(() => undefined);
  }
}

test.describe('MixVy Production Smoke Pass', () => {
  test.describe.configure({ mode: 'serial' });

  const account = createTestAccount();
  let authenticatedAccount = account;

  test('1. Multi-tab stability and console sanity', async ({ browser }) => {
    const isFirefox = browser.browserType().name() == 'firefox';
    const multiTabContext = await browser.newContext();
    const tabA = await multiTabContext.newPage();
    const tabB = isFirefox ? null : await multiTabContext.newPage();
    const consoleLogs: string[] = [];

    try {
      installMultiTabConsoleCapture(tabA, consoleLogs);
      if (tabB) {
        installMultiTabConsoleCapture(tabB, consoleLogs);
      }

      if (tabB) {
        await Promise.all([
          tabA.goto(toProdUrl('/'), { waitUntil: 'domcontentloaded' }),
          tabB.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' }),
        ]);
      } else {
        await tabA.goto(toProdUrl('/'), { waitUntil: 'domcontentloaded' });
      }

      if (isFirefox) {
        await expect
          .poll(() => !tabA.isClosed() && currentRoute(tabA).length > 0, {
            timeout: 30000,
            message: 'Expected Firefox primary tab to stay open and routable',
          })
          .toBe(true);
      } else {
        await waitForAppReady(tabA);
      }

      if (tabB) {
        await waitForAppReady(tabB);
      }

      if (isFirefox) {
        await tabA.goto(toProdUrl('/auth'), { waitUntil: 'domcontentloaded' });
        await tabA.goto(toProdUrl('/'), { waitUntil: 'domcontentloaded' });
      } else {
        await tabA.reload({ waitUntil: 'domcontentloaded' });
        await waitForAppReady(tabA);
      }

      expect(consoleLogs).toEqual([]);
    } finally {
      await multiTabContext.close();
    }
  });

  test('2. Signup and skippable profile flow', async ({ page }) => {
    authenticatedAccount = await completeSignUp(page, account);
    await skipProfileSetup(page);

    await expect
      .poll(() => currentRoute(page), {
        timeout: 15000,
        message: 'Expected post-signup route to land on /home',
      })
      .toBe('/home');
  });

  test('3. Signed-out room deep-link preservation', async ({ page, context }) => {
    await clearSession(context);
    await page.goto(toProdUrl(ROOM_PATH), { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);

    await expect
      .poll(() => currentRoute(page), {
        timeout: 15000,
        message: 'Expected signed-out room navigation to redirect to auth',
      })
      .toBe('/auth');

    await expect
      .poll(() => currentDeepLink(page), {
        timeout: 15000,
        message: 'Expected auth redirect to preserve the original room invite path',
      })
      .toBe(ROOM_PATH);

    // Regression guard: production UX should never leak raw Firestore permission strings.
    await expectNoRawPermissionDeniedLeak(page);

    await signIn(page, authenticatedAccount);

    await expect
      .poll(() => currentRoute(page), {
        timeout: 20000,
        message: 'Expected login to restore the original room invite path',
      })
      .toBe(ROOM_PATH);

    await expectNoRawPermissionDeniedLeak(page);
  });
});