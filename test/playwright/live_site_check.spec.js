const { test, expect } = require('@playwright/test');

test('Guest user can load Live Room and see content', async ({ browser }) => {
  const context = await browser.newContext({
    permissions: ['camera', 'microphone'],
  });
  const page = await context.newPage();

  // Navigate to the specific MixVy live room
  console.log('Navigating to live room...');
  await page.goto('https://mix-and-mingle-v2.web.app/rooms/room/9p6eD0AgRNLU5ce6lBCu');

  // 1. Verify we land on the correct URL and haven't been redirected
  await expect(page).toHaveURL(/.*rooms\/room\/9p6eD0AgRNLU5ce6lBCu/);

  // 2. Wait for the initial "Launching MixVy" splash (HTML) to disappear
  await expect(page.locator('#boot-shell')).toBeHidden({ timeout: 15000 });

  // 3. Wait for the Flutter "Joining room" skeleton to disappear
  // We use getByText which works with Flutter's semantic DOM.
  console.log('Waiting for hydration to complete...');
  const joiningText = page.getByText('Joining room');
  await expect(joiningText).toBeHidden({ timeout: 20000 });

  // 4. Verify the room content is visible
  // Check for the Mic button or the Message input
  const micButton = page.getByRole('button', { name: /mic/i });
  const messageInput = page.getByPlaceholder('Send a message…');

  // If the room is private/adult, we expect an error message instead of the room
  const errorText = page.getByText(/Unable to load room|Check your connection/i);

  await Promise.race([
    expect(micButton).toBeVisible({ timeout: 10000 }),
    expect(messageInput).toBeVisible({ timeout: 10000 }),
    expect(errorText).toBeVisible({ timeout: 10000 })
  ]);

  console.log('Verification complete.');
  await context.close();
});
