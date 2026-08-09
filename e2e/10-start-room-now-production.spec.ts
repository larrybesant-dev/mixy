import { test, expect, type Locator, type Page } from '@playwright/test';

const PROD_BASE_URL = 'https://mixvy-v2.web.app';
const FIREBASE_WEB_API_KEY = (process.env.FIREBASE_API_KEY ?? '').trim();

function toProdUrl(path: string): string {
  return new URL(path, `${PROD_BASE_URL}/`).toString();
}

function isIgnorableAbort(url: string): boolean {
  return (
    /firebase\.googleapis\.com\/v1alpha\/projects\/-\/apps\/.+\/webConfig/i.test(url) ||
    /google\.firestore\.v1\.Firestore\/(Listen|Write)\/channel/i.test(url)
  );
}

function createEphemeralAccount() {
  const ts = Date.now();
  const entropy = Math.random().toString(36).slice(2, 10);
  return {
    username: `startroom${ts.toString().slice(-6)}`,
    email: `mixvy.startroom.${ts}@example.com`,
    password: `Launch${ts}${entropy}!`,
  };
}

async function bootstrapAuthSession(page: Page): Promise<boolean> {
  if (!FIREBASE_WEB_API_KEY) {
    console.warn('FIREBASE_API_KEY is not set; cannot bootstrap authenticated production session.');
    return false;
  }

  const account = createEphemeralAccount();

  try {
    const signUpResponse = await page.request.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_WEB_API_KEY}`,
      {
        data: {
          email: account.email,
          password: account.password,
          returnSecureToken: true,
        },
      }
    );

    if (!signUpResponse.ok()) {
      return false;
    }

    const result = (await signUpResponse.json()) as {
      localId?: string;
      email?: string;
      idToken?: string;
      refreshToken?: string;
      expiresIn?: string;
    };

    if (!result.idToken || !result.refreshToken || !result.localId || !result.email) {
      return false;
    }

    const expirationTime = Date.now() + Number(result.expiresIn ?? '3600') * 1000;
    const authRecord = {
      fbase_key: `firebase:authUser:${FIREBASE_WEB_API_KEY}:[DEFAULT]`,
      value: {
        uid: result.localId,
        email: result.email,
        emailVerified: false,
        displayName: null,
        isAnonymous: false,
        photoURL: null,
        providerData: [
          {
            providerId: 'password',
            uid: result.localId,
            displayName: null,
            email: result.email,
            phoneNumber: null,
            photoURL: null,
          },
        ],
        stsTokenManager: {
          refreshToken: result.refreshToken,
          accessToken: result.idToken,
          expirationTime,
        },
        createdAt: `${Date.now()}`,
        lastLoginAt: `${Date.now()}`,
        apiKey: FIREBASE_WEB_API_KEY,
        appName: '[DEFAULT]',
      },
    };

    await page.evaluate(async (record) => {
      await new Promise<void>((resolve, reject) => {
        const request = indexedDB.open('firebaseLocalStorageDb', 1);
        request.onerror = () => reject(request.error ?? new Error('Failed to open firebaseLocalStorageDb'));
        request.onupgradeneeded = () => {
          const db = request.result;
          if (!db.objectStoreNames.contains('firebaseLocalStorage')) {
            db.createObjectStore('firebaseLocalStorage', { keyPath: 'fbase_key' });
          }
        };
        request.onsuccess = () => {
          const db = request.result;
          const tx = db.transaction('firebaseLocalStorage', 'readwrite');
          const store = tx.objectStore('firebaseLocalStorage');
          store.put(record);
          tx.oncomplete = () => resolve();
          tx.onerror = () => reject(tx.error ?? new Error('Failed to write auth record'));
        };
      });
    }, authRecord);

    await page.goto(toProdUrl('/rooms/create'), { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);
    return !(await isAuthUiVisible(page));
  } catch {
    return false;
  }
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
        target.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Enter' }));
      })
      .catch(() => undefined);
  }
  await page.waitForTimeout(700);
}

async function findFirstVisibleLocator(
  page: Page,
  candidates: Array<() => Locator>,
  timeoutMs: number = 15000
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
    await page.waitForTimeout(350);
  }
  throw new Error('No visible locator found for candidate set.');
}

async function isAuthUiVisible(page: Page): Promise<boolean> {
  const authMarkers = [
    () => page.getByRole('button', { name: /^SIGN IN$/i }).first(),
    () => page.getByRole('button', { name: /^SIGN UP$/i }).first(),
    () => page.getByRole('button', { name: /Instant One-Click Demo Login/i }).first(),
    () => page.getByRole('textbox', { name: /Email address/i }).first(),
  ];

  for (const marker of authMarkers) {
    if (await marker().isVisible().catch(() => false)) {
      return true;
    }
  }
  return false;
}

async function isCreateRoomUiVisible(page: Page): Promise<boolean> {
  const roomMarkers = [
    () => page.getByRole('heading', { name: /start a room/i }).first(),
    () => page.getByRole('button', { name: /start room now|start room/i }).first(),
    () => page.getByPlaceholder(/late night music session/i).first(),
    () => page.getByText(/start a room/i).first(),
  ];

  for (const marker of roomMarkers) {
    if (await marker().isVisible().catch(() => false)) {
      return true;
    }
  }
  return false;
}

async function ensureConsentIfPresent(page: Page): Promise<void> {
  const consent = await findFirstVisibleLocator(
    page,
    [
      () => page.getByRole('checkbox', { name: /18\+|community guidelines|terms/i }).first(),
      () => page.getByText(/I confirm I am 18\+/i).first(),
      () => page.locator('input[type="checkbox"]').first(),
    ],
    6000
  ).catch(() => null);

  if (!consent) return;
  const checked = await consent
    .isChecked()
    .catch(async () => {
      const ariaChecked = await consent.getAttribute('aria-checked').catch(() => null);
      return ariaChecked?.toLowerCase() == 'true';
    });
  if (!checked) {
    await consent.check({ force: true }).catch(async () => {
      await consent.click({ force: true }).catch(() => undefined);
    });
    await page.waitForTimeout(250);
  }
}

async function attemptDemoLogin(page: Page): Promise<boolean> {
  for (let attempt = 1; attempt <= 2; attempt++) {
    await ensureConsentIfPresent(page);

    const guestButton = await findFirstVisibleLocator(page, [
      () => page.getByRole('button', { name: /instant one-click demo login|enter as guest|continue as guest|guest|demo login|demo/i }).first(),
      () =>
        page
          .locator(
            'button:has-text("Instant One-Click Demo Login"), button:has-text("ENTER AS GUEST"), button:has-text("Enter as guest"), button:has-text("DEMO LOGIN"), button:has-text("Demo Login"), button:has-text("Guest")'
          )
          .first(),
    ]).catch(() => null);

    if (!guestButton) return false;
    await guestButton.click({ force: true }).catch(() => undefined);

    try {
      await expect
        .poll(async () => !(await isAuthUiVisible(page)), {
          timeout: 30000,
          message: 'Expected demo login to dismiss auth UI',
        })
        .toBe(true);
      return true;
    } catch {
      if (attempt == 2) {
        return false;
      }
      await page.waitForTimeout(800);
    }
  }

  return false;
}

async function completeSignUp(page: Page): Promise<boolean> {
  const account = createEphemeralAccount();
  await page.goto(toProdUrl('/register'), { waitUntil: 'domcontentloaded' });
  await waitForAppReady(page);
  await enableFlutterSemantics(page);

  const usernameInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /username/i }).first(),
    () => page.locator('input[aria-label*="username" i], input[placeholder*="username" i]').first(),
  ]).catch(() => null);
  const emailInput = await findFirstVisibleLocator(page, [
    () => page.getByRole('textbox', { name: /email/i }).first(),
    () => page.locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="email" i]').first(),
  ]).catch(() => null);
  const passwordInput = await findFirstVisibleLocator(page, [
    () => page.locator('input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]').first(),
    () => page.getByLabel(/password/i).first(),
  ]).catch(() => null);

  if (!usernameInput || !emailInput || !passwordInput) {
    return false;
  }

  await usernameInput.fill(account.username);
  await emailInput.fill(account.email);
  await passwordInput.fill(account.password);
  await ensureConsentIfPresent(page);

  const createAccount = await findFirstVisibleLocator(page, [
    () => page.getByRole('button', { name: /create account/i }).first(),
    () => page.locator('button:has-text("CREATE ACCOUNT"), button:has-text("Create account"), button:has-text("SIGN UP")').first(),
  ]).catch(() => null);
  if (!createAccount) return false;

  await createAccount.click({ force: true }).catch(() => undefined);

  try {
    await expect
      .poll(async () => !(await isAuthUiVisible(page)), {
        timeout: 60000,
        message: 'Expected registration to dismiss auth UI',
      })
      .toBe(true);
    return true;
  } catch {
    return false;
  }
}

async function waitForRoomStartOutcome(page: Page, timeoutMs: number): Promise<void> {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const path = new URL(page.url()).pathname;
    if (/^\/rooms\/room\//.test(path)) {
      return;
    }

    const failureToast = page.getByText(/Failed to start room:/i).first();
    if (await failureToast.isVisible().catch(() => false)) {
      const text = await failureToast.textContent().catch(() => null);
      throw new Error(`Room creation failed in-app: ${(text ?? 'Failed to start room').trim()}`);
    }

    await page.waitForTimeout(500);
  }

  throw new Error('Expected transition into live room route after room creation');
}

test.describe('MixVy Production Start Room Flow', () => {
  test('START ROOM NOW creates room without aborted Firestore requests', async ({ page }) => {
    test.setTimeout(180000);

    const abortedRequests: string[] = [];
    const consoleFailures: string[] = [];

    page.on('requestfailed', (request) => {
      const url = request.url();
      const errorText = request.failure()?.errorText ?? '';
      if (
        /firestore|googleapis|firebase/i.test(url) &&
        /ERR_ABORTED|aborted/i.test(errorText) &&
        !isIgnorableAbort(url)
      ) {
        abortedRequests.push(`${url} :: ${errorText}`);
      }
    });

    page.on('console', (msg) => {
      if (msg.type() !== 'error') return;
      const text = msg.text();
      if (/ERR_ABORTED|firestore|fetch.*failed|permission_denied/i.test(text)) {
        consoleFailures.push(text);
      }
    });

    await page.goto(toProdUrl('/rooms/create'), { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);

    if (!(await isCreateRoomUiVisible(page))) {
      const bootstrapped = await bootstrapAuthSession(page);
      if (!bootstrapped) {
        await page.goto(toProdUrl('/rooms/create'), { waitUntil: 'domcontentloaded' });
        await waitForAppReady(page);
        await enableFlutterSemantics(page);
      }
    }

    if (!(await isCreateRoomUiVisible(page))) {
      let authResolved = false;
      for (let attempt = 1; attempt <= 2; attempt++) {
        if (!(await isAuthUiVisible(page))) {
          await page.goto(toProdUrl('/rooms/create'), { waitUntil: 'domcontentloaded' });
          await waitForAppReady(page);
          await enableFlutterSemantics(page);
        }

        const demoSignedIn = await attemptDemoLogin(page);
        if (!demoSignedIn) {
          const registered = await completeSignUp(page);
          if (!registered && attempt == 2) {
            throw new Error('Could not complete auth via demo login or sign-up fallback.');
          }
        }

        await page.goto(toProdUrl('/rooms/create'), { waitUntil: 'domcontentloaded' });
        await waitForAppReady(page);
        await enableFlutterSemantics(page);
        await expect.poll(() => new URL(page.url()).pathname, { timeout: 25000 }).toContain('/rooms/create');

        if (await isCreateRoomUiVisible(page)) {
          authResolved = true;
          break;
        }
      }

      if (!authResolved) {
        throw new Error('Auth UI remained visible on /rooms/create after login and sign-up fallbacks.');
      }
    }

    await expect
      .poll(async () => await isCreateRoomUiVisible(page), {
        timeout: 30000,
        message: 'Expected create-room form to be visible on /rooms/create before room creation.',
      })
      .toBe(true);

    const createRoomHeading = await findFirstVisibleLocator(page, [
      () => page.getByRole('heading', { name: /start a room/i }).first(),
      () => page.getByText(/start a room/i).first(),
    ], 20000);
    await expect(createRoomHeading).toBeVisible({ timeout: 10000 });

    const titleInput = await findFirstVisibleLocator(page, [
      () => page.getByPlaceholder(/late night music session/i).first(),
      () => page.locator('input[placeholder*="Late Night" i]').first(),
      () => page.getByRole('textbox').first(),
    ]);
    await titleInput.fill(`Production room ${Date.now()}`);

    const startRoomButton = await findFirstVisibleLocator(page, [
      () => page.getByRole('button', { name: /start room now|start room/i }).first(),
      () => page.locator('button:has-text("START ROOM NOW"), button:has-text("Start Room")').first(),
      () => page.getByText(/START ROOM NOW|Start Room/i).first(),
    ]);

    // Ignore earlier auth/bootstrap navigation noise and assert only on room-start window.
    abortedRequests.length = 0;
    consoleFailures.length = 0;

    await startRoomButton.click({ force: true }).catch(() => undefined);

    await waitForRoomStartOutcome(page, 90000);

    await page.waitForTimeout(3000);

    expect(abortedRequests, `Aborted Firestore/network requests: ${abortedRequests.join('\n')}`).toHaveLength(0);
    expect(consoleFailures, `Console failures after room start: ${consoleFailures.join('\n')}`).toHaveLength(0);
  });
});
