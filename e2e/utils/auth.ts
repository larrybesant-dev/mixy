import { Page, expect } from '@playwright/test';

const DEFAULT_AUTH_STEP_TIMEOUT_MS = 45000;
const FIREFOX_AUTH_STEP_TIMEOUT_MS = 90000;
const DEFAULT_READY_TIMEOUT_MS = 30000;
const FIREFOX_READY_TIMEOUT_MS = 60000;
const DEFAULT_NAVIGATION_TIMEOUT_MS = 30000;
const FIREFOX_NAVIGATION_TIMEOUT_MS = 45000;

function envValue(name: string): string {
  return (process.env[name] ?? '').trim();
}

function browserName(page: Page): string {
  return page.context().browser()?.browserType().name() ?? 'unknown';
}

function isFirefox(page: Page): boolean {
  return browserName(page) === 'firefox';
}

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, label: string): Promise<T> {
  return await Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
    }),
  ]);
}

/**
 * Flutter Web (CanvasKit) renders the UI to a <canvas> and does not expose real
 * interactive DOM elements until its semantics/accessibility tree is activated.
 * Until then, the only real element in the DOM is a <flt-semantics-placeholder>
 * used to detect assistive technology. Playwright's actionability checks refuse
 * to click it directly (it reports as "outside the viewport"), so we dispatch a
 * synthetic click at its bounding box instead. This must run before any
 * input/button locators are used against the app.
 */
async function enableFlutterSemantics(page: Page): Promise<void> {
  try {
    await page.evaluate(() => {
      const el = document.querySelector('flt-semantics-placeholder') as HTMLElement | null;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      el.dispatchEvent(new MouseEvent('click', {
        bubbles: true,
        clientX: rect.left + 1,
        clientY: rect.top + 1,
      }));
    });
    await page.waitForTimeout(500);
  } catch {
    // Semantics may already be enabled, or the placeholder may not be present yet - ignore.
  }
}

async function waitForAppReady(page: Page): Promise<void> {
  const readyTimeout = isFirefox(page)
    ? FIREFOX_READY_TIMEOUT_MS
    : DEFAULT_READY_TIMEOUT_MS;

  await page.waitForLoadState('domcontentloaded');
  await expect(page.locator('body')).toBeVisible({ timeout: readyTimeout });
  await expect
    .poll(
      async () =>
        await page
          .locator('flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input')
          .count(),
      {
        timeout: readyTimeout,
        message: 'Expected app readiness markers to be present'
      }
    )
    .toBeGreaterThan(0);
}

/**
 * Authenticates a user in the test environment by logging into the Flutter web app
 * Supports multiple fallback methods including Firebase auth and local storage injection
 */
