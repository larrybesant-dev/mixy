import { Page, expect } from '@playwright/test';
import { activateWorkerCredentials } from './credentials';

const AUTH_STEP_TIMEOUT_MS = 45000;

class InvalidAppEndpointError extends Error {}

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
export async function enableFlutterSemantics(page: Page): Promise<void> {
  try {
    const accessibilityButton = page.getByRole('button', {
      name: 'Enable accessibility',
    });
    if (await accessibilityButton.count()) {
      await accessibilityButton.dispatchEvent('click');
    } else {
      const semanticsPlaceholder = page.locator('flt-semantics-placeholder');
      if (await semanticsPlaceholder.count()) {
        await semanticsPlaceholder.evaluate((element) => {
          (element as HTMLElement).click();
        });
      }
    }
    await page.waitForTimeout(500);
  } catch {
    // Semantics may already be enabled, or the placeholder may not be present yet - ignore.
  }
}

export async function waitForAppReady(page: Page): Promise<void> {
  await page.waitForLoadState('domcontentloaded');
  await expect(page.locator('body')).toBeVisible({ timeout: 30000 });
  await expect
    .poll(
      async () =>
        await page
          .locator('flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input')
          .count(),
      {
        timeout: 30000,
        message: 'Expected app readiness markers to be present'
      }
    )
    .toBeGreaterThan(0);
}

async function assertMixvyAppEndpoint(page: Page): Promise<void> {
  await enableFlutterSemantics(page);
  const currentUrl = new URL(page.url());
  const title = await page.title();
  const endpointText = await page.locator('body').innerText().catch(() => '');
  const isDartDevTools =
    currentUrl.port === '9100' ||
    title.toLowerCase().includes('devtools') ||
    endpointText.includes('No client connection') ||
    endpointText.includes('page cannot be found') ||
    endpointText.includes("What's new in DevTools?");

  if (isDartDevTools) {
    throw new InvalidAppEndpointError(
      `PLAYWRIGHT_BASE_URL points to Dart DevTools (${page.url()}), not the MixVy Flutter app.`,
    );
  }

  const authControls = page.locator(
    'input[aria-label*="mail" i], input[type="email"], input[aria-label*="password" i], input[type="password"]',
  );
  const hasAuthControls = await expect
    .poll(async () => authControls.count(), {
      timeout: 30000,
      message: 'Expected MixVy email and password controls after Flutter startup',
    })
    .toBeGreaterThanOrEqual(2)
    .then(() => true)
    .catch(() => false);
  if (!hasAuthControls) {
    throw new InvalidAppEndpointError(
      `The endpoint ${page.url()} does not expose the MixVy authentication screen.`,
    );
  }
}

/**
 * Authenticates a user in the test environment by logging into the Flutter web app
 * Supports multiple fallback methods including Firebase auth and local storage injection
 */
