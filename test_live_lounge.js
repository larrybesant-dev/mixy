import { chromium } from 'playwright';

(async () => {
  console.log('--- STARTING LIVE LOUNGE DIAGNOSTIC TEST (PROFILE DIRECT LINK FLOW) ---');
  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    page.on('console', msg => {
      const text = msg.text();
      if (msg.type() === 'error' || msg.type() === 'warning' || text.includes('FLUTTER') || text.includes('EXCEPTION') || text.includes('Null')) {
          console.log(`[BROWSER CONSOLE] [${msg.type().toUpperCase()}] ${text}`);
      }
    });

    console.log('1. Registering dummy user to get auth state...');
    await page.goto('https://mix-and-mingle-v2.web.app/register', { waitUntil: 'networkidle', timeout: 45000 });
    await page.waitForTimeout(5000);

    // Attempt registration
    const timestamp = Date.now();
    const username = `qatest${timestamp.toString().slice(-6)}`;
    const email = `qa_${timestamp}@mixvy.com`;
    const password = 'TestPassword123!';

    const viewportSize = page.viewportSize();
    if (viewportSize) {
      await page.mouse.click(viewportSize.width / 2, 10);
    }
    await page.waitForTimeout(500);

    for(let i=0; i<3; i++) {
        await page.keyboard.press('Tab');
        await page.waitForTimeout(200);
    }
    await page.keyboard.type(username);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(200);
    await page.keyboard.type(email);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(200);
    await page.keyboard.type(password);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(200);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(200);
    await page.keyboard.press('Enter');

    console.log('Waiting for auth to settle...');
    await page.waitForTimeout(8000);

    console.log('2. Navigating to the specific profile page...');
    await page.goto('https://mix-and-mingle-v2.web.app/profile/m6UgL5O1Z8ZjOmvEHxvz7oX2wkm2', { waitUntil: 'networkidle', timeout: 45000 });

    await page.waitForTimeout(10000);
    console.log('Test interaction sequence complete.');

  } catch (error) {
    console.error(`[TEST RUNNER EXCEPTION] ${error.message}`);
  } finally {
    if (browser) {
      console.log('Closing browser...');
      await browser.close();
    }
    console.log('--- TEST COMPLETE ---');
  }
})();