export async function authenticateTestUser(page: Page): Promise<boolean> {
  const testEmail = envValue('TEST_EMAIL');
  const testPassword = envValue('TEST_PASSWORD');
  const authRequired = `${process.env.AUTH_REQUIRED ?? ''}`.toLowerCase() === '1' || `${process.env.AUTH_REQUIRED ?? ''}`.toLowerCase() === 'true';
  const authStepTimeout = isFirefox(page)
    ? FIREFOX_AUTH_STEP_TIMEOUT_MS
    : DEFAULT_AUTH_STEP_TIMEOUT_MS;

  try {

    // Navigate to auth page
    await page.goto('/auth', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(isFirefox(page) ? 3500 : 2000);

    if (testEmail && testPassword) {
      // Method 1: Try standard email/password form
      const authSuccess = await withTimeout(
        tryEmailPasswordAuth(page, testEmail, testPassword),
        authStepTimeout,
        'email/password authentication'
      ).catch(() => false);
      if (authSuccess) {
        console.log('✓ Authenticated via email/password form');
        return true;
      }

      // Method 2: Try Firebase Auth REST API (fallback)
      const firebaseSuccess = await withTimeout(
        tryFirebaseRestAuth(page, testEmail, testPassword),
        authStepTimeout,
        'firebase REST authentication'
      ).catch(() => false);
      if (firebaseSuccess) {
        console.log('✓ Authenticated via Firebase REST API');
        return true;
      }
    } else if (authRequired) {
      console.warn('⚠ Missing required TEST_EMAIL/TEST_PASSWORD for AUTH_REQUIRED=1.');
      return false;
    } else {
      console.log('ℹ TEST_EMAIL/TEST_PASSWORD not set; skipping credentialed auth attempts.');
    }

    if (authRequired) {
      console.warn('⚠ Could not authenticate with credentials and guest fallback is disabled (AUTH_REQUIRED=1).');
      return false;
    }

    // Method 3: Try guest access fallback
    const guestSuccess = await withTimeout(
      tryGuestAccess(page),
      authStepTimeout,
      'guest access fallback'
    ).catch(() => false);
    if (guestSuccess) {
      console.log('✓ Accessed as guest');
      return true;
    }

    console.warn('⚠ Could not authenticate - tests may require authentication');
    return false;

  } catch (error) {
    console.log(`⚠ Authentication error: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

/**
 * Attempts email/password authentication via the UI
 */
async function tryEmailPasswordAuth(page: Page, email: string, password: string): Promise<boolean> {
  try {
    // Flutter Web doesn't expose real <input>/<button> DOM nodes until semantics
    // are activated - do this first or every locator below finds nothing.
    await enableFlutterSemantics(page);
    await ensureAuthFormVisible(page);

    // Real DOM attributes (verified against the live app): type="text" with an
    // empty placeholder, identified via aria-label instead (e.g. "Email address").
    const emailInput = page.locator(
      'input[aria-label*="mail" i], input[type="email"], input[placeholder*="mail" i]'
    ).first();

    if ((await emailInput.count()) === 0) {
      return false;
    }

    await emailInput.fill(email);
    await page.waitForTimeout(500);

    // Find and fill password field
    const passwordInput = page.locator(
      'input[aria-label*="password" i], input[type="password"], input[placeholder*="password" i]'
    ).first();
    await passwordInput.fill(password);
    await page.waitForTimeout(500);

    // Find and click login button
    const loginButton = page.locator(
      'button:has-text("SIGN IN"), button:has-text("Sign In"), button:has-text("SIGN IN / UP"), button:has-text("Sign In / Up"), button:has-text("LOGIN"), button:has-text("Log In")'
    ).first();
    await loginButton.click();

    // Verify auth success: the modern Firebase JS SDK (firebase_auth v6+) persists
    // sessions in IndexedDB, not the legacy `firebase:authUser:*` localStorage key,
    // so the real signal is GoRouter navigating away from the /auth route once the
    // app confirms the session.
    try {
      await Promise.race([
        page.waitForURL((url) => !url.pathname.includes('/auth'), { timeout: 8000 }),
        expect
          .poll(
            async () => {
              const authInputsVisible = await page
                .locator('input[aria-label*="mail" i], input[type="email"], input[placeholder*="mail" i]')
                .first()
                .isVisible()
                .catch(() => false);
              const composerVisible = await page
                .locator('text=Share your latest broadcast, text=Share your latest')
                .first()
                .isVisible()
                .catch(() => false);
              return !authInputsVisible && composerVisible;
            },
            {
              timeout: 8000,
              message: 'Expected auth form to close and authenticated shell to appear',
            }
          )
          .toBeTruthy(),
      ]);
      return true;
    } catch {
      return false;
    }
  } catch (e) {
    return false;
  }
}

async function ensureAuthFormVisible(page: Page): Promise<void> {
  const emailInput = page.locator(
    'input[aria-label*="mail" i], input[type="email"], input[placeholder*="mail" i]'
  ).first();

  if (await emailInput.isVisible().catch(() => false)) {
    return;
  }

  const signInTrigger = page.locator(
    'button:has-text("Sign In / Up"), button:has-text("SIGN IN / UP"), button:has-text("SIGN IN"), button:has-text("Sign In"), button[title*="sign in" i]'
  ).first();

  if (await signInTrigger.isVisible().catch(() => false)) {
    await signInTrigger.click();
    await page.waitForTimeout(500);
  }

  const signInTab = page.locator(
    'button:has-text("SIGN IN"), button:has-text("Sign In"), [role="tab"]:has-text("SIGN IN"), [role="tab"]:has-text("Sign In")'
  ).first();

  if (await signInTab.isVisible().catch(() => false)) {
    await signInTab.click().catch(() => undefined);
  }

  await expect(emailInput).toBeVisible({ timeout: 5000 });
}

/**
 * Attempts authentication via Firebase Auth REST API (server-side fallback)
 */
async function tryFirebaseRestAuth(page: Page, email: string, password: string): Promise<boolean> {
  try {
    const firebaseKey = envValue('FIREBASE_API_KEY');
    if (!firebaseKey) {
      return false;
    }

    const response = await page.request.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseKey}`,
      {
        data: {
          email,
          password,
          returnSecureToken: true,
        },
      }
    );

    if (!response.ok()) {
      return false;
    }

    const result = await response.json() as any;
    
    if (!result.idToken) {
      return false;
    }

    const expirationTime = Date.now() + (Number(result.expiresIn ?? 3600) * 1000);
    const authRecord = {
      fbase_key: `firebase:authUser:${firebaseKey}:[DEFAULT]`,
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
        apiKey: firebaseKey,
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

    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1500);
    await page.goto('/profile', { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);

    return !(new URL(page.url()).pathname.includes('/auth'));
  } catch (e) {
    return false;
  }
}

/**
 * Attempts to access as guest
 */
async function tryGuestAccess(page: Page): Promise<boolean> {
  try {
    // Look for guest/anonymous login button
    const guestButton = page.locator('button:has-text("Guest"), button:has-text("GUEST"), button:has-text("Enter as Guest"), text=ENTER AS GUEST').first();
    
    if (await guestButton.isVisible().catch(() => false)) {
      await guestButton.click();
      await waitForAppReady(page);
      return true;
    }

    return false;
  } catch (e) {
    return false;
  }
}

/**
 * Navigates to a page with retry logic
 */
export async function safeNavigate(page: Page, path: string, maxRetries: number = 3): Promise<void> {
  const navigationTimeout = isFirefox(page)
    ? FIREFOX_NAVIGATION_TIMEOUT_MS
    : DEFAULT_NAVIGATION_TIMEOUT_MS;
  const effectiveRetries = isFirefox(page)
    ? Math.max(maxRetries, 5)
    : maxRetries;

  let lastError: Error | null = null;
  
  for (let i = 0; i < effectiveRetries; i++) {
    try {
      await page.goto(path, { waitUntil: 'domcontentloaded', timeout: navigationTimeout });
      await waitForAppReady(page);

      const bodyText = (await page.locator('body').innerText().catch(() => '')).trim();
      if (/^not found$/i.test(bodyText)) {
        throw new Error(
          `Reached a Not Found page while navigating to '${path}'. Verify baseURL/hosting rewrites and deep-link support.`
        );
      }
      return;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      console.log(`Navigation attempt ${i + 1}/${effectiveRetries} failed for path: ${path}`);

      const backoffMs = Math.min(1500, 500 * (i + 1));
      await page.waitForTimeout(backoffMs);
    }
  }
  
  if (lastError) {
    throw lastError;
  }
}

/**
 * Checks if user is authenticated by looking for auth tokens in local storage
 */
export async function isUserAuthenticated(page: Page): Promise<boolean> {
  try {
    // The modern Firebase JS SDK (firebase_auth v6+) persists sessions in
    // IndexedDB, not the legacy `firebase:authUser:*` localStorage key. The
    // reliable signal available to Playwright is whether the app is currently
    // sitting on the /auth route (unauthenticated) or not.
    return !new URL(page.url()).pathname.includes('/auth');
  } catch (error) {
    console.log('Could not check authentication status');
    return false;
  }
}
