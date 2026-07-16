import { Page, expect } from '@playwright/test';

/**
 * Authenticates a user in the test environment by logging into the Flutter web app
 */
export async function authenticateTestUser(page: Page): Promise<void> {
  const testEmail = process.env.TEST_EMAIL || 'test@mixvy.local';
  const testPassword = process.env.TEST_PASSWORD || 'TestPassword123!';

  try {
    // Navigate to auth page
    await page.goto('/auth', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);

    // Wait for the app to load
    const pageContent = await page.content();
    if (!pageContent.includes('html')) {
      console.warn('Auth page may not have loaded properly');
      return;
    }

    // Look for email input field - could be in different forms depending on auth state
    const emailInputs = await page.locator('input[type="email"], input[placeholder*="mail"], input[placeholder*="Email"]').count();
    
    if (emailInputs > 0) {
      // App might be on login form
      const firstEmailInput = page.locator('input[type="email"], input[placeholder*="mail"], input[placeholder*="Email"]').first();
      
      // Try to interact with email field
      try {
        await firstEmailInput.fill(testEmail);
        await page.waitForTimeout(500);
      } catch (e) {
        console.log('Could not fill email field - app may require different auth method');
      }

      // Try to find and fill password field
      const passwordInputs = await page.locator('input[type="password"], input[placeholder*="password"]').count();
      if (passwordInputs > 0) {
        const firstPasswordInput = page.locator('input[type="password"], input[placeholder*="password"]').first();
        try {
          await firstPasswordInput.fill(testPassword);
          await page.waitForTimeout(500);
        } catch (e) {
          console.log('Could not fill password field');
        }
      }

      // Try to find and click login button
      const loginButtons = await page.locator('button:has-text("Sign In"), button:has-text("LOGIN"), button:has-text("Log In")').count();
      if (loginButtons > 0) {
        await page.locator('button:has-text("Sign In"), button:has-text("LOGIN"), button:has-text("Log In")').first().click();
        await page.waitForLoadState('networkidle');
        await page.waitForTimeout(2000);
      }
    } else {
      console.log('Email input not found on auth page - may already be authenticated or using different auth method');
    }

  } catch (error) {
    console.log(`Authentication attempt completed with status. Error details: ${error instanceof Error ? error.message : String(error)}`);
    // Continue anyway - some tests may not require authentication
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
    const hasAuthToken = await page.evaluate(() => {
      const token = localStorage.getItem('firebase:authUser:mixvy-v2');
      return !!token;
    });
    return hasAuthToken;
  } catch (error) {
    console.log('Could not check authentication status');
    return false;
  }
}
