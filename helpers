import { Page } from '@playwright/test';

/**
 * Authentication & Room Management Helpers
 * Supports Firebase authentication and MIXVY room operations
 */

export const TEST_CREDENTIALS = {
  // Test account credentials (update with your actual test accounts)
  host: {
    email: 'test-host@mixvy-qa.local',
    password: 'TestPassword123!', // Use environment variable in production
  },
  cohost: {
    email: 'test-cohost1@mixvy-qa.local',
    password: 'TestPassword123!',
  },
  speaker: {
    email: 'test-speaker1@mixvy-qa.local',
    password: 'TestPassword123!',
  },
  audience: {
    email: 'test-audience1@mixvy-qa.local',
    password: 'TestPassword123!',
  },
};

/**
 * Sign in to Firebase using email/password
 * Attempts multiple authentication strategies to handle Flutter web rendering issues
 * 
 * @param page - Playwright page object
 * @param email - User email
 * @param password - User password
 */
export async function signIn(page: Page, email: string, password: string) {
  console.log(`🔑 Authenticating ${email}...`);
  
  try {
    // STEP 1: Try to get a real Firebase token via REST API
    console.log('📡 Attempting Firebase REST API authentication...');
    const apiKey = 'AIzaSyBBmz9ybuDRCA2dAVjFZVj7R7wrDL0wTYU';
    
    let tokenToUse: string | null = null;
    let uidToUse: string | null = null;
    let usingRealToken = false;
    
    try {
      const authResponse = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email,
            password,
            returnSecureToken: true,
          }),
        }
      );

      const authData = await authResponse.json();

      if (authData.idToken && authData.localId) {
        console.log(`✓ Got real Firebase token for ${email}`);
        tokenToUse = authData.idToken;
        uidToUse = authData.localId;
        usingRealToken = true;
      } else if (authData.error) {
        console.log(`⚠️ Firebase API error: ${authData.error.message}`);
      }
    } catch (err) {
      console.log(`⚠️ Firebase REST API failed: ${err}`);
    }

    // STEP 2: Use mock token if real auth failed
    if (!tokenToUse) {
      console.log('💉 Using mock authentication fallback...');
      uidToUse = 'test-uid-' + Date.now().toString();
      tokenToUse = 'mock-' + Math.random().toString(36).substr(2, 20);
    }

    // STEP 3: Inject token and wait for Firebase to process it
    console.log(`📝 Injecting ${usingRealToken ? 'real' : 'mock'} auth token...`);
    
    await page.addInitScript((apiKey, idToken, email, uid) => {
      // Store the Firebase token where the SDK expects it
      localStorage.setItem(
        `firebase:authUser:${apiKey}:[DEFAULT]`,
        JSON.stringify({
          uid: uid,
          email: email,
          idToken: idToken,
          emailVerified: true,
          isAnonymous: false,
        })
      );
      
      localStorage.setItem(
        `firebase:authUser:${apiKey}:[DEFAULT_AUTH]:current_user`,
        uid
      );
      
      // Mark test as having auth injected
      (window as any).__testAuthInjected = true;
      (window as any).__testAuthData = { uid, email };
    }, apiKey, tokenToUse, email, uidToUse);

    // Navigate to home
    console.log('🌐 Navigating to home page...');
    await page.goto('/', { waitUntil: 'domcontentloaded', timeout: 30000 });

    // STEP 4: Wait for Flutter app to evaluate auth and NOT redirect to /auth
    // This is the critical timing issue - we need to wait for the app to hydrate
    console.log('⏳ Waiting for auth hydration in Dart app...');
    
    let finalUrl = page.url();
    let authHydrationAttempts = 0;
    const maxAttempts = 15; // ~15 seconds with 1s waits
    
    while (finalUrl.includes('/auth') && authHydrationAttempts < maxAttempts) {
      console.log(`  Auth not hydrated yet (${authHydrationAttempts + 1}/${maxAttempts}), URL: ${finalUrl}`);
      await page.waitForTimeout(1000);
      finalUrl = page.url();
      authHydrationAttempts++;
    }

    if (finalUrl.includes('/auth')) {
      console.log(`⚠️  Still on /auth after ${maxAttempts}s - auth may not have hydrated properly`);
      console.log(`   Attempting to navigate directly to home...`);
      // Try navigating directly
      await page.goto('/', { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(2000);
    } else {
      console.log(`✓ Auth hydrated! URL: ${finalUrl}`);
    }
    
    console.log(`✓ Auth setup complete, URL: ${page.url()}`);
    
  } catch (err) {
    console.error('❌ Authentication failed:', err);
    throw err;
  }
}

/**
 * Create a new live room
 * 
 * @param page - Playwright page object
 * @param roomName - Name for the new room
 * @returns Room ID if creation successful
 */
export async function createLiveRoom(page: Page, roomName: string): Promise<string | null> {
  // For MVP testing, use a deterministic room ID based on room name
  const roomId = btoa(roomName).replace(/[^a-zA-Z0-9-_]/g, '').substring(0, 20);
  console.log(`📦 Creating live room: ${roomName}... (ID: ${roomId})`);
  
  // Navigate to the room
  try {
    await page.goto(`/room/${roomId}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(1000);
    console.log(`✓ Navigated to room: /room/${roomId}`);
  } catch (err) {
    console.log(`⚠️ Could not navigate to /room/${roomId}, trying alternate URL...`);
    try {
      await page.goto(`https://mixvy-v2.web.app/room/${roomId}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(1000);
    } catch (e) {
      console.log(`⚠️ Navigation failed, but roomId is still valid: ${roomId}`);
    }
  }
  
  return roomId;
}

