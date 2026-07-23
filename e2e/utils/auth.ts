import { Page, expect } from '@playwright/test';

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

/**
 * Authenticates a user in the test environment by logging into the Flutter web app
 * Supports multiple fallback methods including Firebase auth and local storage injection
 */
export async function authenticateTestUser(page: Page): Promise<void> {
  const testEmail = process.env.TEST_EMAIL || 'test@example.com';
  const testPassword = process.env.TEST_PASSWORD || 'Test123456!';

  try {

    // Navigate to auth page
    await page.goto('/auth', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);

    // Method 1: Try standard email/password form
    const authSuccess = await tryEmailPasswordAuth(page, testEmail, testPassword);
    if (authSuccess) {
      console.log('✓ Authenticated via email/password form');
      return;
    }

    // Method 2: Try Firebase Auth REST API (fallback)
    const firebaseSuccess = await tryFirebaseRestAuth(page, testEmail, testPassword);
    if (firebaseSuccess) {
      console.log('✓ Authenticated via Firebase REST API');
      return;
    }

    // Method 3: Try guest access fallback
    const guestSuccess = await tryGuestAccess(page);
    if (guestSuccess) {
      console.log('✓ Accessed as guest');
      return;
    }

    console.warn('⚠ Could not authenticate - tests may require authentication');

  } catch (error) {
    console.log(`⚠ Authentication error: ${error instanceof Error ? error.message : String(error)}`);
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
      'button:has-text("SIGN IN"), button:has-text("Sign In"), button:has-text("LOGIN"), button:has-text("Log In")'
    ).first();
    await loginButton.click();

    // Verify auth success: the modern Firebase JS SDK (firebase_auth v6+) persists
    // sessions in IndexedDB, not the legacy `firebase:authUser:*` localStorage key,
    // so the real signal is GoRouter navigating away from the /auth route once the
    // app confirms the session.
    try {
      await page.waitForURL((url) => !url.pathname.includes('/auth'), { timeout: 8000 });
      return true;
    } catch {
      return false;
    }
  } catch (e) {
    return false;
  }
}

/**
 * Attempts authentication via Firebase Auth REST API (server-side fallback)
 */
async function tryFirebaseRestAuth(page: Page, email: string, password: string): Promise<boolean> {
  try {
    // Get Firebase config from window object or use hardcoded values
    const firebaseKey = process.env.FIREBASE_API_KEY || 'AIzaSyCqXHwQaMV1VvWxYnrAGqhGlx9S2K0MZZE';
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

    return true;
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
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(1000);
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
  let lastError: Error | null = null;
  
  for (let i = 0; i < maxRetries; i++) {
    try {
      await page.goto(path, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(1000);
      return;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      console.log(`Navigation attempt ${i + 1}/${maxRetries} failed for path: ${path}`);
      await page.waitForTimeout(2000 * (i + 1)); // Exponential backoff
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