export async function authenticateTestUser(page: Page): Promise<boolean> {
  activateWorkerCredentials();
  const testEmail = process.env.TEST_EMAIL || 'test@example.com';
  const testPassword = process.env.TEST_PASSWORD || 'Test123456!';
  const authRequired = `${process.env.AUTH_REQUIRED ?? ''}`.toLowerCase() === '1' || `${process.env.AUTH_REQUIRED ?? ''}`.toLowerCase() === 'true';

  try {

    // Navigate to auth page
    await page.goto('/auth', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    await assertMixvyAppEndpoint(page);

    // Method 1: Try standard email/password form
    const authSuccess = await withTimeout(
      tryEmailPasswordAuth(page, testEmail, testPassword),
      AUTH_STEP_TIMEOUT_MS,
      'email/password authentication'
    ).catch((error) => {
      console.warn(
        `Email/password authentication timed out: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return false;
    });
    if (authSuccess) {
      console.log('✓ Authenticated via email/password form');
      return true;
    }

    // Method 2: Try Firebase Auth REST API (fallback)
    const firebaseSuccess = await withTimeout(
      tryFirebaseRestAuth(page, testEmail, testPassword),
      AUTH_STEP_TIMEOUT_MS,
      'firebase REST authentication'
    ).catch((error) => {
      console.warn(
        `Firebase REST authentication fallback failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return false;
    });
    if (firebaseSuccess) {
      console.log('✓ Authenticated via Firebase REST API');
      return true;
    }

    if (authRequired) {
      console.warn('⚠ Could not authenticate with credentials and guest fallback is disabled (AUTH_REQUIRED=1).');
      return false;
    }

    // Method 3: Try guest access fallback
    const guestSuccess = await withTimeout(
      tryGuestAccess(page),
      AUTH_STEP_TIMEOUT_MS,
      'guest access fallback'
    ).catch(() => false);
    if (guestSuccess) {
      console.log('✓ Accessed as guest');
      return true;
    }

    console.warn('⚠ Could not authenticate - tests may require authentication');
    return false;

  } catch (error) {
    if (error instanceof InvalidAppEndpointError) {
      throw error;
    }
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

    // Real DOM attributes (verified against the live app): type="text" with an
    // empty placeholder, identified via aria-label instead (e.g. "Email address").
    const emailInput = page.locator(
      'input[aria-label*="mail" i], input[type="email"], input[placeholder*="mail" i]'
    ).first();

    if ((await emailInput.count()) === 0) {
      return false;
    }

    await emailInput.click();
    await emailInput.press('Control+A');
    await emailInput.pressSequentially(email, { delay: 10 });
    await page.waitForTimeout(500);

    // Find and fill password field
    const passwordInput = page
      .getByRole('textbox', { name: /^Password$/i })
      .or(
        page.locator(
          'input[aria-label="Password" i], input[type="password"], input[placeholder*="password" i]',
        ),
      )
      .first();
    await passwordInput.click();
    await passwordInput.press('Control+A');
    await passwordInput.pressSequentially(password, { delay: 10 });
    await page.waitForTimeout(500);

    // Find and click login button
    const loginButton = page.getByRole('button', {
      name: /^(sign in|log in|login)$/i,
    }).first();
    await loginButton.click();

    // Verify auth success: the modern Firebase JS SDK (firebase_auth v6+) persists
    // sessions in IndexedDB, not the legacy `firebase:authUser:*` localStorage key,
    // so the real signal is GoRouter navigating away from the /auth route once the
    // app confirms the session.
    try {
      await page.waitForURL((url) => !url.pathname.includes('/auth'), { timeout: 20000 });
      return true;
    } catch (error) {
      const visibleText = await page.locator('body').innerText().catch(() => '');
      console.warn(
        `Email/password authentication did not leave /auth: ${
          error instanceof Error ? error.message : String(error)
        }\nVisible UI: ${visibleText.slice(-1000)}`,
      );
      return false;
    }
  } catch (error) {
    console.warn(
      `Email/password authentication failed before navigation: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
    return false;
  }
}

/**
 * Attempts authentication via Firebase Auth REST API (server-side fallback)
 */
async function tryFirebaseRestAuth(page: Page, email: string, password: string): Promise<boolean> {
  try {
    // Get Firebase config from window object or use hardcoded values
    const firebaseKey = process.env.FIREBASE_API_KEY || 'AIzaSyCM6_Eye8JMEW7dXFpo-i-Frp4t3owyh_I';
    const firebaseProjectId = 'mixvy-v2';

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

    // Store auth tokens in localStorage
    await page.evaluate(
      ({ tokens, uid }) => {
        localStorage.setItem('firebase:authUser:mixvy-v2', JSON.stringify({
          uid,
          email: tokens.email,
          emailVerified: false,
          displayName: null,
          isAnonymous: false,
          metadata: {
            creationTime: new Date().toISOString(),
            lastSignInTime: new Date().toISOString(),
          },
          providerData: [],
          _token: tokens.idToken,
          _tokenExpirationTime: Date.now() + (3600 * 1000),
        }));
      },
      { tokens: result, uid: result.localId }
    );

    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForURL((url) => !url.pathname.includes('/auth'), { timeout: 10000 });
    await page.waitForTimeout(3000);
    return !new URL(page.url()).pathname.includes('/auth');
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
export async function safeNavigate(page: Page, path: string, maxRetries: number = 2): Promise<void> {
  let lastError: Error | null = null;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      await page.goto(path, { waitUntil: 'commit', timeout: 20000 });
      await expect(page.locator('body')).toBeVisible({ timeout: 20000 });
      await expect
        .poll(
          () => page.locator('flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input').count(),
          { timeout: 20000, message: `Expected app readiness after navigating to ${path}` },
        )
        .toBeGreaterThan(0);
      return;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      if (lastError.message.includes('NS_BINDING_ABORTED')) {
        const redirectedAppReady = await expect
          .poll(
            () => page.locator('flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input').count(),
            { timeout: 20000, message: `Expected redirected app readiness after navigating to ${path}` },
          )
          .toBeGreaterThan(0)
          .then(() => true)
          .catch(() => false);
        if (redirectedAppReady) {
          return;
        }
      }
      if (i + 1 < maxRetries) {
        await page.waitForTimeout(2000 * (i + 1));
      }
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