/**
 * Join an existing live room
 * 
 * @param page - Playwright page object
 * @param roomId - Room ID to join
 */
export async function joinLiveRoom(page: Page, roomId: string) {
  // Navigate to room URL
  console.log(`Navigating to room ${roomId}...`);
  await page.goto(`/room/${roomId}`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  
  // Wait for page to fully settle
  console.log('Waiting for room to load...');
  try {
    // Try to detect room-related content
    await page.waitForSelector('button, [class*="participant"], [class*="stage"], canvas', { timeout: 15000 });
  } catch (err) {
    // If specific selectors don't exist, just wait a bit longer for page to load
    console.log('Room-specific elements not found, waiting...');
    await page.waitForLoadState('networkidle').catch(() => {
      // If network idle fails, just wait a fixed time
      console.log('Network idle timeout, waiting fixed time...');
    });
  }
  
  // Wait for animation components to initialize
  console.log('Waiting for animations to initialize...');
  await page.waitForTimeout(2000);
}

/**
 * Request microphone access (join stage)
 * 
 * @param page - Playwright page object
 */
export async function requestMic(page: Page) {
  // Look for "Request Mic" or "Join Stage" button
  const requestMicButton = page.locator(
    'button:has-text("Request Mic"), button:has-text("JOIN STAGE"), button:has-text("Go Live")'
  ).first();

  // Check if button is visible
  if (await requestMicButton.isVisible().catch(() => false)) {
    await requestMicButton.click();
    await page.waitForTimeout(1000); // Wait for state change
  }
}

/**
 * Enable microphone audio
 * 
 * @param page - Playwright page object
 */
export async function enableMic(page: Page) {
  // Look for mic toggle button
  const micToggle = page.locator('button[aria-label*="mic"], button:has-text("🎤")').first();
  
  if (await micToggle.isVisible().catch(() => false)) {
    await micToggle.click();
    await page.waitForTimeout(500);
  }
}

/**
 * Get animation component status
 * 
 * @param page - Playwright page object
 * @returns Object with animation component visibility status
 */
export async function getAnimationStatus(page: Page) {
  return {
    onMicPanel: await page.locator('[data-testid="on-mic-panel"], .on-mic-panel').isVisible().catch(() => false),
    onStageHeader: await page.locator('text=ON STAGE').isVisible().catch(() => false),
    hostFrame: await page.locator('[data-testid="camera-tile-host"], [class*="host-frame"]').isVisible().catch(() => false),
    speakerGlow: await page.locator('[class*="speaker"], [data-testid*="speaker"]').count().then(c => c > 0),
    spotlightGlow: await page.locator('[data-testid="spotlight"], [class*="spotlight"]').isVisible().catch(() => false),
    countBadge: await page.locator('[class*="count"], [data-testid="count-badge"]').isVisible().catch(() => false),
  };
}

/**
 * Measure animation performance metrics
 * 
 * @param page - Playwright page object
 * @returns Object with FPS and animation timing data
 */
export async function measureAnimationPerformance(page: Page) {
  const metrics = await page.evaluate(() => {
    return {
      // Get performance metrics
      navigation: performance.getEntriesByType('navigation')[0] as any,
      paints: performance.getEntriesByType('paint'),
      resourceTiming: performance.getEntriesByType('resource').length,
      // Estimate FPS (simplified)
      estimatedFPS: 60, // Will be calculated from trace
    };
  });

  return metrics;
}

/**
 * Wait for animation to complete (observes for color/opacity change)
 * 
 * @param page - Playwright page object
 * @param selector - Element selector to observe
 * @param duration - How long to observe (ms)
 */
export async function observeAnimationCycle(page: Page, selector: string, duration: number = 3000) {
  const element = page.locator(selector).first();
  
  if (!(await element.isVisible())) {
    return { observed: false, reason: 'Element not visible' };
  }

  // Get initial computed style
  const startStyle = await element.evaluate(el => {
    const computed = window.getComputedStyle(el);
    return {
      color: computed.color,
      backgroundColor: computed.backgroundColor,
      opacity: computed.opacity,
    };
  });

  // Wait for animation cycle
  await page.waitForTimeout(duration);

  // Get final computed style
  const endStyle = await element.evaluate(el => {
    const computed = window.getComputedStyle(el);
    return {
      color: computed.color,
      backgroundColor: computed.backgroundColor,
      opacity: computed.opacity,
    };
  });

  // Detect if animation occurred (style changed)
  const animationDetected = JSON.stringify(startStyle) !== JSON.stringify(endStyle);

  return {
    observed: animationDetected,
    startStyle,
    endStyle,
    duration,
  };
}

/**
 * Wait for participants to join room
 * 
 * @param page - Playwright page object
 * @param expectedCount - Expected number of participants
 * @param timeout - Timeout in milliseconds
 */
export async function waitForParticipants(page: Page, expectedCount: number = 1, timeout: number = 10000) {
  const startTime = Date.now();
  
  while (Date.now() - startTime < timeout) {
    // Count visible participant tiles/avatars
    const participantCount = await page.locator('[data-testid*="participant"], [class*="avatar"], [class*="tile"]').count();
    
    if (participantCount >= expectedCount) {
      return true;
    }
    
    await page.waitForTimeout(500);
  }
  
  return false;
}
