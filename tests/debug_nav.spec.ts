import { test } from '@playwright/test';

test('debug navigation transitions', async ({ page }) => {
  const transitions: string[] = [];
  page.on('framenavigated', frame => {
    if (frame === page.mainFrame()) {
      transitions.push(page.url());
      console.log(`NAVIGATED TO: ${page.url()}`);
    }
  });

  console.log('STARTING NAVIGATION TO ROOT');
  await page.goto('https://mix-and-mingle-v2.web.app/');

  await page.waitForTimeout(10000);
  console.log('TRANSITIONS RECORDED:', transitions);
});
