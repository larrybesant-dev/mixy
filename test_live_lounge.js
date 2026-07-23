import { chromium } from 'playwright';

(async () => {
  console.log('--- STARTING LIVE LOUNGE DIAGNOSTIC TEST ---');
  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    // 1. Console Telemetry Catch
    page.on('console', msg => {
      console.log(`[BROWSER CONSOLE] [${msg.type().toUpperCase()}] ${msg.text()}`);
    });

    // 2. Unhandled Exception Catch
    page.on('pageerror', err => {
      console.error(`[BROWSER EXCEPTION] FATAL: ${err.message}`);
    });

    // 3. Failed Network Catch (DNS/Timeout/etc)
    page.on('requestfailed', request => {
      console.error(`[NETWORK FAILED] ${request.url()} - ${request.failure()?.errorText}`);
    });

    // 4. HTTP Errors (401, 404, 500, etc.)
    page.on('response', response => {
      if (response.status() >= 400) {
        console.error(`[NETWORK ERROR] ${response.status()} ${response.url()}`);
      }
    });

    // 5. Navigate to Live URL
    console.log('Navigating to https://mix-and-mingle-v2.web.app/auth ...');
    await page.goto('https://mix-and-mingle-v2.web.app/auth', { waitUntil: 'networkidle', timeout: 45000 });
    console.log('Page loaded. Waiting for Flutter web engine to initialize...');

    // Allow time for Flutter to bootstrap and draw its canvas
    await page.waitForTimeout(10000);

    // 6. Attempt layout tab interaction
    // Since Flutter Web uses a canvas, standard DOM clicks are hard to map without semantics.
    // We will simulate clicks across the screen to trigger the UI (tabs).
    console.log('Simulating interactions with the layout canvas...');
    const viewportSize = page.viewportSize();
    if (viewportSize) {
      // Click middle
      await page.mouse.click(viewportSize.width / 2, viewportSize.height / 2);
      await page.waitForTimeout(1000);
      // Click near top (common tab area)
      await page.mouse.click(viewportSize.width / 2, 50);
      await page.waitForTimeout(1000);
      // Click near bottom
      await page.mouse.click(viewportSize.width / 2, viewportSize.height - 50);
    }

    // Final wait to catch cascading errors after interaction
    await page.waitForTimeout(5000);

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
